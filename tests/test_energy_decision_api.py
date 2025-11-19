from fastapi.testclient import TestClient
from api_server import app


client = TestClient(app)


def test_energy_match():
    r = client.post("/energy/match", json={"tasks": ["email","code"], "energy": 3})
    assert r.status_code == 200
    assert "recommended_task_type" in r.json()


def test_decision_commit():
    r = client.post("/decision/commit", json={"choice": "Option A"})
    assert r.status_code == 200
    assert r.json().get("committed") is True