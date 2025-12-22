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
from agents.adk_model import get_adk_model
from agents.tools import restore_context
from services.a2a_service import connect_partner
from agents.adk_tools import tool_a2a_post_update, tool_a2a_list_updates
from agents.common import auto_compact_callback


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
    return connect_partner(partner_id)


external_brain_agent = LlmAgent(
    model=get_adk_model(),
    name="external_brain_agent",
    description="External brain delegation agent",
    instruction="Capture notes and coordinate with partners.",
    tools=[capture_voice_note, a2a_connect, restore_context, tool_a2a_post_update, tool_a2a_list_updates],
    after_agent_callback=auto_compact_callback,
)
