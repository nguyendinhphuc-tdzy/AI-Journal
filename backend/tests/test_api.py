"""Backend API tests use temporary SQLite, NEVER the shared Supabase DB."""
from pathlib import Path
from uuid import UUID, uuid4
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
    assert revision == "20261030_19"
    assert "journal_entries" in tables
    assert "user_profiles" in tables
    assert "journal_action_days" in tables
    assert "saved_places" in tables
    assert "place_notes" in tables
    assert "journal_places" in tables
    assert "albums" in tables
    assert "album_memories" in tables
    assert "journal_analyses" in tables
    assert "saved_quotes" in tables
    assert "weekly_insights" in tables
    assert {"conversations", "messages", "conversation_reads"}.issubset(tables)


def test_ai_requires_authentication_in_all_provider_modes(monkeypatch):
    from app.core.config import Settings
    from app.modules.ai.service import MockAIProvider, get_ai_provider

    # An invalid Bearer token is 401 when the verifier is configured.
    # Without SUPABASE_URL, a configuration failure intentionally returns 503.
    monkeypatch.setattr(
        "app.core.auth.get_settings",
        lambda: Settings(database_url="sqlite://", supabase_url="https://test-ref.supabase.co"),
    )
    app.dependency_overrides.clear()
    invoked = []
    def provider_spy():
        invoked.append(True)
        return MockAIProvider()

    app.dependency_overrides[get_ai_provider] = provider_spy
    try:
        for path in ("/api/v1/ai/go-deeper", "/api/v1/ai/reflection"):
            for headers in ({}, {"Authorization": "Bearer not-a-jwt"}):
                response = client.post(
                    path, json={"content": "private entry"}, headers=headers
                )
                assert response.status_code == 401
                assert response.headers.get("www-authenticate") == "Bearer"
        # Authorization must be rejected before any model provider is invoked.
        assert not invoked
    finally:
        app.dependency_overrides.clear()


def test_authenticated_ai_and_bounded_request_content():
    from app.modules.ai.service import MockAIProvider, get_ai_provider

    user = AuthenticatedUser(user_id=uuid4(), email="test@example.com")
    app.dependency_overrides[get_current_user] = lambda: user
    # The developer may set AI_PROVIDER=ollama in backend/.env.
    # Tests must not make requests to their actual Ollama instance.
    app.dependency_overrides[get_ai_provider] = lambda: MockAIProvider()
    try:
        deeper = client.post(
            "/api/v1/ai/go-deeper", json={"content": "I felt peaceful today."}
        )
        assert deeper.status_code == 200
        assert deeper.json()["question"]

        reflection = client.post(
            "/api/v1/ai/reflection",
            json={"content": "I finished my task.", "mood": "relieved"},
        )
        assert reflection.status_code == 200
        assert reflection.json()["emotion"] == "relieved"

        for path in ("/api/v1/ai/go-deeper", "/api/v1/ai/reflection"):
            assert client.post(path, json={"content": " "}).status_code == 422
            assert client.post(path, json={"content": "x" * 8001}).status_code == 422
            assert client.post(path, json={"content": "ok", "mood": "m" * 65}).status_code == 422
            assert client.post(path, json={"content": "x" * 8000}).status_code == 200
    finally:
        app.dependency_overrides.clear()


def test_ai_per_user_rate_limit_does_not_affect_another_account():
    from app.modules.ai.service import MockAIProvider, get_ai_provider

    a = AuthenticatedUser(user_id=uuid4(), email="quota-a@example.com")
    b = AuthenticatedUser(user_id=uuid4(), email="quota-b@example.com")
    app.dependency_overrides[get_ai_provider] = lambda: MockAIProvider()
    try:
        app.dependency_overrides[get_current_user] = lambda: a
        for _ in range(12):
            assert client.post("/api/v1/ai/go-deeper", json={
                "content": "A short journal entry"
            }).status_code == 200
        blocked = client.post("/api/v1/ai/go-deeper", json={
            "content": "One request too many"
        })
        assert blocked.status_code == 429
        assert "journal entry" not in blocked.text

        app.dependency_overrides[get_current_user] = lambda: b
        assert client.post("/api/v1/ai/go-deeper", json={
            "content": "Private second account"
        }).status_code == 200
    finally:
        app.dependency_overrides.clear()


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

        # Null must be rejected with a client error rather than a database
        # integrity error (500); omitting discoverable remains valid.
        assert client.patch("/api/v1/me", json={"discoverable": None}).status_code == 422
        enabled = client.patch("/api/v1/me", json={"discoverable": True})
        assert enabled.status_code == 200
        assert enabled.json()["discoverable"] is True
        assert client.patch("/api/v1/me", json={"discoverable": None}).status_code == 422
        assert client.get("/api/v1/me").json()["discoverable"] is True
        disabled = client.patch("/api/v1/me", json={"discoverable": False})
        assert disabled.status_code == 200
        assert disabled.json()["discoverable"] is False

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
    from uuid import UUID
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


def test_notes_and_journal_place_links_do_not_complete_streak(monkeypatch):
    from datetime import datetime, timezone
    from app.modules.streak import service

    clock = [datetime(2026, 10, 18, 12, 0, tzinfo=timezone.utc)]
    monkeypatch.setattr(service, "utc_now", lambda: clock[0])
    identity = AuthenticatedUser(user_id=uuid4(), email="map-streak@example.com")
    app.dependency_overrides[get_current_user] = lambda: identity
    try:
        journal = client.post("/api/v1/journals", json={"content": "A valid line"})
        assert journal.status_code == 201, journal.text
        jid = journal.json()["id"]
        pin = client.post("/api/v1/places", json={
            "label": "A reading bench", "latitude": 10, "longitude": 106
        })
        assert pin.status_code == 201, pin.text
        pid = pin.json()["id"]

        clock[0] = datetime(2026, 10, 19, 12, 0, tzinfo=timezone.utc)
        assert client.get("/api/v1/streak").json()["today_completed"] is False
        assert client.post(f"/api/v1/places/{pid}/notes", json={
            "content": "Today I sat here"
        }).status_code == 201
        assert client.put(f"/api/v1/journals/{jid}/places/{pid}").status_code == 204
        assert client.get(f"/api/v1/journals/{jid}/places").status_code == 200
        assert client.delete(f"/api/v1/journals/{jid}/places/{pid}").status_code == 204
        after = client.get("/api/v1/streak").json()
        assert after["today_completed"] is False
        assert after["current_streak"] == 1
        assert after["activity_dates"] == ["2026-10-18"]
    finally:
        app.dependency_overrides.clear()


