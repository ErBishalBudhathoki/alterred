from typing import Dict, List, Any
import datetime
import random

# ============================================================================
# CUSTOM TOOLS (Migrated from neuropilot_starter_code.py)
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
