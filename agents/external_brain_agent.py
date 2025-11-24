import os
from google.adk.agents import LlmAgent
from google.adk.models.google_llm import Gemini
from neuropilot_starter_code import restore_context


def capture_voice_note(transcript: str) -> dict:
    return {"transcript": transcript, "task": {"title": transcript.split(".")[0], "status": "captured"}}


def a2a_connect(partner_id: str) -> dict:
    return {"partner_id": partner_id, "status": "connected"}


external_brain_agent = LlmAgent(
    model=Gemini(model=os.getenv("DEFAULT_MODEL", "gemini-flash-latest")),
    name="external_brain_agent",
    instruction="Capture notes, restore context, and coordinate with accountability partners.",
    tools=[capture_voice_note, restore_context, a2a_connect],
)