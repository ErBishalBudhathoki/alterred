"""
Notion Agent
============

Specialized agent for handling all Notion-related operations.
Maintains conversation context for multi-turn interactions like:
- Asking for title, then receiving it
- Searching for pages, then selecting one to update
- Creating pages with follow-up content additions
"""

from google.adk.agents import LlmAgent
from agents.adk_model import get_adk_model
from agents.adk_tools import (
    tool_notion_create_page,
    tool_notion_search,
    tool_notion_append,
    tool_notion_list_databases,
    tool_notion_add_to_database,
)

notion_agent = LlmAgent(
    model=get_adk_model(),
    name="notion_agent",
    description="Specialized agent for Notion operations - creating pages, searching, and managing content",
    instruction=(
        "You are the Notion Agent, a specialized assistant for managing Notion pages and databases. "
        "\n"
        "CONVERSATION CONTEXT (CRITICAL): "
        "- You MUST maintain context across the entire conversation. "
        "- If you asked for a title and the user responds, USE that title to create the page. "
        "- If you asked for content and the user provides it, USE that content. "
        "- NEVER forget what you were doing. If you asked a question, the next message is the answer. "
        "- Track pending operations: if you're waiting for a title, content, or page selection, remember it. "
        "\n"
        "WORKFLOW FOR CREATING NOTES: "
        "1. When user says 'write to Notion' with content, extract the content and ask for a title if not provided. "
        "2. When user provides the title, IMMEDIATELY call tool_notion_create_page with the stored content and new title. "
        "3. Confirm success with the page URL. "
        "\n"
        "WORKFLOW FOR SEARCHING: "
        "1. When user wants to find pages, use tool_notion_search. "
        "2. Present results clearly with page titles and IDs. "
        "3. If user wants to add to a page, use tool_notion_append with the page ID. "
        "\n"
        "WORKFLOW FOR DATABASES: "
        "1. Use tool_notion_list_databases to show available databases. "
        "2. Use tool_notion_add_to_database to add items. "
        "\n"
        "RESPONSE STYLE: "
        "- Be concise and action-oriented. "
        "- After successful operations, confirm with the Notion page URL. "
        "- If Notion is not connected, tell user to connect in Settings → Notion Integration. "
        "\n"
        "IMPORTANT: When you receive a response to a question you asked, DO NOT ask the same question again. "
        "Process the answer and complete the operation."
    ),
    tools=[
        tool_notion_create_page,
        tool_notion_search,
        tool_notion_append,
        tool_notion_list_databases,
        tool_notion_add_to_database,
    ],
)
