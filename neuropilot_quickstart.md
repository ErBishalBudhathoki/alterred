# Altered - Quick Start Implementation Guide
## Get Your First Agent Running in 2 Hours

---

## 🚀 PHASE 1: SETUP (30 minutes)

### **Step 1: Environment Setup**

```bash
# Create project directory
mkdir neuropilot-capstone
cd neuropilot-capstone

# Create virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install google-adk google-genai fastapi uvicorn python-dotenv firebase-admin

# Verify installation
python -c "import google.adk; print('ADK installed successfully!')"
```

### **Step 2: Get API Keys**

1. **Gemini API Key** (FREE):
   - Go to: https://ai.google.dev/
   - Click "Get API Key in Google AI Studio"
   - Create new API key
   - Copy it

2. **Create .env file**:
```bash
# .env
GOOGLE_API_KEY=your_api_key_here
GOOGLE_GENAI_USE_VERTEXAI=FALSE
MODEL=gemini-2.0-flash-001
```

### **Step 3: Test Basic Setup**

```python
# test_setup.py
import os
from dotenv import load_dotenv
from google.genai import Client

load_dotenv()

client = Client(api_key=os.getenv('GOOGLE_API_KEY'))
response = client.models.generate_content(
    model='gemini-2.0-flash-001',
    contents='Say hello!'
)
print(response.text)
```

Run: `python test_setup.py`

If you see a response, you're ready! ✅

---

## 🤖 PHASE 2: FIRST WORKING AGENT (60 minutes)

### **Create Your First Agent**

```python
# simple_agent.py
from google.adk.agents.llm_agent import Agent
from google.adk.sessions import InMemorySessionService
import os
from dotenv import load_dotenv

load_dotenv()

# Define a simple tool
def analyze_brain_state(user_message: str) -> dict:
    """Detect if user is focused, scattered, or overwhelmed"""
    message_lower = user_message.lower()
    
    if any(word in message_lower for word in ['stuck', 'overwhelmed', 'can\'t']):
        state = 'overwhelmed'
    elif any(word in message_lower for word in ['distracted', 'jumping', 'tabs']):
        state = 'scattered'
    elif any(word in message_lower for word in ['working', 'progress', 'focused']):
        state = 'focused'
    else:
        state = 'neutral'
    
    return {
        'brain_state': state,
        'confidence': 0.8,
        'suggestion': f"You seem {state}. Let me help."
    }

# Create agent
neuropilot_agent = Agent(
    model='gemini-2.0-flash-001',
    name='neuropilot_simple',
    instruction="""You are NeuroPilot, an executive function companion for 
    neurodivergent adults. Be empathetic, direct, and supportive. 
    
    Use the analyze_brain_state tool to understand the user's current state,
    then provide appropriate support.""",
    tools=[analyze_brain_state]
)

# Initialize session
session_service = InMemorySessionService()

# Test interaction
if __name__ == "__main__":
    print("🧠 Altered Simple Demo")
    print("=" * 50)
    
    # Create session
    session_id = "test_user_001"
    session = session_service.create_session(session_id)
    
    # Simulate conversation
    user_messages = [
        "I feel so overwhelmed with all these tasks",
        "I've been jumping between tabs for an hour",
        "Actually making good progress on my code!"
    ]
    
    for msg in user_messages:
        print(f"\n👤 User: {msg}")
        
        response = neuropilot_agent.run(
            user_message=msg,
            session_id=session_id
        )
        
        print(f"🤖 NeuroPilot: {response.text}")
        print(f"   [Brain State: {response.tool_results}]" if response.tool_results else "")

print("\n✅ Simple agent working!")
```

Run: `python simple_agent.py`

---

## 🎨 PHASE 3: ADD WEB INTERFACE (30 minutes)

### **Simple FastAPI Backend**

