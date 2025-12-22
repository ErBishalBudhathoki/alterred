# Multi-Agent Architecture

- Coordinator uses ADK and delegates to specialized agents.
- Agents:
  - TaskFlow: atomize, body doubling, dopamine reframe, scheduling.
  - Time Perception: estimate correction, countdown, transition helper, hyperfocus detection, calendar integration.
  - Energy/Sensory: energy matching, sensory overload detection, routine vs novelty balance.
  - Decision Support: reduce options, defaults, motivation matcher, paralysis protocol.
  - External Brain: capture notes, restore context, accountability connect.
  - **Notion Agent**: Dedicated agent for all Notion operations with multi-turn conversation support.
- Workflows:
  - Sequential: Task execution workflow.
  - Parallel: Continuous monitors.

## Technical Specs
- Model: `gemini-2.5-flash` from `.env`.
- ADK agents with tools exposed to Coordinator.
- Firestore persists sessions, events, and task logs.
- Notion service (`services/notion_service.py`) enables agents to create/search pages using user's stored token.
- **Conversation Context Injection**: The coordinator automatically injects recent conversation history (last 4 messages) into each agent request, ensuring continuity across turns and preventing the agent from "forgetting" what was discussed.

## Notion Agent

The Notion Agent (`agents/notion_agent.py`) is a specialized agent for handling all Notion-related operations. It maintains conversation context for multi-turn interactions.

**Key Features:**
- Multi-turn conversation support (e.g., asking for title, then receiving it)
- Context preservation across messages
- Dedicated workflows for creating pages, searching, and database operations

**Available Tools:**
- `tool_notion_create_page(title, content)` - Create new pages
- `tool_notion_search(query)` - Search workspace pages
- `tool_notion_append(page_id, content)` - Append to existing pages
- `tool_notion_list_databases()` - List available databases
- `tool_notion_add_to_database(database_id, title)` - Add items to databases

See [NOTION_INTEGRATION.md](NOTION_INTEGRATION.md) for detailed documentation.

## Configuration
- `.env` keys: `DEFAULT_MODEL`, `MEMORY_RETENTION_DAYS`.

## Testing
- Import agents and run sample tool calls; verify Coordinator delegates.