def test_pr17_album_and_memory_require_authentication():
    app.dependency_overrides.clear()
    for endpoint in ("/api/v1/albums", "/api/v1/albums/00000000-0000-0000-0000-000000000001"):
        assert client.get(endpoint).status_code == 401
    assert client.post("/api/v1/albums", json={"name": "Private"}).status_code == 401


def test_pr17_album_memory_owner_isolation_and_e05_place():
    from sqlalchemy import select
    from app.core.database import SessionLocal
    from app.models.album import AlbumMemory

    a = AuthenticatedUser(user_id=uuid4(), email="album-a@example.com")
    b = AuthenticatedUser(user_id=uuid4(), email="album-b@example.com")
    app.dependency_overrides[get_current_user] = lambda: a
    try:
        created = client.post("/api/v1/albums", json={
            "name": "  A special day  ", "theme_id": "classic",
            "locked": True, "hide_name_when_locked": True,
        })
        assert created.status_code == 201, created.text
        album = created.json()
        aid = album["id"]
        assert album["name"] == "A special day"
        assert album["memory_count"] == 0
        assert "user_id" not in album

        invalid = client.post("/api/v1/albums", json={
            "name": "A", "user_id": str(b.user_id),
        })
        assert invalid.status_code == 422
        assert client.post("/api/v1/albums", json={"name": " "}).status_code == 422

        place = {
            "label": "Coffee place", "latitude": 10.8231,
            "longitude": 106.6297, "named": True,
            "address": "Ho Chi Minh City", "place_id": "sample-id",
        }
        memory = client.post(f"/api/v1/albums/{aid}/memories", json={
            "title": "Morning", "note": "A memory from today",
            "display_date": "2026-10-25", "place": place,
        })
        assert memory.status_code == 201, memory.text
        mid = memory.json()["id"]
        assert memory.json()["place"]["label"] == "Coffee place"
        assert "user_id" not in memory.json()
        assert client.get(f"/api/v1/albums/{aid}").json()["memory_count"] == 1
        assert len(client.get(f"/api/v1/albums/{aid}/memories").json()) == 1

        # PR17 local file paths are NOT a remote asset: never accept them.
        assert client.post(f"/api/v1/albums/{aid}/memories", json={
            "photoPath": "/data/user/0/app/secret.jpg", "note": "hi",
            "display_date": "2026-10-25",
        }).status_code == 422
        assert client.post(f"/api/v1/albums/{aid}/memories", json={
            "note": " ", "display_date": "2026-10-25",
        }).status_code == 422
        assert client.patch(f"/api/v1/albums/{aid}/memories/{mid}",
            json={"note": "  "}).status_code == 422
        assert client.patch(f"/api/v1/albums/{aid}",
            json={"name": None}).status_code == 422

        app.dependency_overrides[get_current_user] = lambda: b
        assert client.get("/api/v1/albums").json() == []
        assert client.get(f"/api/v1/albums/{aid}").status_code == 404
        assert client.patch(f"/api/v1/albums/{aid}",
            json={"name": "stolen"}).status_code == 404
        assert client.delete(f"/api/v1/albums/{aid}").status_code == 404
        assert client.get(f"/api/v1/albums/{aid}/memories").status_code == 404
        assert client.get(f"/api/v1/albums/{aid}/memories/{mid}").status_code == 404
        assert client.delete(f"/api/v1/albums/{aid}/memories/{mid}").status_code == 404
        assert client.post(f"/api/v1/albums/{aid}/memories", json={
            "note": "steal", "display_date": "2026-10-25",
        }).status_code == 404

        app.dependency_overrides[get_current_user] = lambda: a
        assert client.patch(f"/api/v1/albums/{aid}/memories/{mid}", json={
            "note": "Updated note", "place": None,
        }).json()["note"] == "Updated note"
        assert client.get(f"/api/v1/albums/{aid}/memories/{mid}").json()["place"] is None
        assert client.delete(f"/api/v1/albums/{aid}").status_code == 204
        assert client.get(f"/api/v1/albums/{aid}").status_code == 404
        with SessionLocal() as session:
            assert session.scalar(
                select(AlbumMemory).where(AlbumMemory.id == UUID(mid))
            ) is None
    finally:
        app.dependency_overrides.clear()


def test_album_and_memory_offset_pagination_remains_owner_scoped():
    a = AuthenticatedUser(user_id=uuid4(), email="paged@example.com")
    b = AuthenticatedUser(user_id=uuid4(), email="other@example.com")
    app.dependency_overrides[get_current_user] = lambda: a
    try:
        ids = []
        for index in range(4):
            result = client.post("/api/v1/albums", json={"name": f"Album {index}"})
            assert result.status_code == 201, result.text
            ids.append(result.json()["id"])
        first = client.get("/api/v1/albums?limit=2&offset=0")
        second = client.get("/api/v1/albums?limit=2&offset=2")
        assert first.status_code == second.status_code == 200
        assert len(first.json()) == len(second.json()) == 2
        assert set(x["id"] for x in first.json()).isdisjoint(
            x["id"] for x in second.json()
        )
        assert client.get("/api/v1/albums?offset=-1").status_code == 422
        assert client.get("/api/v1/albums?offset=100001").status_code == 422

        aid = ids[0]
        for index in range(5):
            result = client.post(f"/api/v1/albums/{aid}/memories", json={
                "note": f"Entry {index}", "display_date": "2026-10-29",
            })
            assert result.status_code == 201
        page1 = client.get(f"/api/v1/albums/{aid}/memories?limit=3&offset=0")
        page2 = client.get(f"/api/v1/albums/{aid}/memories?limit=3&offset=3")
        assert len(page1.json()) == 3
        assert len(page2.json()) == 2
        assert set(x["id"] for x in page1.json()).isdisjoint(
            x["id"] for x in page2.json()
        )

        app.dependency_overrides[get_current_user] = lambda: b
        assert client.get("/api/v1/albums?limit=2&offset=0").json() == []
        assert client.get(f"/api/v1/albums/{aid}/memories?offset=2").status_code == 404
    finally:
        app.dependency_overrides.clear()


