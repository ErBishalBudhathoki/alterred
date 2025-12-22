from fastapi.testclient import TestClient

from api_server import app

client = TestClient(app)


def _post(path: str, payload: dict):
    return client.post(path, json=payload)


def test_help():
    r = client.get("/chat/help")
    assert r.status_code == 200
    data = r.json()
    assert data.get("ok") is True
    assert "help" in data


def test_metrics_overview_via_command():
    r = _post("/chat/command", {"text": "metrics overview"})
    assert r.status_code == 200
    d = r.json()
    assert d.get("ok") in (True, False)
    assert "session_id" in d


def test_yesterday_conversations():
    r = _post("/chat/command", {"text": "show yesterday conversations"})
    assert r.status_code == 200
    d = r.json()
    assert d.get("ok") in (True, False)


def test_sound_list():
    r = _post("/chat/command", {"text": "sound: list"})
    assert r.status_code == 200
    d = r.json()
    assert d.get("ok") in (True, False)


def test_unknown_command():
    r = _post("/chat/command", {"text": "blorp this does nothing"})
    assert r.status_code == 200
    d = r.json()
    assert d.get("ok") in (True, False)
    assert "session_id" in d
