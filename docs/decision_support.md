# Decision Support Feature Set

## Description
Reduces choice overload, sets decision deadlines, generates defaults, and matches motivation type.

## Technical Specs
- Agent: `agents/decision_support_agent.py`
- Tools:
  - `reduce_options(options, max_options)`
  - `default_generator(context)`
  - `motivation_matcher(state)`
  - `paralysis_protocol(options)`
- Storage: Firestore at `users/{user}/decision/{YYYY-MM-DD}/events` with kind/payload/timestamp

## Configuration
- Uses `DEFAULT_MODEL`
- No additional env keys required

## Testing Procedures
- Invoke reduce options via Coordinator and verify Firestore logs
- Trigger default generator and motivation matcher; verify logs
- Test paralysis protocol payload includes `deadline_seconds` and `auto_decide` and is logged

## Known Limitations
- Protocol returns configuration payload; UI timer and auto-commit flow will be integrated in a later step.