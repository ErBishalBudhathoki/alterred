import os
from google.adk.agents import LlmAgent
from google.adk.models.google_llm import Gemini
from neuropilot_starter_code import match_task_to_energy


def detect_sensory_overload(text: str) -> dict:
    t = text.lower()
    overload = any(k in t for k in ["overstimulated", "loud", "bright", "crowded"])
    return {"overload": overload}


def routine_vs_novelty_balancer(day_context: str) -> dict:
    return {"context": day_context, "balance": "Alternate routine blocks with short novelty breaks."}


energy_sensory_agent = LlmAgent(
    model=Gemini(model=os.getenv("DEFAULT_MODEL", "gemini-flash-latest")),
    name="energy_sensory_agent",
    instruction="Track energy, detect sensory overload, balance routine and novelty, and recommend tasks.",
    tools=[match_task_to_energy, detect_sensory_overload, routine_vs_novelty_balancer],
)