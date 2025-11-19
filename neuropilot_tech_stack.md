# NeuroPilot - Complete Technical Stack & Implementation Guide

## 🎨 USER INTERFACE → BACKEND → AGENTS FLOW

```
┌─────────────────────────────────────────────────────────────────┐
│                        USER LAYER                               │
│  [Mobile App] ←→ [Web App] ←→ [CLI] ←→ [Voice Assistant]      │
└────────────────┬────────────────────────────────────────────────┘
                 │ HTTPS / WebSocket
                 ▼
┌─────────────────────────────────────────────────────────────────┐
│                      API GATEWAY LAYER                          │
│               FastAPI Server (Cloud Run)                        │
│  • Authentication (Firebase Auth / OAuth)                       │
│  • Rate Limiting                                                │
│  • Request Routing                                              │
│  • WebSocket for real-time updates                             │
└────────────────┬────────────────────────────────────────────────┘
                 │ gRPC / HTTP
                 ▼
┌─────────────────────────────────────────────────────────────────┐
│                   AGENT ENGINE LAYER                            │
│              (Vertex AI Agent Engine)                           │
│                                                                 │
│  ┌──────────────────────────────────────────────────────┐      │
│  │         NeuroPilot Coordinator Agent                 │      │
│  │         (Gemini 2.0 Flash)                           │      │
│  └────┬────────────────────────────────────────────┬────┘      │
│       │                                            │            │
│       ├──→ [TaskFlow Agent]      ←─┐              │            │
│       ├──→ [Time Agent]             ├── Parallel  │            │
│       ├──→ [Energy Agent]         ←─┘              │            │
│       ├──→ [Decision Agent]                        │            │
│       └──→ [External Brain Agent] ←────────────────┘            │
│                                                                 │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 ├─────→ [Tools Layer]
                 ├─────→ [Memory Layer]
                 └─────→ [Integration Layer]
```

---

## 🔧 COMPLETE TECH STACK BREAKDOWN

### **1. FRONTEND / USER INTERFACE**

#### **Option A: Web Application (Recommended for Capstone)**
```
Technology: React + TypeScript + Tailwind CSS
Hosting: Vercel / Netlify (Free tier)
Real-time: WebSocket connection to backend
```

**Key Components**:
```typescript
// Main Chat Interface
- Chat window (conversation history)
- Input box (text + voice)
- Status indicators (agent thinking, decision timer)
- Quick action buttons (break timer, task list)
- Energy level slider (manual input)

// Dashboard
- Today's tasks (completed/abandoned)
- Energy graph (historical)
- Time estimation accuracy
- Success metrics
```

**File Structure**:
```
frontend/
├── src/
│   ├── components/
│   │   ├── ChatInterface.tsx
│   │   ├── TaskList.tsx
│   │   ├── EnergyTracker.tsx
│   │   └── DecisionTimer.tsx
│   ├── hooks/
│   │   ├── useWebSocket.ts      # Real-time agent connection
│   │   ├── useAgentState.ts      # Agent state management
│   │   └── useA2AConnection.ts   # Peer-to-peer for A2A
│   ├── services/
│   │   ├── api.ts               # Backend API calls
│   │   └── auth.ts              # User authentication
│   └── App.tsx
```

#### **Option B: Mobile App (Future Enhancement)**
```
Technology: React Native / Flutter
Features: Push notifications, voice input, background monitoring
```

#### **Option C: CLI (For Capstone Demo)**
```python
# Simplest option for capstone - just terminal interface
Technology: Python + Rich library (for formatted output)
Good for: Quick demo, development testing
```

---

### **2. BACKEND / API LAYER**

#### **FastAPI Server** (Python)

**Purpose**: 
- Receives user messages
- Routes to Agent Engine
- Handles authentication
- Manages WebSocket connections
- Stores user data

**Tech Stack**:
```python
# Core Framework
FastAPI 0.104+         # Modern Python API framework
Uvicorn               # ASGI server
Pydantic              # Data validation

# Real-time Communication
WebSockets            # Bidirectional communication
SSE (Server-Sent Events)  # Alternative for streaming

# Authentication
Firebase Auth         # User management (free tier)
# OR
OAuth 2.0             # Google/GitHub login

# Database
Firestore             # NoSQL, real-time sync
# OR
PostgreSQL + SQLAlchemy  # Relational database
```

**API Structure**:
```python
# main.py - FastAPI Server

from fastapi import FastAPI, WebSocket, Depends
from fastapi.middleware.cors import CORSMiddleware
from google.adk.runner import AgentRunner
import firebase_admin
from firebase_admin import firestore

app = FastAPI(title="NeuroPilot API")

# CORS for web access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://yourdomain.com"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize Agent Runner
agent_runner = AgentRunner(root_agent=coordinator_agent)

# Initialize Firestore
db = firestore.client()

# ============================================
# REST API ENDPOINTS
# ============================================

@app.post("/api/chat")
async def chat_message(
    message: str, 
    user_id: str = Depends(get_current_user)
):
    """
    Handle single chat message
    """
    # Load user context from database
    user_data = db.collection('users').document(user_id).get().to_dict()
    
    # Run agent with context
    response = await agent_runner.run(
        user_message=message,
        session_id=user_id,
        context={
            "user_profile": user_data.get('profile', {}),
            "memory": user_data.get('memory', {}),
            "current_tasks": user_data.get('tasks', [])
        }
    )
    
    # Save updated state
    db.collection('users').document(user_id).update({
        'last_interaction': firestore.SERVER_TIMESTAMP,
        'memory': response.updated_memory
    })
    
    return {
        "response": response.text,
        "agent_state": response.state,
        "actions_taken": response.actions
    }


@app.get("/api/tasks/{user_id}")
async def get_tasks(user_id: str):
    """Get user's current tasks"""
    tasks = db.collection('users').document(user_id)\
              .collection('tasks').stream()
    return [task.to_dict() for task in tasks]


@app.post("/api/tasks/{user_id}/complete")
async def complete_task(user_id: str, task_id: str):
    """Mark task as complete, update metrics"""
    # Update task status
    task_ref = db.collection('users').document(user_id)\
                 .collection('tasks').document(task_id)
    
    task_data = task_ref.get().to_dict()
    
    # Calculate time accuracy
    estimated_time = task_data['estimated_minutes']
    actual_time = task_data['actual_minutes']
    accuracy = estimated_time / actual_time
    
    # Update task
    task_ref.update({
        'status': 'completed',
        'completed_at': firestore.SERVER_TIMESTAMP,
        'time_accuracy': accuracy
    })
    
    # Update user metrics
    db.collection('users').document(user_id).update({
        'tasks_completed': firestore.Increment(1),
        'avg_time_accuracy': firestore.Increment(accuracy)
    })
    
    return {"status": "completed", "accuracy": accuracy}


# ============================================
# WEBSOCKET FOR REAL-TIME UPDATES
# ============================================

@app.websocket("/ws/{user_id}")
async def websocket_endpoint(websocket: WebSocket, user_id: str):
    """
    WebSocket connection for real-time agent interaction
    """
    await websocket.accept()
    
    try:
        while True:
            # Receive message from user
            data = await websocket.receive_json()
            message = data.get('message')
            
            # Stream agent response in real-time
            async for chunk in agent_runner.stream(
                user_message=message,
                session_id=user_id
            ):
                await websocket.send_json({
                    "type": "agent_response",
                    "content": chunk.text,
                    "thinking": chunk.is_thinking,
                    "tool_use": chunk.tool_name if chunk.is_tool else None
                })
            
            # Send final state
            await websocket.send_json({
                "type": "complete",
                "state": chunk.final_state
            })
            
    except Exception as e:
        print(f"WebSocket error: {e}")
    finally:
        await websocket.close()
```

---

### **3. AGENT ENGINE LAYER**

#### **ADK Agent Implementation**

```python
# agents/coordinator.py

from google.adk.agents.llm_agent import Agent
from google.adk.sessions import InMemorySessionService
from google.adk.memory import MemoryBank
from typing import Dict, Any

# Initialize Memory Bank with Firestore backend
class FirestoreMemoryBank(MemoryBank):
    """Custom Memory Bank that persists to Firestore"""
    
    def __init__(self, user_id: str):
        self.user_id = user_id
        self.db = firestore.client()
        self.memory_ref = self.db.collection('users')\
                               .document(user_id)\
                               .collection('memory')
    
    def store(self, key: str, value: Any):
        """Store memory in Firestore"""
        self.memory_ref.document(key).set({
            'value': value,
            'timestamp': firestore.SERVER_TIMESTAMP,
            'user_id': self.user_id
        })
    
    def retrieve(self, key: str) -> Any:
        """Retrieve memory from Firestore"""
        doc = self.memory_ref.document(key).get()
        return doc.to_dict()['value'] if doc.exists else None
    
    def search(self, query: str, top_k: int = 5):
        """Search similar memories (using embeddings)"""
        # Use Vertex AI Matching Engine for semantic search
        # Or simple keyword search for capstone
        pass


# ============================================
# SESSION MANAGEMENT
# ============================================

class UserSessionManager:
    """Manages user sessions with persistent state"""
    
    def __init__(self):
        self.sessions = {}  # In-memory for current session
        self.db = firestore.client()
    
    def get_session(self, user_id: str) -> Dict:
        """Load or create user session"""
        if user_id in self.sessions:
            return self.sessions[user_id]
        
        # Load from database
        user_doc = self.db.collection('users').document(user_id).get()
        
        if user_doc.exists:
            session_data = user_doc.to_dict()
        else:
            # New user - initialize
            session_data = {
                'user_id': user_id,
                'created_at': firestore.SERVER_TIMESTAMP,
                'profile': {
                    'neurotype': None,  # ADHD, Autism, etc.
                    'time_estimation_factor': 1.5,
                    'peak_hours': [],
                    'sensory_triggers': [],
                    'preferred_strategies': []
                },
                'state': {
                    'current_task': None,
                    'brain_state': 'neutral',
                    'energy_level': 5,
                    'last_break': None,
                    'work_duration_minutes': 0
                },
                'metrics': {
                    'tasks_completed': 0,
                    'tasks_abandoned': 0,
                    'avg_time_accuracy': 1.0,
                    'burnout_prevented': 0
                }
            }
            
            # Save to database
            self.db.collection('users').document(user_id).set(session_data)
        
        self.sessions[user_id] = session_data
        return session_data
    
    def update_session(self, user_id: str, updates: Dict):
        """Update session state"""
        # Update in-memory
        if user_id in self.sessions:
            self.sessions[user_id].update(updates)
        
        # Persist to database
        self.db.collection('users').document(user_id).update(updates)


session_manager = UserSessionManager()


# ============================================
# COORDINATOR AGENT WITH SESSION AWARENESS
# ============================================

coordinator_agent = Agent(
    model='gemini-2.0-flash-001',
    name='neuropilot_coordinator',
    instruction="""You are NeuroPilot, an executive function companion.
    
    You have access to the user's session state including:
    - current_task: What they're working on
    - brain_state: focused/scattered/overwhelmed
    - energy_level: 1-10
    - work_duration_minutes: Time since last break
    - profile: Their neurotype patterns and preferences
    
    Use this context to provide personalized support.
    """,
    tools=[
        analyze_brain_state,
        get_current_context,
        # ... other tools
    ]
)


# Agent execution with session
async def run_agent_with_session(user_id: str, message: str):
    """Run agent with full user context"""
    
    # Get user session
    session = session_manager.get_session(user_id)
    
    # Load memory bank
    memory = FirestoreMemoryBank(user_id)
    
    # Run agent
    response = await coordinator_agent.run(
        user_message=message,
        context={
            "session": session,
            "memory": memory,
            "user_id": user_id
        }
    )
    
    # Update session state
    session_manager.update_session(user_id, {
        'state': response.updated_state,
        'last_interaction': firestore.SERVER_TIMESTAMP
    })
    
    return response
```

