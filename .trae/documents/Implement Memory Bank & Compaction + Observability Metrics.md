## Goals
- Persist long-term patterns and compaction summaries in Firestore.
- Add automatic and manual compaction of session history.
- Implement observability metrics: task completion rate, time estimation accuracy, decision resolution time, hyperfocus interruptions.
- Update docs and tests; keep example files unchanged.

## Implementation
1) Memory Bank Service
- Create `services/memory_bank_service.py` with APIs:
  - `update_time_estimation_pattern(session_events)`, `update_peak_hours(energy_logs)`, `add_sensory_trigger(trigger)`, `add_successful_strategy(category,strategy)` (wrap existing functions and add aggregations).
  - `get_patterns(user_id)` to read `users/{user}/memory_bank`.
- Firestore schema: extend `users/{user}/memory_bank` doc with keys:
  - `time_estimation_error_pattern`, `peak_hours[]`, `sensory_triggers[]`, `successful_strategies{}`, `hyperfocus_patterns[]`.

2) Compaction Job
- Create `services/compaction_service.py`:
  - `compact_session(user_id, app_name, session_id, overlap=1)` → read recent events, summarize with Gemini, store in `users/{user}/compactions/{session_id}`.
  - `auto_compact_after_agent` callback (ADK) triggers compaction every N turns (read `.env` `COMPACTION_INTERVAL`, `COMPACTION_OVERLAP`).
- Store summaries: `{summary_text, events_compacted, timestamp}`.

3) Observability Metrics
- Create `services/metrics_service.py`:
  - `record_task_completion(task_id, estimated_minutes, actual_minutes)` → update accuracy.
  - `record_decision_resolution(duration_seconds)` → track paralysis resolution.
  - `record_hyperfocus_interrupt()` and `record_agent_latency(ms)`.
  - `compute_daily_overview(user_id,date)` returns metrics.
- Firestore: `users/{user}/metrics/{YYYY-MM-DD}`.

4) CLI & Docs
- CLI commands:
  - `/compact now <sessionId>` → manual compaction.
  - `/metrics overview` → print daily metrics.
- Docs:
  - `docs/memory_bank.md` with schema and APIs.
  - `docs/observability.md` with metric definitions and usage.

5) Tests
- Unit tests for compaction summary creation and metrics computations.
- Integration tests: automatic compaction callback triggers; metrics updated across flows.

## Validation
- Run compaction on a session and verify summary stored.
- Simulate task completion and decision timers; compute metrics overview.

## Notes
- No changes to `example/day_3b_agent_memory.py`.
- Uses existing Firestore and ADK setup; env keys: `COMPACTION_INTERVAL`, `COMPACTION_OVERLAP` (with safe defaults).