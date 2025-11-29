import os
import sys

# Mock environment variables
os.environ["ENCRYPTION_KEY"] = "test_key"
os.environ["GOOGLE_OAUTH_CLIENT_ID"] = "test_client_id"
os.environ["GOOGLE_OAUTH_CLIENT_SECRET"] = "test_client_secret"
os.environ["OAUTH_REDIRECT_URI"] = "http://localhost:8000/callback"

print("Attempting to import neuropilot_starter_code...")
try:
    import neuropilot_starter_code
    print("Successfully imported neuropilot_starter_code")
except Exception as e:
    print(f"Failed to import neuropilot_starter_code: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
