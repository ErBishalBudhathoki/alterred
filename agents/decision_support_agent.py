import os
from google.adk.agents import LlmAgent
from google.adk.models.google_llm import Gemini
from neuropilot_starter_code import reduce_options


def default_generator(context: str) -> dict:
    return {"context": context, "default": "Pick the simplest acceptable option."}


def motivation_matcher(state: str) -> dict:
    s = state.lower()
    if "urgent" in s:
        return {"motivation": "urgency"}
    if "new" in s or "novel" in s:
        return {"motivation": "novelty"}
    return {"motivation": "interest"}


def paralysis_protocol(options: list) -> dict:
    return {"reduce_to": 3, "deadline_seconds": 60, "auto_decide": True, "options": options[:3]}


decision_support_agent = LlmAgent(
    model=Gemini(model=os.getenv("DEFAULT_MODEL", "gemini-2.5-flash")),
    name="decision_support_agent",
    instruction="Reduce choices, set deadlines, generate defaults, and match motivation.",
    tools=[reduce_options, default_generator, motivation_matcher, paralysis_protocol],
)