"""
Energy & Sensory Agent
======================
Monitors user energy levels and sensory inputs to prevent burnout and overload.

Implementation Details:
- Analyzes text for keywords indicating sensory overload.
- Balances routine and novelty based on context.

Design Decisions:
- 'detect_sensory_overload' uses simple keyword matching for speed and privacy.
- 'routine_vs_novelty_balancer' suggests alternating blocks to maintain engagement without overwhelming.

Behavioral Specifications:
- Alerts the system if sensory overload is detected.
- Provides recommendations for structuring the day based on energy needs.
"""
import os
from google.adk.agents import LlmAgent
from agents.adk_model import get_adk_model
from agents.common import auto_compact_callback

def detect_sensory_overload(text: str) -> dict:
    """
    Analyzes text to detect signs of sensory overload.

    Implementation Details:
    - Checks for keywords like "overstimulated", "loud", "bright", etc.
    - Returns a boolean flag indicating potential overload.

    Args:
        text (str): The user's input text.

    Returns:
        dict: A dictionary containing the 'overload' boolean status.
    """
    t = text.lower()
    overload = any(k in t for k in ["overstimulated", "loud", "bright", "crowded"])
    return {"overload": overload}


def routine_vs_novelty_balancer(day_context: str) -> dict:
    """
    Suggests a balance between routine and novelty based on the day's context.

    Implementation Details:
    - Provides a general strategy of alternating routine blocks with novelty breaks.
    - Can be expanded to use more sophisticated analysis of the day's schedule.

    Args:
        day_context (str): Description of the day's context or schedule.

    Returns:
        dict: A dictionary containing the context and a balancing recommendation.
    """
    return {"context": day_context, "balance": "Alternate routine blocks with short novelty breaks."}


energy_sensory_agent = LlmAgent(
    model=get_adk_model(),
    name="energy_sensory_agent",
    description="Energy and sensory delegation agent",
    instruction="Detect sensory overload and balance routine vs novelty.",
    tools=[detect_sensory_overload, routine_vs_novelty_balancer],
    after_agent_callback=auto_compact_callback,
)