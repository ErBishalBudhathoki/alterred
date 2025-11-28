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

    def get_oauth_tokens(self, provider: str):
        return {
            "provider": provider,
            "access_token": "token",
            "refresh_token": "refresh",
            "expires_at": "1999-01-01T00:00:00",
            "scopes": ["https://www.googleapis.com/auth/calendar"],
        }

    def save_oauth_tokens(self, provider: str, access_token: str, refresh_token: str, expires_at: str, scopes: list[str]):
        return {"ok": True}


class StubOAuthHandler:
    def __init__(self):
        pass

    def refresh_access_token(self, refresh_token: str):
        return {"ok": True, "access_token": "new", "expires_at": "2999-01-01T00:00:00"}


def test_calendar_validate_refreshes(monkeypatch):
    import api_server as api
    monkeypatch.setattr(api, "UserSettings", StubUserSettings)
    from services import oauth_handlers as oh
    monkeypatch.setattr(oh, "GoogleOAuthHandler", StubOAuthHandler)

    r = client.get("/auth/google/calendar/validate")
    j = r.json()
    assert r.status_code == 200
    assert j["ok"] is True
    assert j["connected"] is True
    assert j["status"] == "ready"


class StubUserSettingsNoTokens(StubUserSettings):
    def get_oauth_tokens(self, provider: str):
        return None


def test_calendar_validate_no_tokens(monkeypatch):
    import api_server as api
    monkeypatch.setattr(api, "UserSettings", StubUserSettingsNoTokens)

    r = client.get("/auth/google/calendar/validate")
    j = r.json()
    assert r.status_code == 200
    assert j["ok"] is True
    assert j["connected"] is False
    assert j["status"] == "reauth_required"
