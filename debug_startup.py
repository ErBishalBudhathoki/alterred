import os
import sys

# Mock environment variables required for import
os.environ["ENCRYPTION_KEY"] = "test_key"
os.environ["GOOGLE_OAUTH_CLIENT_ID"] = "test_client_id"
os.environ["GOOGLE_OAUTH_CLIENT_SECRET"] = "test_client_secret"
os.environ["OAUTH_REDIRECT_URI"] = "http://localhost:8000/callback"

print("Attempting to import api_server...")
try:
    import api_server
    print("Successfully imported api_server")
except Exception as e:
    print(f"Failed to import api_server: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
