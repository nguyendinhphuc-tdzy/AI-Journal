"""Backend API tests use temporary SQLite, NEVER the shared Supabase DB."""
from pathlib import Path
from uuid import uuid4
import os
import tempfile

from alembic import command
from alembic.config import Config

fd, db_path = tempfile.mkstemp(suffix=".db")
os.close(fd)
os.environ["DATABASE_URL"] = f"sqlite:///{db_path}"
os.environ["MIGRATION_DATABASE_URL"] = f"sqlite:///{db_path}"

backend_dir = Path(__file__).resolve().parents[1]
config = Config(str(backend_dir / "alembic.ini"))
config.set_main_option("script_location", str(backend_dir / "alembic"))
command.upgrade(config, "head")

from fastapi.testclient import TestClient  # noqa: E402
from app.core.auth import AuthenticatedUser, get_current_user  # noqa: E402
from app.main import app  # noqa: E402

client = TestClient(app)


def teardown_module():
    from app.core.database import engine

    app.dependency_overrides.clear()
    engine.dispose()
    Path(db_path).unlink(missing_ok=True)


def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_migration_applied():
    from sqlalchemy import text
    from app.core.database import engine

    with engine.connect() as conn:
        revision = conn.execute(text("SELECT version_num FROM alembic_version")).scalar_one()
        tables = conn.execute(text("SELECT name FROM sqlite_master WHERE type='table'")).scalars().all()
    assert revision == "20261018_06"
    assert "journal_entries" in tables
    assert "user_profiles" in tables
    assert "journal_action_days" in tables
    assert "saved_places" in tables
    assert "place_notes" in tables
    assert "journal_places" in tables


def test_public_mock_ai_preserved():
    deeper = client.post(
        "/api/v1/ai/go-deeper",
        json={"content": "I felt peaceful today."},
    )
    assert deeper.status_code == 200
    assert deeper.json()["question"]

    reflection = client.post(
        "/api/v1/ai/reflection",
        json={"content": "I finished my task.", "mood": "relieved"},
    )
    assert reflection.status_code == 200
    assert reflection.json()["emotion"] == "relieved"


def test_journal_crud_requires_authentication():
    app.dependency_overrides.clear()
    assert client.get("/api/v1/journals").status_code == 401
    assert client.post("/api/v1/journals", json={"content": "private"}).status_code == 401
    assert client.get("/api/v1/journals/1").status_code == 401
    assert client.put("/api/v1/journals/1", json={"content": "private"}).status_code == 401
    assert client.delete("/api/v1/journals/1").status_code == 401


def test_journal_crud_is_owner_scoped():
    user_a = AuthenticatedUser(user_id=uuid4(), email="a@example.com")
    user_b = AuthenticatedUser(user_id=uuid4(), email="b@example.com")

    app.dependency_overrides[get_current_user] = lambda: user_a
    try:
        a = client.post("/api/v1/journals", json={"title": "Owner A", "content": "A's diary", "mood": "calm"})
        assert a.status_code == 201, a.text
        aid = a.json()["id"]
        assert "user_id" not in a.json()
        assert client.get(f"/api/v1/journals/{aid}").status_code == 200
        assert client.put(f"/api/v1/journals/{aid}", json={"content": "Updated A"}).status_code == 200
        assert client.put(f"/api/v1/journals/{aid}", json={"content": None}).status_code == 422
        assert client.put(f"/api/v1/journals/{aid}", json={"title": None}).status_code == 422

        # An input user_id must never be permitted to override the verified JWT.
        assert client.post("/api/v1/journals", json={
            "content": "Injected", "user_id": str(user_b.user_id)
        }).status_code == 422
        assert client.put(f"/api/v1/journals/{aid}", json={
            "user_id": str(user_b.user_id)
        }).status_code == 422

        assert client.post("/api/v1/journals", json={"content": "   "}).status_code == 422
    finally:
        app.dependency_overrides.clear()

    app.dependency_overrides[get_current_user] = lambda: user_b
    try:
        assert client.get(f"/api/v1/journals/{aid}").status_code == 404
        assert client.put(f"/api/v1/journals/{aid}", json={"content": "steal"}).status_code == 404
        assert client.delete(f"/api/v1/journals/{aid}").status_code == 404
        page = client.get("/api/v1/journals")
        assert page.status_code == 200
        assert page.json() == {"items": [], "next_cursor": None}
        b = client.post("/api/v1/journals", json={"content": "Owner B diary"})
        assert b.status_code == 201
        bid = b.json()["id"]
        assert bid != aid
    finally:
        app.dependency_overrides.clear()

    app.dependency_overrides[get_current_user] = lambda: user_a
    try:
        page = client.get("/api/v1/journals")
        assert page.status_code == 200
        assert all(entry["id"] != bid for entry in page.json()["items"])
        assert any(entry["id"] == aid for entry in page.json()["items"])
        assert client.delete(f"/api/v1/journals/{aid}").status_code == 204
        assert client.get(f"/api/v1/journals/{aid}").status_code == 404
    finally:
        app.dependency_overrides.clear()


