## Root Cause Summary
- `/metrics/overview` returns 422 because FastAPI treats `request: Any` as a required query parameter; it must be typed `Request` and imported.
- ADK agent can’t use tools (calendar, memory) because `load_firestore_memory` and `preload_firestore_memory` are referenced before being defined, causing a `NameError` during module import.
- Calendar MCP calls can silently fail if `GOOGLE_OAUTH_CREDENTIALS` is missing or MCP SDK isn’t installed; readiness paths exist but are not used proactively.
- `metrics_service.record_task_completion` contains an invalid Firestore update (`get_client().transaction(lambda t: [])`), risking runtime errors.

## Changes by File

### api_server.py
- Import `Request` from `fastapi`.
- Change all endpoints currently declared as `request: Any` to `request: Request`:
  - `/sessions/yesterday`, `/sessions/{session_id}/events`, `/metrics/overview`, `/memory/patterns`, `/memory/compact`.
- Keep optional `user_id` query param; default with `_uid()` as currently implemented.
- Result: FastAPI no longer expects a missing `request` query param and 422 is resolved.

### auth.py
- Leave token parsing and fallback behavior unchanged.
- Minor: add safe handling notes for missing Firebase admin (already present).

### adk_app.py
- Move definitions of `load_firestore_memory` and `preload_firestore_memory` above `agent = LlmAgent(...)` so they exist when the agent’s `tools` list is constructed.
- Optional hardening: if MCP isn’t ready, keep agent running by still registering non-MCP tools; calendar tool invocations will return `{ok: False}` from `calendar_mcp` as today.

### services/calendar_mcp.py
- Keep existing MCP readiness checks.
- Small hardening:
  - In `_create_event_async`, `_list_events_async`, `_delete_event_async`, `_update_event_async`, return clearer errors if `npx` or package resolution fails (wrap exceptions already returned as `error: str(e)` is present).
  - Ensure `_parse_content_json` is used consistently and handle empty content.

### services/metrics_service.py
- Remove the invalid `doc.update({"tasks": get_client().transaction(lambda t: [])})` line.
- Keep appending metrics as events under `metrics/{date}/events` (already used by `compute_daily_overview`).
- Optional: if you want a daily summary array, implement with Firestore `ArrayUnion` later; for now, avoid broken writes.

### services/timer_store.py
- No functional changes. Current reads/writes look fine.

### services/memory_bank_service.py
- No functional changes. Existing updates and reads are fine.

### services/a2a_service.py
- No functional changes. Writes partner connection and updates under user’s `a2a` as expected.

### services/ambient_sound.py
- No changes.

### services/compaction_service.py
- No changes to logic; compact writes are correctly scoped. Keep as-is.

### services/slack_mcp.py
- No changes; MCP readiness helpers exist. Ensure envs (`SLACK_MCP_TOKEN_PATH`, etc.) are set in runtime.

## Verification
- Restart backend: `uvicorn api_server:app --host 0.0.0.0 --port 8000`.
- Confirm:
  - `GET /metrics/overview` returns 200 with a JSON body (even if empty metrics).
  - Importing `adk_app` no longer throws `NameError`; run a minimal call: `adk_respond(user_id, session_id, "Do I have any appointment today?")` and observe tool results.
  - Calendar MCP: run `check_mcp_ready()` (via `cli.py` or Python REPL) to verify tools list; if okay, try creating and listing an event.
- Flutter app: keep `API_BASE_URL` unchanged; retry chat and calendar actions; the 422 error banner should disappear.

## Risks & Assumptions
- `GOOGLE_OAUTH_CREDENTIALS` points to a valid local file; MCP package `@cocal/google-calendar-mcp` is installed and accessible by `npx`.
- Firebase Admin SDK is initialized via `FIREBASE_SERVICE_ACCOUNT_PATH`/`FIREBASE_PROJECT_ID` or default credentials; Firestore writes succeed.
- No additional endpoints are required; we focus on backend fixes impacting the existing mobile flows.

Do you want me to implement these changes now and run verification tests?