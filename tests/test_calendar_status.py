import os
import sys
from fastapi.testclient import TestClient

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from api_server import app

client = TestClient(app)


class StubUserSettings:
    def __init__(self, user_id: str):
        self.user_id = user_id

    def is_oauth_connected(self, provider: str) -> bool:
        return True

    def get_oauth_tokens(self, provider: str):
        return {
            "provider": provider,
            "access_token": "token",
            "refresh_token": "refresh",
            "expires_at": "2999-01-01T00:00:00",
            "scopes": ["https://www.googleapis.com/auth/calendar"],
        }


def test_calendar_status_connected(monkeypatch):
    import api_server as api
    monkeypatch.setattr(api, "UserSettings", StubUserSettings)

    r = client.get("/auth/google/calendar/status")
    j = r.json()
    assert r.status_code == 200
    assert j["ok"] is True
    assert j["connected"] is True
    assert j["details"]["has_tokens"] is True


class StubUserSettingsNoTokens(StubUserSettings):
    def is_oauth_connected(self, provider: str) -> bool:
        return False

    def get_oauth_tokens(self, provider: str):
        return None


def test_calendar_status_disconnected(monkeypatch):
    import api_server as api
    monkeypatch.setattr(api, "UserSettings", StubUserSettingsNoTokens)

    r = client.get("/auth/google/calendar/status")
    j = r.json()
    assert r.status_code == 200
    assert j["ok"] is True
    assert j["connected"] is False
    assert j["details"]["has_tokens"] is False