def test_journal_archive_pagination_and_filters():
    from datetime import datetime
    from zoneinfo import ZoneInfo

    user = AuthenticatedUser(user_id=uuid4(), email="search@example.com")
    app.dependency_overrides[get_current_user] = lambda: user
    try:
        for title, content, mood in [
            ("Reading cafe", "quiet coffee", "calm"),
            ("Busy meeting", "challenging call", "tense"),
            ("Book cafe", "coffee and books", "calm"),
        ]:
            response = client.post("/api/v1/journals", json={
                "title": title, "content": content, "mood": mood
            })
            assert response.status_code == 201, response.text

        first = client.get("/api/v1/journals", params={"limit": 2})
        assert first.status_code == 200
        body = first.json()
        assert len(body["items"]) == 2
        assert body["next_cursor"]
        second = client.get("/api/v1/journals", params={
            "limit": 2, "cursor": body["next_cursor"]
        })
        assert second.status_code == 200
        assert len(second.json()["items"]) == 1
        assert second.json()["next_cursor"] is None
        ids = [x["id"] for x in body["items"] + second.json()["items"]]
        assert len(ids) == len(set(ids)) == 3

        calm = client.get("/api/v1/journals", params={"mood": "calm"})
        assert len(calm.json()["items"]) == 2
        coffee = client.get("/api/v1/journals", params={"q": "coffee"})
        assert len(coffee.json()["items"]) == 2

        stamp = datetime.fromisoformat(body["items"][0]["created_at"].replace("Z", "+00:00"))
        local_date = stamp.astimezone(ZoneInfo("Asia/Ho_Chi_Minh")).date().isoformat()
        dates = client.get("/api/v1/journals", params={
            "from": local_date, "to": local_date
        })
        assert dates.status_code == 200
        assert len(dates.json()["items"]) == 3

        assert client.get("/api/v1/journals", params={"cursor": "bad"}).status_code == 400
        assert client.get("/api/v1/journals", params={"limit": 101}).status_code == 422
        assert client.get("/api/v1/journals", params={
            "from": "2026-10-20", "to": "2026-10-01"
        }).status_code == 422
    finally:
        app.dependency_overrides.clear()


def test_me_requires_authentication():
    app.dependency_overrides.clear()
    assert client.get("/api/v1/me").status_code == 401
    assert client.patch("/api/v1/me", json={"display_name": "X"}).status_code == 401


def test_me_creates_and_updates_owned_profiles():
    first = AuthenticatedUser(user_id=uuid4(), email="first@example.com")
    second = AuthenticatedUser(user_id=uuid4(), email="second@example.com")
    app.dependency_overrides[get_current_user] = lambda: first
    try:
        created = client.get("/api/v1/me")
        assert created.status_code == 200, created.text
        assert created.json()["user_id"] == str(first.user_id)
        assert created.json()["timezone"] == "Asia/Ho_Chi_Minh"
        assert created.json()["email"] == first.email
        again = client.get("/api/v1/me")
        assert again.json()["user_id"] == created.json()["user_id"]

        updated = client.patch(
            "/api/v1/me", json={"display_name": "First", "timezone": "Asia/Tokyo"}
        )
        assert updated.status_code == 200
        assert updated.json()["display_name"] == "First"
        assert updated.json()["timezone"] == "Asia/Tokyo"

        invalid_tz = client.patch("/api/v1/me", json={"timezone": "Fake/Timezone"})
        assert invalid_tz.status_code == 422

        invalid_owner = client.patch(
            "/api/v1/me", json={"user_id": str(second.user_id)}
        )
        assert invalid_owner.status_code == 422
    finally:
        app.dependency_overrides.clear()

    app.dependency_overrides[get_current_user] = lambda: second
    try:
        response = client.get("/api/v1/me")
        assert response.status_code == 200
        assert response.json()["user_id"] == str(second.user_id)
        assert response.json()["display_name"] is None
        assert response.json()["timezone"] == "Asia/Ho_Chi_Minh"
    finally:
        app.dependency_overrides.clear()