---

## 🍜 SCENARIO 1: AUTOMATED FOOD ORDERING

### **How the Decision Paralysis → Food Ordering Flow Works**

```
User: "I need to pick where to order dinner from..."
    ↓
[Frontend sends message via WebSocket]
    ↓
[Backend receives, routes to Agent Engine]
    ↓
[Decision Agent detects paralysis keywords]
    ↓
[START 90-SECOND TIMER on backend]
    ↓
[Agent queries Memory Bank for food preferences]
    ↓
[No user response after 90 seconds]
    ↓
[Agent triggers food ordering tool]
    ↓
[Sends 60-second cancellation countdown to user]
    ↓
[If no "STOP" command received]
    ↓
[Execute food order via DoorDash/UberEats API]
    ↓
[Notify user: "Order placed"]
```

### **Implementation Code**

```python
# tools/food_ordering.py

import asyncio
from datetime import datetime, timedelta
import requests

class FoodOrderingTool:
    """Handles automated food ordering during decision paralysis"""
    
    def __init__(self, user_id: str):
        self.user_id = user_id
        self.db = firestore.client()
        self.active_timers = {}
    
    async def detect_food_decision_paralysis(
        self, 
        conversation_history: list,
        time_spent_deciding: int
    ) -> bool:
        """
        Detect if user is stuck deciding on food
        
        Args:
            conversation_history: Recent messages
            time_spent_deciding: Seconds since first mention
            
        Returns:
            True if paralysis detected
        """
        food_keywords = ["dinner", "lunch", "food", "eat", "hungry", "order"]
        decision_keywords = ["don't know", "can't decide", "not sure", "maybe"]
        
        # Check if discussing food
        is_food_topic = any(
            keyword in msg.lower() 
            for msg in conversation_history[-5:]
            for keyword in food_keywords
        )
        
        # Check for indecision language
        is_indecisive = any(
            keyword in msg.lower()
            for msg in conversation_history[-3:]
            for keyword in decision_keywords
        )
        
        # Time-based trigger
        is_stuck = time_spent_deciding > 90  # 90 seconds
        
        return is_food_topic and is_indecisive and is_stuck
    
    async def get_preferred_restaurant(self, user_id: str) -> dict:
        """
        Get user's most frequently ordered restaurant
        """
        # Query user's order history
        orders = self.db.collection('users').document(user_id)\
                       .collection('food_orders')\
                       .order_by('ordered_at', direction='DESCENDING')\
                       .limit(20).stream()
        
        # Count frequency
        restaurant_counts = {}
        for order in orders:
            data = order.to_dict()
            restaurant = data['restaurant_name']
            restaurant_counts[restaurant] = restaurant_counts.get(restaurant, 0) + 1
        
        # Get most common
        if restaurant_counts:
            top_restaurant = max(restaurant_counts, key=restaurant_counts.get)
            
            # Get last order from this restaurant
            last_order = self.db.collection('users').document(user_id)\
                               .collection('food_orders')\
                               .where('restaurant_name', '==', top_restaurant)\
                               .order_by('ordered_at', direction='DESCENDING')\
                               .limit(1).get()[0].to_dict()
            
            return {
                'restaurant_name': top_restaurant,
                'restaurant_id': last_order['restaurant_id'],
                'usual_order': last_order['items'],
                'typical_cost': last_order['total_cost']
            }
        
        # No history - use defaults
        return {
            'restaurant_name': 'Thai Restaurant',
            'restaurant_id': 'default_thai_001',
            'usual_order': ['Pad Thai', 'Spring Rolls'],
            'typical_cost': 25.00
        }
    
    async def initiate_auto_order_countdown(
        self, 
        user_id: str, 
        restaurant: dict,
        websocket_connection
    ) -> str:
        """
        Start 60-second countdown for order cancellation
        
        Returns:
            Timer ID for tracking
        """
        timer_id = f"food_order_{user_id}_{int(datetime.now().timestamp())}"
        
        # Send countdown message to user via WebSocket
        await websocket_connection.send_json({
            "type": "decision_paralysis_intervention",
            "message": f"You're in decision paralysis. Based on your preferences, "
                      f"I'm ordering {restaurant['restaurant_name']} "
                      f"({', '.join(restaurant['usual_order'])}). "
                      f"Reply STOP to cancel in 60 seconds.",
            "timer_seconds": 60,
            "timer_id": timer_id,
            "restaurant": restaurant
        })
        
        # Store active timer
        self.active_timers[timer_id] = {
            'user_id': user_id,
            'restaurant': restaurant,
            'started_at': datetime.now(),
            'expires_at': datetime.now() + timedelta(seconds=60),
            'cancelled': False
        }
        
        # Start background countdown task
        asyncio.create_task(
            self._countdown_and_order(timer_id, websocket_connection)
        )
        
        return timer_id
    
    async def _countdown_and_order(self, timer_id: str, websocket):
        """
        Background task: Wait 60 seconds, then order if not cancelled
        """
        timer = self.active_timers[timer_id]
        
        # Send countdown updates every 15 seconds
        for remaining in [45, 30, 15, 5]:
            await asyncio.sleep(15)
            
            # Check if cancelled
            if timer['cancelled']:
                await websocket.send_json({
                    "type": "timer_cancelled",
                    "message": "Order cancelled. Want to decide manually?"
                })
                return
            
            # Send update
            await websocket.send_json({
                "type": "timer_update",
                "timer_id": timer_id,
                "remaining_seconds": remaining
            })
        
        # Wait final 5 seconds
        await asyncio.sleep(5)
        
        # Check if cancelled during final countdown
        if timer['cancelled']:
            return
        
        # TIME'S UP - Place the order
        order_result = await self._place_food_order(
            timer['user_id'],
            timer['restaurant']
        )
        
        # Notify user
        await websocket.send_json({
            "type": "order_placed",
            "message": f"✅ Order placed! {timer['restaurant']['restaurant_name']} "
                      f"will arrive in ~30 minutes.",
            "order_id": order_result['order_id'],
            "estimated_arrival": order_result['estimated_arrival']
        })
        
        # Clean up timer
        del self.active_timers[timer_id]
    
    async def cancel_order_timer(self, timer_id: str) -> bool:
        """Cancel active order timer"""
        if timer_id in self.active_timers:
            self.active_timers[timer_id]['cancelled'] = True
            return True
        return False
    
    async def _place_food_order(self, user_id: str, restaurant: dict) -> dict:
        """
        Actually place the food order via DoorDash/UberEats API
        
        NOTE: For capstone, this can be SIMULATED
        For production, integrate with real food delivery APIs
        """
        
        # ==== CAPSTONE VERSION: SIMULATED ORDER ====
        order_id = f"sim_order_{int(datetime.now().timestamp())}"
        
        # Save to database
        self.db.collection('users').document(user_id)\
               .collection('food_orders').add({
            'order_id': order_id,
            'restaurant_name': restaurant['restaurant_name'],
            'restaurant_id': restaurant['restaurant_id'],
            'items': restaurant['usual_order'],
            'total_cost': restaurant['typical_cost'],
            'ordered_at': firestore.SERVER_TIMESTAMP,
            'status': 'simulated',
            'estimated_arrival': datetime.now() + timedelta(minutes=30)
        })
        
        return {
            'order_id': order_id,
            'status': 'confirmed',
            'estimated_arrival': (datetime.now() + timedelta(minutes=30)).isoformat()
        }
        
        # ==== PRODUCTION VERSION: REAL INTEGRATION ====
        # Uncomment for production deployment
        """
        # DoorDash API Example
        doordash_api_key = os.getenv('DOORDASH_API_KEY')
        
        response = requests.post(
            'https://api.doordash.com/drive/v2/orders',
            headers={
                'Authorization': f'Bearer {doordash_api_key}',
                'Content-Type': 'application/json'
            },
            json={
                'external_delivery_id': f'neuropilot_{user_id}_{int(time.time())}',
                'pickup_address': restaurant['address'],
                'dropoff_address': user_address,
                'order_value': restaurant['typical_cost'] * 100,  # cents
                'items': restaurant['usual_order']
            }
        )
        
        return response.json()
        """


# ============================================
# INTEGRATE WITH DECISION AGENT
# ============================================

# Add to Decision Agent's tools
decision_agent = Agent(
    model='gemini-2.0-flash-001',
    name='decision_support_agent',
    instruction="""...
    
    SPECIAL PROTOCOL: Food Decision Paralysis
    If user is stuck deciding on food for >90 seconds:
    1. Use detect_food_decision_paralysis tool
    2. If detected, use initiate_auto_order_countdown tool
    3. Wait for user response or timer expiration
    4. If "STOP" received, use cancel_order_timer
    5. Otherwise, order will be placed automatically
    """,
    tools=[
        reduce_options,
        analyze_brain_state,
        # NEW TOOLS for food ordering
        FoodOrderingTool.detect_food_decision_paralysis,
        FoodOrderingTool.initiate_auto_order_countdown,
        FoodOrderingTool.cancel_order_timer
    ]
)
```

### **Frontend Component for Timer**

