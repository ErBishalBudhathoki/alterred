"""
External Brain Agent
====================
Acts as a second brain for the user, capturing notes and managing external connections.

Implementation Details:
- Integrates with external tools for note-taking and accountability partners.
- Uses `restore_context` to help users resume tasks after interruptions.

Design Decisions:
- 'Capture Voice Note' assumes a transcript is available, prioritizing voice-first interaction.
- 'A2A Connect' provides a hook for future agent-to-agent communication features.

Behavioral Specifications:
- Listens for commands to save information or retrieve context.
- Facilitates hand-offs to other agents or human accountability partners.
"""
import os
from google.adk.agents import LlmAgent
from google.adk.models.google_llm import Gemini
from neuropilot_starter_code import restore_context


def capture_voice_note(transcript: str) -> dict:
    """
    Captures a voice note and formats it as a task.

    Args:
        transcript (str): The transcribed text of the voice note.

    Returns:
        dict: A dictionary with the transcript and a generated task object.
    """
    return {"transcript": transcript, "task": {"title": transcript.split(".")[0], "status": "captured"}}


def a2a_connect(partner_id: str) -> dict:
    """
    Simulates a connection to an accountability partner agent.

    Args:
        partner_id (str): The identifier of the partner to connect to.

    Returns:
        dict: Connection status details.
    """
    return {"partner_id": partner_id, "status": "connected"}


external_brain_agent = LlmAgent(
    model=Gemini(model=os.getenv("DEFAULT_MODEL", "gemini-flash-latest")),
    name="external_brain_agent",
    instruction="Capture notes, restore context, and coordinate with accountability partners.",
    tools=[capture_voice_note, restore_context, a2a_connect],
)