def test_completed_journal_action_not_app_open_triggers_streak(monkeypatch):
    """Only saved nonblank journal content earns a daily completion."""
    from datetime import datetime, timezone
    from sqlalchemy import select

    from app.core.database import SessionLocal
    from app.models.journal_action_day import JournalActionDay
    from app.modules.streak import service

    time = [datetime(2026, 10, 18, 10, 0, tzinfo=timezone.utc)]
    monkeypatch.setattr(service, "utc_now", lambda: time[0])
    user_a = AuthenticatedUser(user_id=uuid4(), email="writer@example.com")
    user_b = AuthenticatedUser(user_id=uuid4(), email="observer@example.com")
    app.dependency_overrides[get_current_user] = lambda: user_a
    try:
        assert client.get("/api/v1/streak").json()["current_streak"] == 0
        assert client.get("/api/v1/journals").status_code == 200
        assert client.post("/api/v1/activity/open", json={}).status_code == 404
        assert client.get("/api/v1/streak").json()["today_completed"] is False
        assert client.post("/api/v1/journals", json={"content": "  "}).status_code == 422
        assert client.get("/api/v1/streak").json()["current_streak"] == 0

        first = client.post("/api/v1/journals", json={"content": "A"})
        assert first.status_code == 201, first.text
        entry_id = first.json()["id"]
        current = client.get("/api/v1/streak").json()
        assert current["current_streak"] == 1
        assert current["longest_streak"] == 1
        assert current["today_completed"] is True
        assert current["activity_dates"] == ["2026-10-18"]

        # Multiple journal saves on the same day are one achievement day.
        another = client.post("/api/v1/journals", json={"content": "Another"})
        assert another.status_code == 201
        assert client.put(
            f"/api/v1/journals/{entry_id}", json={"content": "B"}
        ).status_code == 200
        with SessionLocal() as db:
            rows = list(db.scalars(select(JournalActionDay).where(
                JournalActionDay.user_id == user_a.user_id
            )))
        assert len(rows) == 1

        # New day, metadata edits and unchanged content do NOT count.
        time[0] = datetime(2026, 10, 19, 10, 0, tzinfo=timezone.utc)
        assert client.get("/api/v1/streak").json()["today_completed"] is False
        assert client.put(
            f"/api/v1/journals/{entry_id}", json={"mood": "happy"}
        ).status_code == 200
        assert client.put(
            f"/api/v1/journals/{entry_id}", json={"content": "B"}
        ).status_code == 200
        # Edge whitespace differences are not a meaningful writing action.
        assert client.put(
            f"/api/v1/journals/{entry_id}", json={"content": "B   "}
        ).status_code == 200
        assert client.get("/api/v1/streak").json()["today_completed"] is False

        # Writing a changed line, successfully saving, counts on new day.
        changed = client.put(
            f"/api/v1/journals/{entry_id}", json={"content": "One new line"}
        )
        assert changed.status_code == 200, changed.text
        after = client.get("/api/v1/streak").json()
        assert after["current_streak"] == 2
        assert after["longest_streak"] == 2
        assert after["activity_dates"] == ["2026-10-18", "2026-10-19"]
        assert client.delete(f"/api/v1/journals/{entry_id}").status_code == 204
        assert client.get("/api/v1/streak").json()["current_streak"] == 2

        # No retroactive credit merely by visiting on a later day.
        time[0] = datetime(2026, 10, 20, 10, 0, tzinfo=timezone.utc)
        assert client.get("/api/v1/streak").json()["current_streak"] == 2
        assert client.get("/api/v1/streak").json()["today_completed"] is False
        time[0] = datetime(2026, 10, 21, 10, 0, tzinfo=timezone.utc)
        assert client.get("/api/v1/streak").json()["current_streak"] == 0
        assert client.get("/api/v1/streak").json()["longest_streak"] == 2
        assert client.get("/api/v1/streak", params={"days": 1}).json()["activity_dates"] == []
        assert client.get("/api/v1/streak", params={"days": 0}).status_code == 422
        assert client.get("/api/v1/streak", params={"days": 366}).status_code == 422
    finally:
        app.dependency_overrides.clear()

    app.dependency_overrides[get_current_user] = lambda: user_b
    try:
        other = client.get("/api/v1/streak").json()
        assert other["current_streak"] == 0
        assert other["longest_streak"] == 0
        assert other["activity_dates"] == []
    finally:
        app.dependency_overrides.clear()


