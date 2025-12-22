from fastapi.testclient import TestClient
from api_server import app

from unittest.mock import patch


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


def test_time_countdown_accepts_query_payload():
    with patch("api_server.get_user_id_from_request", return_value="u_test"), patch(
        "api_server.store_countdown", return_value="t1"
    ) as mock_store:
        r = client.post("/time/countdown", json={"query": "1 minute"})
        assert r.status_code == 200
        data = r.json()
        assert data.get("timer_id") == "t1"
        assert data.get("ok") is True
        mock_store.assert_called_once()
        args = mock_store.call_args[0]
        assert args[2] == "u_test"


def test_time_countdown_accepts_target_iso_payload():
    with patch("api_server.get_user_id_from_request", return_value="u_test"), patch(
        "api_server.store_countdown", return_value="t2"
    ) as mock_store:
        r = client.post("/time/countdown", json={"target_iso": "2025-11-18T21:15:00"})
        assert r.status_code == 200
        data = r.json()
        assert data.get("timer_id") == "t2"
        assert data.get("ok") is True
        mock_store.assert_called_once()


def test_time_countdown_missing_payload_errors():
    r = client.post("/time/countdown", json={})
    assert r.status_code == 400
    data = r.json()
    assert data.get("ok") is False
    assert data.get("error") == "query_required"


def test_stt_transcribe_empty_audio_returns_400():
    r = client.post(
        "/stt/transcribe",
        data={"language": "en-US"},
        files={"file": ("audio.webm", b"", "audio/webm")},
    )
    assert r.status_code == 400
    assert r.json().get("error") == "empty_audio"


def test_stt_transcribe_success_returns_transcript():
    with patch(
        "api_server.GoogleSttService.transcribe_with_diagnostics",
        return_value={
            "transcript": "hello",
            "error": None,
            "details": None,
        },
    ):
        r = client.post(
            "/stt/transcribe",
            data={"language": "en-US"},
            files={"file": ("audio.webm", b"abc", "audio/webm")},
        )
        assert r.status_code == 200
        data = r.json()
        assert data.get("ok") is True
        assert data.get("transcript") == "hello"
        assert data.get("request_id")
