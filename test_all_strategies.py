import requests
import json

BASE_URL = "http://localhost:8000"

def test_all_strategies():
    """Test that dopamine reframe now returns ALL strategies"""
    print("Testing: 'I hate doing taxes'")
    print("=" * 60)
    
    payload = {
        "text": "I hate doing taxes", 
        "session_id": "test_all_strategies_123"
    }
    
    try:
        r = requests.post(f"{BASE_URL}/chat/respond", json=payload)
        data = r.json()
        
        print(f"\nAgent Response Text:")
        print(f"{data.get('text', '')}")
        
        print(f"\n\nTools Called:")
        tools = data.get('tools', [])
        if tools:
            for tool in tools:
                if 'strategies' in tool:
                    print("\n✨ All Strategies Returned:")
                    for name, desc in tool['strategies'].items():
                        print(f"  - {name}: {desc}")
        
        # Check what the agent did
        text = data.get("text", "")
        has_speed_run = "speed run" in text.lower()
        has_body_double = "body double" in text.lower()
        has_dj_mode = "dj mode" in text.lower()
        has_multiple = text.count("**") >= 6  # Each strategy has bold name
        
        print("\n" + "=" * 60)
        print("RESULTS:")
        print(f"✓ Speed Run included: {has_speed_run}")
        print(f"✓ Body Double included: {has_body_double}")
        print(f"✓ DJ Mode included: {has_dj_mode}")
        print(f"✓ Multiple strategies shown: {has_multiple}")
        
        if has_speed_run and has_body_double and has_dj_mode and has_multiple:
            print("\n🎉 SUCCESS: ALL strategies are being shown!")
        else:
            print("\n⚠️  PARTIAL: Some strategies missing")
            
    except Exception as e:
        print(f"Request failed: {e}")

if __name__ == "__main__":
    test_all_strategies()
