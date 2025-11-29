"""
Taskflow Agent
==============
Manages task breakdown, body doubling, and gamification to help users maintain focus.

Implementation Details:
- Integrates `atomize_task` to break large tasks into smaller steps.
- Provides 'dopamine_reframe' to gamify boring tasks.
- Supports 'body_double' mode for companionship during tasks.

Design Decisions:
- Body doubling includes periodic check-ins (`body_double_checkin`) to prevent drift.
- `just_in_time_prompt` offers gentle nudges when inactivity is detected, avoiding shame-based prompts.

Behavioral Specifications:
- Breaks tasks down recursively if needed.
- Monitors user activity during body doubling and intervenes gently if silence persists.
"""
import os
from google.adk.agents import LlmAgent
from google.adk.models.google_llm import Gemini
from services.tools import atomize_task


import random

def dopamine_reframe(task: str) -> dict:
    """
    Reframes a boring task using multiple gamification and novelty strategies.

    Implementation Details:
    - Returns a dictionary of strategies, allowing the user to choose the most appealing one.
    - Strategies include 'Speed Run', 'Side Quest', 'Roleplay', etc.

    Args:
        task (str): The task to be reframed.

    Returns:
        dict: A dictionary containing the original task, available strategies, and a formatted string for display.
    """
    strategies = {
        "Speed Run": "Set a timer for 10 minutes and see how much you can get done. Beat your high score!",
        "Side Quest": "Pretend this task is a side mission in an RPG that unlocks a special reward.",
        "Roleplay": "Do this task as if you are a secret agent defusing a bomb (the deadline).",
        "Novelty": "Do the task in a different order or a different location than usual.",
        "DJ Mode": "Create a specific 3-song playlist. You must finish the task before the music ends.",
        "Body Double": "Pretend you are teaching someone else how to do this task as you do it."
    }
    
    # Format all strategies nicely
    formatted_strategies = "\n\n".join([
        f"**{name}:** {description}" 
        for name, description in strategies.items()
    ])
    
    return {
        "task": task, 
        "strategies": strategies,
        "reframe": f"Try these dopamine hacks - pick one that resonates:\n\n{formatted_strategies}",
        "ui_mode": "dopamine_card"
    }


def body_double(mode: str = "start") -> dict:
    """
    Starts or stops a body doubling session.

    Implementation Details:
    - Sets the UI mode to 'body_double' on start.
    - Returns a confirmation message on stop.

    Args:
        mode (str): 'start' to begin session, 'stop' to end it. Defaults to "start".

    Returns:
        dict: A dictionary containing the mode, a message, and the UI mode (if starting).
    """
    if mode == "stop":
        return {"mode": "stop", "message": "Body doubling session ended. Great work!"}
    
    return {
        "mode": "start", 
        "presence": "I'm here with you. I'll stay quiet but present. I'll check in gently if you're silent for a while.",
        "ui_mode": "body_double"
    }


def body_double_checkin(duration_minutes: int) -> dict:
    """
    Generates a check-in message during a body doubling session.

    Implementation Details:
    - Selects a random message from a curated list of ADHD-friendly prompts.
    - Categories include gentle presence, acknowledging struggle, celebrating progress, and practical prompts.

    Args:
        duration_minutes (int): How long the session has been running.

    Returns:
        dict: A dictionary containing the check-in status, duration, and the selected prompt.
    """
    # ADHD-friendly check-in messages - varied and supportive
    messages = [
        # Gentle presence
        f"Still here with you. You've been in flow for {duration_minutes} min. 🌊",
        f"Just a quiet check-in - {duration_minutes} minutes of focus time so far. You're doing great.",
        f"Keeping you company. {duration_minutes} min in. Take a breath if you need one. 🫁",
        
        # Acknowledging struggle
        f"{duration_minutes} min in. Stuck? Sometimes stepping away for 60 seconds helps reset your brain.",
        f"Hey, {duration_minutes} minutes down. If you're in a loop, try changing *one* small thing and see what happens.",
        f"Quick vibe check at {duration_minutes} min. Feeling resistance? That's your brain asking for novelty.",
        
        # Celebrating progress
        f"🎯 {duration_minutes} minutes! That's {duration_minutes} more than zero. Progress is progress.",
        f"Look at you - {duration_minutes} min of showing up. That's the hard part.",
        f"{duration_minutes} min of intentional time. Your dopamine system is learning to trust you. 🧠",
        
        # Gentle redirection
        f"{duration_minutes} min check. If you wandered off, no judgment - just redirect. The task is still here.",
        f"Quiet nudge at {duration_minutes} min: Are you doing The Thing or adjacent-to-The-Thing?",
        f"{duration_minutes} min mark. If you're doom-scrolling, remember: future-you always thanks present-you for trying.",
        
        # Practical prompts
        f"{duration_minutes} min in. Quick question: What's the *tiniest* next step?",
        f"Checking in at {duration_minutes} min. If you're stuck, try this: describe what you're doing out loud.",
        f"{duration_minutes} minutes. Reminder: You don't have to do it perfectly. You just have to do it.",
    ]
    
    import random
    prompt = random.choice(messages)
    
    return {
        "check_in": True,
        "duration_minutes": duration_minutes,
        "prompt": prompt
    }


def just_in_time_prompt(activity: str, duration_seconds: int = 0) -> dict:
    """
    Provides a gentle prompt to help the user return to focus after distraction.

    Implementation Details:
    - Selects a random prompt designed to reduce shame and encourage resumption.
    - Sets the UI mode to 'jit_rescue'.

    Args:
        activity (str): The activity the user was supposed to be doing.
        duration_seconds (int): How long the user was away/distracted. Defaults to 0.

    Returns:
        dict: A dictionary containing the activity, duration, prompt, and UI mode.
    """
    prompts = [
        "Welcome back! No guilt, just restart. What's the very next micro-step?",
        "You're back! That's a win. Let's do just 2 minutes of {activity}.",
        "Distractions happen. The important thing is you're here now. Ready to resume?",
        "Brain break over! Let's get that dopamine from finishing {activity} instead.",
        "Hey! missed you. Let's jump back into {activity} for a bit."
    ]
    import random
    prompt = random.choice(prompts).format(activity=activity if activity else "your task")
    
    return {
        "activity": activity, 
        "duration_seconds": duration_seconds,
        "prompt": prompt,
        "ui_mode": "jit_rescue"
    }


def schedule_tasks(items: list, energy: int, deadline_weights: list | None = None) -> dict:
    """
    Schedules tasks based on energy levels and deadlines.

    Implementation Details:
    - Calculates a score for each task based on deadline weight and current energy.
    - Sorts tasks by score in descending order.

    Args:
        items (list): A list of tasks to schedule.
        energy (int): The user's current energy level.
        deadline_weights (list | None): Optional weights for task deadlines.

    Returns:
        dict: A dictionary containing the ordered list of tasks.
    """
    scored = []
    for i, it in enumerate(items):
        w = deadline_weights[i] if deadline_weights and i < len(deadline_weights) else 1
        scored.append((it, w + energy))
    scored.sort(key=lambda x: x[1], reverse=True)
    return {"ordered": [s[0] for s in scored]}


taskflow_agent = LlmAgent(
    model=Gemini(model=os.getenv("DEFAULT_MODEL", "models/gemini-flash-latest")),
    name="taskflow_agent",
    instruction="Break tasks into micro-steps, provide body doubling, reframe for dopamine, and schedule by energy/deadline.",
    tools=[atomize_task, dopamine_reframe, body_double, just_in_time_prompt, schedule_tasks, body_double_checkin],
)