def test_guided_journal_roundtrip_version_and_owner_isolation():
    """Structured guided fields survive server JSON serialization and updates."""
    alice = AuthenticatedUser(user_id=uuid4(), email="alice@example.test")
    bob = AuthenticatedUser(user_id=uuid4(), email="bob@example.test")
    first_guided = {
        "id": "onboarding_first_entry",
        "version": 1,
        "fields": {"cause": "trời mát", "hope": "nghỉ ngơi"},
    }
    app.dependency_overrides[get_current_user] = lambda: alice
    try:
        created = client.post("/api/v1/journals", json={
            "content": "Một ngày yên bình",
            "mood": "calm",
            "guided": first_guided,
        })
        assert created.status_code == 201, created.text
        data = created.json()
        assert data["body_version"] == 1
        assert data["guided"] == first_guided
        assert data["mood"] == "calm"
        ident = data["id"]
        assert client.get(f"/api/v1/journals/{ident}").json()["guided"] == first_guided
        assert client.get("/api/v1/journals").json()["items"][0]["guided"] == first_guided

        # A no-op edit and title change must not invalidate AI body version.
        unchanged = client.put(f"/api/v1/journals/{ident}", json={
            "content": data["content"], "mood": "calm", "guided": first_guided,
        })
        assert unchanged.status_code == 200
        assert unchanged.json()["body_version"] == 1
        title_only = client.put(f"/api/v1/journals/{ident}", json={
            "title": "New title"
        })
        assert title_only.json()["body_version"] == 1

        # Mood is part of Flutter JournalContent and changes the bodyVersion.
        changed = client.put(f"/api/v1/journals/{ident}", json={"mood": "happy"})
        assert changed.json()["body_version"] == 2
        guided_update = dict(first_guided, fields={"cause": "đã hoàn thành"})
        changed = client.put(f"/api/v1/journals/{ident}", json={
            "guided": guided_update
        })
        assert changed.json()["body_version"] == 3
        changed = client.put(f"/api/v1/journals/{ident}", json={
            "content": "Nội dung mới"
        })
        assert changed.json()["body_version"] == 4
        assert changed.json()["guided"] == guided_update

        # No client-controlled version, owner ID or arbitrary guided keys.
        assert client.put(f"/api/v1/journals/{ident}", json={
            "body_version": 99
        }).status_code == 422
        assert client.post("/api/v1/journals", json={
            "content": "x",
            "guided": {"id": "abc", "version": 1, "fields": {}, "extra": "bad"}
        }).status_code == 422
    finally:
        app.dependency_overrides.clear()

    app.dependency_overrides[get_current_user] = lambda: bob
    try:
        assert client.get(f"/api/v1/journals/{ident}").status_code == 404
        assert client.put(f"/api/v1/journals/{ident}", json={
            "guided": first_guided
        }).status_code == 404
        assert client.get("/api/v1/journals").json()["items"] == []
    finally:
        app.dependency_overrides.clear()


def test_study_journal_source_roundtrip_and_rejects_invalid_metadata():
    """Study attribution survives cloud fetch/list/update without client-owned IDs."""
    alice = AuthenticatedUser(user_id=uuid4(), email="study-source@example.test")
    source = {
        "kind": "challenge",
        "id": "gratitude",
        "label": "Challenge · Nhiệm vụ 2",
        "task": 1,
    }
    app.dependency_overrides[get_current_user] = lambda: alice
    try:
        response = client.post("/api/v1/journals", json={
            "content": "Tôi đã hoàn thành một nhiệm vụ", "source": source,
        })
        assert response.status_code == 201, response.text
        journal = response.json()
        journal_id = journal["id"]
        assert journal["body_version"] == 1
        assert journal["source"] == source
        assert client.get(f"/api/v1/journals/{journal_id}").json()["source"] == source
        assert any(item["source"] == source for item in
                   client.get("/api/v1/journals").json()["items"])
        unchanged = client.put(f"/api/v1/journals/{journal_id}", json={
            "source": source,
        })
        assert unchanged.status_code == 200
        assert unchanged.json()["body_version"] == 1
        cleared = client.put(f"/api/v1/journals/{journal_id}", json={
            "source": None,
        })
        assert cleared.status_code == 200
        assert cleared.json()["body_version"] == 2
        assert cleared.json()["source"] is None
        assert client.post("/api/v1/journals", json={
            "content": "x", "source": dict(source, kind="arbitrary"),
        }).status_code == 422
        assert client.put(f"/api/v1/journals/{journal_id}", json={
            "source": dict(source, extra="not permitted"),
        }).status_code == 422
    finally:
        app.dependency_overrides.clear()


