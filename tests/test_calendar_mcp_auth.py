
import unittest
from unittest.mock import MagicMock, patch, mock_open
from datetime import datetime, timedelta, timezone
import sys
import os
import json

# Add project root to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from services.calendar_mcp import _get_user_credentials_file, _is_valid_credential_file

class TestCalendarMCPAuth(unittest.TestCase):

    def test_is_valid_credential_file_installed_flow(self):
        """Test validation for 'installed' app flow credentials."""
        valid_data = {
            "installed": {
                "client_id": "test_id",
                "client_secret": "test_secret",
                "redirect_uris": ["http://localhost"]
            }
        }
        with patch("builtins.open", mock_open(read_data=json.dumps(valid_data))):
            self.assertTrue(_is_valid_credential_file("path/to/creds.json"))

    def test_is_valid_credential_file_web_flow(self):
        """Test validation for 'web' app flow credentials."""
        valid_data = {
            "web": {
                "client_id": "test_id",
                "client_secret": "test_secret",
                "redirect_uris": ["http://localhost"]
            }
        }
        with patch("builtins.open", mock_open(read_data=json.dumps(valid_data))):
            self.assertTrue(_is_valid_credential_file("path/to/creds.json"))

    def test_is_valid_credential_file_authorized_user(self):
        """Test validation for 'authorized_user' credentials."""
        valid_data = {
            "type": "authorized_user",
            "client_id": "test_id",
            "client_secret": "test_secret",
            "refresh_token": "test_refresh"
        }
        with patch("builtins.open", mock_open(read_data=json.dumps(valid_data))):
            self.assertTrue(_is_valid_credential_file("path/to/creds.json"))

    def test_is_valid_credential_file_invalid_structure(self):
        """Test validation fails for invalid structure."""
        invalid_data = {
            "foo": "bar"
        }
        with patch("builtins.open", mock_open(read_data=json.dumps(invalid_data))):
            self.assertFalse(_is_valid_credential_file("path/to/creds.json"))

    def test_is_valid_credential_file_missing_fields(self):
        """Test validation fails when required fields are missing."""
        # Missing redirect_uris
        invalid_installed = {
            "installed": {
                "client_id": "test_id"
            }
        }
        with patch("builtins.open", mock_open(read_data=json.dumps(invalid_installed))):
            self.assertFalse(_is_valid_credential_file("path/to/creds.json"))

        # Missing refresh_token
        invalid_user = {
            "type": "authorized_user",
            "client_id": "test_id"
        }
        with patch("builtins.open", mock_open(read_data=json.dumps(invalid_user))):
            self.assertFalse(_is_valid_credential_file("path/to/creds.json"))

    def test_is_valid_credential_file_json_error(self):
        """Test validation handles JSON errors gracefully."""
        with patch("builtins.open", mock_open(read_data="{invalid_json")):
            self.assertFalse(_is_valid_credential_file("path/to/creds.json"))

    @patch('services.user_settings.UserSettings')
    @patch('services.oauth_handlers.GoogleOAuthHandler')
    @patch('services.calendar_mcp.tempfile')
    @patch('services.calendar_mcp.os')
    def test_get_credentials_valid_token(self, mock_os, mock_tempfile, mock_oauth_handler, mock_user_settings):
        # Setup env vars
        mock_os.getenv.return_value = "dummy_value"
        mock_os.fdopen.return_value.__enter__.return_value = MagicMock()

        # Setup valid tokens
        mock_settings_instance = mock_user_settings.return_value
        mock_settings_instance.get_oauth_tokens.return_value = {
            "access_token": "valid_access_token",
            "refresh_token": "valid_refresh_token",
            "expires_at": (datetime.now(timezone.utc) + timedelta(hours=1)).isoformat(),
            "scopes": ["scope1"]
        }
        
        # Mock tempfile
        mock_tempfile.mkstemp.return_value = (123, "/tmp/oauth_test.json")
        mock_os.fdopen.return_value.__enter__.return_value = MagicMock()
        
        # Call function
        result = _get_user_credentials_file("test_user")
        
        # Verify
        self.assertEqual(result, "/tmp/oauth_test.json")
        mock_oauth_handler.return_value.refresh_access_token.assert_not_called()

    @patch('services.user_settings.UserSettings')
    @patch('services.oauth_handlers.GoogleOAuthHandler')
    @patch('services.calendar_mcp.tempfile')
    @patch('services.calendar_mcp.os')
    def test_get_credentials_expired_token_refresh_success(self, mock_os, mock_tempfile, mock_oauth_handler, mock_user_settings):
        # Setup env vars
        mock_os.getenv.return_value = "dummy_value"
        mock_os.fdopen.return_value.__enter__.return_value = MagicMock()

        # Setup expired tokens
        mock_settings_instance = mock_user_settings.return_value
        mock_settings_instance.get_oauth_tokens.return_value = {
            "access_token": "expired_access_token",
            "refresh_token": "valid_refresh_token",
            "expires_at": (datetime.now(timezone.utc) - timedelta(hours=1)).isoformat(),
            "scopes": ["scope1"]
        }
        
        # Mock successful refresh
        mock_oauth_instance = mock_oauth_handler.return_value
        mock_oauth_instance.refresh_access_token.return_value = {
            "ok": True,
            "access_token": "new_access_token",
            "expires_at": (datetime.now(timezone.utc) + timedelta(hours=1)).isoformat()
        }
        
        # Mock tempfile
        mock_tempfile.mkstemp.return_value = (123, "/tmp/oauth_test.json")
        mock_os.fdopen.return_value.__enter__.return_value = MagicMock()
        
        # Call function
        result = _get_user_credentials_file("test_user")
        
        # Verify
        self.assertEqual(result, "/tmp/oauth_test.json")
        mock_oauth_instance.refresh_access_token.assert_called_once()
        mock_settings_instance.save_oauth_tokens.assert_called_once()

    @patch('services.user_settings.UserSettings')
    @patch('services.oauth_handlers.GoogleOAuthHandler')
    @patch('services.calendar_mcp.os')
    def test_get_credentials_expired_token_refresh_failure_no_fallback(self, mock_os, mock_oauth_handler, mock_user_settings):
        # Setup expired tokens
        mock_settings_instance = mock_user_settings.return_value
        mock_settings_instance.get_oauth_tokens.return_value = {
            "access_token": "expired_access_token",
            "refresh_token": "invalid_refresh_token",
            "expires_at": (datetime.now(timezone.utc) - timedelta(hours=1)).isoformat(),
            "scopes": ["scope1"]
        }
        
        # Mock failed refresh
        mock_oauth_instance = mock_oauth_handler.return_value
        mock_oauth_instance.refresh_access_token.return_value = {
            "ok": False,
            "error": "Invalid grant. Token likely expired or revoked"
        }
        
        # Ensure fallback also fails
        mock_os.path.exists.return_value = False
        mock_os.getenv.return_value = None
        
        # Call function
        result = _get_user_credentials_file("test_user")
        
        # Verify
        self.assertIsNone(result)
        # Should call delete_oauth_tokens
        mock_settings_instance.delete_oauth_tokens.assert_called_once_with("google_calendar")

    @patch('services.calendar_mcp._is_valid_credential_file')
    @patch('services.user_settings.UserSettings')
    @patch('services.calendar_mcp.os')
    def test_get_credentials_fallback_to_file(self, mock_os, mock_user_settings, mock_is_valid):
        # Setup: UserSettings returns None (no tokens)
        mock_settings_instance = mock_user_settings.return_value
        mock_settings_instance.get_oauth_tokens.return_value = None

        # Setup: Mock os.path.join to return expected paths
        def side_effect_join(a, b):
            return f"{a}/{b}"
        mock_os.path.join.side_effect = side_effect_join

        # Setup: Mock os.path.exists to return True for a specific file
        fallback_dir = "/Users/pratikshatiwari/Documents/trae_projects/altered/credentials"
        target_file = "oauth-neuropilot.json"
        target_path = f"{fallback_dir}/{target_file}"
        
        def side_effect_exists(path):
            return path == target_path
        mock_os.path.exists.side_effect = side_effect_exists
        
        # Mock validation to return True
        mock_is_valid.return_value = True
        
        # Call function
        result = _get_user_credentials_file("test_user")
        
        # Verify
        self.assertEqual(result, target_path)
        mock_is_valid.assert_called_with(target_path)

    @patch('services.calendar_mcp._is_valid_credential_file')
    @patch('services.user_settings.UserSettings')
    @patch('services.calendar_mcp.os')
    def test_get_credentials_fallback_to_env_var(self, mock_os, mock_user_settings, mock_is_valid):
        # Setup: UserSettings returns None
        mock_settings_instance = mock_user_settings.return_value
        mock_settings_instance.get_oauth_tokens.return_value = None
        
        # Setup: File fallback fails
        mock_os.path.exists.return_value = False
        
        # Setup: Env var fallback
        mock_os.getenv.return_value = "/path/to/env/creds.json"
        
        # When checking if env var path exists, return True
        def side_effect_exists(path):
            if path == "/path/to/env/creds.json":
                return True
            return False
        mock_os.path.exists.side_effect = side_effect_exists
        
        # Mock validation to return True
        mock_is_valid.return_value = True

        # Call function
        result = _get_user_credentials_file("test_user")
        
        # Verify
        self.assertEqual(result, "/path/to/env/creds.json")
        mock_is_valid.assert_called_with("/path/to/env/creds.json")

    @patch('services.calendar_mcp._is_valid_credential_file')
    @patch('services.user_settings.UserSettings')
    @patch('services.calendar_mcp.os')
    def test_get_credentials_fallback_skips_invalid_file(self, mock_os, mock_user_settings, mock_is_valid):
        # Setup: UserSettings returns None
        mock_settings_instance = mock_user_settings.return_value
        mock_settings_instance.get_oauth_tokens.return_value = None

        # Setup: Mock os.path.join
        def side_effect_join(a, b):
            return f"{a}/{b}"
        mock_os.path.join.side_effect = side_effect_join

        # Setup: Mock os.path.exists to return True for a specific file
        fallback_dir = "/Users/pratikshatiwari/Documents/trae_projects/altered/credentials"
        target_file = "gcp-oauth.keys.json"
        target_path = f"{fallback_dir}/{target_file}"
        
        def side_effect_exists(path):
            return path == target_path
        mock_os.path.exists.side_effect = side_effect_exists
        
        # Mock validation to return FALSE
        mock_is_valid.return_value = False
        
        # Mock env var also failing or being invalid
        mock_os.getenv.return_value = None

        # Call function
        result = _get_user_credentials_file("test_user")
        
        # Verify
        self.assertIsNone(result)
        mock_is_valid.assert_called_with(target_path)

if __name__ == '__main__':
    unittest.main()
