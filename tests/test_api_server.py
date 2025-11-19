from fastapi.testclient import TestClient
from api_server import app


client = TestClient(app)


def test_health():
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json().get("ok") is True


def test_atomize_and_schedule():
    r = client.post("/tasks/atomize", json={"description": "Write report"})
    assert r.status_code == 200
    r2 = client.post("/tasks/schedule", json={"items": ["A","B"], "energy": 5, "weights": [1,2]})
    assert r2.status_code == 200
    assert "ordered" in r2.json()