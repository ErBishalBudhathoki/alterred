import os
from google.adk.agents import LlmAgent
from google.adk.models.google_llm import Gemini
from neuropilot_starter_code import atomize_task


import random

def dopamine_reframe(task: str) -> dict:
    """
    Reframes a boring task using multiple gamification and novelty strategies.
    Returns ALL strategies so the user can choose which one they prefer.
    Args:
        task: The task to be reframed.
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
    REQUIRED tool to start or stop body doubling mode in the UI.
    You MUST call this tool when the user asks to start body doubling.
    Args:
        mode: 'start' to begin session, 'stop' to end it.
    """
    if mode == "stop":
        return {"mode": "stop", "message": "Body doubling session ended. Great work!"}
    
    return {
        "mode": "start", 
        "presence": "I'm here with you. I'll stay quiet but present. I'll check in gently if you're silent for a while.",
        "check_in_interval_seconds": 15,  # 15 seconds for testing
        "ui_mode": "body_double"
    }


def body_double_checkin(duration_minutes: int) -> dict:
    """
    REQUIRED tool to generate a check-in message during body doubling.
    You MUST call this tool when the system prompts that the user has been silent.
    Returns varied, ADHD-friendly messages.
    Args:
        duration_minutes: How long the session has been running.
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
    Provides a gentle, non-judgmental prompt to help the user return to focus.
    Args:
        activity: The activity the user was supposed to be doing.
        duration_seconds: How long the user was away/distracted.
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
    scored = []
    for i, it in enumerate(items):
        w = deadline_weights[i] if deadline_weights and i < len(deadline_weights) else 1
        scored.append((it, w + energy))
    scored.sort(key=lambda x: x[1], reverse=True)
    return {"ordered": [s[0] for s in scored]}


taskflow_agent = LlmAgent(
    model=Gemini(model=os.getenv("DEFAULT_MODEL", "gemini-2.5-flash")),
    name="taskflow_agent",
    instruction="Break tasks into micro-steps, provide body doubling, reframe for dopamine, and schedule by energy/deadline.",
    tools=[atomize_task, dopamine_reframe, body_double, just_in_time_prompt, schedule_tasks, body_double_checkin],
)