```python
# api.py
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from simple_agent import neuropilot_agent, session_service
import json
from typing import Dict

app = FastAPI(title="NeuroPilot API")

# Enable CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # For development only
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Store active WebSocket connections
active_connections: Dict[str, WebSocket] = {}

@app.get("/")
async def root():
    return {"message": "NeuroPilot API is running!"}

@app.websocket("/ws/{user_id}")
async def websocket_endpoint(websocket: WebSocket, user_id: str):
    await websocket.accept()
    active_connections[user_id] = websocket
    
    # Create or get session
    try:
        session = session_service.get_session(user_id)
    except:
        session = session_service.create_session(user_id)
    
    try:
        while True:
            # Receive message from frontend
            data = await websocket.receive_text()
            message_data = json.loads(data)
            user_message = message_data.get('message', '')
            
            # Send "thinking" indicator
            await websocket.send_json({
                "type": "thinking",
                "message": "NeuroPilot is thinking..."
            })
            
            # Run agent
            response = neuropilot_agent.run(
                user_message=user_message,
                session_id=user_id
            )
            
            # Send response
            await websocket.send_json({
                "type": "response",
                "message": response.text,
                "brain_state": response.tool_results[0] if response.tool_results else None
            })
            
    except WebSocketDisconnect:
        del active_connections[user_id]
        print(f"Client {user_id} disconnected")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
```

### **Simple HTML Frontend**

```html
<!-- index.html -->
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>NeuroPilot - Executive Function Companion</title>
    <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-gray-100">
    <div class="container mx-auto max-w-4xl p-4">
        <div class="bg-white rounded-lg shadow-lg p-6">
            <h1 class="text-3xl font-bold mb-4">🧠 NeuroPilot</h1>
            <p class="text-gray-600 mb-6">Your Executive Function Companion</p>
            
            <!-- Chat Container -->
            <div id="chat-container" class="h-96 overflow-y-auto mb-4 p-4 bg-gray-50 rounded">
                <!-- Messages will appear here -->
            </div>
            
            <!-- Input Area -->
            <div class="flex gap-2">
                <input 
                    id="message-input" 
                    type="text" 
                    placeholder="Tell me what's on your mind..."
                    class="flex-1 p-3 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
                <button 
                    id="send-button"
                    class="px-6 py-3 bg-blue-500 text-white rounded-lg hover:bg-blue-600 transition"
                >
                    Send
                </button>
            </div>
        </div>
    </div>

    <script>
        const userId = 'user_' + Math.random().toString(36).substr(2, 9);
        const ws = new WebSocket(`ws://localhost:8000/ws/${userId}`);
        const chatContainer = document.getElementById('chat-container');
        const messageInput = document.getElementById('message-input');
        const sendButton = document.getElementById('send-button');

        // Add message to chat
        function addMessage(message, isUser = false) {
            const messageDiv = document.createElement('div');
            messageDiv.className = `mb-4 ${isUser ? 'text-right' : 'text-left'}`;
            
            const bubble = document.createElement('div');
            bubble.className = `inline-block p-3 rounded-lg max-w-md ${
                isUser 
                    ? 'bg-blue-500 text-white' 
                    : 'bg-gray-200 text-gray-800'
            }`;
            bubble.textContent = message;
            
            messageDiv.appendChild(bubble);
            chatContainer.appendChild(messageDiv);
            chatContainer.scrollTop = chatContainer.scrollHeight;
        }

        // WebSocket message handler
        ws.onmessage = (event) => {
            const data = JSON.parse(event.data);
            
            if (data.type === 'thinking') {
                addMessage('💭 ' + data.message);
            } else if (data.type === 'response') {
                // Remove "thinking" message
                const lastMessage = chatContainer.lastElementChild;
                if (lastMessage && lastMessage.textContent.includes('💭')) {
                    lastMessage.remove();
                }
                
                addMessage(data.message);
                
                // Show brain state if available
                if (data.brain_state) {
                    const state = data.brain_state.brain_state;
                    addMessage(`[Detected state: ${state}]`, false);
                }
            }
        };

        // Send message
        function sendMessage() {
            const message = messageInput.value.trim();
            if (!message) return;
            
            addMessage(message, true);
            
            ws.send(JSON.stringify({
                message: message
            }));
            
            messageInput.value = '';
        }

        sendButton.addEventListener('click', sendMessage);
        messageInput.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') sendMessage();
        });

        // Welcome message
        ws.onopen = () => {
            addMessage("Hi! I'm NeuroPilot, your executive function companion. How can I support you today?");
        };
    </script>
