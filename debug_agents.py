import os
import sys

# Mock environment variables
os.environ["ENCRYPTION_KEY"] = "test_key"
os.environ["GOOGLE_OAUTH_CLIENT_ID"] = "test_client_id"
os.environ["GOOGLE_OAUTH_CLIENT_SECRET"] = "test_client_secret"
os.environ["OAUTH_REDIRECT_URI"] = "http://localhost:8000/callback"

print(f"Current working directory: {os.getcwd()}")
print(f"sys.path: {sys.path}")

print("Attempting to import agents.taskflow_agent...")
try:
    import agents.taskflow_agent
    print("Successfully imported agents.taskflow_agent")
except Exception as e:
    print(f"Failed to import agents.taskflow_agent: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
