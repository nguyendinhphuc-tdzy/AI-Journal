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
    assert revision == "20261018_03"
    assert "journal_entries" in tables
    assert "user_profiles" in tables


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
