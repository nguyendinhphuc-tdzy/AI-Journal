from pathlib import Path
import os
import tempfile

from alembic import command
from alembic.config import Config

fd, db_path = tempfile.mkstemp(suffix=".db")
os.close(fd)
os.environ["DATABASE_URL"] = f"sqlite:///{db_path}"

backend_dir = Path(__file__).resolve().parents[1]
config = Config(str(backend_dir / "alembic.ini"))
config.set_main_option("script_location", str(backend_dir / "alembic"))
command.upgrade(config, "head")

from fastapi.testclient import TestClient  # noqa: E402
from app.main import app  # noqa: E402

client = TestClient(app)


def teardown_module():
    from app.core.database import engine

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
        result = conn.execute(text("SELECT version_num FROM alembic_version")).scalar_one()
    assert result == "20261011_01"


def test_core_journal_flow():
    create = client.post(
        "/api/v1/journals",
        json={
            "title": "Demo entry",
            "content": "I finished something that had been worrying me.",
            "mood": "relieved",
        },
    )
    assert create.status_code == 201
    journal_id = create.json()["id"]

    listing = client.get("/api/v1/journals")
    assert listing.status_code == 200
    assert any(item["id"] == journal_id for item in listing.json())

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


def test_diary_update_and_delete():
    response = client.post("/api/v1/journals", json={"content": "First version"})
    assert response.status_code == 201
    journal_id = response.json()["id"]

    detail = client.get(f"/api/v1/journals/{journal_id}")
    assert detail.status_code == 200
    assert detail.json()["content"] == "First version"

    updated = client.put(f"/api/v1/journals/{journal_id}", json={"content": "Updated"})
    assert updated.status_code == 200
    assert updated.json()["content"] == "Updated"

    deleted = client.delete(f"/api/v1/journals/{journal_id}")
    assert deleted.status_code == 204
    assert client.get(f"/api/v1/journals/{journal_id}").status_code == 404


def test_empty_content_is_rejected():
    response = client.post("/api/v1/journals", json={"content": ""})
    assert response.status_code == 422