def test_streak_uses_profile_local_date_and_server_clock(monkeypatch):
    from datetime import datetime, timezone
    from app.modules.streak import service

    time = [datetime(2026, 10, 18, 16, 59, tzinfo=timezone.utc)]
    monkeypatch.setattr(service, "utc_now", lambda: time[0])
    user = AuthenticatedUser(user_id=uuid4(), email="timezone@example.com")
    app.dependency_overrides[get_current_user] = lambda: user
    try:
        assert client.get("/api/v1/me").status_code == 200
        assert client.post("/api/v1/journals", json={"content": "before midnight"}).status_code == 201
        time[0] = datetime(2026, 10, 18, 17, 1, tzinfo=timezone.utc)
        assert client.post("/api/v1/journals", json={"content": "after midnight"}).status_code == 201
        response = client.get("/api/v1/streak").json()
        assert response["timezone"] == "Asia/Ho_Chi_Minh"
        assert response["activity_dates"] == ["2026-10-18", "2026-10-19"]
        assert response["current_streak"] == 2

        # Switching timezones never rewrites the original local dates.
        assert client.patch(
            "/api/v1/me", json={"timezone": "Asia/Tokyo"}
        ).status_code == 200
        after = client.get("/api/v1/streak").json()
        assert after["activity_dates"] == ["2026-10-18", "2026-10-19"]
        assert after["timezone"] == "Asia/Tokyo"
    finally:
        app.dependency_overrides.clear()


def test_journal_and_streak_roll_back_together(monkeypatch):
    """A journal save that fails after its streak insert must credit nothing."""
    import pytest
    from sqlalchemy import select
    from app.core.database import SessionLocal
    from app.models.journal import JournalEntry
    from app.models.journal_action_day import JournalActionDay
    from app.modules.journal import router as journal_router

    identity = AuthenticatedUser(user_id=uuid4(), email="rollback@example.com")
    app.dependency_overrides[get_current_user] = lambda: identity
    record_original = journal_router.record_journal_completion

    def record_and_fail(db, user_id):
        record_original(db, user_id)
        raise RuntimeError("simulated write failure before transaction commit")

    monkeypatch.setattr(journal_router, "record_journal_completion", record_and_fail)
    try:
        with pytest.raises(RuntimeError, match="simulated write failure"):
            client.post("/api/v1/journals", json={"content": "not persisted"})
        with SessionLocal() as db:
            assert not list(db.scalars(
                select(JournalEntry).where(JournalEntry.user_id == identity.user_id)
            ))
            assert not list(db.scalars(
                select(JournalActionDay).where(JournalActionDay.user_id == identity.user_id)
            ))
    finally:
        app.dependency_overrides.clear()


def test_streak_requires_valid_authentication():
    app.dependency_overrides.clear()
    assert client.get("/api/v1/streak").status_code == 401


