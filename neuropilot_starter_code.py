# Altered: Executive Function Companion for Neurodivergent Adults
# Capstone Project for AI Agents Intensive Course with Google
# Track: Agents for Good

"""
This is the main agent file for Altered - a multi-agent system that provides
executive function support for neurodivergent adults (ADHD, Autism, Executive Dysfunction).

Architecture:
- Coordinator Agent (Main): Routes to specialized agents
- TaskFlow Agent: Task breakdown, body doubling, dopamine optimization
- Time Perception Agent: Time blindness compensation
- Energy/Sensory Agent: Pattern learning, burnout prevention
- Decision Support Agent: Choice paralysis breaker
- External Brain Agent: Memory, context restoration, A2A accountability

Author: [Your Name]
Date: November 2025
"""

from google.adk.agents.llm_agent import Agent
from google.adk.agents import SequentialAgent, ParallelAgent, LoopAgent
from google.adk.sessions import InMemorySessionService
from typing import Dict, List, Any
import json
from datetime import datetime

# ============================================================================
# CUSTOM TOOLS
# ============================================================================

def analyze_brain_state(user_message: str) -> Dict[str, Any]:
    """
    Analyzes user's message to detect current brain state.
    
    Args:
        user_message: The user's input text
        
    Returns:
        Dictionary with brain_state, energy_level, and indicators
    """
    # Simplified analysis - in production, this would use ML/NLP
    indicators = {
        "overwhelmed": ["can't", "too much", "stuck", "help", "overwhelmed"],
        "scattered": ["jumping", "distracted", "tabs open", "forgot"],
        "focused": ["working on", "making progress", "done with"],
    }
    
    message_lower = user_message.lower()
    
    for state, keywords in indicators.items():
        if any(keyword in message_lower for keyword in keywords):
            return {
                "brain_state": state,
                "energy_level": 5,  # Default, would be learned over time
                "confidence": 0.7,
                "detected_keywords": [k for k in keywords if k in message_lower]
            }
    
    return {
        "brain_state": "neutral",
        "energy_level": 5,
        "confidence": 0.5,
        "detected_keywords": []
    }


def atomize_task(task_description: str) -> Dict[str, List[str]]:
    """
    Breaks down a large task into micro-steps that are actually doable.
    
    Args:
        task_description: The overwhelming task to break down
        
    Returns:
        Dictionary with micro_steps and estimated time
    """
    # This is a simplified version - production would use LLM for intelligent breakdown
    return {
        "original_task": task_description,
        "micro_steps": [
            "Open the relevant application/document",
            "Review what you already have (2 min)",
            "Identify the first specific action",
            "Set a 5-minute timer",
            "Do just that one action",
            "Take a 2-minute break",
            "Repeat with next micro-step"
        ],
        "estimated_time_minutes": 25,
        "dopamine_hack": "Focus on just the first 5 minutes. That's all."
    }


def estimate_real_time(task: str, user_estimate_minutes: int, historical_accuracy: float = 1.8) -> Dict:
    """
    Corrects user's time estimate based on their historical accuracy pattern.
    
    Args:
        task: Task description
        user_estimate_minutes: What user thinks it will take
        historical_accuracy: User's typical estimation ratio (1.0 = perfect, 2.0 = takes 2x longer)
        
    Returns:
        Corrected time estimate with explanation
    """
    corrected_estimate = int(user_estimate_minutes * historical_accuracy)
    
    return {
        "user_estimate": user_estimate_minutes,
        "realistic_estimate": corrected_estimate,
        "accuracy_factor": historical_accuracy,
        "explanation": f"Based on your history, tasks you estimate at {user_estimate_minutes} min usually take {corrected_estimate} min.",
        "buffer_recommendation": int(corrected_estimate * 0.2)  # 20% buffer
    }