```typescript
// frontend/src/components/DecisionTimer.tsx

import React, { useState, useEffect } from 'react';

interface DecisionTimerProps {
  timerData: {
    timer_id: string;
    message: string;
    timer_seconds: number;
    restaurant: any;
  };
  onCancel: (timerId: string) => void;
}

export const DecisionTimer: React.FC<DecisionTimerProps> = ({ 
  timerData, 
  onCancel 
}) => {
  const [secondsLeft, setSecondsLeft] = useState(timerData.timer_seconds);
  
  useEffect(() => {
    const interval = setInterval(() => {
      setSecondsLeft(prev => {
        if (prev <= 1) {
          clearInterval(interval);
          return 0;
        }
        return prev - 1;
      });
    }, 1000);
    
    return () => clearInterval(interval);
  }, []);
  
  return (
    <div className="decision-timer bg-yellow-100 border-2 border-yellow-500 rounded-lg p-4">
      <div className="text-lg font-bold mb-2">
        ⚠️ Decision Paralysis Detected
      </div>
      
      <p className="mb-4">{timerData.message}</p>
      
      <div className="flex items-center justify-between">
        <div className="text-3xl font-bold text-red-600">
          {secondsLeft}s
        </div>
        
        <button
          onClick={() => onCancel(timerData.timer_id)}
          className="bg-red-500 hover:bg-red-700 text-white font-bold py-2 px-4 rounded"
        >
          STOP ORDER
        </button>
      </div>
      
      <div className="mt-4 text-sm text-gray-600">
        Ordering: {timerData.restaurant.restaurant_name}<br/>
        Items: {timerData.restaurant.usual_order.join(', ')}<br/>
        Cost: ${timerData.restaurant.typical_cost}
      </div>
    </div>
  );
};
```

---

## 📝 SCENARIO 2: CONTEXT RESTORATION

### **"You stopped coding mid-function yesterday - here's exactly where you left off"**

This requires capturing and restoring the EXACT state of work, including:
- Code being written
- Thought process
- Next steps
- Mental state

```python
# tools/context_restoration.py

from dataclasses import dataclass
from datetime import datetime
from typing import List, Optional
import json

@dataclass
class WorkContext:
    """Complete snapshot of work session"""
    task_id: str
    task_name: str
    last_worked_on: datetime
    work_duration_minutes: int
    
    # Code context (for developers)
    file_path: Optional[str] = None
    last_line_number: Optional[int] = None
    incomplete_code: Optional[str] = None
    
    # Thought process
    brain_dump_notes: List[str] = None
    next_steps: List[str] = None
    blockers: List[str] = None
    
    # Mental state
    brain_state: str = "focused"  # focused/scattered/overwhelmed
    energy_level: int = 5
    mood: str = "neutral"
    
    # Progress tracking
    progress_percentage: int = 0
    completed_subtasks: List[str] = None
    remaining_subtasks: List[str] = None


class ContextRestorationEngine:
    """Captures and restores complete work context"""
    
    def __init__(self, user_id: str):
        self.user_id = user_id
        self.db = firestore.client()
        self.contexts_ref = self.db.collection('users')\
                                    .document(user_id)\
                                    .collection('work_contexts')
    
    async def capture_context_snapshot(
        self, 
        task_id: str,
        user_message: str = None,
        active_files: List[dict] = None
    ) -> str:
        """
        Capture current work context for later restoration
        
        This should be called:
        - Every 5 minutes during active work
        - When user indicates they're stopping
        - On any significant state change
        """
        
        # Get current task details
        task_ref = self.db.collection('users').document(self.user_id)\
                          .collection('tasks').document(task_id)
        task_data = task_ref.get().to_dict()
        
        # Extract context from user's last messages
        recent_messages = await self._get_recent_messages(limit=10)
        brain_dump = await self._extract_thoughts(recent_messages)
        next_steps = await self._infer_next_steps(recent_messages, task_data)
        
        # Capture code context (if applicable)
        code_context = None
        if active_files:
            code_context = await self._capture_code_context(active_files)
        
        # Create context snapshot
        context = WorkContext(
            task_id=task_id,
            task_name=task_data['name'],
            last_worked_on=datetime.now(),
            work_duration_minutes=task_data.get('work_duration', 0),
            
            # Code details
            file_path=code_context['file_path'] if code_context else None,
            last_line_number=code_context['line_number'] if code_context else None,
            incomplete_code=code_context['incomplete_code'] if code_context else None,
            
            # Thoughts and plans
            brain_dump_notes=brain_dump,
            next_steps=next_steps,
            blockers=task_data.get('blockers', []),
            
            # Mental state
            brain_state=task_data.get('brain_state', 'focused'),
            energy_level=task_data.get('energy_level', 5),
            mood=await self._detect_mood(recent_messages),
            
            # Progress
            progress_percentage=task_data.get('progress', 0),
            completed_subtasks=task_data.get('completed_subtasks', []),
            remaining_subtasks=task_data.get('remaining_subtasks', [])
        )
        
        # Save context snapshot to database
        context_id = f"context_{int(datetime.now().timestamp())}"
        self.contexts_ref.document(context_id).set({
            **context.__dict__,
            'last_worked_on': firestore.SERVER_TIMESTAMP,
            'context_id': context_id
        })
        
        # Update task with latest context reference
        task_ref.update({
            'latest_context_id': context_id,
            'last_context_saved': firestore.SERVER_TIMESTAMP
        })
        
        return context_id
    
    async def restore_context(self, task_id: str = None) -> WorkContext:
        """
        Restore the most recent work context
        
        Args:
            task_id: Specific task to restore (or most recent if None)
        """
        
        if task_id:
            # Get specific task's latest context
            task = self.db.collection('users').document(self.user_id)\
                         .collection('tasks').document(task_id).get()
            
            if not task.exists:
                raise ValueError(f"Task {task_id} not found")
            
            context_id = task.to_dict().get('latest_context_id')
            
            if not context_id:
                raise ValueError(f"No saved context for task {task_id}")
            
            context_doc = self.contexts_ref.document(context_id).get()
        else:
            # Get most recent context from any task
            contexts = self.contexts_ref\
                          .order_by('last_worked_on', direction='DESCENDING')\
                          .limit(1)\
                          .stream()
            
            context_doc = next(contexts, None)
            
            if not context_doc:
                raise ValueError("No saved contexts found")
        
        # Convert to WorkContext object
        context_data = context_doc.to_dict()
        return WorkContext(**context_data)
    
    async def generate_restoration_message(self, context: WorkContext) -> str:
        """
        Generate human-friendly restoration message
        
        Example: "You stopped coding mid-function yesterday—here's exactly where you left off"
        """
        
        # Time since last worked
        time_ago = datetime.now() - context.last_worked_on
        if time_ago.days > 0:
            time_str = f"{time_ago.days} day{'s' if time_ago.days > 1 else ''} ago"
        elif time_ago.seconds > 3600:
            hours = time_ago.seconds // 3600
            time_str = f"{hours} hour{'s' if hours > 1 else ''} ago"
        else:
            minutes = time_ago.seconds // 60
            time_str = f"{minutes} minute{'s' if minutes > 1 else ''} ago"
        
        # Build restoration message
        message_parts = [
            f"💡 **Context Restoration: {context.task_name}**",
            f"Last worked on: {time_str}",
            ""
        ]
        
        # Add code-specific context
        if context.file_path:
            message_parts.extend([
                "📄 **Code Context:**",
                f"- File: `{context.file_path}`",
                f"- Line: {context.last_line_number}",
                ""
            ])
            
            if context.incomplete_code:
                message_parts.extend([
                    "**Incomplete code:**",
                    f"```python",
                    context.incomplete_code,
                    "```",
                    ""
                ])
        
        # Add thought process
        if context.brain_dump_notes:
            message_parts.extend([
                "🧠 **What you were thinking:**",
                *[f"- {note}" for note in context.brain_dump_notes[-3:]],  # Last 3
                ""
            ])
        
        # Add next steps
        if context.next_steps:
            message_parts.extend([
                "✅ **Next steps:**",
                *[f"{i+1}. {step}" for i, step in enumerate(context.next_steps[:3])],
                ""
            ])
        
        # Add blockers if any
        if context.blockers:
            message_parts.extend([
                "🚧 **Blockers you identified:**",
                *[f"- {blocker}" for blocker in context.blockers],
                ""
            ])
        
        # Add mental state context
        message_parts.extend([
            f"🎯 **Your state:** {context.brain_state.title()} | Energy: {context.energy_level}/10",
            f"📊 **Progress:** {context.progress_percentage}% complete",
            ""
        ])
        
        # Motivational close
        if context.progress_percentage > 50:
            message_parts.append("You're over halfway! Let's finish this. 💪")
        else:
            message_parts.append("Let's pick up where you left off. I'm here with you. 🤝")
        
        return "\n".join(message_parts)
    
    async def _capture_code_context(self, active_files: List[dict]) -> dict:
        """
        Capture code-specific context from IDE/editor
        
        For capstone: Simulated or manual input
        For production: IDE extension integration (VS Code, JetBrains)
        """
        
        # Get most recently edited file
        most_recent_file = max(active_files, key=lambda f: f['last_modified'])
        
        return {
            'file_path': most_recent_file['path'],
            'line_number': most_recent_file.get('cursor_line', 0),
            'incomplete_code': most_recent_file.get('incomplete_code', ''),
            'function_name': most_recent_file.get('current_function', 'unknown')
        }
    
    async def _extract_thoughts(self, messages: List[str]) -> List[str]:
        """
        Extract thought process from recent messages using LLM
        """
        
        # Use Gemini to extract key thoughts
        from google.genai import Client
        client = Client(api_key=os.getenv('GOOGLE_API_KEY'))
        
        prompt = f"""
        Analyze these recent messages from a developer and extract their key thoughts/plans:
        
        Messages:
        {chr(10).join(messages)}
        
        Extract 3-5 key thoughts or plans they mentioned. Format as bullet points.
        Focus on technical decisions, blockers, or implementation ideas.
        """
        
        response = client.models.generate_content(
            model='gemini-2.0-flash-001',
            contents=prompt
        )
        
        # Parse response into list
        thoughts = response.text.strip().split('\n')
        return [t.strip('- ').strip() for t in thoughts if t.strip()]
    
    async def _infer_next_steps(self, messages: List[str], task_data: dict) -> List[str]:
        """
        Infer logical next steps based on context
        """
        
        # Use Gemini to suggest next steps
        from google.genai import Client
        client = Client(api_key=os.getenv('GOOGLE_API_KEY'))
        
        prompt = f"""
        Task: {task_data['name']}
        Progress: {task_data.get('progress', 0)}%
        Recent work: {chr(10).join(messages[-5:])}
        
        Suggest 3 concrete next steps to continue this work.
        Be specific and actionable.
        """
        
        response = client.models.generate_content(
            model='gemini-2.0-flash-001',
            contents=prompt
        )
        
        steps = response.text.strip().split('\n')
        return [s.strip('123. ').strip() for s in steps if s.strip()]
    
    async def _detect_mood(self, messages: List[str]) -> str:
        """Detect mood from recent messages"""
        
        # Simple sentiment analysis
        negative_words = ['frustrated', 'stuck', 'confused', 'tired', 'overwhelmed']
        positive_words = ['great', 'progress', 'working', 'figured out', 'done']
        
        text = ' '.join(messages).lower()
        
        neg_count = sum(1 for word in negative_words if word in text)
        pos_count = sum(1 for word in positive_words if word in text)
        
        if neg_count > pos_count:
            return 'frustrated'
        elif pos_count > neg_count:
            return 'positive'
        else:
            return 'neutral'
    
    async def _get_recent_messages(self, limit: int = 10) -> List[str]:
        """Get recent conversation messages"""
        
        messages = self.db.collection('users').document(self.user_id)\
                          .collection('messages')\
                          .order_by('timestamp', direction='DESCENDING')\
                          .limit(limit)\
                          .stream()
        
        return [msg.to_dict()['content'] for msg in messages]


