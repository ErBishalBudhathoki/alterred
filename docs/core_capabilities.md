Core Capabilities

- Terminal-first chat with a single Coordinator agent using gemini-2.5-flash .
- ADK integration ( LlmAgent + Runner ) to orchestrate tool calls and maintain agent workflows.
- Identity scoping via user_id and session_id so conversations and data remain user- and session-specific.
Calendar (MCP) Actions

- Lists today’s events from Google Calendar.
- Creates events from natural language (title, time, duration, note).
- Deletes events with robust intent parsing (“remove/cancel/take off/etc.”) using title/time matching.
- Reschedules events (“move/shift/change time”) by parsing new time and duration.
- Uses OAuth desktop credentials; tokens managed and refreshed automatically.
Sessions & Persistence

- Firestore-backed session storage (meta, state, events) under users/{userId}/apps/{appName}/sessions/{sessionId} .
- Resumes sessions after restart; retrieves previous state and event history.
- Session expiration via .env MEMORY_RETENTION_DAYS with cleanup support.
Conversation Memory

- Stores user/assistant messages with tool results in Firestore (fallback in-memory cache).
- Injects conversation history into prompts to maintain context across turns.
- Uses stored “today’s events” to resolve follow-ups (“that/first one/9:15 class”).
- Summarizes history when long to keep prompts compact.
CLI Features

- Startup connectivity logs: Firebase connection and Calendar MCP tool readiness.
- Commands:
  - /history shows latest 20 messages.
  - /session <id> switches active session and displays message count.
Developer & Ops

- Storage backends:
  - Firestore (primary) and optional file-based backend for testing.
- Unit tests:
  - File backend round-trip
  - Firestore create/retrieve/update/expire
- Documentation:
  - Session persistence architecture, layout, security, TTL, and ADK integration.
Security & Integrity

- Firestore document layout enforces user-scoped data.
- Avoids storing secrets in session data; relies on Firebase rules for access control.
- Structured error handling and defensive updates for storage operations.