def test_saved_places_are_private_and_validate_coordinates():
    from app.core.database import SessionLocal
    from app.models.saved_place import SavedPlace
    from sqlalchemy import select

    a = AuthenticatedUser(user_id=uuid4(), email="map-a@example.com")
    b = AuthenticatedUser(user_id=uuid4(), email="map-b@example.com")

    app.dependency_overrides.clear()
    assert client.get("/api/v1/places").status_code == 401
    assert client.post("/api/v1/places", json={
        "label": "No auth", "latitude": 10, "longitude": 106
    }).status_code == 401

    app.dependency_overrides[get_current_user] = lambda: a
    try:
        for bad in [
            {"label": "x", "latitude": 91, "longitude": 106},
            {"label": "x", "latitude": 10, "longitude": -181},
            {"label": "  ", "latitude": 10, "longitude": 106},
            {"label": "x", "latitude": "nan", "longitude": 106},
            {"label": "x", "latitude": 10, "longitude": 106, "user_id": str(b.user_id)},
            {"label": "x", "latitude": 10, "longitude": 106,
             "provider": "geoapify", "external_place_id": None},
            {"label": "x", "latitude": 10, "longitude": 106,
             "provider": "manual", "external_place_id": "not-allowed"},
        ]:
            resp = client.post("/api/v1/places", json=bad)
            assert resp.status_code == 422, (bad, resp.text)

        pinned = client.post("/api/v1/places", json={
            "label": "  Reading park  ", "latitude": 10.8231,
            "longitude": 106.6297, "address_text": "Near a tree"
        })
        assert pinned.status_code == 201, pinned.text
        place_id = pinned.json()["id"]
        assert pinned.json()["label"] == "Reading park"
        assert pinned.json()["provider"] == "manual"
        assert "user_id" not in pinned.json()

        provider = {
            "label": "Found café", "latitude": 10.9, "longitude": 106.7,
            "provider": "geoapify", "external_place_id": "provider-123",
        }
        first = client.post("/api/v1/places", json=provider)
        assert first.status_code == 201, first.text
        provider_id = first.json()["id"]
        assert client.post("/api/v1/places", json=provider).status_code == 409

        assert client.get(f"/api/v1/places/{place_id}").status_code == 200
        assert client.patch(f"/api/v1/places/{place_id}", json={
            "label": "My tree", "latitude": 11.2
        }).status_code == 200
        assert client.patch(f"/api/v1/places/{place_id}", json={
            "label": None
        }).status_code == 422
        assert client.patch(f"/api/v1/places/{place_id}", json={
            "latitude": None
        }).status_code == 422
        assert client.patch(f"/api/v1/places/{provider_id}", json={
            "latitude": 12.0
        }).status_code == 422
        assert client.patch(f"/api/v1/places/{provider_id}", json={
            "label": "Favorite café"
        }).status_code == 200

        listing = client.get("/api/v1/places", params={"limit": 1})
        assert listing.status_code == 200, listing.text
        first_page = listing.json()
        assert len(first_page["items"]) == 1
        assert first_page["next_cursor"]
        next_page = client.get("/api/v1/places", params={
            "limit": 1, "cursor": first_page["next_cursor"]
        })
        assert next_page.status_code == 200
        assert len(next_page.json()["items"]) == 1
        assert next_page.json()["next_cursor"] is None
        assert first_page["items"][0]["id"] != next_page.json()["items"][0]["id"]
        assert client.get("/api/v1/places", params={"cursor": "!bad!"}).status_code == 400
        assert client.get("/api/v1/places", params={"limit": 101}).status_code == 422
    finally:
        app.dependency_overrides.clear()

    app.dependency_overrides[get_current_user] = lambda: b
    try:
        assert client.get("/api/v1/places").json()["items"] == []
        assert client.get(f"/api/v1/places/{place_id}").status_code == 404
        assert client.patch(f"/api/v1/places/{place_id}", json={
            "label": "attempted steal"
        }).status_code == 404
        assert client.delete(f"/api/v1/places/{place_id}").status_code == 404
        # Provider uniqueness is per account, not across all users.
        assert client.post("/api/v1/places", json=provider).status_code == 201
    finally:
        app.dependency_overrides.clear()

    app.dependency_overrides[get_current_user] = lambda: a
    try:
        assert client.delete(f"/api/v1/places/{place_id}").status_code == 204
        assert client.get(f"/api/v1/places/{place_id}").status_code == 404
        with SessionLocal() as db:
            assert db.scalar(select(SavedPlace).where(
                SavedPlace.id == place_id
            )) is None
    finally:
        app.dependency_overrides.clear()


def test_geo_search_requires_auth_key_and_valid_bias():
    from app.core.config import Settings, get_settings
    from app.modules.geo.router import enforce_geo_rate_limit

    app.dependency_overrides.clear()
    assert client.get("/api/v1/geo/search", params={"q": "Hanoi"}).status_code == 401

    identity = AuthenticatedUser(user_id=uuid4(), email="geo@example.com")
    app.dependency_overrides[get_current_user] = lambda: identity
    app.dependency_overrides[enforce_geo_rate_limit] = lambda: None
    app.dependency_overrides[get_settings] = lambda: Settings(
        database_url="sqlite://", geoapify_api_key=None
    )
    try:
        assert client.get("/api/v1/geo/search", params={"q": "Hanoi"}).status_code == 503
        assert client.get("/api/v1/geo/search", params={"q": "a"}).status_code == 422
        assert client.get("/api/v1/geo/search", params={
            "q": "Hanoi", "lat": 10
        }).status_code == 422
        assert client.get("/api/v1/geo/search", params={
            "q": "Hanoi", "lat": 99, "lon": 106
        }).status_code == 422
    finally:
        app.dependency_overrides.clear()


