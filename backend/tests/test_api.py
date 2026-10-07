from pathlib import Path
import os
import tempfile

fd, db_path = tempfile.mkstemp(suffix=".db")
os.close(fd)
os.environ["DATABASE_URL"] = f"sqlite:///{db_path}"

from fastapi.testclient import TestClient  # noqa: E402
from app.main import app  # noqa: E402

client = TestClient(app)


def teardown_module():
    Path(db_path).unlink(missing_ok=True)


def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


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
