from fastapi.testclient import TestClient
from api_server import app


client = TestClient(app)


def test_memory_patterns_endpoint():
    r = client.get("/memory/patterns")
    assert r.status_code == 200
    assert "patterns" in r.json()


def test_memory_compact_requires_session_id():
    r = client.post("/memory/compact", json={"session_id": "sess_missing"})
    assert r.status_code == 200
    # ok may be False if session missing
    assert "ok" in r.json()