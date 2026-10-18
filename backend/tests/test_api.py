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
    assert revision == "20261018_02"
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


def test_journal_crud_is_closed_until_owner_migration():
    app.dependency_overrides.clear()
    assert client.get("/api/v1/journals").status_code == 401
    assert client.post("/api/v1/journals", json={"content": "private"}).status_code == 401
    assert client.get("/api/v1/journals/1").status_code == 401
    assert client.put("/api/v1/journals/1", json={"content": "private"}).status_code == 401
    assert client.delete("/api/v1/journals/1").status_code == 401

    user = AuthenticatedUser(user_id=uuid4(), email="user@example.com")
    app.dependency_overrides[get_current_user] = lambda: user
    try:
        assert client.get("/api/v1/journals").status_code == 503
        assert client.post("/api/v1/journals", json={"content": "private"}).status_code == 503
        assert client.get("/api/v1/journals/1").status_code == 503
        assert client.put("/api/v1/journals/1", json={"content": "private"}).status_code == 503
        assert client.delete("/api/v1/journals/1").status_code == 503
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