# ============================================
# AUTO-CAPTURE: PERIODIC CONTEXT SAVING
# ============================================

class AutoContextCapture:
    """Background service that automatically captures context"""
    
    def __init__(self, user_id: str):
        self.user_id = user_id
        self.engine = ContextRestorationEngine(user_id)
        self.capture_interval = 300  # 5 minutes
    
    async def start_monitoring(self, task_id: str):
        """Start auto-capturing context every 5 minutes"""
        
        while True:
            try:
                # Capture current context
                await self.engine.capture_context_snapshot(task_id)
                
                # Wait 5 minutes
                await asyncio.sleep(self.capture_interval)
                
            except Exception as e:
                print(f"Error in auto-capture: {e}")
                await asyncio.sleep(self.capture_interval)


# ============================================
# INTEGRATE WITH EXTERNAL BRAIN AGENT
# ============================================

external_brain_agent = Agent(
    model='gemini-2.0-flash-001',
    name='external_brain_agent',
    instruction="""You are the External Brain - the memory keeper.
    
    When user says things like:
    - "What was I working on?"
    - "Where did I leave off?"
    - "I forgot what I was doing"
    
    Use restore_context tool to bring back their exact state.
    
    Present the context in a helpful, non-judgmental way.
    Include:
    1. Time since last worked
    2. What they were doing (code/task details)
    3. Their thought process
    4. Concrete next steps
    5. Any blockers they identified
    
    Make it easy to jump back in immediately.
    """,
    tools=[
        ContextRestorationEngine.capture_context_snapshot,
        ContextRestorationEngine.restore_context,
        ContextRestorationEngine.generate_restoration_message
    ]
)
```

---

## 🤝 SCENARIO 3: A2A PROTOCOL - MULTI-USER COORDINATION

### **How Two Users' Agents Communicate**

```
Alice's Agent ←→ A2A Protocol Server ←→ Bob's Agent
     ↓                                        ↓
Alice's NeuroPilot                    Bob's NeuroPilot
```

### **Implementation: A2A Agent-to-Agent Communication**

```python
# a2a/peer_coordination.py

from a2a_python import Agent as A2AAgent, Message, Connection
import asyncio
from typing import List, Optional
from dataclasses import dataclass

@dataclass
class AccountabilityPartner:
    """Represents a connected accountability partner"""
    user_id: str
    name: str
    agent_url: str
    connection_status: str  # connected/disconnected
    shared_goals: List[str]
    check_in_frequency: str  # daily/weekly


class A2ACoordinator:
    """Manages agent-to-agent communication for accountability"""
    
    def __init__(self, user_id: str):
        self.user_id = user_id
        self.db = firestore.client()
        self.a2a_agent = None
        self.active_connections = {}
    
    async def initialize_a2a_agent(self, agent_url: str):
        """
        Initialize this user's A2A-enabled agent
        
        Args:
            agent_url: Public URL where this agent can be reached
        """
        
        # Create A2A agent profile
        self.a2a_agent = A2AAgent(
            id=f"neuropilot_{self.user_id}",
            name=f"NeuroPilot for User {self.user_id}",
            description="Executive function companion for neurodivergent adults",
            url=agent_url,
            capabilities=[
                "accountability_tracking",
                "co_working_sessions",
                "goal_sharing",
                "progress_updates"
            ]
        )
        
        # Register agent on A2A network
        await self.a2a_agent.register()
        
        print(f"✅ A2A Agent initialized: {agent_url}")
    
    async def connect_accountability_partner(
        self, 
        partner_user_id: str,
        partner_agent_url: str
    ) -> bool:
        """
        Establish A2A connection with accountability partner
        
        Example: Alice wants Bob as her accountability partner
        """
        
        try:
            # Discover partner's agent
            partner_agent = await A2AAgent.discover(partner_agent_url)
            
            # Send connection request
            connection_request = Message(
                type="connection_request",
                from_agent=self.a2a_agent.id,
                to_agent=partner_agent.id,
                content={
                    "user_id": self.user_id,
                    "message": "I'd like you as my accountability partner!",
                    "proposed_check_ins": "daily",
                    "shared_goals": []
                }
            )
            
            response = await partner_agent.send(connection_request)
            
            if response.content.get('accepted'):
                # Store connection
                connection = Connection(
                    agent_a=self.a2a_agent,
                    agent_b=partner_agent
                )
                
                self.active_connections[partner_user_id] = connection
                
                # Save to database
                self.db.collection('users').document(self.user_id)\
                       .collection('accountability_partners').add({
                    'partner_user_id': partner_user_id,
                    'partner_agent_url': partner_agent_url,
                    'connected_at': firestore.SERVER_TIMESTAMP,
                    'status': 'active'
                })
                
                return True
            else:
                return False
                
        except Exception as e:
            print(f"Error connecting to partner: {e}")
            return False
    
    async def schedule_coworking_session(
        self,
        partner_user_id: str,
        proposed_time: datetime,
        duration_minutes: int = 90
    ) -> dict:
        """
        Coordinate a co-working session via A2A
        
        Flow:
        1. Alice's agent proposes time to Bob's agent
        2. Bob's agent checks Bob's calendar
        3. Bob's agent confirms or suggests alternative
        4. Both agents send reminders
        """
        
        connection = self.active_connections.get(partner_user_id)
        if not connection:
            raise ValueError(f"Not connected to {partner_user_id}")
        
        # Send co-working proposal via A2A
        proposal = Message(
            type="coworking_proposal",
            from_agent=self.a2a_agent.id,
            to_agent=connection.agent_b.id,
            content={
                "proposed_time": proposed_time.isoformat(),
                "duration_minutes": duration_minutes,
                "session_type": "focused_work",
                "agenda": "Deep work session with accountability"
            }
        )
        
        # Wait for response (with timeout)
        response = await asyncio.wait_for(
            connection.agent_b.send(proposal),
            timeout=300.0  # 5 minutes for human to respond
        )
        
        if response.content.get('accepted'):
            # Schedule confirmed!
            session_id = f"cowork_{self.user_id}_{partner_user_id}_{int(proposed_time.timestamp())}"
            
            # Save session details
            session_data = {
                'session_id': session_id,
                'participants': [self.user_id, partner_user_id],
                'scheduled_time': proposed_time,
                'duration_minutes': duration_minutes,
                'status': 'scheduled',
                'reminders_sent': []
            }
            
            # Save to both users' databases
            self.db.collection('coworking_sessions').document(session_id).set(session_data)
            
            # Schedule reminders
            await self._schedule_session_reminders(session_data)
            
            return {
                'session_id': session_id,
                'confirmed': True,
                'scheduled_time': proposed_time.isoformat()
            }
        else:
            # Partner declined or suggested alternative
            return {
                'confirmed': False,
                'alternative_time': response.content.get('alternative_time'),
                'reason': response.content.get('reason')
            }
    
    async def send_progress_update(
        self,
        partner_user_id: str,
        task_name: str,
        progress: int,
        message: str = None
    ):
        """
        Send progress update to accountability partner
        
        Example: "I completed my coding task!"
        """
        
        connection = self.active_connections.get(partner_user_id)
        if not connection:
            return
        
        update = Message(
            type="progress_update",
            from_agent=self.a2a_agent.id,
            to_agent=connection.agent_b.id,
            content={
                "task_name": task_name,
                "progress": progress,
                "message": message or f"Made progress on {task_name}",
                "timestamp": datetime.now().isoformat()
            }
        )
        
        await connection.agent_b.send(update)
        
        # Log in database
        self.db.collection('users').document(self.user_id)\
               .collection('shared_updates').add({
            'partner_id': partner_user_id,
            'task': task_name,
            'progress': progress,
            'sent_at': firestore.SERVER_TIMESTAMP
        })
    
    async def check_partner_availability(
        self,
        partner_user_id: str
    ) -> dict:
        """
        Ask partner's agent if they're available for co-working
        
        This is how: "Sarah's agent confirmed she's ready" works
        """
        
        connection = self.active_connections.get(partner_user_id)
        if not connection:
            return {'available': False, 'reason': 'not_connected'}
        
        # Query partner's agent
        query = Message(
            type="availability_check",
            from_agent=self.a2a_agent.id,
            to_agent=connection.agent_b.id,
            content={
                "query": "Are you available for co-working session now?"
            }
        )
        
        response = await connection.agent_b.send(query)
        
        return {
            'available': response.content.get('available', False),
            'current_activity': response.content.get('current_activity'),
            'available_in_minutes': response.content.get('available_in_minutes'),
            'message': response.content.get('message')
        }
    
    async def send_accountability_check(
        self,
        partner_user_id: str,
        commitment: str,
        deadline: datetime
    ):
        """
        Ask partner's agent to hold you accountable
        
        Example: "You committed to finishing X by Friday—want me to check in with your accountability partner?"
        """
        
        connection = self.active_connections.get(partner_user_id)
        if not connection:
            return
        
        check_request = Message(
            type="accountability_request",
            from_agent=self.a2a_agent.id,
            to_agent=connection.agent_b.id,
            content={
                "commitment": commitment,
                "deadline": deadline.isoformat(),
                "user_wants_check_in": True,
                "check_in_timing": "deadline" # or "daily", "weekly"
            }
        )
        
        response = await connection.agent_b.send(check_request)
        
        if response.content.get('will_check_in'):
            # Partner's agent agreed to check in
            # Schedule check-in task
            self.db.collection('accountability_check_ins').add({
                'requester_id': self.user_id,
                'partner_id': partner_user_id,
                'commitment': commitment,
                'deadline': deadline,
                'check_in_scheduled': True,
                'status': 'pending'
            })
    
    async def _schedule_session_reminders(self, session_data: dict):
        """Schedule reminders for co-working session"""
        
        session_time = session_data['scheduled_time']
        
        # Reminder times: 1 day before, 1 hour before, 10 min before
        reminder_times = [
            session_time - timedelta(days=1),
            session_time - timedelta(hours=1),
            session_time - timedelta(minutes=10)
        ]
        
        for reminder_time in reminder_times:
            # Schedule background task
            asyncio.create_task(
                self._send_reminder_at_time(
                    session_data['session_id'],
                    reminder_time,
                    session_data['participants']
                )
            )
    
    async def _send_reminder_at_time(
        self,
        session_id: str,
        reminder_time: datetime,
        participants: List[str]
    ):
        """Send reminder to all participants"""
        
        # Wait until reminder time
        wait_seconds = (reminder_time - datetime.now()).total_seconds()
        if wait_seconds > 0:
            await asyncio.sleep(wait_seconds)
        
        # Send to each participant's agent
        for user_id in participants:
            connection = self.active_connections.get(user_id)
            if connection:
                reminder = Message(
                    type="session_reminder",
                    from_agent=self.a2a_agent.id,
                    to_agent=connection.agent_b.id,
                    content={
                        "session_id": session_id,
                        "message": f"Co-working session in {self._format_time_until(reminder_time)}!",
                        "action": "prepare"
                    }
                )
                
                await connection.agent_b.send(reminder)


