import requests
import json

BASE_URL = "http://localhost:8000"

def test_both_features():
    """Test that agent provides both dopamine reframe AND task atomization"""
    print("Testing: 'I have to do my taxes'")
    print("=" * 60)
    
    payload = {
        "text": "I have to do my taxes", 
        "session_id": "test_combined_123"
    }
    
    try:
        r = requests.post(f"{BASE_URL}/chat/respond", json=payload)
        data = r.json()
        
        print(f"\nAgent Response Text:")
        print(f"{data.get('text', '')}")
        
        print(f"\nTools Called:")
        print(f"{json.dumps(data.get('tools', []), indent=2)}")
        
        # Check what the agent did
        has_dopamine = "dopamine" in data.get("text", "").lower() or "speed run" in data.get("text", "").lower()
        has_atomization = "break" in data.get("text", "").lower() or "steps" in data.get("text", "").lower()
        
        print("\n" + "=" * 60)
        print("RESULTS:")
        print(f"✓ Dopamine hack mentioned: {has_dopamine}")
        print(f"✓ Task breakdown offered: {has_atomization}")
        
        if has_dopamine and has_atomization:
            print("\n🎉 SUCCESS: Both features working together!")
        elif has_dopamine and not has_atomization:
            print("\n⚠️  PARTIAL: Only dopamine hack, missing atomization")
        elif has_atomization and not has_dopamine:
            print("\n⚠️  PARTIAL: Only atomization, missing dopamine")
        else:
            print("\n❌ FAILURE: Neither feature detected")
            
    except Exception as e:
        print(f"Request failed: {e}")

if __name__ == "__main__":
    test_both_features()
