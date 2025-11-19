## Key Patterns to Adapt (from day_3b)
- MemoryService plus SessionService provided to ADK Runner
- Explicit ingestion: add_session_to_memory(session)
- Retrieval tools: load_memory (reactive) and preload_memory (proactive)
- Automatic persistence using after_agent_callback

## Our Architecture Adaptation
- Use ADK for orchestration (existing LlmAgent + Runner)
- Use Firestore as long‑term memory store by querying persisted sessions/events (we already persist meta/state/events)
- Expose memory‑like retrieval tools that operate on Firestore history instead of ADK InMemoryMemoryService

## Implementation Plan
1. FirestoreMemoryRetrievalService
- API: search_memories(user_id, app_name, query, date_range?) → returns relevant past events (author/text/tool results) with session_id
- API: add_session_to_memory(session) → no‑op or consolidates key facts from session into a new collection (optional later)
- Internals: query `users/{userId}/apps/{appName}/sessions/*` by `meta.last_activity`; filter events by timeframe (e.g., yesterday), apply keyword/heuristic matching; return normalized snippets

2. ADK Memory Tools (wrappers)
- load_firestore_memory(query: str, timeframe?: str) → reactive retrieval from Firestore; returns snippets and references
- preload_firestore_memory(timeframe?: str) → proactive retrieval before each turn (small summary and pointers)
- Provide these tools to the Coordinator agent; keep calendar/task tools intact

3. Automatic Ingestion Callback
- after_agent_callback: compact the latest turn and append a “memory snippet” doc (optional) or mark session for retrieval; update session’s last_activity
- Keep token costs low: store compact snippets (author + first N chars + tool summary)

4. Yesterday’s History & Tasks (from the requirements doc)
- Implement service methods:
  - get_sessions_by_date(user_id, app_name, start_iso, end_iso)
  - get_events_for_session(app_name, user_id, session_id, start_iso, end_iso)
  - task logs: store_task_event(task_id, title, status, session_id); get_tasks_by_date(date)
- Integrate with ADK tools: when task atomizer runs, log “created”; on confirmations (done/finished), log “completed”

5. CLI Commands
- /yesterday conversations → list sessions active yesterday; summarize + print snippets
- /yesterday tasks → show created/completed tasks
- /resume <sessionId> → switch active session and show last N events

6. Security & Integrity
- Keep retrieval read‑only; sanitize returned text; rely on Firestore rules scoped by user_id
- Avoid storing secrets in memory snippets

7. Tests
- Unit tests for date‑range queries, snippet assembly, load/preload tools behavior, resume flow correctness, and task logs

8. Documentation
- Update session_persistence.md section: Memory retrieval from Firestore
- Add docs for new tools and CLI usage; note differences from ADK InMemoryMemoryService

## Integration Notes
- We will not modify `example/day_3b_agent_memory.py`; it remains as reference
- The Coordinator agent will get two new tools (load_firestore_memory, preload_firestore_memory) and an after_agent_callback for auto‑ingest
- All changes align with current ADK + Firestore setup and coding standards

## Validation
- Create yesterday’s data via a quick session; restart; run /yesterday conversations and /resume; verify context continuity
- Confirm task logs reflect created/completed and link back to sessions