import requests
import json
import time

BASE_URL = "http://localhost:8000"

def test_body_double_flow():
    print("1. Testing Health...")
    try:
        r = requests.get(f"{BASE_URL}/health")
        print(f"Health: {r.json()}")
    except Exception as e:
        print(f"Health check failed: {e}")
        return

    print("\n2. Starting Body Double...")
    payload = {"text": "start body double", "session_id": "test_session_123"}
    r = requests.post(f"{BASE_URL}/chat/respond", json=payload)
    data = r.json()
    print(f"Response: {json.dumps(data, indent=2)}")
    
    # Check if tool was called
    tools = data.get("tools", [])
    body_double_started = False
    for t in tools:
        if isinstance(t, dict) and t.get("ui_mode") == "body_double":
            body_double_started = True
            print("SUCCESS: Body double mode started.")
            break
    
    if not body_double_started:
        print("FAILURE: Body double mode NOT started.")

    print("\n3. Testing Check-in Trigger...")
    # Simulate the system message sent by frontend
    checkin_payload = {
        "text": "System: User has been silent for 15 seconds. Session active for 1 minutes. Please use body_double_checkin tool with duration_minutes=1.",
        "session_id": "test_session_123"
    }
    r = requests.post(f"{BASE_URL}/chat/respond", json=checkin_payload)
    data = r.json()
    print(f"Response: {json.dumps(data, indent=2)}")

    # Check if check-in tool was called
    tools = data.get("tools", [])
    checkin_fired = False
    for t in tools:
        if isinstance(t, dict) and "check_in" in t:
            checkin_fired = True
            print(f"SUCCESS: Check-in fired. Prompt: {t.get('prompt')}")
            break
    
    if not checkin_fired:
        print("FAILURE: Check-in tool NOT called.")
        # Print text to see if it just chatted back
        print(f"Agent Text Response: {data.get('text')}")

if __name__ == "__main__":
    test_body_double_flow()