def test_private_memory_photo_owner_boundary_and_storage_proxy(monkeypatch):
    """JWT owner check precedes every Storage API request."""
    import httpx
    from app.modules.albums import photos_router

    owner = AuthenticatedUser(user_id=uuid4(), email="photo-a@example.com")
    other = AuthenticatedUser(user_id=uuid4(), email="photo-b@example.com")
    calls = []

    def fake_storage(method, path, token, **kwargs):
        calls.append((method, path, token))
        if method == "GET":
            return httpx.Response(200, content=b"\x89PNG\r\n\x1a\nphoto",
                                  headers={"content-type": "image/png"})
        return httpx.Response(201 if method == "POST" else 200, json={})

    monkeypatch.setattr(photos_router, "_storage_request", fake_storage)
    app.dependency_overrides[get_current_user] = lambda: owner
    album_id = memory_id = None
    try:
        album = client.post("/api/v1/albums", json={"name": "Private photos"})
        assert album.status_code == 201
        album_id = album.json()["id"]
        memory = client.post(f"/api/v1/albums/{album_id}/memories", json={
            "note": "Private photo",
            "display_date": "2026-10-28",
        })
        assert memory.status_code == 201
        assert memory.json()["photo_available"] is False
        assert "photo_path" not in memory.json()
        memory_id = memory.json()["id"]
        url = f"/api/v1/albums/{album_id}/memories/{memory_id}/photo"
        headers = {"Authorization": "Bearer valid-test-token"}
        bad = client.put(url, content=b"<svg>", headers={
            **headers, "Content-Type": "image/png",
        })
        assert bad.status_code == 415
        assert calls == []
        image = b"\x89PNG\r\n\x1a\nphoto"
        uploaded = client.put(url, content=image, headers={
            **headers, "Content-Type": "image/png",
        })
        assert uploaded.status_code == 200, uploaded.text
        assert calls[-1][0] == "POST"
        assert calls[-1][2] == "Bearer valid-test-token"
        info = client.get(f"/api/v1/albums/{album_id}/memories/{memory_id}")
        assert info.status_code == 200
        assert info.json()["photo_available"] is True
        assert "photo_path" not in info.json()
        listed = client.get(f"/api/v1/albums/{album_id}/memories")
        assert listed.status_code == 200
        assert listed.json()[0]["photo_available"] is True
        assert "photo_path" not in listed.json()[0]
        response = client.get(url, headers=headers)
        assert response.status_code == 200
        assert response.content == image
    finally:
        app.dependency_overrides.clear()

    # Other user must see 404 and must not trigger a Storage call.
    prior = len(calls)
    app.dependency_overrides[get_current_user] = lambda: other
    try:
        for method in ("GET", "PUT", "DELETE"):
            response = client.request(method, url, headers={
                "Authorization": "Bearer other-test-token",
                "Content-Type": "image/png",
            }, content=image if method == "PUT" else None)
            assert response.status_code == 404
        assert len(calls) == prior
    finally:
        app.dependency_overrides.clear()

    app.dependency_overrides[get_current_user] = lambda: owner
    try:
        removed = client.delete(f"/api/v1/albums/{album_id}/memories/{memory_id}",
                                headers={"Authorization": "Bearer valid-test-token"})
        assert removed.status_code == 204
        assert calls[-1][0] == "DELETE"
        assert client.get(url, headers={"Authorization": "Bearer valid-test-token"}).status_code == 404
        assert client.delete(f"/api/v1/albums/{album_id}").status_code == 204
    finally:
        app.dependency_overrides.clear()


def test_private_friend_request_accept_and_remove():
    """A can request B; only B can accept, and C cannot act on their pair."""
    a = AuthenticatedUser(user_id=uuid4(), email="friends-a@example.com")
    b = AuthenticatedUser(user_id=uuid4(), email="friends-b@example.com")
    c = AuthenticatedUser(user_id=uuid4(), email="friends-c@example.com")
    app.dependency_overrides.clear()
    assert client.get("/api/v1/friends").status_code == 401
    assert client.post("/api/v1/friends/requests", json={"user_id": str(b.user_id)}).status_code == 401
    try:
        app.dependency_overrides[get_current_user] = lambda: a
        assert client.post("/api/v1/friends/requests", json={
            "user_id": str(a.user_id)
        }).status_code == 422
        response = client.post("/api/v1/friends/requests", json={
            "user_id": str(b.user_id)
        })
        assert response.status_code == 201, response.text
        assert response.json() == {
            "user_id": str(b.user_id), "status": "pending", "direction": "outgoing"
        }
        assert client.post("/api/v1/friends/requests", json={
            "user_id": str(b.user_id)
        }).status_code == 409
        assert client.post(f"/api/v1/friends/{b.user_id}/accept").status_code == 409
        assert len(client.get("/api/v1/friends").json()) == 1
        app.dependency_overrides[get_current_user] = lambda: c
        assert client.get("/api/v1/friends").json() == []
        assert client.post(f"/api/v1/friends/{b.user_id}/accept").status_code == 404
        assert client.delete(f"/api/v1/friends/{b.user_id}").status_code == 404
        app.dependency_overrides[get_current_user] = lambda: b
        incoming = client.get("/api/v1/friends").json()
        assert incoming[0]["direction"] == "incoming"
        accept = client.post(f"/api/v1/friends/{a.user_id}/accept")
        assert accept.status_code == 200
        assert accept.json()["status"] == "accepted"
        assert client.post(f"/api/v1/friends/{a.user_id}/accept").status_code == 409
        assert client.delete(f"/api/v1/friends/{a.user_id}").status_code == 204
        assert client.get("/api/v1/friends").json() == []
        app.dependency_overrides[get_current_user] = lambda: a
        assert client.get("/api/v1/friends").json() == []
    finally:
        app.dependency_overrides.clear()


def test_friend_discovery_opt_in_and_block_privacy():
    from app.core.database import SessionLocal
    from app.models.user_profile import UserProfile
    a = AuthenticatedUser(user_id=uuid4(), email="discover-a@example.com")
    b = AuthenticatedUser(user_id=uuid4(), email="discover-b@example.com")
    with SessionLocal() as db:
        db.add(UserProfile(user_id=b.user_id, display_name="Lan Anh", discoverable=False))
        db.commit()
    app.dependency_overrides[get_current_user] = lambda: a
    try:
        assert client.get("/api/v1/friends/discover", params={"q": "Lan"}).json() == []
        with SessionLocal() as db:
            db.get(UserProfile, b.user_id).discoverable = True
            db.commit()
        res = client.get("/api/v1/friends/discover", params={"q": "Lan"})
        assert res.status_code == 200
        assert res.json() == [{"user_id": str(b.user_id), "display_name": "Lan Anh"}]
        assert client.post("/api/v1/friends/blocks", json={
            "user_id": str(b.user_id)
        }).status_code == 204
        assert client.get("/api/v1/friends/discover", params={"q": "Lan"}).json() == []
        assert client.post("/api/v1/friends/requests", json={
            "user_id": str(b.user_id)
        }).status_code == 404
        assert client.delete(f"/api/v1/friends/blocks/{b.user_id}").status_code == 204
        assert len(client.get("/api/v1/friends/discover", params={"q": "Lan"}).json()) == 1
    finally:
        app.dependency_overrides.clear()


