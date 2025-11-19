## Goals & Constraints
- Terminal-first app that works out of the box (no demo code)
- Single user-facing "Coordinator" agent; other agents talk to it, not directly to the user
- Multi-agent system powered by `gemini-2.5-flash`
- Persist short- and long-term memory in Firebase Firestore
- Future-ready for Firebase Auth when UI is added
- Robust error handling, logging, and clean architecture

## High-Level Architecture
- **Coordinator (User-Facing)**: Receives terminal input, analyzes state, routes to specialists, composes the final response
- **Specialists (Internal)**: TaskFlow, Time Perception, Energy/Sensory, Decision Support, External Brain
- **Workflows**: Sequential and Parallel compositions used internally; only Coordinator returns text to the user
- **Memory Layer**: Firestore-backed memory bank for user profile, brain states, task history, patterns
- **Sessions**: Use ADK `InMemorySessionService` for conversation state; persist key outcomes to Firestore
- **Config & Bootstrap**: `.env` driven configuration, Firebase Admin init, model selection, logging setup

## File/Module Plan
- `config.py`: Load and validate env (`GOOGLE_API_KEY`, `FIREBASE_PROJECT_ID`, `FIREBASE_SERVICE_ACCOUNT_PATH`, `DEFAULT_MODEL` fallback to `gemini-2.5-flash`)
- `services/firebase_client.py`: Initialize Firebase Admin and Firestore client; health-check on startup
- `services/memory_bank.py`: `FirestoreMemoryBank` with methods:
  - `store_brain_state(state, context)`
  - `store_task_completion(task, estimated_min, actual_min)` (auto-update estimation factor)
  - `get_time_estimation_factor()` and `get_profile()`
  - `store_strategy_success(kind, detail)`
- `sessions/firestore_session_service.py` (optional later): If needed, replace in-memory sessions with Firestore-backed sessions; for now use `InMemorySessionService`
- `agents/coordinator.py`: Coordinator agent definition and tools:
  - `analyze_brain_state(user_message)` → stores observation in Firestore
  - `route_to_specialist(brain_state, context)` → invokes appropriate specialist agent/tool
  - `compose_response(outputs)` → deterministic final message to user
- `agents/taskflow.py`, `agents/time_perception.py`, `agents/energy_sensory.py`, `agents/decision_support.py`, `agents/external_brain.py`: Define each specialist agent and its tools; return structured results (not user-facing text)
- `workflows/orchestration.py`: Internal `SequentialAgent` and `ParallelAgent` compositions used by Coordinator as tools
- `cli.py`: Terminal REPL that loads config, initializes Firebase + Firestore, constructs agents, starts a session, and loops on user input

## Data Model (Firestore)
- Collection `users/{userId}` → profile doc
  - `time_estimation_factor:number` (default 1.8)
  - `peak_hours:list`, `sensory_triggers:list`, `hyperfocus_activities:list`, `successful_strategies:map`
- Collection `users/{userId}/brain_states` → events
  - `{ state, context, timestamp }`
- Collection `users/{userId}/task_history` → events
  - `{ task, estimated_minutes, actual_minutes, accuracy, completed_at }`
- Collection `users/{userId}/metrics` (optional) → aggregates

## Agent Behaviors (Concise)
- **Coordinator**: Uses `analyze_brain_state` → decides specialist → aggregates structured outputs → crafts empathetic, actionable final response; persists key signals
- **TaskFlow**: `atomize_task()`, dopamine reframing, body-doubling suggestions → returns micro-steps + rationale
- **Time Perception**: `estimate_real_time()` using Firestore factor; `detect_hyperfocus()` → returns timers/warnings and buffers
- **Energy/Sensory**: `match_task_to_energy()` + overload detection → returns recommended task type and rest guidance
- **Decision Support**: `reduce_options()` + decision deadlines (Coordinator enforces) → returns reduced options + default
- **External Brain**: `restore_context()` for interrupted work; capture hooks for future voice → returns resume package

## Orchestration Rules
- Only Coordinator emits user-facing text
- Specialists return structured payloads; Coordinator composes
- Coordinator decides when to call workflows:
  - Example: Task initiation → `Sequential(taskflow → time_perception → decision_support)`
  - Continuous monitors via `Parallel(time_perception, energy_sensory)` can be invoked as needed (not streaming to user)

## Configuration & Model
- Use `DEFAULT_MODEL` from env, defaulting to `gemini-2.5-flash`
- All ADK agents constructed with the same model
- Respect existing `.env` without printing/seeding secrets; no changes to `.env` keys in code

## Error Handling & Logging
- Centralized `logging` config (JSON or plain) with levels via `DEBUG` env
- Defensive try/except around Firebase init and agent calls; user-friendly messages in Coordinator
- Firestore writes guarded; exponential backoff on transient failures

## Verification Plan (Terminal)
- Start CLI, create `session_id` from machine/user
- Run scenarios:
  - "I feel overwhelmed" → Coordinator routes to TaskFlow + Time Perception; stores brain state
  - "I think this task is 30 minutes" → realistic time returned using Firestore factor
  - "I've been coding 5 hours" → hyperfocus detection → break guidance
  - "Too many dinner options" → Decision Support reduction + default
- Confirm Firestore documents created and updated

## Migration of Existing Code
- Reuse `neuropilot_starter_code.py` agent definitions (e.g., Coordinator at `/Users/pratikshatiwari/Documents/trae_projects/altered/neuropilot_starter_code.py:233`) and tools (`analyze_brain_state` at `:33`) as starting points
- Update model to `gemini-2.5-flash`
- Remove demo `__main__` test block (`:459-498`) and move into `cli.py`
- Wire Firestore memory calls in tool functions

## Run Instructions (after implementation)
- `python cli.py` → interactive REPL
- Type messages; output comes from Coordinator; Firestore updates occur in background

## Future Hooks
- Firebase Auth integration when UI is added (Coordinator reads `userId` from Auth)
- MCP Calendar and workplace tools integration via ADK MCP
- A2A protocol for accountability partners

## Clarifications Requested
- Confirm preferred model string: `gemini-2.5-flash` vs `gemini-2.5-flash-001`
- Confirm using `FIREBASE_SERVICE_ACCOUNT_PATH` from `.env` for Admin SDK init
- Approve Firestore collection names above or provide alternatives
- Any specific CLI commands (e.g., `/quit`, `/status`) you want included