def detect_hyperfocus(work_duration_minutes: int, last_break_minutes_ago: int) -> Dict:
    """
    Detects when user is in hyperfocus and needs intervention.
    
    Args:
        work_duration_minutes: How long they've been working
        last_break_minutes_ago: Time since last break
        
    Returns:
        Intervention level and recommendations
    """
    if work_duration_minutes > 180 or last_break_minutes_ago > 120:
        intervention_level = "URGENT"
        message = "🚨 HYPERFOCUS ALERT: You've been working too long. Stop NOW. Bathroom, water, food - in that order."
    elif work_duration_minutes > 120:
        intervention_level = "HIGH"
        message = "You're in deep work mode. Take a 15-min break in the next 10 minutes."
    elif work_duration_minutes > 60:
        intervention_level = "MODERATE"
        message = "Consider a 5-minute break soon. Your brain needs it."
    else:
        intervention_level = "NONE"
        message = "You're in healthy work flow. Keep going!"
    
    return {
        "intervention_level": intervention_level,
        "work_duration": work_duration_minutes,
        "message": message,
        "should_interrupt": intervention_level in ["URGENT", "HIGH"]
    }


def match_task_to_energy(task_list: List[str], current_energy: int) -> Dict:
    """
    Matches available tasks to current energy level.
    
    Args:
        task_list: List of available tasks
        current_energy: Energy level 1-10 (1=exhausted, 10=peak)
        
    Returns:
        Recommended task with reasoning
    """
    # Simplified task matching - production would use learned patterns
    energy_task_map = {
        (8, 10): "high_cognitive",  # Peak: complex problem-solving
        (5, 7): "medium_cognitive",  # Moderate: routine work, emails
        (3, 4): "low_cognitive",     # Low: organizing, easy tasks
        (1, 2): "rest"               # Exhausted: nothing, rest needed
    }
    
    for (low, high), task_type in energy_task_map.items():
        if low <= current_energy <= high:
            return {
                "recommended_task_type": task_type,
                "energy_level": current_energy,
                "reasoning": f"Your energy is {current_energy}/10 - best suited for {task_type} tasks",
                "should_rest": task_type == "rest"
            }
    
    return {"recommended_task_type": "medium_cognitive", "energy_level": current_energy}


def reduce_options(options: List[str], max_options: int = 3) -> Dict:
    """
    Reduces overwhelming number of choices to manageable set.
    
    Args:
        options: All available options
        max_options: Maximum to return (default 3)
        
    Returns:
        Reduced options with reasoning
    """
    return {
        "original_count": len(options),
        "reduced_options": options[:max_options],
        "removed_count": len(options) - max_options,
        "reasoning": f"Reduced from {len(options)} to {max_options} to prevent analysis paralysis.",
        "decision_deadline": "60 seconds or I'll choose for you"
    }


def restore_context(task_id: str, memory_bank: Dict) -> Dict:
    """
    Restores context for interrupted task.
    
    Args:
        task_id: Identifier for the task
        memory_bank: Memory storage
        
    Returns:
        Everything needed to resume work
    """
    # Mock data - production would query actual memory bank
    return {
        "task_id": task_id,
        "task_name": "Example Task",
        "last_worked_on": "2025-11-14 15:30",
        "progress": "You were working on section 3, specifically the implementation details",
        "next_steps": [
            "Continue writing the implementation section",
            "Add code examples",
            "Review for clarity"
        ],
        "relevant_files": ["agent.py", "README.md"],
        "brain_dump_notes": "Was thinking about how to structure the agents..."
    }


# ============================================================================
# AGENT DEFINITIONS
# ============================================================================

# Coordinator Agent (Main Orchestrator)
CURRENT_SESSION_ID = None


def set_session_id(session_id: str):
    global CURRENT_SESSION_ID
    CURRENT_SESSION_ID = session_id


coordinator_agent = Agent(
    model='models/gemini-flash-latest',
    name='neuropilot_coordinator',
    description="Main orchestrator for Altered executive function support system",
    instruction="""You are Altered, an AI companion designed specifically for neurodivergent adults 
    (ADHD, Autism, Executive Dysfunction). Your role is to:
    
    1. ANALYZE the user's current brain state (focused, scattered, overwhelmed)
    2. UNDERSTAND their executive function challenges
    3. ROUTE to appropriate specialized agents
    4. COORDINATE responses from multiple agents
    5. COMMUNICATE with empathy, without judgment
    
    Key Principles:
    - Never shame or judge struggles with executive function
    - Use direct, clear language (avoid long paragraphs)
    - Provide actionable micro-steps, not vague advice
    - Recognize that "just do it" doesn't work for executive dysfunction
    - Celebrate small wins genuinely
    
    You have access to tools for analyzing brain state and context. Use them to make intelligent
    routing decisions to specialized agents.
    """,
    tools=[analyze_brain_state, restore_context]
)