def test_friends_only_memory_shares_revoke_expire_and_unfriend():
    from datetime import datetime, timedelta, timezone
    from app.core.database import SessionLocal
    from app.models.memory_share import MemoryShare
    a = AuthenticatedUser(user_id=uuid4(), email="share-a@example.com")
    b = AuthenticatedUser(user_id=uuid4(), email="share-b@example.com")
    c = AuthenticatedUser(user_id=uuid4(), email="share-c@example.com")
    try:
        app.dependency_overrides[get_current_user] = lambda: a
        album = client.post("/api/v1/albums", json={"name": "Share test"})
        assert album.status_code == 201, album.text
        album_id = album.json()["id"]
        memory = client.post(f"/api/v1/albums/{album_id}/memories", json={
            "note": "A private day", "display_date": "2026-10-28",
        })
        assert memory.status_code == 201, memory.text
        memory_id = memory.json()["id"]
        # No share to non-friends, no share without explicit recipients.
        assert client.post("/api/v1/memory-shares", json={
            "memory_id": memory_id, "recipient_ids": [str(b.user_id)], "text": "A public caption", "place": {"label": "Park", "latitude": 10.8, "longitude": 106.7}
        }).status_code == 422
        assert client.post("/api/v1/memory-shares", json={
            "memory_id": memory_id, "recipient_ids": [], "text": "Caption", "place": {"label": "Park", "latitude": 10, "longitude": 106}
        }).status_code == 422
        assert client.post("/api/v1/friends/requests", json={
            "user_id": str(b.user_id)
        }).status_code == 201
        app.dependency_overrides[get_current_user] = lambda: b
        assert client.post(f"/api/v1/friends/{a.user_id}/accept").status_code == 200
        app.dependency_overrides[get_current_user] = lambda: a
        share = client.post("/api/v1/memory-shares", json={
            "memory_id": memory_id, "recipient_ids": [str(b.user_id)], "text": "A public caption", "place": {"label": "Park", "latitude": 10.8, "longitude": 106.7}
        })
        assert share.status_code == 201, share.text
        sid = share.json()["id"]
        assert client.get(f"/api/v1/memory-shares/{sid}").status_code == 200
        assert any(row["id"] == sid for row in client.get("/api/v1/memory-shares/mine", params={"memory_id": memory_id}).json())
        app.dependency_overrides[get_current_user] = lambda: b
        view = client.get(f"/api/v1/memory-shares/{sid}")
        assert view.status_code == 200, view.text
        assert view.json()["text"] == "A public caption"
        assert "note" not in view.json()
        assert "A private day" not in view.text
        received = client.get("/api/v1/memory-shares/received")
        assert received.status_code == 200 and any(row["share_id"] == sid for row in received.json())
        assert "photo_path" not in view.json()
        assert client.delete(f"/api/v1/memory-shares/{sid}").status_code == 404
        app.dependency_overrides[get_current_user] = lambda: c
        assert client.get(f"/api/v1/memory-shares/{sid}").status_code == 404
        app.dependency_overrides[get_current_user] = lambda: a
        with SessionLocal() as db:
            item = db.get(MemoryShare, UUID(sid))
            item.created_at = datetime.now(timezone.utc) - timedelta(hours=25)
            item.expires_at = datetime.now(timezone.utc) - timedelta(hours=1)
            db.commit()
        app.dependency_overrides[get_current_user] = lambda: b
        assert client.get(f"/api/v1/memory-shares/{sid}").status_code == 404
        app.dependency_overrides[get_current_user] = lambda: a
        new_share = client.post("/api/v1/memory-shares", json={
            "memory_id": memory_id, "recipient_ids": [str(b.user_id)], "text": "A public caption", "place": {"label": "Park", "latitude": 10.8, "longitude": 106.7}
        })
        assert new_share.status_code == 201, new_share.text
        sid2 = new_share.json()["id"]
        app.dependency_overrides[get_current_user] = lambda: b
        assert client.get(f"/api/v1/memory-shares/{sid2}").status_code == 200
        assert client.delete(f"/api/v1/friends/{a.user_id}").status_code == 204
        assert client.get(f"/api/v1/memory-shares/{sid2}").status_code == 404
        app.dependency_overrides[get_current_user] = lambda: a
        assert client.delete(f"/api/v1/memory-shares/{sid2}").status_code == 204
        assert client.get(f"/api/v1/memory-shares/{sid2}").status_code == 404
    finally:
        app.dependency_overrides.clear()


def test_community_disabled_by_default_and_moderation():
    from app.core.config import Settings, get_settings
    a = AuthenticatedUser(user_id=uuid4(), email="community-a@example.com")
    b = AuthenticatedUser(user_id=uuid4(), email="community-b@example.com")
    c = AuthenticatedUser(user_id=uuid4(), email="community-c@example.com")
    app.dependency_overrides.clear()
    app.dependency_overrides[get_current_user] = lambda: a
    try:
        assert client.get("/api/v1/community/feed").status_code == 503
        app.dependency_overrides[get_settings] = lambda: Settings(
            database_url="sqlite://", community_feed_enabled=True,
            community_moderator_ids=str(b.user_id))
        post = client.post("/api/v1/community/posts", json={"body": "Hôm nay tôi thấy rất vui vì điều nhỏ bé."})
        assert post.status_code == 201, post.text
        pid = post.json()["id"]
        assert post.json()["status"] == "pending"
        assert client.get("/api/v1/community/feed").json() == []
        assert client.get("/api/v1/community/moderation/pending").status_code == 403
        app.dependency_overrides[get_current_user] = lambda: b
        assert len(client.get("/api/v1/community/moderation/pending").json()) >= 1
        approved = client.post(f"/api/v1/community/moderation/{pid}/approve")
        assert approved.status_code == 200, approved.text
        assert approved.json()["status"] == "approved"
        assert any(row["id"] == pid for row in client.get("/api/v1/community/feed").json())
        app.dependency_overrides[get_current_user] = lambda: c
        assert client.post(f"/api/v1/community/posts/{pid}/reports", json={
            "reason": "Nội dung cần kiểm tra"
        }).status_code == 204
        assert client.get("/api/v1/community/moderation/reports").status_code == 403
        app.dependency_overrides[get_current_user] = lambda: b
        reports = client.get("/api/v1/community/moderation/reports")
        assert reports.status_code == 200 and any(x["post_id"] == pid for x in reports.json())
        assert client.post(f"/api/v1/community/moderation/{pid}/hide").status_code == 200
        assert client.get("/api/v1/community/feed").json() == []
        app.dependency_overrides[get_current_user] = lambda: a
        assert client.delete(f"/api/v1/community/posts/{pid}").status_code == 204
        assert client.get("/api/v1/community/feed").json() == []
    finally:
        app.dependency_overrides.clear()