</body>
</html>
```

### **Run Your App**

```bash
# Terminal 1: Start backend
python api.py

# Terminal 2: Serve frontend (simple HTTP server)
python -m http.server 3000

# Open browser: http://localhost:3000
```

---

## 🎯 PHASE 4: ADD DECISION TIMER FEATURE (45 minutes)

### **Enhanced Agent with Timer**

```python
# decision_agent.py
from simple_agent import neuropilot_agent
import asyncio
from datetime import datetime, timedelta

class DecisionTimerManager:
    def __init__(self):
        self.active_timers = {}
    
    async def start_decision_timer(
        self, 
        user_id: str, 
        decision: str,
        websocket
    ) -> str:
        """Start 90-second detection + 60-second countdown"""
        
        timer_id = f"decision_{user_id}_{int(datetime.now().timestamp())}"
        
        self.active_timers[timer_id] = {
            'user_id': user_id,
            'decision': decision,
            'default_choice': 'Thai Restaurant',  # From memory
            'started_at': datetime.now(),
            'cancelled': False
        }
        
        # Start countdown task
        asyncio.create_task(
            self._countdown_and_decide(timer_id, websocket)
        )
        
        return timer_id
    
    async def _countdown_and_decide(self, timer_id: str, websocket):
        """Background task for countdown"""
        
        timer = self.active_timers[timer_id]
        
        # Send initial message
        await websocket.send_json({
            "type": "decision_timer_start",
            "message": f"You're in decision paralysis. Based on your preferences, "
                      f"I'm choosing {timer['default_choice']}. "
                      f"Reply STOP to cancel in 60 seconds.",
            "timer_seconds": 60,
            "timer_id": timer_id
        })
        
        # Count down
        for remaining in range(60, 0, -10):
            await asyncio.sleep(10)
            
            if timer['cancelled']:
                await websocket.send_json({
                    "type": "timer_cancelled",
                    "message": "Decision cancelled. Want to decide manually?"
                })
                return
            
            await websocket.send_json({
                "type": "timer_update",
                "remaining_seconds": remaining
            })
        
        # Time's up - make decision
        if not timer['cancelled']:
            await websocket.send_json({
                "type": "decision_made",
                "message": f"✅ Decision made: {timer['default_choice']}!",
                "choice": timer['default_choice']
            })
        
        # Cleanup
        del self.active_timers[timer_id]
    
    def cancel_timer(self, timer_id: str):
        """Cancel active timer"""
        if timer_id in self.active_timers:
            self.active_timers[timer_id]['cancelled'] = True
            return True
        return False

# Global timer manager
timer_manager = DecisionTimerManager()
```

### **Update API with Timer Support**

```python
# Add to api.py

@app.websocket("/ws/{user_id}")
async def websocket_endpoint(websocket: WebSocket, user_id: str):
    # ... existing code ...
    
    try:
        while True:
            data = await websocket.receive_text()
            message_data = json.loads(data)
            user_message = message_data.get('message', '')
            
            # Check for STOP command
            if user_message.upper() == 'STOP':
                # Cancel any active timers
                for timer_id in list(timer_manager.active_timers.keys()):
                    if timer_manager.active_timers[timer_id]['user_id'] == user_id:
                        timer_manager.cancel_timer(timer_id)
                
                await websocket.send_json({
                    "type": "response",
                    "message": "Timer cancelled!"
                })
                continue
            
            # Run agent
            response = neuropilot_agent.run(
                user_message=user_message,
                session_id=user_id
            )
            
            # Check if decision paralysis detected
            if response.tool_results:
                brain_state = response.tool_results[0]['brain_state']
                
                if brain_state == 'overwhelmed' and 'food' in user_message.lower():
                    # Start decision timer
                    await timer_manager.start_decision_timer(
                        user_id, 
                        user_message,
                        websocket
                    )
            
            # Send normal response
            await websocket.send_json({
                "type": "response",
                "message": response.text
            })
    
    except WebSocketDisconnect:
        # Cleanup
        for timer_id in list(timer_manager.active_timers.keys()):
            if timer_manager.active_timers[timer_id]['user_id'] == user_id:
                timer_manager.cancel_timer(timer_id)
        
        del active_connections[user_id]
