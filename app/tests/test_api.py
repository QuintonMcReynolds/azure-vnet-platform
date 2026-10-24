import os

os.environ["DATABASE_URL"] = "sqlite:///./test.db"

from fastapi.testclient import TestClient  # noqa: E402

from src.main import app  # noqa: E402


def client():
    return TestClient(app)


def test_info():
    with client() as c:
        r = c.get("/")
        assert r.status_code == 200
        assert r.json()["service"] == "notes-api"


def test_health_and_ready():
    with client() as c:
        assert c.get("/healthz").json() == {"status": "ok"}
        assert c.get("/readyz").status_code == 200


def test_create_and_list_notes():
    with client() as c:
        r = c.post("/api/notes", json={"text": "deployed into a private VNet"})
        assert r.status_code == 201
        notes = c.get("/api/notes").json()
        assert any(n["text"] == "deployed into a private VNet" for n in notes)


def test_rejects_empty_note():
    with client() as c:
        assert c.post("/api/notes", json={"text": ""}).status_code == 422
