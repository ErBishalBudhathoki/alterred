# Memory Bank & Compaction

## Description
Stores long-term patterns (time estimation, peak hours, sensory triggers, strategies) and compaction summaries of sessions.

## Technical Specs
- Firestore doc: `users/{user}/memory_bank`
  - `time_estimation_error_pattern`, `peak_hours[]`, `sensory_triggers[]`, `successful_strategies{}`, `hyperfocus_patterns[]`
- Compactions: `users/{user}/compactions/{session_id}` with `summary_text`, `events_compacted`, `timestamp`
- Services:
  - `services/memory_bank_service.py` (pattern updates, retrieval)
  - `services/compaction_service.py` (session compaction, auto-compaction turns)

## Configuration
- `.env`:
  - `COMPACTION_INTERVAL` (default 5)
  - `COMPACTION_OVERLAP` (future use)

## Testing Procedures
- `/compact now <sessionId>` in CLI writes a compaction summary
- Verify `compactions/{session_id}` exists in Firestore
- Patterns can be updated via service calls; verify fields in `memory_bank`

## Known Limitations
- Compaction uses concise summarization; may lose detail; adjust interval as needed