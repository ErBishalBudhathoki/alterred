import os
import unittest
from fastapi.testclient import TestClient

from api_server import app


class TestMcpCredentialsEndpoint(unittest.TestCase):
    def setUp(self):
        os.environ["CALENDAR_MCP_TOKEN"] = "test-mcp-token"
        os.environ["MCP_CREDENTIALS_PREFERRED"] = "gcp-oauth.keys.json"
        os.environ["ALLOW_MCP_TOKEN_QUERY"] = "true"

    def test_credentials_endpoint_returns_filename(self):
        client = TestClient(app)
        r = client.get(
            "/mcp/calendar/v1/credentials",
            headers={"X-Calendar-MCP-Token": os.environ["CALENDAR_MCP_TOKEN"]},
        )
        self.assertEqual(r.status_code, 200)
        data = r.json()
        self.assertTrue(data.get("ok"))
        self.assertTrue(data.get("filename"))
        self.assertTrue(data["filename"].endswith(".json"))


if __name__ == "__main__":
    unittest.main()
    def test_credentials_endpoint_query_token(self):
        client = TestClient(app)
        r = client.get(
            "/mcp/calendar/v1/credentials?token=" + os.environ["CALENDAR_MCP_TOKEN"],
        )
        self.assertEqual(r.status_code, 200)
        data = r.json()
        self.assertTrue(data.get("ok"))
        self.assertTrue(data.get("filename"))
