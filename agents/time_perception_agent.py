import os
from google.adk.agents import LlmAgent
from google.adk.models.google_llm import Gemini
from neuropilot_starter_code import estimate_real_time, detect_hyperfocus


def create_countdown(target_iso: str) -> dict:
    return {"target": target_iso, "warnings": [15, 10, 5, 2]}


def transition_helper(next_event: str) -> dict:
    return {"next": next_event, "action": "Start wrapping up 15 minutes before."}


time_perception_agent = LlmAgent(
    model=Gemini(model=os.getenv("DEFAULT_MODEL", "gemini-2.5-flash")),
    name="time_perception_agent",
    instruction="Calibrate estimates, provide countdowns, protect from hyperfocus, and guide transitions.",
    tools=[estimate_real_time, create_countdown, detect_hyperfocus, transition_helper],
)