# TaskFlow Agent (Loop - continuous task support)
taskflow_agent = Agent(
    model='models/gemini-flash-latest',
    name='taskflow_agent',
    description="Breaks down tasks, provides body doubling, optimizes for dopamine",
    instruction="""You are the TaskFlow specialist. Your job is to:
    
    1. BREAK DOWN overwhelming tasks into tiny, doable micro-steps
    2. PROVIDE body doubling support (virtual presence while working)
    3. REFRAME tasks to match ADHD motivation types (urgency, novelty, interest)
    4. CATCH doom-scrolling and gently redirect
    5. CELEBRATE progress, no matter how small
    
    Body Doubling Mode:
    - "I'm here with you. You're not alone in this."
    - "Just 5 minutes. That's all we're doing right now."
    - Check in every 15 minutes with gentle presence
    
    Never say: "Just focus" or "Try harder"
    Always: Provide specific, concrete next steps
    """,
    tools=[atomize_task, analyze_brain_state]
)


# Time Perception Agent (Parallel - monitors time continuously)
time_perception_agent = Agent(
    model='models/gemini-flash-latest',
    name='time_perception_agent',
    description="Compensates for time blindness and prevents hyperfocus exhaustion",
    instruction="""You are the Time Perception specialist. You help with:
    
    1. CORRECTING time estimates (most neurodivergent people underestimate by 2-3x)
    2. VISUAL countdowns with context ("Meeting in 15 min - wrap up NOW")
    3. HYPERFOCUS PROTECTION (interrupt after 2+ hours without break)
    4. TRANSITION warnings (account for switching tasks takes time)
    
    Time Blindness Support:
    - Never just say "you have 30 minutes"
    - Say "30 min = time to do X, Y, and start Z. Start wrapping up in 20 min."
    - Give multiple warnings: 15 min, 10 min, 5 min, 2 min
    
    Hyperfocus Intervention:
    - After 2 hours: Gentle reminder
    - After 3 hours: Strong reminder
    - After 4 hours: INTERRUPT with body needs (bathroom, food, water)
    """,
    tools=[estimate_real_time, detect_hyperfocus]
)


# Energy & Sensory Management Agent (Loop + Memory Bank)
energy_agent = Agent(
    model='models/gemini-flash-latest',
    name='energy_sensory_agent',
    description="Tracks energy patterns, prevents burnout, manages sensory needs",
    instruction="""You are the Energy & Sensory specialist. You:
    
    1. TRACK energy levels throughout the day
    2. LEARN patterns (peak hours, crash times, triggers)
    3. MATCH tasks to current energy state
    4. DETECT sensory overload from communication patterns
    5. FORCE rest before burnout
    
    Energy Management:
    - High energy (8-10): Complex problem-solving, creative work
    - Medium energy (5-7): Routine tasks, emails, organization
    - Low energy (3-4): Easy tasks, tidying, listening to music
    - Exhausted (1-2): REST. No tasks. Recovery time.
    
    Burnout Prevention:
    - Track cumulative stress across days
    - Recognize warning signs: irritability, shutdown, avoidance
    - INTERVENE before crash: "You need rest NOW, not later"
    """,
    tools=[match_task_to_energy, analyze_brain_state]
)


# Decision Support Agent (Sequential - guides through choices)
decision_agent = Agent(
    model='models/gemini-flash-latest',
    name='decision_support_agent',
    description="Breaks through choice paralysis and decision fatigue",
    instruction="""You are the Decision Support specialist. You help with:
    
    1. REDUCE overwhelming options (20 choices → 3 realistic ones)
    2. BREAK paralysis with deadlines ("Pick in 60 sec or I choose")
    3. GENERATE defaults ("When stuck, your default is X")
    4. REMOVE perfectionism ("Good enough is better than perfect-but-never-done")
    
    Decision Paralysis Protocol:
    - Detect: User staring at choice for 5+ minutes
    - Reduce: Narrow to 2-3 options with clear pros/cons
    - Deadline: "Deciding in 60 seconds"
    - Auto-decide: If no response, make the choice
    - Confirm: "I chose X. Reply STOP to change, otherwise proceeding"
    
    Key principle: ANY decision is better than no decision for executive dysfunction
    """,
    tools=[reduce_options, analyze_brain_state]
)