def test_geoapify_search_normalizes_response_without_exposing_key():
    import httpx
    from app.core.config import Settings, get_settings
    from app.modules.geo.router import get_geo_client, enforce_geo_rate_limit

    calls = []

    def fake_provider(request):
        calls.append(request)
        assert request.url.path == "/v1/geocode/autocomplete"
        assert request.url.params["bias"] == "proximity:106.6297,10.8231"
        assert request.url.params["limit"] == "5"
        return httpx.Response(200, json={
            "type": "FeatureCollection",
            "features": [{
                "properties": {
                    "place_id": "place-123",
                    "name": "Reading café",
                    "formatted": "Example, Vietnam",
                    "lat": 10.8231, "lon": 106.6297
                }
            }, {
                "properties": {"formatted": "Missing provider id", "lat": 10, "lon": 106}
            }]
        })

    # Never call external network in tests.
    provider = httpx.AsyncClient(transport=httpx.MockTransport(fake_provider))
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(
        user_id=uuid4(), email="geo@example.com"
    )
    app.dependency_overrides[get_settings] = lambda: Settings(
        database_url="sqlite://", geoapify_api_key="test-secret-key"
    )
    app.dependency_overrides[get_geo_client] = lambda: provider
    app.dependency_overrides[enforce_geo_rate_limit] = lambda: None
    try:
        response = client.get("/api/v1/geo/search", params={
            "q": "coffee", "lat": 10.8231, "lon": 106.6297
        })
        assert response.status_code == 200, response.text
        assert response.json() == {"items": [{
            "provider": "geoapify", "external_place_id": "place-123",
            "label": "Reading café", "formatted_address": "Example, Vietnam",
            "latitude": 10.8231, "longitude": 106.6297
        }]}
        assert "test-secret-key" not in response.text
        assert len(calls) == 1
    finally:
        app.dependency_overrides.clear()


def test_geoapify_upstream_failure_is_sanitized():
    import httpx
    from app.core.config import Settings, get_settings
    from app.modules.geo.router import get_geo_client, enforce_geo_rate_limit

    def provider_failure(request):
        return httpx.Response(401, json={"error": "secret-key-not-authorized"})

    provider = httpx.AsyncClient(transport=httpx.MockTransport(provider_failure))
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(
        user_id=uuid4(), email="geo-fail@example.com"
    )
    app.dependency_overrides[get_settings] = lambda: Settings(
        database_url="sqlite://", geoapify_api_key="test-secret"
    )
    app.dependency_overrides[get_geo_client] = lambda: provider
    app.dependency_overrides[enforce_geo_rate_limit] = lambda: None
    try:
        response = client.get("/api/v1/geo/search", params={"q": "Hanoi"})
        assert response.status_code == 502, response.text
        assert "secret" not in response.text
    finally:
        app.dependency_overrides.clear()


def test_geo_search_limits_requests_per_user(monkeypatch):
    import pytest
    from fastapi import HTTPException
    from app.modules.geo import router as geo_router

    user = AuthenticatedUser(user_id=uuid4(), email="throttled@example.com")
    monkeypatch.setattr(geo_router.time, "monotonic", lambda: 1000.0)
    geo_router._recent_requests.clear()
    try:
        for _ in range(geo_router.RATE_LIMIT):
            geo_router.enforce_geo_rate_limit(user)
        with pytest.raises(HTTPException) as err:
            geo_router.enforce_geo_rate_limit(user)
        assert err.value.status_code == 429
        # Other authenticated accounts have independent limits.
        geo_router.enforce_geo_rate_limit(
            AuthenticatedUser(user_id=uuid4(), email="another@example.com")
        )
        monkeypatch.setattr(geo_router.time, "monotonic", lambda: 1061.0)
        geo_router.enforce_geo_rate_limit(user)
    finally:
        geo_router._recent_requests.clear()



