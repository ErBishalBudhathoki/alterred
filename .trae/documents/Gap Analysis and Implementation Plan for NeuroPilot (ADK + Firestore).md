## Gap Analysis
- **Multi-Agent Architecture (6 agents)**: Coordinator exists; Task atomizer and decision reduce wired. Missing fully separated ADK agents (TaskFlow, Time Perception, Energy/Sensory, Decision Support, External Brain) and orchestration.
- **TaskFlow**: Atomize tool present; missing Body Double mode, Dopamine optimizer, Just-in-Time prompts, scheduling with code execution.
- **Time Perception**: Basic estimate/reschedule exists; missing Reality Calibrator, visual countdown/timers, Transition helper, continuous monitoring.
- **Energy/Sensory**: Simple match_task_to_energy exists; missing sensory overload detection, pattern learning, routine vs novelty balance.
- **Decision Support**: Reduce options tool present; missing paralysis protocol timer, default generator, motivation matcher.
- **External Brain + A2A**: Calendar appointment guardian exists; missing universal capture (voice → tasks), context restoration persistence, A2A protocol integration.
- **Memory Bank**: Firestore session/event persistence implemented; missing long-term pattern store (time estimation errors, peak hours, triggers, strategies), compaction pipeline, semantic retrieval.
- **Observability**: Startup connectivity logs exist; missing tracing, metrics dashboard (task completion rate, time accuracy, paralysis resolution), performance monitoring.
- **Evaluation**: Partial tests added; missing comprehensive unit/integration tests and before/after metrics.
- **Context Compaction**: Lightweight summarization exists; missing configurable compaction (interval/overlap) aligned with ADK.
- **Advanced Tools**: MCP Slack/Jira integration, ambient sound API not implemented.
- **Deployment**: No Docker/Agent Engine/Cloud Run config in codebase.
- **Auth/UI**: Firebase Auth integration and web/mobile API endpoints missing.

## Implementation Plan
### 1) Multi-Agent Setup
- **Code Changes**: Create modules:
  - `agents/taskflow_agent.py`, `agents/time_perception_agent.py`, `agents/energy_sensory_agent.py`, `agents/decision_support_agent.py`, `agents/external_brain_agent.py` (ADK LlmAgents + tools)
  - `orchestration/workflows.py` for Sequential/Parallel/Loop compositions
- **Storage**: No schema changes for agents; reuse Firestore session storage.
- **Tests**: Unit tests per agent; integration tests for delegation.
- **Docs**: Add `docs/agents_overview.md`.

### 2) TaskFlow Features
- **Code**: Add tools:
  - `dopamine_reframe(task)`, `body_double(mode='start/keep-alive')`, `just_in_time_prompt(activity)`
  - Code execution scheduling function (priority by energy/deadline).
- **Storage**: Firestore: `users/{user}/taskflow/{date}/events` for body-double pings and reframes.
- **API**: Add FastAPI endpoints: `POST /task/atomize`, `POST /task/schedule`.
- **Tests**: Atomize scheduling correctness; JIT prompt triggers.
- **Docs**: TaskFlow section.

### 3) Time Perception
- **Code**: Tools:
  - `reality_calibrator(user_estimate)`, `create_countdown(target_time)`, `transition_helper(next_event)`; Loop agent for monitoring.
- **Storage**: Firestore: `users/{user}/timers/{id}` with start/end, status.
- **API**: `POST /time/countdown`, `POST /time/estimate`.
- **Tests**: Estimate correction vs memory factor; countdown tick.
- **Docs**: Time module.

### 4) Energy/Sensory
- **Code**: Tools:
  - `detect_sensory_overload(text)`, `routine_vs_novelty_balancer(day_context)`.
- **Storage**: Memory Bank: `users/{user}/memory_bank` doc fields:
  - time_estimation_error_pattern, peak_hours[], sensory_triggers[], successful_strategies{...}, hyperfocus_patterns[]
- **API**: `POST /energy/match`, `POST /sensory/detect`.
- **Tests**: Pattern learning updates; matching suggestions.
- **Docs**: Energy/Sensory guide.

### 5) Decision Support
- **Code**: Tools:
  - Paralysis protocol timer (integrated with ADK callbacks), `default_generator(context)`, `motivation_matcher(state)`.
- **Storage**: Firestore: `users/{user}/decision/{date}/events` for timers and outcomes.
- **API**: `POST /decision/reduce`, `POST /decision/commit`.
- **Tests**: Timer cancel/auto-decide; defaults and motivation selection.
- **Docs**: Decision support.

### 6) External Brain + A2A
- **Code**:
  - Voice → text MCP tool (or local STT) to capture notes and convert to structured tasks.
  - Context restoration persistent store: `users/{user}/external_brain/{task_id}` with snapshot and next steps.
  - A2A integration using `a2a-python`: endpoints for pairing and updates.
- **API**: `POST /capture/voice`, `GET /context/{task_id}`, `POST /a2a/connect`, `POST /a2a/update`.
- **Tests**: Capture parsing; context resume; A2A message flow (mock).
- **Docs**: External Brain + A2A.

### 7) Memory Bank & Compaction
- **Code**:
  - Add `memory_bank_service.py` to manage pattern updates and retrieval.
  - Implement compaction worker: summarize sessions every N turns (interval & overlap via `.env`).
- **Storage**: Expand `users/{user}/memory_bank` doc; `users/{user}/compactions/{date}`.
- **API**: `POST /memory/compact`, `GET /memory/patterns`.
- **Tests**: Compaction trigger, pattern accuracy updates.
- **Docs**: Memory bank spec; compaction design.

### 8) Observability & Evaluation
- **Code**:
  - Metrics collector: task completion rate, time estimation accuracy, paralysis resolution time, hyperfocus interruptions; logging/tracing through Python logging.
- **Storage**: `users/{user}/metrics/{date}`
- **API**: `GET /metrics/overview`.
- **Tests**: Metric calculations correctness.
- **Docs**: Observability dashboard instructions.

### 9) UI/API & Auth
- **Code**:
  - FastAPI server with endpoints above; Firebase Auth stub to accept `user_id` from JWT later.
- **Docs**: API usage, auth integration plan.

### 10) Advanced MCP Tools (Future hooks)
- Slack/Jira MCP integrations; Ambient sound API module.

## Verification
- Unit tests for all new modules.
- Integration tests: multi-agent orchestration and workflows; calendar/time/decision interactions.
- Manual scenarios matched to requirements (Task initiation, Hyperfocus protection, Decision paralysis, Time blindness).

## Documentation & Change Control
- Update `docs/session_persistence.md` and create `docs/agents_overview.md`, `docs/api.md`, `docs/observability.md`.
- Record any deviations (e.g., semantic memory as future Vertex AI Memory Bank) and rationale; update requirements via change log.

## Next Steps
- Implement modules and endpoints per plan; wire agents and workflows into ADK Runner while maintaining Firestore persistence; add tests and docs.