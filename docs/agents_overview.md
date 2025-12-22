# Multi-Agent Architecture

- Coordinator uses ADK and delegates to specialized agents.
- Agents:
  - TaskFlow: atomize, body doubling, dopamine reframe, scheduling.
  - Time Perception: estimate correction, countdown, transition helper, hyperfocus detection, calendar integration.
  - Energy/Sensory: energy matching, sensory overload detection, routine vs novelty balance.
  - Decision Support: reduce options, defaults, motivation matcher, paralysis protocol.
  - External Brain: capture notes, restore context, accountability connect.
- Workflows:
  - Sequential: Task execution workflow.
  - Parallel: Continuous monitors.

## Technical Specs
- Model: `gemini-2.5-flash` from `.env`.
- ADK agents with tools exposed to Coordinator.
- Firestore persists sessions, events, and task logs.

## Configuration
- `.env` keys: `DEFAULT_MODEL`, `MEMORY_RETENTION_DAYS`.

## Testing
- Import agents and run sample tool calls; verify Coordinator delegates.