def test_multiple_private_place_notes_paging_and_delete_cascade():
    from sqlalchemy import func, select

    from app.core.database import SessionLocal
    from app.models.place_note import PlaceNote

    a = AuthenticatedUser(user_id=uuid4(), email="notes-a@example.com")
    b = AuthenticatedUser(user_id=uuid4(), email="notes-b@example.com")
    app.dependency_overrides.clear()
    assert client.get("/api/v1/places/1/notes").status_code == 401
    assert client.post("/api/v1/places/1/notes", json={"content": "secret"}).status_code == 401

    app.dependency_overrides[get_current_user] = lambda: a
    try:
        new_place = client.post("/api/v1/places", json={
            "label": "Quiet park", "latitude": 10.82, "longitude": 106.62
        })
        assert new_place.status_code == 201, new_place.text
        pid = new_place.json()["id"]
        assert client.post(f"/api/v1/places/{pid}/notes", json={
            "content": "    "
        }).status_code == 422
        assert client.post(f"/api/v1/places/{pid}/notes", json={
            "content": "spoof", "user_id": str(b.user_id)
        }).status_code == 422
        ids = []
        for content in ["Morning walk", "Afternoon walk", "Evening walk"]:
            response = client.post(f"/api/v1/places/{pid}/notes", json={
                "content": content
            })
            assert response.status_code == 201, response.text
            note = response.json()
            assert note["place_id"] == pid
            assert "user_id" not in note
            ids.append(note["id"])

        page1 = client.get(f"/api/v1/places/{pid}/notes", params={"limit": 2})
        assert page1.status_code == 200
        assert len(page1.json()["items"]) == 2
        cursor = page1.json()["next_cursor"]
        assert cursor is not None
        page2 = client.get(f"/api/v1/places/{pid}/notes", params={
            "limit": 2, "cursor": cursor
        })
        assert page2.status_code == 200
        assert len(page2.json()["items"]) == 1
        assert page2.json()["next_cursor"] is None
        assert len({item["id"] for item in page1.json()["items"] + page2.json()["items"]}) == 3
        assert client.get(f"/api/v1/places/{pid}/notes", params={
            "cursor": "!bad!"
        }).status_code == 400
        assert client.get(f"/api/v1/places/{pid}/notes", params={"limit": 0}).status_code == 422

        edit = client.patch(f"/api/v1/places/{pid}/notes/{ids[0]}", json={
            "content": "Morning walk updated"
        })
        assert edit.status_code == 200
        assert edit.json()["content"] == "Morning walk updated"
        assert client.patch(f"/api/v1/places/{pid}/notes/{ids[0]}", json={
            "content": None
        }).status_code == 422
        assert client.patch(f"/api/v1/places/{pid}/notes/{ids[0]}", json={
            "content": "new", "place_id": -1
        }).status_code == 422
    finally:
        app.dependency_overrides.clear()

    app.dependency_overrides[get_current_user] = lambda: b
    try:
        assert client.get(f"/api/v1/places/{pid}/notes").status_code == 404
        assert client.post(f"/api/v1/places/{pid}/notes", json={
            "content": "steal"
        }).status_code == 404
        assert client.patch(f"/api/v1/places/{pid}/notes/{ids[0]}", json={
            "content": "steal"
        }).status_code == 404
        assert client.delete(f"/api/v1/places/{pid}/notes/{ids[0]}").status_code == 404
        own_place = client.post("/api/v1/places", json={
            "label": "Other user", "latitude": 10, "longitude": 106
        })
        assert own_place.status_code == 201
        other_pid = own_place.json()["id"]
        assert client.get(f"/api/v1/places/{other_pid}/notes").json()["items"] == []
    finally:
        app.dependency_overrides.clear()

    app.dependency_overrides[get_current_user] = lambda: a
    try:
        assert client.delete(f"/api/v1/places/{pid}/notes/{ids[0]}").status_code == 204
        assert client.delete(f"/api/v1/places/{pid}/notes/{ids[0]}").status_code == 404
        assert client.delete(f"/api/v1/places/{pid}").status_code == 204
        with SessionLocal() as db:
            remaining = db.scalar(
                select(func.count(PlaceNote.id)).where(PlaceNote.place_id == pid)
            )
            assert remaining == 0
    finally:
        app.dependency_overrides.clear()

    app.dependency_overrides[get_current_user] = lambda: b
    try:
        assert client.get(f"/api/v1/places/{other_pid}").status_code == 200
    finally:
        app.dependency_overrides.clear()


