import os
import unittest

from services.calendar_mcp import _get_user_credentials_file


class TestCalendarMcpCredentials(unittest.TestCase):
    def setUp(self):
        # Ensure no user settings override
        if "GOOGLE_OAUTH_CREDENTIALS" in os.environ:
            del os.environ["GOOGLE_OAUTH_CREDENTIALS"]
        os.environ["MCP_CREDENTIALS_PREFERRED"] = "gcp-oauth.keys.json"

    def test_prefers_gcp_oauth_keys_json(self):
        path = _get_user_credentials_file(None, account="normal")
        self.assertIsNotNone(path)
        self.assertTrue(path.endswith("gcp-oauth.keys.json"))

    def test_respects_preferred_env(self):
        os.environ["MCP_CREDENTIALS_PREFERRED"] = "oauth-neuropilot.keys.json"
        path = _get_user_credentials_file(None, account="normal")
        self.assertIsNotNone(path)
        self.assertTrue(path.endswith("oauth-neuropilot.keys.json"))


if __name__ == "__main__":
    unittest.main()