def test_reflection_response_exposes_normalized_groups_and_scores():
    from app.modules.ai.service import MockAIProvider, get_ai_provider
    current = AuthenticatedUser(user_id=uuid4(), email="mood-schema@example.com")
    app.dependency_overrides[get_current_user] = lambda: current
    app.dependency_overrides[get_ai_provider] = lambda: MockAIProvider()
    try:
        score = client.post("/api/v1/ai/reflection", json={
            "content": "Today was calm", "mood": "Bình yên",
        })
        assert score.status_code == 200, score.text
        payload = score.json()
        assert payload["emotion"] == "Bình yên"
        assert payload["mood_group"] == "calm"
        assert payload["mood_score"] == 80
        assert payload["quote"] is None
        assert payload["topics"] == []
        unknown = client.post("/api/v1/ai/reflection", json={
            "content": "A day without a named emotion",
            "mood": "unclassified",
        })
        assert unknown.status_code == 200
        assert unknown.json()["mood_group"] is None
        assert unknown.json()["mood_score"] is None
    finally:
        app.dependency_overrides.clear()


def test_ai_emotions_match_flutter_scale_without_fabricating_unknown():
    from app.modules.ai.emotions import classify_emotion

    assert classify_emotion("Buồn chán") == ("sad", 25)
    assert classify_emotion("Bình yên") == ("calm", 80)
    assert classify_emotion("Không vui") == (None, None)
    assert classify_emotion("Nặng nề nhưng tìm thấy sự dịu nhẹ") == ("mixed", 60)
    assert classify_emotion("Không rõ cảm xúc gì") == (None, None)


def test_analysis_routes_auth_and_saved_journal_version_lifecycle():
    from app.modules.ai.service import MockAIProvider, get_ai_provider
    a = AuthenticatedUser(user_id=uuid4(), email="analyze-a@example.com")
    b = AuthenticatedUser(user_id=uuid4(), email="analyze-b@example.com")
    app.dependency_overrides.clear()
    try:
        for path in ("/api/v1/saved-quotes", "/api/v1/insights/week?start=2026-10-26",
                     "/api/v1/journals/1/analysis"):
            assert client.get(path).status_code == 401
        assert client.post("/api/v1/journals/1/analysis").status_code == 401
        app.dependency_overrides[get_current_user] = lambda: a
        app.dependency_overrides[get_ai_provider] = lambda: MockAIProvider()
        saved = client.post("/api/v1/journals", json={
            "title": "Memory", "content": "My diary from yesterday",
            "mood": "Bình yên",
        })
        assert saved.status_code == 201, saved.text
        jid = saved.json()["id"]
        absent = client.get(f"/api/v1/journals/{jid}/analysis")
        assert absent.status_code == 404
        created = client.post(f"/api/v1/journals/{jid}/analysis")
        assert created.status_code == 200, created.text
        payload = created.json()
        assert payload["analysis"]["emotion"] == "Bình yên"
        assert payload["analysis"]["mood_group"] == "calm"
        assert payload["analysis"]["mood_score"] == 80
        assert payload["body_version"] == 1 and payload["stale"] is False
        # An accidental repeat must not re-infer and must not duplicate rows.
        assert client.post(f"/api/v1/journals/{jid}/analysis").json()["id"] == payload["id"]
        listing = client.get("/api/v1/journals?include=analysis")
        assert listing.status_code == 200, listing.text
        entry = next(x for x in listing.json()["items"] if x["id"] == jid)
        assert entry["analysis"]["id"] == payload["id"]
        assert client.get("/api/v1/journals?include=anything").status_code == 422
        feedback = client.put(f"/api/v1/journals/{jid}/analysis/feedback", json={
            "rating": "up"
        })
        assert feedback.status_code == 200 and feedback.json()["feedback"] == "up"
        assert client.put(f"/api/v1/journals/{jid}/analysis/feedback", json={
            "rating": "invalid"
        }).status_code == 422
        app.dependency_overrides[get_current_user] = lambda: b
        assert client.get(f"/api/v1/journals/{jid}/analysis").status_code == 404
        assert client.post(f"/api/v1/journals/{jid}/analysis").status_code == 404
        assert client.put(f"/api/v1/journals/{jid}/analysis/feedback", json={
            "rating": "down"
        }).status_code == 404
        app.dependency_overrides[get_current_user] = lambda: a
        edit = client.put(f"/api/v1/journals/{jid}", json={"content": "Updated diary"})
        assert edit.status_code == 200 and edit.json()["body_version"] == 2
        old = client.get(f"/api/v1/journals/{jid}/analysis")
        assert old.json()["stale"] is True
        assert client.put(f"/api/v1/journals/{jid}/analysis/feedback", json={
            "rating": "down"
        }).status_code == 409
        new = client.post(f"/api/v1/journals/{jid}/analysis")
        assert new.status_code == 200, new.text
        assert new.json()["body_version"] == 2
        assert new.json()["feedback"] is None
        assert client.delete(f"/api/v1/journals/{jid}").status_code == 204
        assert client.get(f"/api/v1/journals/{jid}/analysis").status_code == 404
        from sqlalchemy import select
        from app.core.database import SessionLocal
        from app.models.journal_analysis import JournalAnalysis
        with SessionLocal() as db:
            assert db.scalar(select(JournalAnalysis).where(
                JournalAnalysis.journal_id == jid,
            )) is None
    finally:
        app.dependency_overrides.clear()