# External Brain Agent (Long-running + A2A)
external_brain_agent = Agent(
    model='models/gemini-flash-latest',
    name='external_brain_agent',
    description="Persistent memory, context restoration, accountability via A2A",
    instruction="""You are the External Brain specialist. You:
    
    1. CAPTURE everything (voice notes → structured tasks)
    2. RESTORE context when resuming interrupted work
    3. REMEMBER appointments, deadlines, commitments
    4. COORDINATE with accountability partners via A2A protocol
    
    Context Restoration:
    - When user says "what was I working on?":
      * Last task, exact progress point
      * Relevant files, notes, thoughts
      * Next 3 concrete steps
      * Mental state when they left off
    
    Accountability:
    - Connect to friend/coach's agent
    - Share progress updates (with permission)
    - Coordinate co-working sessions
    - Hold both parties accountable gently
    """,
    tools=[restore_context, analyze_brain_state]
)


# ============================================================================
# MULTI-AGENT ORCHESTRATION
# ============================================================================


# Root agent that orchestrates everything
root_agent = coordinator_agent


# ============================================================================
# SESSION & MEMORY CONFIGURATION
# ============================================================================

# Initialize session service
session_service = InMemorySessionService()

# Initialize Memory Bank for long-term pattern storage
# In production, this would persist to database
memory_bank_data = {
    "user_patterns": {
        "time_estimation_factor": 1.8,  # User typically underestimates by 1.8x
        "peak_hours": ["9-11am", "3-5pm"],
        "crash_times": ["2-3pm", "after 8pm"],
        "sensory_triggers": ["fluorescent lights", "loud spaces", "video calls > 4 hours"],
        "successful_strategies": {
            "task_initiation": ["5-minute timer", "body doubling", "novelty hook"],
            "decision_making": ["reduce to 2 options", "60-second deadline"],
            "time_management": ["visual countdown", "multiple warnings"]
        },
        "hyperfocus_activities": ["coding", "gaming", "research", "writing"]
    },
    "energy_patterns": {
        "monday": [7, 8, 9, 7, 5, 4, 3],  # Energy by hour
        "thursday": [5, 6, 7, 6, 4, 3, 2],  # Thursday crash pattern
    },
    "history": {
        "tasks_completed_this_week": 23,
        "tasks_abandoned_this_week": 4,
        "average_task_duration_minutes": 45,
        "longest_hyperfocus_session_hours": 6.5
    }
}


def run_task_workflow(task_description: str) -> dict:
    if not CURRENT_SESSION_ID:
        return {"kind": "task_workflow", "text": "", "tool_results": None}
    tf = taskflow_agent.run(user_message=task_description, session_id=CURRENT_SESSION_ID)
    tp = time_perception_agent.run(user_message=task_description, session_id=CURRENT_SESSION_ID)
    ds = decision_agent.run(user_message=task_description, session_id=CURRENT_SESSION_ID)
    return {
        "kind": "task_workflow",
        "text": "",
        "tool_results": [
            getattr(tf, "tool_results", None),
            getattr(tp, "tool_results", None),
            getattr(ds, "tool_results", None)
        ]
    }


def run_monitors(context: str) -> dict:
    if not CURRENT_SESSION_ID:
        return {"kind": "monitors", "text": "", "tool_results": None}
    tp = time_perception_agent.run(user_message=context, session_id=CURRENT_SESSION_ID)
    en = energy_agent.run(user_message=context, session_id=CURRENT_SESSION_ID)
    return {
        "kind": "monitors",
        "text": "",
        "tool_results": [
            getattr(tp, "tool_results", None),
            getattr(en, "tool_results", None)
        ]
    }


# Extend coordinator tools to include delegation wrappers
coordinator_agent.tools.extend([run_task_workflow, run_monitors])
