# Time Perception Feature Set

## Description
Compensates time blindness via realistic estimation, countdown warnings, transition helpers, and hyperfocus protection.

## Technical Specs
- Agent: `agents/time_perception_agent.py` (ADK LlmAgent)
- Tools:
  - `estimate_real_time(task, user_estimate_minutes, historical_accuracy)`
  - `create_countdown(target_iso)` → warnings: [15,10,5,2]
  - `detect_hyperfocus(work_duration_minutes, last_break_minutes_ago)`
  - `transition_helper(next_event)`
- Storage: Firestore timers under `users/{user}/timers/{timer_id}` with `target`, `warnings`, `status`, and ticks

## Configuration
- Uses `DEFAULT_MODEL`
- No additional configuration required; user identity taken from environment for storage scoping

## Testing Procedures
- Call `create_countdown` via Coordinator; verify CLI prints timer ID and target
- Inspect Firestore `users/{user}/timers` for scheduled timer docs
- Verify `estimate_real_time` returns corrected estimate based on factor
- Validate `detect_hyperfocus` returns appropriate intervention level

## Results
- Countdown creation produces Firestore records with target and warnings
- Estimation correction and hyperfocus detection return structured payloads

## Known Limitations
- Countdown ticking and transitions are not live timers in CLI; implementation provides stored configuration and stubs to be integrated with a scheduler or UI loop.