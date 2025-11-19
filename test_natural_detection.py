import requests
import json

BASE_URL = "http://localhost:8000"

def test_natural_detection():
    """Test if agent naturally offers dopamine without explicit 'hate' keyword"""
    
    test_cases = [
        "I have to do my taxes",
        "Need to clean my room",
        "Got some paperwork to do",
        "I should organize my files"
    ]
    
    for test_input in test_cases:
        print(f"\n{'='*60}")
        print(f"Testing: '{test_input}'")
        print('='*60)
        
        payload = {
            "text": test_input, 
            "session_id": f"test_natural_{test_input[:10]}"
        }
        
        try:
            r = requests.post(f"{BASE_URL}/chat/respond", json=payload)
            data = r.json()
            
            text = data.get('text', '')
            tools = data.get('tools', [])
            
            # Check if dopamine was mentioned
            has_dopamine = any([
                "dopamine" in text.lower(),
                "speed run" in text.lower(),
                "game" in text.lower(),
                any(tool.get('ui_mode') == 'dopamine_card' for tool in tools if isinstance(tool, dict))
            ])
            
            print(f"\n📝 Response: {text[:200]}...")
            print(f"\n{'✅' if has_dopamine else '❌'} Dopamine offered: {has_dopamine}")
            
        except Exception as e:
            print(f"❌ Request failed: {e}")

if __name__ == "__main__":
    test_natural_detection()