# ============================================
# A2A MESSAGE HANDLERS
# ============================================

class A2AMessageHandler:
    """Handles incoming A2A messages from other agents"""
    
    def __init__(self, user_id: str):
        self.user_id = user_id
        self.db = firestore.client()
    
    async def handle_connection_request(self, message: Message) -> Message:
        """Handle incoming accountability partner request"""
        
        # Notify user via WebSocket
        # User can accept/reject
        
        # For capstone: Auto-accept with notification
        return Message(
            type="connection_response",
            from_agent=f"neuropilot_{self.user_id}",
            to_agent=message.from_agent,
            content={
                "accepted": True,
                "message": "Connection accepted! Let's support each other."
            }
        )
    
    async def handle_coworking_proposal(self, message: Message) -> Message:
        """Handle incoming co-working session proposal"""
        
        proposed_time = datetime.fromisoformat(message.content['proposed_time'])
        
        # Check user's calendar (via MCP - Google Calendar)
        is_available = await self._check_calendar_availability(proposed_time)
        
        if is_available:
            # Accept and notify user
            await self._notify_user({
                "type": "coworking_invitation",
                "message": f"Co-working session proposed for {proposed_time.strftime('%I:%M %p')}. Accepted!",
                "time": proposed_time.isoformat()
            })
            
            return Message(
                type="coworking_response",
                from_agent=f"neuropilot_{self.user_id}",
                to_agent=message.from_agent,
                content={
                    "accepted": True,
                    "confirmed_time": proposed_time.isoformat()
                }
            )
        else:
            # Suggest alternative time
            alternative = await self._find_next_available_slot(proposed_time)
            
            return Message(
                type="coworking_response",
                from_agent=f"neuropilot_{self.user_id}",
                to_agent=message.from_agent,
                content={
                    "accepted": False,
                    "reason": "Calendar conflict",
                    "alternative_time": alternative.isoformat()
                }
            )
    
    async def handle_session_reminder(self, message: Message):
        """Handle co-working session reminder"""
        
        # Notify user
        await self._notify_user({
            "type": "session_reminder",
            "message": message.content['message'],
            "session_id": message.content['session_id'],
            "action": message.content['action']
        })
    
    async def _check_commitment_status(self, commitment: str, deadline: datetime) -> dict:
        """Check if user completed their commitment"""
        
        # Query tasks from Firestore
        tasks = self.db.collection('users').document(self.user_id)\
                       .collection('tasks')\
                       .where('name', '==', commitment)\
                       .where('deadline', '==', deadline)\
                       .stream()
        
        task = next(tasks, None)
        
        if task:
            task_data = task.to_dict()
            return {
                'completed': task_data.get('status') == 'completed',
                'progress': task_data.get('progress', 0),
                'last_worked_on': task_data.get('last_worked_on')
            }
        
        return {
            'completed': False,
            'progress': 0,
            'last_worked_on': None
        }
    
    async def _find_next_available_slot(self, after_time: datetime) -> datetime:
        """Find next available time slot in calendar"""
        # Would use MCP Google Calendar
        # For capstone: simple logic
        return after_time + timedelta(hours=2)


# ============================================
# A2A AGENT SERVER
# ============================================

class NeuroPilotA2AServer:
    """
    HTTP server that handles incoming A2A messages from other agents
    This makes your agent discoverable and reachable by other agents
    """
    
    def __init__(self, user_id: str, host: str = "0.0.0.0", port: int = 8001):
        self.user_id = user_id
        self.host = host
        self.port = port
        self.handler = A2AMessageHandler(user_id)
        self.app = FastAPI(title=f"NeuroPilot A2A Server - {user_id}")
    
    def setup_routes(self):
        """Setup A2A protocol endpoints"""
        
        @self.app.get("/.well-known/agent.json")
        async def agent_manifest():
            """
            Agent discovery endpoint
            Other agents call this to learn about capabilities
            """
            return {
                "id": f"neuropilot_{self.user_id}",
                "name": f"NeuroPilot for {self.user_id}",
                "description": "Executive function companion for neurodivergent adults",
                "version": "1.0.0",
                "capabilities": [
                    "accountability_tracking",
                    "co_working_sessions",
                    "availability_checking",
                    "progress_sharing"
                ],
                "endpoints": {
                    "messages": f"http://{self.host}:{self.port}/a2a/messages"
                },
                "protocol_version": "1.0"
            }
        
        @self.app.post("/a2a/messages")
        async def receive_message(message: dict):
            """
            Receive A2A messages from other agents
            """
            message_type = message.get('type')
            
            # Route to appropriate handler
            if message_type == 'connection_request':
                response = await self.handler.handle_connection_request(
                    Message(**message)
                )
            elif message_type == 'coworking_proposal':
                response = await self.handler.handle_coworking_proposal(
                    Message(**message)
                )
            elif message_type == 'availability_check':
                response = await self.handler.handle_availability_check(
                    Message(**message)
                )
            elif message_type == 'progress_update':
                await self.handler.handle_progress_update(Message(**message))
                response = Message(
                    type="acknowledgment",
                    from_agent=f"neuropilot_{self.user_id}",
                    to_agent=message['from_agent'],
                    content={"received": True}
                )
            elif message_type == 'accountability_request':
                response = await self.handler.handle_accountability_check(
                    Message(**message)
                )
            elif message_type == 'session_reminder':
                await self.handler.handle_session_reminder(Message(**message))
                response = Message(
                    type="acknowledgment",
                    from_agent=f"neuropilot_{self.user_id}",
                    to_agent=message['from_agent'],
                    content={"received": True}
                )
            else:
                response = Message(
                    type="error",
                    from_agent=f"neuropilot_{self.user_id}",
                    to_agent=message['from_agent'],
                    content={"error": f"Unknown message type: {message_type}"}
                )
            
            return response.__dict__
    
    def start(self):
        """Start the A2A server"""
        import uvicorn
        self.setup_routes()
        print(f"🌐 A2A Server starting at http://{self.host}:{self.port}")
        uvicorn.run(self.app, host=self.host, port=self.port)


# ============================================
# DEMO: TWO USERS COMMUNICATING VIA A2A
# ============================================

async def demo_a2a_coordination():
    """
    Demo showing how Alice and Bob's agents communicate
    """
    print("=" * 70)
    print("A2A COORDINATION DEMO")
    print("=" * 70)
    
    # Initialize two users' coordinators
    alice_coordinator = A2ACoordinator('alice_001')
    bob_coordinator = A2ACoordinator('bob_002')
    
    # Initialize their A2A agents
    await alice_coordinator.initialize_a2a_agent('http://localhost:8001')
    await bob_coordinator.initialize_a2a_agent('http://localhost:8002')
    
    print("\n1️⃣ Alice connects Bob as accountability partner...")
    connected = await alice_coordinator.connect_accountability_partner(
        'bob_002',
        'http://localhost:8002'
    )
    print(f"   Connected: {connected}")
    
    print("\n2️⃣ Alice checks if Bob is available...")
    availability = await alice_coordinator.check_partner_availability('bob_002')
    print(f"   Bob's status: {availability}")
    
    print("\n3️⃣ Alice schedules co-working session...")
    session_time = datetime.now() + timedelta(hours=1)
    session = await alice_coordinator.schedule_coworking_session(
        'bob_002',
        session_time,
        duration_minutes=90
    )
    print(f"   Session scheduled: {session}")
    
    print("\n4️⃣ Alice sends progress update...")
    await alice_coordinator.send_progress_update(
        'bob_002',
        'Build NeuroPilot agents',
        progress=60,
        message="Making great progress! Finished 3 agents."
    )
    print("   Progress update sent!")
    
    print("\n5️⃣ Alice sets up accountability check...")
    await alice_coordinator.send_accountability_check(
        'bob_002',
        'Complete NeuroPilot capstone project',
        deadline=datetime.now() + timedelta(days=7)
    )
    print("   Accountability request sent!")
    
    print("\n✅ A2A Demo Complete!")
    print("=" * 70)


# Run demo
if __name__ == "__main__":
    import asyncio
    asyncio.run(demo_a2a_coordination())
```

---

## 🔄 BACKGROUND SERVICES & MONITORING

### **Continuous Context Capture Service**

```python
# services/context_capture_service.py

import asyncio
from datetime import datetime, timedelta
from typing import Dict, Optional

