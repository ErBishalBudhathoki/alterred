"""
Time Perception Agent
=====================
Assists users with time management, estimation, and transitions.

Implementation Details:
- Uses `create_countdown` to interpret natural language time requests.
- Provides `transition_helper` to guide users through task switching.

Design Decisions:
- 'create_countdown' handles various time formats (seconds, minutes, hours) and absolute ISO times.
- Warnings are pre-calculated to provide multiple reminders as the deadline approaches.

Behavioral Specifications:
- Accurately parses time duration from user input.
- Suggests transition strategies to reduce friction when changing tasks.
"""
import os
import datetime
from google.adk.agents import LlmAgent
from google.adk.models.google_llm import Gemini
from services.tools import estimate_real_time, detect_hyperfocus


def create_countdown(natural_language_query: str) -> dict:
    """
    Parses a natural language query to create a countdown timer.

    Implementation Details:
    - Supports ISO format and regex-based duration parsing (seconds, minutes, hours).
    - Sets warning intervals at 15, 10, 5, and 2 minutes/seconds depending on context.

    Args:
        natural_language_query (str): The user's request for a timer (e.g., "10 minutes").

    Returns:
        dict: A dictionary containing success status, target time, and warning intervals, or an error.
    """
    q = (natural_language_query or "").strip()
    try:
        target_time = datetime.datetime.fromisoformat(q)
        return {"ok": True, "target": target_time.isoformat(), "warnings": [15, 10, 5, 2]}
    except Exception:
        import re
        lower = q.lower()
        m = re.search(r"(\d+)\s*(second|seconds|sec|s)\b", lower)
        if m:
            secs = int(m.group(1))
            target_time = datetime.datetime.now() + datetime.timedelta(seconds=secs)
            return {"ok": True, "target": target_time.isoformat(), "warnings": [15, 10, 5, 2]}
        m = re.search(r"(\d+)\s*(minute|minutes|min|m)\b", lower)
        if m:
            mins = int(m.group(1))
            target_time = datetime.datetime.now() + datetime.timedelta(minutes=mins)
            return {"ok": True, "target": target_time.isoformat(), "warnings": [15, 10, 5, 2]}
        m = re.search(r"(\d+)\s*(hour|hours|hr|h)\b", lower)
        if m:
            hrs = int(m.group(1))
            target_time = datetime.datetime.now() + datetime.timedelta(hours=hrs)
            return {"ok": True, "target": target_time.isoformat(), "warnings": [15, 10, 5, 2]}
        return {"ok": False, "error": "invalid_duration"}


def transition_helper(next_event: str) -> dict:
    """
    Provides strategies to help users transition to the next event.

    Implementation Details:
    - Suggests a wrap-up buffer time (15 minutes).
    - Can be enhanced with more specific strategies based on the event type.

    Args:
        next_event (str): The name or description of the next event.

    Returns:
        dict: A dictionary containing the next event and a recommended action.
    """
    return {"next": next_event, "action": "Start wrapping up 15 minutes before."}


time_perception_agent = LlmAgent(
    model=Gemini(model=os.getenv("DEFAULT_MODEL", "models/gemini-flash-latest")),
    name="time_perception_agent",
    instruction="You are a time perception agent. Your goal is to help users manage their time. When a user asks to set a timer or countdown, you MUST use the `create_countdown` tool. Do not ask for a specific time or date, the tool will handle it. You can also calibrate time estimates, protect from hyperfocus, and guide transitions.",
    tools=[estimate_real_time, create_countdown, detect_hyperfocus, transition_helper],
)