"""
Decision Support Agent
======================
Helps users overcome analysis paralysis and decision fatigue.

Implementation Details:
- Uses a Large Language Model (Gemini) to generate choices and recommendations.
- Defines specific tools for reducing options and matching motivation.

Design Decisions:
- 'Paralysis Protocol' offers a structured way to force a decision when stuck.
- Motivation matching helps frame tasks in a way that appeals to the user's current state (urgency vs. novelty).

Behavioral Specifications:
- Analyzes user input to detect decision blocks.
- Suggests simplified options or defaults to reduce cognitive load.
"""
import os
from google.adk.agents import LlmAgent
from google.adk.models.google_llm import Gemini
from neuropilot_starter_code import reduce_options


def default_generator(context: str) -> dict:
    """
    Generates a default option for a given context.

    Args:
        context (str): The situation requiring a decision.

    Returns:
        dict: A dictionary containing the context and a recommended default action.
    """
    return {"context": context, "default": "Pick the simplest acceptable option."}


def motivation_matcher(state: str) -> dict:
    """
    Identifies the user's current motivational state.

    Args:
        state (str): The user's described state or feeling.

    Returns:
        dict: A dictionary classifying the motivation as 'urgency', 'novelty', or 'interest'.
    """
    s = state.lower()
    if "urgent" in s:
        return {"motivation": "urgency"}
    if "new" in s or "novel" in s:
        return {"motivation": "novelty"}
    return {"motivation": "interest"}


def paralysis_protocol(options: list) -> dict:
    """
    Initiates a protocol to break analysis paralysis.

    Args:
        options (list): A list of available choices.

    Returns:
        dict: Instructions to reduce options, set a deadline, and auto-decide if necessary.
    """
    return {"reduce_to": 3, "deadline_seconds": 60, "auto_decide": True, "options": options[:3]}


decision_support_agent = LlmAgent(
    model=Gemini(model=os.getenv("DEFAULT_MODEL", "gemini-flash-latest")),
    name="decision_support_agent",
    instruction="Reduce choices, set deadlines, generate defaults, and match motivation.",
    tools=[reduce_options, default_generator, motivation_matcher, paralysis_protocol],
)