class ContinuousContextCaptureService:
    """
    Background service that automatically captures work context
    Runs every 5 minutes during active work sessions
    """
    
    def __init__(self):
        self.active_captures = {}  # user_id -> capture_task
        self.capture_interval = 300  # 5 minutes
    
    async def start_capturing(self, user_id: str, task_id: str):
        """Start continuous context capture for a user"""
        
        if user_id in self.active_captures:
            # Already capturing
            return
        
        print(f"📸 Starting context capture for user {user_id}")
        
        # Create background task
        task = asyncio.create_task(
            self._capture_loop(user_id, task_id)
        )
        self.active_captures[user_id] = task
    
    async def stop_capturing(self, user_id: str):
        """Stop context capture for a user"""
        
        if user_id in self.active_captures:
            task = self.active_captures[user_id]
            task.cancel()
            del self.active_captures[user_id]
            print(f"⏹️ Stopped context capture for user {user_id}")
    
    async def _capture_loop(self, user_id: str, task_id: str):
        """Background loop that captures context every 5 minutes"""
        
        engine = ContextRestorationEngine(user_id)
        
        try:
            while True:
                # Wait 5 minutes
                await asyncio.sleep(self.capture_interval)
                
                try:
                    # Capture current context
                    context_id = await engine.capture_context_snapshot(
                        task_id=task_id,
                        user_message=None,
                        active_files=None  # Would come from IDE extension
                    )
                    
                    print(f"💾 Context captured: {context_id} for user {user_id}")
                    
                except Exception as e:
                    print(f"❌ Error capturing context: {e}")
                    
        except asyncio.CancelledError:
            # Task was cancelled
            print(f"Context capture cancelled for {user_id}")


# Global service instance
context_capture_service = ContinuousContextCaptureService()


# ============================================
# HYPERFOCUS MONITORING SERVICE
# ============================================

class HyperfocusMonitoringService:
    """
    Monitors work duration and intervenes during hyperfocus
    Prevents burnout from extended work sessions
    """
    
    def __init__(self):
        self.active_sessions = {}  # user_id -> session_data
    
    async def start_monitoring(self, user_id: str, websocket):
        """Start monitoring user's work session"""
        
        self.active_sessions[user_id] = {
            'started_at': datetime.now(),
            'last_break': datetime.now(),
            'websocket': websocket,
            'work_duration_minutes': 0,
            'break_count': 0
        }
        
        # Start monitoring task
        asyncio.create_task(self._monitor_loop(user_id))
    
    async def stop_monitoring(self, user_id: str):
        """Stop monitoring when user ends session"""
        if user_id in self.active_sessions:
            del self.active_sessions[user_id]
    
    async def record_break(self, user_id: str):
        """Record that user took a break"""
        if user_id in self.active_sessions:
            session = self.active_sessions[user_id]
            session['last_break'] = datetime.now()
            session['break_count'] += 1
    
    async def _monitor_loop(self, user_id: str):
        """Background loop checking for hyperfocus"""
        
        while user_id in self.active_sessions:
            session = self.active_sessions[user_id]
            
            # Calculate work duration
            work_duration = datetime.now() - session['last_break']
            work_minutes = work_duration.total_seconds() / 60
            
            session['work_duration_minutes'] = int(work_minutes)
            
            # Check if intervention needed
            if work_minutes >= 120:  # 2 hours
                await self._send_hyperfocus_alert(
                    user_id, 
                    session['websocket'],
                    work_minutes,
                    "URGENT"
                )
            elif work_minutes >= 60:  # 1 hour
                await self._send_hyperfocus_alert(
                    user_id,
                    session['websocket'],
                    work_minutes,
                    "HIGH"
                )
            
            # Check every 5 minutes
            await asyncio.sleep(300)
    
    async def _send_hyperfocus_alert(
        self, 
        user_id: str, 
        websocket,
        work_minutes: int,
        level: str
    ):
        """Send hyperfocus intervention message"""
        
        messages = {
            "URGENT": f"🚨 HYPERFOCUS ALERT: You've been working {int(work_minutes)} minutes "
                     f"without a break! Stop NOW. Bathroom, water, food - in that order.",
            "HIGH": f"⚠️ You've been in deep work for {int(work_minutes)} minutes. "
                   f"Take a 10-minute break in the next 5 minutes."
        }
        
        try:
            await websocket.send_json({
                "type": "hyperfocus_alert",
                "level": level,
                "message": messages.get(level, "Time for a break!"),
                "work_minutes": int(work_minutes),
                "should_interrupt": level == "URGENT"
            })
        except Exception as e:
            print(f"Error sending hyperfocus alert: {e}")


# Global service instance
hyperfocus_service = HyperfocusMonitoringService()


# ============================================
# ENERGY PATTERN LEARNING SERVICE
# ============================================

class EnergyPatternLearner:
    """
    Learns user's energy patterns over time
    Predicts energy levels and optimal work times
    """
    
    def __init__(self, user_id: str):
        self.user_id = user_id
        self.db = firestore.client()
    
    async def record_energy_datapoint(self, energy_level: int, hour: int, day_of_week: int):
        """Record energy level at specific time"""
        
        self.db.collection('users').document(self.user_id)\
               .collection('energy_data').add({
            'energy_level': energy_level,
            'hour': hour,
            'day_of_week': day_of_week,  # 0=Monday, 6=Sunday
            'timestamp': firestore.SERVER_TIMESTAMP
        })
    
    async def predict_energy(self, target_time: datetime) -> dict:
        """
        Predict energy level at target time based on historical data
        """
        
        hour = target_time.hour
        day_of_week = target_time.weekday()
        
        # Query similar times from history
        historical_data = self.db.collection('users').document(self.user_id)\
                                 .collection('energy_data')\
                                 .where('hour', '==', hour)\
                                 .where('day_of_week', '==', day_of_week)\
                                 .limit(20)\
                                 .stream()
        
        energy_levels = [doc.to_dict()['energy_level'] for doc in historical_data]
        
        if energy_levels:
            avg_energy = sum(energy_levels) / len(energy_levels)
            std_dev = (sum((x - avg_energy) ** 2 for x in energy_levels) / len(energy_levels)) ** 0.5
            
            return {
                'predicted_energy': round(avg_energy, 1),
                'confidence': min(len(energy_levels) / 20, 1.0),  # More data = higher confidence
                'std_dev': round(std_dev, 2),
                'sample_size': len(energy_levels)
            }
        else:
            # No data yet - return neutral
            return {
                'predicted_energy': 5.0,
                'confidence': 0.0,
                'message': 'Not enough data yet to predict'
            }
    
    async def get_peak_hours(self) -> list:
        """Identify user's peak productivity hours"""
        
        # Get last 30 days of energy data
        thirty_days_ago = datetime.now() - timedelta(days=30)
        
        energy_data = self.db.collection('users').document(self.user_id)\
                             .collection('energy_data')\
                             .where('timestamp', '>=', thirty_days_ago)\
                             .stream()
        
        # Group by hour
        hour_energies = {}
        for doc in energy_data:
            data = doc.to_dict()
            hour = data['hour']
            energy = data['energy_level']
            
            if hour not in hour_energies:
                hour_energies[hour] = []
            hour_energies[hour].append(energy)
        
        # Calculate average energy per hour
        hour_averages = {
            hour: sum(energies) / len(energies)
            for hour, energies in hour_energies.items()
        }
        
        # Find top 3 hours
        sorted_hours = sorted(hour_averages.items(), key=lambda x: x[1], reverse=True)
        peak_hours = sorted_hours[:3]
        
        return [
            {
                'hour': hour,
                'time': f"{hour:02d}:00",
                'avg_energy': round(energy, 1)
            }
            for hour, energy in peak_hours
        ]


# ============================================
# INTEGRATED MONITORING SERVICE
# ============================================

class IntegratedMonitoringService:
    """
    Coordinates all background monitoring services
    Single entry point for starting/stopping monitoring
    """
    
    def __init__(self):
        self.context_capture = ContinuousContextCaptureService()
        self.hyperfocus_monitor = HyperfocusMonitoringService()
        self.energy_learner_cache = {}
    
    async def start_work_session(
        self, 
        user_id: str, 
        task_id: str,
        websocket
    ):
        """
        Start all monitoring services when user begins work
        """
        print(f"🎬 Starting work session monitoring for {user_id}")
        
        # Start context capture
        await self.context_capture.start_capturing(user_id, task_id)
        
        # Start hyperfocus monitoring
        await self.hyperfocus_monitor.start_monitoring(user_id, websocket)
        
        # Initialize energy learner
        if user_id not in self.energy_learner_cache:
            self.energy_learner_cache[user_id] = EnergyPatternLearner(user_id)
        
        print(f"✅ All monitoring services active for {user_id}")
    
    async def end_work_session(self, user_id: str):
        """Stop all monitoring when user ends work"""
        
        await self.context_capture.stop_capturing(user_id)
        await self.hyperfocus_monitor.stop_monitoring(user_id)
        
        print(f"⏹️ Work session ended for {user_id}")
    
    async def record_break(self, user_id: str):
        """Record that user took a break"""
        await self.hyperfocus_monitor.record_break(user_id)
    
    async def record_energy(self, user_id: str, energy_level: int):
        """Record energy level data point"""
        
        learner = self.energy_learner_cache.get(user_id)
        if learner:
            now = datetime.now()
            await learner.record_energy_datapoint(
                energy_level,
                now.hour,
                now.weekday()
            )
    
    async def get_energy_insights(self, user_id: str) -> dict:
        """Get energy pattern insights for user"""
        
        learner = self.energy_learner_cache.get(user_id)
        if not learner:
            learner = EnergyPatternLearner(user_id)
            self.energy_learner_cache[user_id] = learner
        
        peak_hours = await learner.get_peak_hours()
        next_hour_prediction = await learner.predict_energy(
            datetime.now() + timedelta(hours=1)
        )
        
        return {
            'peak_hours': peak_hours,
            'next_hour_prediction': next_hour_prediction
        }


# Global integrated service
monitoring_service = IntegratedMonitoringService()
```

---

## 🎨 ENHANCED FRONTEND WITH ALL FEATURES

### **Complete React Component Structure**

```typescript
// frontend/src/App.tsx

import React, { useState, useEffect } from 'react';
import ChatInterface from './components/ChatInterface';
import DecisionTimer from './components/DecisionTimer';
import HyperfocusAlert from './components/HyperfocusAlert';
import EnergyTracker from './components/EnergyTracker';
import ContextRestoration from './components/ContextRestoration';
import PartnerStatus from './components/PartnerStatus';
import TaskList from './components/TaskList';
import { useWebSocket } from './hooks/useWebSocket';
import { useAgentState } from './hooks/useAgentState';

