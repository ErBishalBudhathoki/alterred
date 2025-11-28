import os
import sys
import unittest
from unittest.mock import patch

# Set env for MCP auth and rate limiting BEFORE importing app
os.environ["CALENDAR_MCP_TOKEN"] = "testtoken"
os.environ["MCP_RATE_LIMIT_COUNT"] = "3"
os.environ["MCP_RATE_LIMIT_WINDOW_SECONDS"] = "60"

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from fastapi.testclient import TestClient
from api_server import app

client = TestClient(app)


class TestMcpCalendarApi(unittest.TestCase):
    @patch("api_server.record_api_access")
    @patch("api_server.account_status")
    def test_status_auth_success(self, mock_status, mock_record):
        # Reset rate limit buckets to avoid interference from other tests
        from api_server import _MCP_RATE_BUCKETS
        _MCP_RATE_BUCKETS.clear()
        mock_status.return_value = {"ok": True, "normal": {"has_tokens": True}, "mcp_ready": True}
        r = client.get(
            "/mcp/calendar/v1/status",
            headers={"X-Calendar-MCP-Token": "testtoken"},
            params={"user_id": "tester"},
        )
        self.assertEqual(r.status_code, 200)
        self.assertTrue(r.json().get("ok"))
        mock_record.assert_called()

    def test_status_auth_missing(self):
        r = client.get("/mcp/calendar/v1/status")
        self.assertEqual(r.status_code, 401)

    def test_status_auth_wrong(self):
        r = client.get("/mcp/calendar/v1/status", headers={"X-Calendar-MCP-Token": "wrong"})
        self.assertEqual(r.status_code, 401)

    @patch("api_server.record_api_access")
    @patch("api_server.search_events")
    def test_search_rate_limit(self, mock_search, mock_record):
        # Reset rate limit buckets for deterministic behavior
        from api_server import _MCP_RATE_BUCKETS
        _MCP_RATE_BUCKETS.clear()
        mock_search.return_value = {"ok": True, "result": {"events": []}}
        headers = {"X-Calendar-MCP-Token": "testtoken"}
        payload = {"calendarIds": ["primary"], "timeMin": "2025-01-01T00:00:00+00:00", "timeMax": "2025-01-02T00:00:00+00:00"}
        # 3 allowed
        for _ in range(3):
            r = client.post("/mcp/calendar/v1/search", headers=headers, json=payload)
            self.assertEqual(r.status_code, 200)
        # 4th should be rate limited (429)
        r = client.post("/mcp/calendar/v1/search", headers=headers, json=payload)
        self.assertEqual(r.status_code, 429)


if __name__ == "__main__":
    unittest.main()