def test_quotes_are_scoped_and_weekly_chart_uses_real_analysis_only():
    from datetime import timedelta, datetime
    from zoneinfo import ZoneInfo
    from app.modules.ai.service import MockAIProvider, get_ai_provider
    a = AuthenticatedUser(user_id=uuid4(), email="insights-a@example.com")
    b = AuthenticatedUser(user_id=uuid4(), email="insights-b@example.com")
    app.dependency_overrides[get_current_user] = lambda: a
    app.dependency_overrides[get_ai_provider] = lambda: MockAIProvider()
    try:
        bad = client.post("/api/v1/saved-quotes", json={
            "text": "  ", "author": "Someone"
        })
        assert bad.status_code == 422
        q = client.post("/api/v1/saved-quotes", json={
            "text": "A verified quote from the client's catalog",
            "author": "Example author",
        })
        assert q.status_code == 201, q.text
        qid = q.json()["id"]
        assert client.post("/api/v1/saved-quotes", json={
            "text": "A verified quote from the client's catalog",
            "author": "Example author",
        }).status_code == 201
        own = client.get("/api/v1/saved-quotes")
        assert own.status_code == 200
        assert len([x for x in own.json()["items"] if x["id"] == qid]) == 1

        journal = client.post("/api/v1/journals", json={
            "content": "This week I felt peaceful.", "mood": "Bình yên",
        })
        jid = journal.json()["id"]
        from_date = datetime.now(ZoneInfo("Asia/Ho_Chi_Minh")).date()
        monday = from_date - timedelta(days=from_date.weekday())
        url = f"/api/v1/insights/week?start={monday.isoformat()}"
        assert client.get(url).status_code == 200
        week_before = client.get(url).json()
        assert week_before["summary"] is None
        assert sum(d["analyzed_count"] for d in week_before["days"]) == 0
        assert client.post(f"/api/v1/journals/{jid}/analysis").status_code == 200
        week = client.get(url)
        assert week.status_code == 200, week.text
        body = week.json()
        assert sum(d["analyzed_count"] for d in body["days"]) == 1
        assert body["top_emotions"] == [{"mood_group": "calm", "count": 1}]
        assert any(d["score"] == 80 for d in body["days"])
        assert body["summary"] is None and body["summary_status"] == "not_requested"
        no_fake = client.get(url + "&generate_summary=true")
        assert no_fake.status_code == 200
        assert no_fake.json()["summary"] is None
        assert no_fake.json()["summary_status"] == "unavailable"
        assert client.get("/api/v1/insights/week?start=2026-10-27").status_code == 422

        app.dependency_overrides[get_current_user] = lambda: b
        assert client.get("/api/v1/saved-quotes").json()["items"] == []
        assert sum(d["analyzed_count"] for d in client.get(url).json()["days"]) == 0
        assert client.delete(f"/api/v1/saved-quotes/{qid}").status_code == 404
        app.dependency_overrides[get_current_user] = lambda: a
        assert client.delete(f"/api/v1/saved-quotes/{qid}").status_code == 204
    finally:
        app.dependency_overrides.clear()



def test_weekly_narrative_caches_and_invalidates_with_journal_updates(monkeypatch):
    from datetime import datetime, timedelta
    from zoneinfo import ZoneInfo
    from app.modules.ai.service import MockAIProvider, get_ai_provider

    class NarrativeAI(MockAIProvider):
        calls = 0

        def summarize_week(self, aggregate_json: str) -> str:
            self.calls += 1
            assert "This is raw journal text" not in aggregate_json
            return "Tuần này bạn có những khoảnh khắc bình yên."

    user = AuthenticatedUser(user_id=uuid4(), email="narrative@example.com")
    provider = NarrativeAI()
    # Insights selects the provider lazily so chart GET doesn't fail if
    # Ollama is absent; override that lazy lookup for this isolated test.
    monkeypatch.setattr("app.modules.insights.router.get_ai_provider",
                        lambda: provider)
    app.dependency_overrides[get_current_user] = lambda: user
    app.dependency_overrides[get_ai_provider] = lambda: provider
    try:
        diary = client.post("/api/v1/journals", json={
            "content": "This is raw journal text",
            "mood": "Bình yên",
        }).json()
        assert client.post(f"/api/v1/journals/{diary['id']}/analysis").status_code == 200
        now = datetime.now(ZoneInfo("Asia/Ho_Chi_Minh")).date()
        monday = now - timedelta(days=now.weekday())
        url = f"/api/v1/insights/week?start={monday}"
        assert client.get(url).json()["summary_status"] == "not_requested"
        result = client.get(url + "&generate_summary=true")
        assert result.status_code == 200, result.text
        assert result.json()["summary_status"] == "ready"
        assert "bạn" in result.json()["summary"]
        assert provider.calls == 1

        cached = client.get(url)
        assert cached.status_code == 200
        assert cached.json()["summary_status"] == "ready"
        assert provider.calls == 1
        # A journal edit invalidates the narrative and its prior analysis.
        assert client.put(f"/api/v1/journals/{diary['id']}",
                          json={"content": "Now it changed"}).status_code == 200
        after = client.get(url)
        assert after.status_code == 200
        assert after.json()["summary"] is None
        assert after.json()["summary_status"] == "no_data"
        assert provider.calls == 1
    finally:
        app.dependency_overrides.clear()