function App() {
  const userId = localStorage.getItem('userId') || 
                 'user_' + Math.random().toString(36).substr(2, 9);
  
  const { 
    messages, 
    sendMessage, 
    agentState,
    connectionStatus 
  } = useWebSocket(userId);
  
  const {
    tasks,
    energyLevel,
    brainState,
    decisionTimer,
    hyperfocusAlert,
    contextData,
    partnerStatus
  } = useAgentState(agentState);
  
  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-purple-50">
      <div className="container mx-auto max-w-7xl p-4">
        
        {/* Header */}
        <header className="bg-white rounded-lg shadow-lg p-6 mb-4">
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-4xl font-bold text-gray-800">
                🧠 NeuroPilot
              </h1>
              <p className="text-gray-600 mt-1">
                Your Executive Function Companion
              </p>
            </div>
            
            <div className="flex items-center gap-4">
              {/* Connection Status */}
              <div className={`px-4 py-2 rounded-full text-sm font-medium ${
                connectionStatus === 'connected' 
                  ? 'bg-green-100 text-green-800' 
                  : 'bg-red-100 text-red-800'
              }`}>
                {connectionStatus === 'connected' ? '🟢 Connected' : '🔴 Disconnected'}
              </div>
              
              {/* Brain State Indicator */}
              {brainState && (
                <div className="px-4 py-2 bg-blue-100 text-blue-800 rounded-full text-sm font-medium">
                  {brainState === 'focused' && '🎯 Focused'}
                  {brainState === 'scattered' && '🌀 Scattered'}
                  {brainState === 'overwhelmed' && '😰 Overwhelmed'}
                </div>
              )}
            </div>
          </div>
        </header>
        
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
          
          {/* Left Column - Chat & Alerts */}
          <div className="lg:col-span-2 space-y-4">
            
            {/* Hyperfocus Alert - Shows above chat when active */}
            {hyperfocusAlert && (
              <HyperfocusAlert 
                alert={hyperfocusAlert}
                onTakeBreak={() => sendMessage('I\'ll take a break now')}
                onDismiss={() => sendMessage('Dismiss alert')}
              />
            )}
            
            {/* Decision Timer - Shows when active */}
            {decisionTimer && (
              <DecisionTimer 
                timer={decisionTimer}
                onCancel={() => sendMessage('STOP')}
              />
            )}
            
            {/* Context Restoration - Shows when available */}
            {contextData && (
              <ContextRestoration 
                context={contextData}
                onResume={() => sendMessage('Resume where I left off')}
                onDismiss={() => /* hide */ null}
              />
            )}
            
            {/* Main Chat Interface */}
            <ChatInterface 
              messages={messages}
              onSendMessage={sendMessage}
              isThinking={agentState?.thinking || false}
            />
          </div>
          
          {/* Right Column - Stats & Tools */}
          <div className="space-y-4">
            
            {/* Energy Tracker */}
            <EnergyTracker 
              currentEnergy={energyLevel}
              onEnergyChange={(level) => sendMessage(`My energy is ${level}/10`)}
              peakHours={agentState?.energyInsights?.peak_hours || []}
            />
            
            {/* Today's Tasks */}
            <TaskList 
              tasks={tasks}
              onTaskComplete={(taskId) => sendMessage(`Completed task ${taskId}`)}
              onTaskStart={(taskId) => sendMessage(`Starting task ${taskId}`)}
            />
            
            {/* Accountability Partners */}
            {partnerStatus && partnerStatus.length > 0 && (
              <PartnerStatus 
                partners={partnerStatus}
                onCheckAvailability={(partnerId) => 
                  sendMessage(`Is ${partnerId} available?`)
                }
                onScheduleSession={(partnerId) => 
                  sendMessage(`Schedule co-work with ${partnerId}`)
                }
              />
            )}
            
          </div>
        </div>
        
      </div>
    </div>
  );
}

export default App;
```

### **WebSocket Hook with Full Integration**

```typescript
// frontend/src/hooks/useWebSocket.ts

import { useState, useEffect, useRef, useCallback } from 'react';

interface Message {
  id: string;
  type: 'user' | 'agent' | 'system';
  content: string;
  timestamp: Date;
  metadata?: any;
}

interface AgentState {
  thinking: boolean;
  brainState?: string;
  energyLevel?: number;
  decisionTimer?: any;
  hyperfocusAlert?: any;
  contextData?: any;
  tasks?: any[];
  partnerStatus?: any[];
  energyInsights?: any;
}