```

### **Update Frontend with Timer Display**

```html
<!-- Add to index.html after chat-container -->

<div id="timer-container" class="hidden mb-4 p-4 bg-yellow-100 border-2 border-yellow-500 rounded-lg">
    <div class="flex items-center justify-between">
        <div>
            <p class="font-bold text-lg mb-2">⚠️ Decision Paralysis Detected</p>
            <p id="timer-message" class="text-sm"></p>
        </div>
        <div class="text-center">
            <div id="timer-display" class="text-4xl font-bold text-red-600 mb-2">60</div>
            <button 
                id="stop-timer-button"
                class="px-4 py-2 bg-red-500 text-white rounded hover:bg-red-600"
            >
                STOP
            </button>
        </div>
    </div>
</div>

<script>
// Add to existing script

let activeTimerId = null;
let timerInterval = null;

ws.onmessage = (event) => {
    const data = JSON.parse(event.data);
    
    if (data.type === 'decision_timer_start') {
        // Show timer
        document.getElementById('timer-container').classList.remove('hidden');
        document.getElementById('timer-message').textContent = data.message;
        document.getElementById('timer-display').textContent = data.timer_seconds;
        
        activeTimerId = data.timer_id;
        
        // Start countdown
        let remaining = data.timer_seconds;
        timerInterval = setInterval(() => {
            remaining--;
            document.getElementById('timer-display').textContent = remaining;
            
            if (remaining <= 0) {
                clearInterval(timerInterval);
            }
        }, 1000);
    }
    else if (data.type === 'timer_update') {
        document.getElementById('timer-display').textContent = data.remaining_seconds;
    }
    else if (data.type === 'timer_cancelled' || data.type === 'decision_made') {
        // Hide timer
        document.getElementById('timer-container').classList.add('hidden');
        clearInterval(timerInterval);
        activeTimerId = null;
        
        addMessage(data.message);
    }
    // ... rest of existing handlers ...
};

// Stop timer button
document.getElementById('stop-timer-button').addEventListener('click', () => {
    ws.send(JSON.stringify({ message: 'STOP' }));
});
</script>
```

---

## 📊 PHASE 5: ADD SIMPLE MEMORY (30 minutes)

### **Simple Memory Storage**

```python
# memory.py
import json
import os
from datetime import datetime
from typing import Dict, List, Any

