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
    assert revision == "20261018_04"
    assert "journal_entries" in tables
    assert "user_profiles" in tables
    assert "journal_action_days" in tables


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
