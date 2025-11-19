import requests
import json

BASE_URL = "http://localhost:8000"

def test_dopamine_flow():
    print("1. Testing Dopamine Reframe...")
    payload = {
        "text": "I have to do my taxes and it's so boring.", 
        "session_id": "test_dopamine_123"
    }
    try:
        r = requests.post(f"{BASE_URL}/chat/respond", json=payload)
        data = r.json()
        print(f"Response: {json.dumps(data, indent=2)}")
        
        # Check if tool was called
        tools = data.get("tools", [])
        tool_called = False
        for t in tools:
            if isinstance(t, dict) and "strategy" in t:
                tool_called = True
                print(f"SUCCESS: Dopamine reframe tool called. Strategy: {t.get('strategy')}")
                break
        
        if not tool_called:
            # It might just return text if the model decides to answer directly, but we want to encourage tool use.
            # Let's see what the text says.
            print(f"Tool might not have been called explicitly in the final response list if the agent just used the output.")
            if "dopamine" in data.get("text", "").lower() or "strategy" in data.get("text", "").lower():
                 print("SUCCESS: Agent response seems relevant.")
            else:
                 print("FAILURE: Agent did not seem to use the dopamine reframe logic.")

    except Exception as e:
        print(f"Request failed: {e}")

if __name__ == "__main__":
    test_dopamine_flow()