class SimpleMemoryBank:
    """File-based memory storage for capstone"""
    
    def __init__(self, user_id: str):
        self.user_id = user_id
        self.memory_file = f"memory_{user_id}.json"
        self.memory = self._load_memory()
    
    def _load_memory(self) -> Dict:
        """Load memory from file"""
        if os.path.exists(self.memory_file):
            with open(self.memory_file, 'r') as f:
                return json.load(f)
        return {
            'user_profile': {
                'time_estimation_factor': 1.8,
                'favorite_restaurant': 'Thai Restaurant',
                'peak_hours': ['9-11am', '3-5pm']
            },
            'task_history': [],
            'brain_states': [],
            'successful_strategies': []
        }
    
    def _save_memory(self):
        """Save memory to file"""
        with open(self.memory_file, 'w') as f:
            json.dump(self.memory, f, indent=2, default=str)
    
    def store_brain_state(self, state: str, context: str):
        """Store brain state observation"""
        self.memory['brain_states'].append({
            'state': state,
            'context': context,
            'timestamp': datetime.now().isoformat()
        })
        self._save_memory()
    
    def get_favorite_restaurant(self) -> str:
        """Get user's favorite restaurant"""
        return self.memory['user_profile']['favorite_restaurant']
    
    def store_task_completion(self, task: str, estimated_time: int, actual_time: int):
        """Store task for learning time estimation"""
        self.memory['task_history'].append({
            'task': task,
            'estimated_minutes': estimated_time,
            'actual_minutes': actual_time,
            'accuracy': estimated_time / actual_time if actual_time > 0 else 1.0,
            'completed_at': datetime.now().isoformat()
        })
        
        # Update estimation factor
        if len(self.memory['task_history']) >= 5:
            recent_tasks = self.memory['task_history'][-10:]
            avg_accuracy = sum(t['accuracy'] for t in recent_tasks) / len(recent_tasks)
            self.memory['user_profile']['time_estimation_factor'] = 1 / avg_accuracy
        
        self._save_memory()
    
    def get_time_estimation_factor(self) -> float:
        """Get learned time estimation correction factor"""
        return self.memory['user_profile']['time_estimation_factor']

# Usage
memory = SimpleMemoryBank('test_user')
memory.store_brain_state('overwhelmed', 'Too many tabs open')
print(f"Favorite restaurant: {memory.get_favorite_restaurant()}")
```

---

## ✅ YOU NOW HAVE A WORKING NEURPILOT DEMO!

### **What You Built:**
1. ✅ Agent with brain state detection tool
2. ✅ Web interface with WebSocket real-time communication
3. ✅ Decision paralysis timer feature
4. ✅ Simple memory system
5. ✅ Clean, commented code

### **To Run Complete Demo:**

```bash
# Terminal 1: Backend
python api.py

# Terminal 2: Frontend
python -m http.server 3000

# Browser
Open: http://localhost:3000
Try: "I can't decide where to order food from"
Watch: Timer countdown in action!
```

---

## 🎬 NEXT STEPS FOR FULL PROJECT

### **This Weekend (Add 2 More Agents)**
1. Time Perception Agent (estimates realistic time)
2. Task Flow Agent (breaks down tasks)

### **Next Week (Advanced Features)**
1. Context restoration (save/restore work state)
2. A2A simulation (two browser tabs as different users)
3. Deploy to Cloud Run

### **Final Week (Polish)**
1. Documentation
2. Video recording
3. Submit to Kaggle

---

## 💡 TIPS FOR RAPID DEVELOPMENT

1. **Copy-Paste First, Understand Later**: Get it working, then learn
2. **Test After Every Change**: Run `python api.py` constantly
3. **Use Print Statements**: Add `print(f"Debug: {variable}")` everywhere
4. **Simplify If Stuck**: Remove features until it works, add back slowly
5. **Ask for Help Early**: Discord/Reddit if stuck >1 hour

---

## 🆘 COMMON ISSUES & FIXES

### Issue: "ModuleNotFoundError: No module named 'google.adk'"
```bash
pip install --upgrade google-adk
```

### Issue: WebSocket won't connect
```bash
# Make sure both servers are running:
# Terminal 1: python api.py
# Terminal 2: python -m http.server 3000
```

### Issue: Agent not responding
```python
# Add debug prints
print(f"Received message: {user_message}")
print(f"Agent response: {response.text}")
```

### Issue: Timer not appearing
```javascript
// Check browser console (F12)
// Look for WebSocket errors
```

---

## 🎉 YOU'RE READY TO BUILD!

This quick start gives you a **working foundation** in just a few hours. Now you can:
- Add more agents incrementally
- Enhance features one at a time
- Deploy when stable
- Create documentation and video

**Remember**: Perfect is the enemy of done. Get it working, then make it better!

**Good luck! You've got this! 🚀**
