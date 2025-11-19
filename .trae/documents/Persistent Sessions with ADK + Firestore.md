## Overview
- Persist agent sessions (events, state, metadata) across restarts using Firestore
- Keep `example/day_3a_agent_sessions.py` unchanged; implement in production modules only
- Integrate with ADK (`LlmAgent` + `Runner`) and replace in‑memory sessions with Firestore‑backed service

## Storage Design
- **Path**: `users/{userId}/apps/{appName}/sessions/{sessionId}`
- **Docs**:
  - `meta`: { session_id, user_id, app_name, created_at, last_activity, expires_at, status, version }
  - `state`: flattened dict of session state (string keys/values; nested serialized JSON)
- **Subcollection**: `events`
  - Event doc: { id, author, content_parts[], tool_calls[], created_at }
- **Indexes**: `meta.last_activity` for listing/retrieval and expiration scans

## Modules To Add
- `sessions/session_storage.py` (interface):
  - `create_session(app_name, user_id, session_id, meta)`
  - `get_session(app_name, user_id, session_id)` → returns {meta, state, events}
  - `append_event(app_name, user_id, session_id, event)`
  - `update_state(app_name, user_id, session_id, state)`
  - `list_sessions(user_id, app_name, limit=20, order='desc')`
  - `expire_sessions(now)` → marks expired in `meta.status`
  - `delete_session(app_name, user_id, session_id)`
  - Helpers: `serialize_event(event)`, `deserialize_event(doc)`
- `sessions/firestore_session_storage.py` (Firestore impl):
  - Uses `google-cloud-firestore`; retries/backoff for transient errors
  - Defensive checks; timestamps as ISO8601 UTC
- `sessions/file_session_storage.py` (optional dev):
  - Files under `./sessions/{user}/{app}/{session}/` with `meta.json`, `state.json`, `events.jsonl`

## ADK Adapter
- `sessions/firestore_session_service.py`:
  - Implements minimal adapter compatible with ADK Runner expectations:
  - `create_session(app_name, user_id, session_id)` → writes `meta`
  - `get_session(...)` → returns assembled session (meta/state/events)
  - Utility hooks used by messaging loop to `append_event` and `update_state` on each turn
- Integration points:
  - In `adk_app.py` or main app bootstrapping, instantiate `FirestoreSessionService` and pass to `Runner`

## Session ID & Tracking
- `sessions/id.py`: `generate_session_id(prefix='sess_')` using UUIDv4 or ULID
- Track current session in CLI via `/session <id>` (already present) and surface counts

## Expiration & Cleanup
- Use `.env` `MEMORY_RETENTION_DAYS` to set `meta.expires_at`
- On startup, run `expire_sessions(now)` to mark sessions as expired (soft delete)
- Provide `cli` command `/cleanup expired` to purge expired sessions

## Error Handling & Security
- Wrap Firestore ops with structured exceptions; log codes and messages
- Validate field sizes/types; sanitize content
- Rely on Firestore encryption at rest; do not store secrets in session data
- Recommend Firebase Security Rules limiting read/write by `user_id`

## Serialization/Deserialization
- Events: parts → [{type:'text', value:...}] and tool_calls → normalized dicts
- State: flatten nested dicts into stringified JSON where needed
- Timestamps: ISO8601 UTC strings; serverTime if available

## Unit Tests (pytest)
- `tests/test_session_storage_firestone.py` (mock or emulator):
  - create & retrieve session
  - append events, update state; restart and re‑retrieve
  - expiration and cleanup behavior
  - error handling paths (simulate permission/connection errors)
- `tests/test_file_session_storage.py` for optional file backend

## Documentation
- `docs/session_persistence.md`:
  - Data model and Firestore layout
  - ADK integration
  - Expiration policy & cleanup
  - Security considerations & recommended rules
  - Example flows (create, resume after restart)

## Changes in Production Files
- `adk_app.py`: swap `InMemorySessionService` with `FirestoreSessionService`
- `cli.py`: expose `/session` and `/cleanup expired`; on startup display session count and last activity

## Validation Plan
- Start app → create session and converse → restart app → re‑open same session id → verify history and state
- Run tests locally; ensure persistence works with emulator/mocks

## Approval
After approval, I will implement the modules, integrate with ADK Runner, add tests and docs, and verify across restarts.