def test_journal_place_links_owner_isolation_and_safe_deletes():
    import pytest
    from sqlalchemy import func, select, text
    from sqlalchemy.exc import IntegrityError

    from app.core.database import SessionLocal
    from app.models.journal import JournalEntry
    from app.models.journal_place import JournalPlace
    from app.models.place_note import PlaceNote
    from app.models.saved_place import SavedPlace

    with SessionLocal() as db:
        assert db.execute(text("PRAGMA foreign_keys")).scalar_one() == 1

    a = AuthenticatedUser(user_id=uuid4(), email="links-a@example.com")
    b = AuthenticatedUser(user_id=uuid4(), email="links-b@example.com")

    app.dependency_overrides.clear()
    assert client.get("/api/v1/journals/1/places").status_code == 401
    assert client.get("/api/v1/places/1/journals").status_code == 401
    assert client.put("/api/v1/journals/1/places/1").status_code == 401

    app.dependency_overrides[get_current_user] = lambda: a
    try:
        journal_ids = []
        for phrase in ["A day by the lake", "A walk in town"]:
            r = client.post("/api/v1/journals", json={"content": phrase})
            assert r.status_code == 201, r.text
            journal_ids.append(r.json()["id"])
        place_ids = []
        for label in ["Lake", "Town"]:
            r = client.post("/api/v1/places", json={
                "label": label, "latitude": 10.0, "longitude": 106.0
            })
            assert r.status_code == 201, r.text
            place_ids.append(r.json()["id"])

        j1, j2 = journal_ids
        p1, p2 = place_ids
        for jid, pid in [(j1, p1), (j1, p2), (j2, p1), (j1, p1)]:
            assert client.put(f"/api/v1/journals/{jid}/places/{pid}").status_code == 204
        with SessionLocal() as db:
            count = db.scalar(select(func.count()).select_from(JournalPlace).where(
                JournalPlace.user_id == a.user_id
            ))
            assert count == 3

        linked_places = client.get(f"/api/v1/journals/{j1}/places")
        assert linked_places.status_code == 200
        assert {p["id"] for p in linked_places.json()["items"]} == {p1, p2}

        journals_page1 = client.get(f"/api/v1/places/{p1}/journals", params={"limit": 1})
        assert journals_page1.status_code == 200
        assert len(journals_page1.json()["items"]) == 1
        assert journals_page1.json()["next_cursor"]
        journals_page2 = client.get(f"/api/v1/places/{p1}/journals", params={
            "limit": 1, "cursor": journals_page1.json()["next_cursor"]
        })
        assert journals_page2.status_code == 200
        assert len(journals_page2.json()["items"]) == 1
        assert journals_page2.json()["next_cursor"] is None
        assert {j["id"] for j in journals_page1.json()["items"] + journals_page2.json()["items"]} == {j1, j2}
        assert client.get(f"/api/v1/places/{p1}/journals", params={
            "cursor": "!bad!"
        }).status_code == 400

        # Idempotent unlink must not erase either resource.
        assert client.delete(f"/api/v1/journals/{j1}/places/{p2}").status_code == 204
        assert client.delete(f"/api/v1/journals/{j1}/places/{p2}").status_code == 204
        assert client.get(f"/api/v1/journals/{j1}").status_code == 200
        assert client.get(f"/api/v1/places/{p2}").status_code == 200
        note = client.post(f"/api/v1/places/{p1}/notes", json={
            "content": "One of many notes"
        })
        assert note.status_code == 201
    finally:
        app.dependency_overrides.clear()

    app.dependency_overrides[get_current_user] = lambda: b
    try:
        foreign_place = client.post("/api/v1/places", json={
            "label": "Private B place", "latitude": 11.0, "longitude": 107.0
        })
        assert foreign_place.status_code == 201
        bpid = foreign_place.json()["id"]
        foreign_journal = client.post("/api/v1/journals", json={
            "content": "B private journal"
        })
        assert foreign_journal.status_code == 201
        bjid = foreign_journal.json()["id"]

        assert client.put(f"/api/v1/journals/{j1}/places/{bpid}").status_code == 404
        assert client.put(f"/api/v1/journals/{bjid}/places/{p1}").status_code == 404
        assert client.delete(f"/api/v1/journals/{j1}/places/{p1}").status_code == 404
        assert client.get(f"/api/v1/journals/{j1}/places").status_code == 404
        assert client.get(f"/api/v1/places/{p1}/journals").status_code == 404
    finally:
        app.dependency_overrides.clear()

    # Database composite foreign keys reject forged links, not just FastAPI.
    with SessionLocal() as db:
        from datetime import datetime, timezone
        with pytest.raises(IntegrityError):
            db.add(JournalPlace(
                user_id=a.user_id, journal_id=j1, place_id=bpid,
                created_at=datetime.now(timezone.utc)
            ))
            db.commit()
        db.rollback()
        with pytest.raises(IntegrityError):
            db.add(PlaceNote(
                user_id=b.user_id, place_id=p1, content="forged",
            ))
            db.commit()
        db.rollback()

    app.dependency_overrides[get_current_user] = lambda: a
    try:
        assert client.delete(f"/api/v1/journals/{j1}").status_code == 204
        assert client.get(f"/api/v1/places/{p1}").status_code == 200
        assert client.get(f"/api/v1/places/{p2}").status_code == 200
        with SessionLocal() as db:
            assert db.scalar(select(func.count()).select_from(JournalPlace).where(
                JournalPlace.journal_id == j1
            )) == 0
        assert client.delete(f"/api/v1/places/{p1}").status_code == 204
        assert client.get(f"/api/v1/journals/{j2}").status_code == 200
        with SessionLocal() as db:
            assert db.scalar(select(func.count()).select_from(JournalPlace).where(
                JournalPlace.place_id == p1
            )) == 0
            assert db.scalar(select(func.count()).select_from(PlaceNote).where(
                PlaceNote.place_id == p1
            )) == 0
            assert db.get(SavedPlace, p1) is None
            assert db.get(JournalEntry, j2) is not None
    finally:
        app.dependency_overrides.clear()