export function useWebSocket(userId: string) {
  const [messages, setMessages] = useState<Message[]>([]);
  const [agentState, setAgentState] = useState<AgentState>({ thinking: false });
  const [connectionStatus, setConnectionStatus] = useState<'connecting' | 'connected' | 'disconnected'>('connecting');
  
  const wsRef = useRef<WebSocket | null>(null);
  const reconnectTimeoutRef = useRef<NodeJS.Timeout>();
  
  const connect = useCallback(() => {
    const ws = new WebSocket(`ws://localhost:8000/ws/${userId}`);
    
    ws.onopen = () => {
      console.log('WebSocket connected');
      setConnectionStatus('connected');
      
      // Clear reconnect timeout
      if (reconnectTimeoutRef.current) {
        clearTimeout(reconnectTimeoutRef.current);
      }
    };
    
    ws.onmessage = (event) => {
      const data = JSON.parse(event.data);
      
      switch (data.type) {
        case 'response':
          // Agent response
          setMessages(prev => [...prev, {
            id: Date.now().toString(),
            type: 'agent',
            content: data.message,
            timestamp: new Date(),
            metadata: data.brain_state
          }]);
          setAgentState(prev => ({ ...prev, thinking: false }));
          break;
        
        case 'thinking':
          setAgentState(prev => ({ ...prev, thinking: true }));
          break;
        
        case 'decision_timer_start':
          setAgentState(prev => ({
            ...prev,
            decisionTimer: {
              timerId: data.timer_id,
              message: data.message,
              secondsRemaining: data.timer_seconds,
              startedAt: new Date()
            }
          }));
          break;
        
        case 'timer_update':
          setAgentState(prev => ({
            ...prev,
            decisionTimer: prev.decisionTimer ? {
              ...prev.decisionTimer,
              secondsRemaining: data.remaining_seconds
            } : null
          }));
          break;
        
        case 'timer_cancelled':
        case 'decision_made':
          setMessages(prev => [...prev, {
            id: Date.now().toString(),
            type: 'system',
            content: data.message,
            timestamp: new Date()
          }]);
          setAgentState(prev => ({ ...prev, decisionTimer: null }));
          break;
        
        case 'hyperfocus_alert':
          setAgentState(prev => ({
            ...prev,
            hyperfocusAlert: {
              level: data.level,
              message: data.message,
              workMinutes: data.work_minutes,
              shouldInterrupt: data.should_interrupt
            }
          }));
          break;
        
        case 'context_restored':
          setAgentState(prev => ({
            ...prev,
            contextData: data.context
          }));
          break;
        
        case 'partner_update':
          setAgentState(prev => ({
            ...prev,
            partnerStatus: data.partners
          }));
          break;
        
        case 'energy_insights':
          setAgentState(prev => ({
            ...prev,
            energyInsights: data.insights
          }));
          break;
        
        case 'tasks_update':
          setAgentState(prev => ({
            ...prev,
            tasks: data.tasks
          }));
          break;
        
        case 'state_update':
          setAgentState(prev => ({
            ...prev,
            brainState: data.brain_state,
            energyLevel: data.energy_level
          }));
          break;
      }
    };
    
    ws.onerror = (error) => {
      console.error('WebSocket error:', error);
    
    
    async def handle_availability_check(self, message: Message) -> Message:
        """
        Respond to availability query from partner's agent
        
        This is what makes "Sarah's agent confirmed she's ready" possible
        """
        
        # Get user's current state from session
        user_session = session_manager.get_session(self.user_id)
        current_state = user_session['state']
        
        # Determine availability
        is_available = (
            current_state['brain_state'] != 'overwhelmed' and
            current_state['energy_level'] >= 4 and
            current_state.get('current_task') is None
        )
        
        if is_available:
            message_text = "Ready to co-work!"
        elif current_state['brain_state'] == 'overwhelmed':
            message_text = "Currently overwhelmed, need some time"
        elif current_state.get('current_task'):
            message_text = f"In the middle of {current_state['current_task']}, can join in 30 min"
        else:
            message_text = "Low energy, maybe later"
        
        return Message(
            type="availability_response",
            from_agent=f"neuropilot_{self.user_id}",
            to_agent=message.from_agent,
            content={
                "available": is_available,
                "current_activity": current_state.get('current_task', 'none'),
                "brain_state": current_state['brain_state'],
                "energy_level": current_state['energy_level'],
                "available_in_minutes": 0 if is_available else 30,
                "message": message_text
            }
        )
    
    async def handle_progress_update(self, message: Message):
        """Receive progress update from accountability partner"""
        
        # Notify user
        await self._notify_user({
            "type": "partner_progress",
            "message": f"🎉 Your partner completed: {message.content['task_name']}!",
            "partner_message": message.content.get('message', '')
        })
        
        # Log in database
        self.db.collection('users').document(self.user_id)\
               .collection('partner_updates').add({
            'from_partner': message.from_agent,
            'task': message.content['task_name'],
            'progress': message.content['progress'],
            'received_at': firestore.SERVER_TIMESTAMP
        })
    
    async def handle_accountability_check(self, message: Message):
        """Partner's agent is checking on commitment"""
        
        commitment = message.content['commitment']
        deadline = datetime.fromisoformat(message.content['deadline'])
        
        # Check if commitment was completed
        task_status = await self._check_commitment_status(commitment, deadline)
        
        if task_status['completed']:
            # Celebrate!
            response_message = f"✅ Yes! I completed: {commitment}"
        else:
            # Be honest about status
            response_message = f"Still working on it. {task_status['progress']}% done."
        
        # Send update to partner
        await self._notify_user({
            "type": "accountability_check",
            "message": f"Your partner is checking on: {commitment}",
            "status": task_status
        })
        
        return Message(
            type="accountability_response",
            from_agent=f"neuropilot_{self.user_id}",
            to_agent=message.from_agent,
            content={
                "commitment": commitment,
                "completed": task_status['completed'],
                "progress": task_status['progress'],
                "message": response_message
            }
        )
    
    async def _check_calendar_availability(self, proposed_time: datetime) -> bool:
        """Check Google Calendar via MCP"""
        # Would use MCP Google Calendar integration
        # For capstone: simplified check
        return True
    
    async def _notify_user(self, notification: dict):
        """Send notification to user via WebSocket"""
        # This would connect to active WebSocket
        # For capstone: store in database for polling
        self.db.collection('users').document(self.user_id)\
               .collection('notifications').add({
            **notification,
            'timestamp': firestore.SERVER_TIMESTAMP,
            'read': False
        })


# ============================================
# INTEGRATE A2A WITH EXTERNAL BRAIN AGENT
# ============================================

# Add A2A tools to External Brain Agent
external_brain_agent = Agent(
    model='gemini-2.0-flash-001',
    name='external_brain_agent',
    instruction="""You are the External Brain with A2A capabilities.
    
    You can:
    1. Restore context when user asks "what was I working on?"
    2. Connect users with accountability partners
    3. Schedule co-working sessions
    4. Check if partners are available
    5. Send/receive progress updates
    
    When user says things like:
    - "Is Sarah available to co-work?"
      → Use check_partner_availability
      
    - "Let's schedule a session with Bob"
      → Use schedule_coworking_session
      
    - "Tell my partner I finished the task"
      → Use send_progress_update
      
    Always coordinate through A2A protocol, never direct messaging.
    """,
    tools=[
        # Context restoration tools
        ContextRestorationEngine.restore_context,
        ContextRestorationEngine.generate_restoration_message,
        
        # A2A coordination tools
        A2ACoordinator.connect_accountability_partner,
        A2ACoordinator.schedule_coworking_session,
        A2ACoordinator.check_partner_availability,
        A2ACoordinator.send_progress_update,
        A2ACoordinator.send_accountability_check
    ]
)
```

---

## 💻 COMPLETE TECH STACK SUMMARY

### **Layer 1: Frontend (User Interface)**
```
Web App:
├── React 18+ with TypeScript
├── Tailwind CSS for styling
├── WebSocket client (socket.io-client)
├── State management: Zustand or Redux
├── Real-time updates: WebSocket connection
└── Deployment: Vercel (free tier)

Components:
├── ChatInterface.tsx - Main conversation UI
├── TaskList.tsx - Today's tasks
├── DecisionTimer.tsx - Countdown display
├── EnergyTracker.tsx - Energy level input
├── ContextRestoration.tsx - "Where you left off" display
└── PartnerStatus.tsx - A2A partner availability
```

### **Layer 2: API Gateway (Backend)**
```
FastAPI Server:
├── Python 3.11+
├── FastAPI 0.104+ (REST + WebSocket)
├── Uvicorn (ASGI server)
├── Firebase Auth (authentication)
├── CORS middleware
└── Deployment: Cloud Run (Google Cloud)

Endpoints:
├── POST /api/chat - Send message to agent
├── GET /api/tasks - Fetch user tasks
├── POST /api/tasks/complete - Mark task done
├── WS /ws/{user_id} - WebSocket for real-time
├── POST /api/a2a/connect - Connect partners
└── GET /api/context/restore - Get last context
```

### **Layer 3: Agent Engine**
```
Google ADK:
├── Vertex AI Agent Engine (hosted)
├── Gemini 2.0 Flash (LLM)
├── 6 specialized agents
├── InMemorySessionService
├── Memory Bank (Firestore backend)
└── A2A Protocol integration

Agents:
├── Coordinator (main)
├── TaskFlow (loop)
├── Time Perception (parallel)
├── Energy/Sensory (loop + memory)
├── Decision Support (sequential)
└── External Brain (long-running + A2A)
```

### **Layer 4: Data Storage**
```
Firestore (NoSQL):
├── users/
│   ├── {user_id}/
│   │   ├── profile (neurotype, preferences)
│   │   ├── state (current task, brain state)
│   │   ├── metrics (tasks completed, accuracy)
│   │   ├── tasks/ (subcollection)
│   │   ├── work_contexts/ (subcollection)
│   │   ├── food_orders/ (subcollection)
│   │   ├── messages/ (subcollection)
│   │   ├── accountability_partners/ (subcollection)
│   │   └── notifications/ (subcollection)
├── coworking_sessions/
├── accountability_check_ins/
└── a2a_connections/

Alternative (for larger scale):
PostgreSQL with:
├── Users table
├── Tasks table
├── Contexts table
├── Messages table
└── A2A connections table
```

### **Layer 5: External Integrations**
```
MCP Integrations:
├── Google Calendar (schedule management)
├── Gmail (email notifications)
├── Google Drive (file access for context)

APIs:
├── DoorDash/UberEats (food ordering)
├── Spotify/YouTube (focus music)
├── Notion/Todoist (task sync)

A2A Network:
├── Agent discovery service
├── Message routing
└── Connection management
```

---

## 🎬 COMPLETE USER FLOW EXAMPLES

### **Flow 1: Morning Startup**
```
1. User opens app → WebSocket connects
2. Frontend sends: "Good morning"
3. Backend routes to Coordinator Agent
4. Agent checks session: energy_level=null
5. Agent asks: "How's your energy 1-10?"
6. User: "7"
7. Agent updates session: energy_level=7
8. Agent queries tasks from Firestore
9. Agent + TaskFlow: Prioritizes 3 tasks for energy level 7
10. Response sent via WebSocket
11. Frontend displays: Tasks + Energy tracker
```

### **Flow 2: Decision Paralysis → Auto Food Order**
```
1. User: "I need to order dinner but can't decide"
2. Backend: Routes to Decision Agent
3. Decision Agent: Detects food + indecision keywords
4. Decision Agent: Queries Memory Bank for food preferences
5. Timer starts (90 seconds) - stored in Redis/Memory
6. Backend sends WebSocket message with timer UI
7. Frontend displays DecisionTimer component
8. [90 seconds pass with no user input]
9. Decision Agent calls FoodOrderingTool
10. Tool queries most frequent restaurant
11. Tool starts 60-second cancellation countdown
12. WebSocket update: "Ordering Thai in 60 sec - STOP to cancel"
13. [60 seconds pass]
14. Tool executes order (via API or simulation)
15. Firestore updated: food_orders collection
16. WebSocket: "✅ Order placed! ETA 30 min"
17. Frontend shows confirmation
```

### **Flow 3: Context Restoration**
```
1. User: "What was I working on yesterday?"
2. Backend routes to External Brain Agent
3. Agent calls ContextRestorationEngine.restore_context()
4. Engine queries Firestore: work_contexts collection
5. Retrieves most recent context for user
6. Finds: task="Build NeuroPilot", file="agent.py", line=247
7. Engine calls generate_restoration_message()
8. LLM (Gemini) formats user-friendly message
9. Message includes:
   - Time since last worked
   - Code location
   - Thought process from brain_dump_notes
   - Next steps
   - Energy/mood state
10. Response sent via WebSocket
11. Frontend displays rich context card
12. User clicks "Resume" → Agent loads exact state
```

### **Flow 4: A2A Partner Coordination**
```
Alice wants to co-work with Bob:

1. Alice: "Is Bob available to co-work?"
2. Backend routes to External Brain Agent (A2A-enabled)
3. Agent calls A2ACoordinator.check_partner_availability()
4. A2A Message sent to Bob's agent:
   {
     type: "availability_check",
     from: "neuropilot_alice",
     to: "neuropilot_bob"
   }
5. Bob's agent (A2AMessageHandler) receives message
6. Bob's agent checks Bob's session state:
   - brain_state: "focused"
   - energy_level: 6
   - current_task: null
7. Bob's agent responds via A2A:
   {
     available: true,
     message: "Ready to co-work!"
   }
8. Alice's agent receives response
9. Alice gets message: "✅ Bob's agent confirmed he's ready!"
10. Alice: "Great! Schedule for 3pm today"
11. Agent calls A2ACoordinator.schedule_coworking_session()
12. A2A proposal sent to Bob's agent
13. Bob's agent checks Bob's Google Calendar (via MCP)
14. Bob's agent confirms
15. Both agents save session to Firestore
16. Both agents schedule reminders (10 min before)
17. At 2:50pm: Both users get notification
    "Co-working session with [partner] starts in 10 min!"
```

---

## 📦 DEPLOYMENT ARCHITECTURE

```
┌─────────────────────────────────────────────────────────────┐
│                    USER DEVICES                             │
│   [Mobile] [Tablet] [Desktop] [Voice Assistant]            │
└────────────────┬────────────────────────────────────────────┘
                 │ HTTPS
                 ▼
┌─────────────────────────────────────────────────────────────┐
│                 CDN (Cloudflare/Vercel)                     │
│               Static Frontend Assets                        │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│            Cloud Run (FastAPI Backend)                      │
│  ├── Auto-scaling (0 to N instances)                        │
│  ├── WebSocket support                                      │
│  ├── Authentication middleware                              │
│  └── Agent Engine client                                    │
└────────────────┬────────────────────────────────────────────┘
                 │ gRPC
                 ▼
┌─────────────────────────────────────────────────────────────┐
│          Vertex AI Agent Engine                             │
│  ├── Hosted ADK runtime                                     │
│  ├── Managed scaling                                        │
│  ├── Observability built-in                                 │
│  └── 6 NeuroPilot agents                                    │
└────────────────┬────────────────────────────────────────────┘
                 │
      ┌──────────┼──────────┬────────────┐
      ▼          ▼          ▼            ▼
┌─────────┐ ┌─────────┐ ┌────────┐ ┌─────────┐
│Firestore│ │MemCache │ │  MCP   │ │   A2A   │
│         │ │(Session)│ │Services│ │ Network │
│User Data│ │  Cache  │ │        │ │         │
└─────────┘ └─────────┘ └────────┘ └─────────┘
```

### **Deployment Commands**

```bash
# 1. Deploy Frontend to Vercel
cd frontend
vercel deploy --prod

# 2. Build Backend Docker image
cd backend
docker build -t neuropilot-api .

# 3. Deploy to Cloud Run
gcloud run deploy neuropilot-api \
  --image gcr.io/PROJECT_ID/neuropilot-api \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars="GOOGLE_CLOUD_PROJECT=PROJECT_ID"

# 4. Deploy Agent to Agent Engine
adk deploy \
  --agent coordinator_agent \
  --project PROJECT_ID \
  --region us-central1
```

---

## 🎯 FOR CAPSTONE SUBMISSION

### **Minimal Viable Demo (What Judges Need to See)**

1. **Chat Interface**: Web UI where user types messages
2. **One Working Scenario**: Decision paralysis → countdown → action
3. **Context Restoration**: Show saved state being restored
4. **A2A Simulation**: Two browser tabs as "different users"
5. **Code Documentation**: Well-commented explaining each part

### **What Can Be Simulated (OK for Capstone)**

✅ Food ordering (don't need real DoorDash API)
✅ A2A between two local agents (don't need production A2A network)
✅ Calendar integration (mock responses)
✅ Some Memory Bank queries (simplified)

### **What Must Be Real**

❌ ADK agents (must use actual ADK)
❌ Gemini LLM (must be real AI responses)
❌ Multi-agent coordination (must show actual orchestration)
❌ Session/Memory management (must persist data)
❌ Observability (must show real logs/metrics)

---