def test_username_discovery_privacy_and_friendship_roundtrip():
    """A username is globally unique; search is opt-in; friends are real users."""
    from app.core.database import SessionLocal
    from app.models.user_profile import UserProfile

    alice = AuthenticatedUser(user_id=uuid4(), email="u-alice@example.test")
    bob = AuthenticatedUser(user_id=uuid4(), email="u-bob@example.test")
    outsider = AuthenticatedUser(user_id=uuid4(), email="u-third@example.test")
    try:
        app.dependency_overrides[get_current_user] = lambda: alice
        a = client.patch("/api/v1/me", json={
            "display_name": "Vy Tường", "username": "@VyTuong",
        })
        assert a.status_code == 200, a.text
        assert a.json()["username"] == "vytuong"
        assert a.json()["discoverable"] is False
        assert client.get("/api/v1/friends/discover", params={"q": "vyt"}).json() == []

        app.dependency_overrides[get_current_user] = lambda: bob
        b = client.patch("/api/v1/me", json={"display_name": "Người B",
                                              "username": "another_b"})
        assert b.status_code == 200, b.text
        duplicate = client.patch("/api/v1/me", json={"username": "VYTUONG"})
        assert duplicate.status_code == 409, duplicate.text
        # Failed writes never overwrite the old username.
        assert client.get("/api/v1/me").json()["username"] == "another_b"
        assert client.patch("/api/v1/me",
                            json={"username": "no spaces"}).status_code == 422
        assert client.patch("/api/v1/me",
                            json={"username": "ok"}).status_code == 422
        assert client.patch("/api/v1/me",
                            json={"discoverable": True}).status_code == 200

        app.dependency_overrides[get_current_user] = lambda: alice
        assert client.get("/api/v1/friends/discover", params={"q": "another"}).json()[0]["username"] == "another_b"
        # The requester is not discoverable until explicitly enabled.
        app.dependency_overrides[get_current_user] = lambda: bob
        assert client.get("/api/v1/friends/discover", params={"q": "@vytuong"}).json() == []
        app.dependency_overrides[get_current_user] = lambda: alice
        assert client.patch("/api/v1/me", json={"discoverable": True}).status_code == 200

        app.dependency_overrides[get_current_user] = lambda: bob
        found = client.get("/api/v1/friends/discover", params={"q": "@vyt"})
        assert found.status_code == 200, found.text
        assert found.json()[0]["user_id"] == str(alice.user_id)
        assert found.json()[0]["display_name"] == "Vy Tường"
        assert "email" not in found.json()[0]
        invite = client.post("/api/v1/friends/requests", json={"user_id": str(alice.user_id)})
        assert invite.status_code == 201, invite.text

        app.dependency_overrides[get_current_user] = lambda: alice
        inbox = client.get("/api/v1/friends")
        assert inbox.status_code == 200
        row = next(x for x in inbox.json() if x["user_id"] == str(bob.user_id))
        assert row["status"] == "pending"
        assert row["direction"] == "incoming"
        assert row["username"] == "another_b"
        assert client.post(f"/api/v1/friends/{bob.user_id}/accept").status_code == 200

        app.dependency_overrides[get_current_user] = lambda: bob
        result = client.get("/api/v1/friends").json()
        assert any(x["status"] == "accepted" and
                   x["user_id"] == str(alice.user_id) for x in result)
        assert client.delete(f"/api/v1/friends/{alice.user_id}").status_code == 204

        app.dependency_overrides[get_current_user] = lambda: outsider
        assert client.get("/api/v1/friends").json() == []
        # Disable discovery but keep the owner's private profile intact.
        app.dependency_overrides[get_current_user] = lambda: alice
        assert client.patch("/api/v1/me", json={"discoverable": False}).status_code == 200
        app.dependency_overrides[get_current_user] = lambda: bob
        assert client.get("/api/v1/friends/discover", params={"q": "Vy Tường"}).json() == []
        with SessionLocal() as db:
            assert db.get(UserProfile, alice.user_id).username == "vytuong"
    finally:
        app.dependency_overrides.clear()

def test_memory_sharing_local_snapshot_and_private_data_never_exposed():
    from app.core.database import SessionLocal
    from app.models.memory_share import MemoryShare
    a = AuthenticatedUser(user_id=uuid4(), email="local-a@example.com")
    b = AuthenticatedUser(user_id=uuid4(), email="local-b@example.com")
    c = AuthenticatedUser(user_id=uuid4(), email="local-c@example.com")
    place = {"label": "Café", "latitude": 10.77, "longitude": 106.69}
    try:
        app.dependency_overrides[get_current_user] = lambda: a
        assert client.post("/api/v1/friends/requests", json={"user_id": str(b.user_id)}).status_code == 201
        app.dependency_overrides[get_current_user] = lambda: b
        assert client.post(f"/api/v1/friends/{a.user_id}/accept").status_code == 200
        app.dependency_overrides[get_current_user] = lambda: a
        body = {"recipient_ids": [str(b.user_id)], "title": "Shared", "text": "Visible text", "place": place}
        assert client.post("/api/v1/memory-shares", json={**body, "recipient_ids": [str(c.user_id)]}).status_code == 422
        assert client.post("/api/v1/memory-shares", json={**body, "recipient_ids": [str(b.user_id)] * 2}).status_code == 422
        assert client.post("/api/v1/memory-shares", json={**body, "text": "x" * 301}).status_code == 422
        first = client.post("/api/v1/memory-shares", json=body)
        assert first.status_code == 201, first.text
        sid = first.json()["id"]
        app.dependency_overrides[get_current_user] = lambda: c
        assert client.get(f"/api/v1/memory-shares/{sid}").status_code == 404
        assert client.get("/api/v1/memory-shares/received").json() == []
        app.dependency_overrides[get_current_user] = lambda: b
        assert client.get(f"/api/v1/memory-shares/{sid}").json()["text"] == "Visible text"
        app.dependency_overrides[get_current_user] = lambda: a
        second = client.post("/api/v1/memory-shares", json={**body, "text": "Updated", "replacing": sid})
        assert second.status_code == 201, second.text
        sid2 = second.json()["id"]
        assert client.get(f"/api/v1/memory-shares/{sid}").status_code == 404
        app.dependency_overrides[get_current_user] = lambda: b
        assert client.get(f"/api/v1/memory-shares/{sid2}").json()["text"] == "Updated"
        app.dependency_overrides[get_current_user] = lambda: a
        assert client.post("/api/v1/friends/blocks", json={"user_id": str(b.user_id)}).status_code == 204
        app.dependency_overrides[get_current_user] = lambda: b
        assert client.get(f"/api/v1/memory-shares/{sid2}").status_code == 404
        assert client.get("/api/v1/memory-shares/received").json() == []
    finally:
        app.dependency_overrides.clear()

