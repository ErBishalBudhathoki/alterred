## Process & Versioning
- Execute features in the order below; move to next only after tests + docs pass.
- Use a dedicated branch per feature; open PR with code + docs; merge after review.
- Keep docs synchronized: every PR must include doc updates and test results.

## 1) Multi‑Agent Architecture
- Implement ADK agents: TaskFlow, Time Perception, Energy/Sensory, Decision Support, External Brain.
- Create `orchestration/workflows.py` (Sequential/Parallel/Loop) and wire Coordinator delegation.
- Docs update: Feature overview, agent roles, technical specs (models, tools), configuration, tests executed, limitations.

## 2) TaskFlow Feature Set
- Tools: `dopamine_reframe`, `body_double` (presence ticks), `just_in_time_prompt`; scheduler (code execution) based on energy/deadline.
- Storage: Firestore `users/{user}/taskflow/{date}/events` for presence/reframe logs.
- Docs update: How to use, env vars, test procedures (atomize correctness, presence cadence), edge cases (long tasks).

## 3) Time Perception
- Tools: `reality_calibrator`, `create_countdown`, `transition_helper`; Loop agent monitoring time.
- Storage: Firestore `users/{user}/timers/{id}` with status and ticks.
- Docs update: API for countdowns, specs, tests (estimation accuracy, countdown ticks), edge cases (DST/zone drift).

## 4) Energy & Sensory Management
- Tools: `detect_sensory_overload` (text patterns), `routine_vs_novelty_balancer`; pattern learning updates.
- Storage: `users/{user}/memory_bank` patterns (peak_hours, triggers, strategies, hyperfocus).
- Docs update: Pattern schema, learning flow, tests, limitations (signal noise).

## 5) Decision Support
- Tools: paralysis protocol timer (cancel/auto‑decide), `default_generator`, `motivation_matcher`.
- Storage: Firestore `users/{user}/decision/{date}/events`.
- Docs update: Timer UX, defaults, tests (cancel vs auto decide), edge cases (ambiguous options).

## 6) External Brain + A2A
- Voice → text capture tool (MCP or local STT) to tasks; context restoration persistent snapshots.
- A2A integration using `a2a-python` (pairing, progress updates).
- Docs update: endpoints, configuration (credentials), tests (mock flows), limitations (privacy, consent).

## 7) Memory Bank & Compaction
- `memory_bank_service.py` for pattern updates + retrieval.
- Compaction job (interval + overlap via `.env`) using Gemini summarization; store in `compactions`.
- Docs update: compaction policy, configuration, tests (summary integrity), limitations (info loss).

## 8) Observability & Evaluation
- Metrics collector for: task completion rate, time estimation accuracy, decision resolution time, hyperfocus interruptions.
- Logging/tracing; Firestore metrics at `users/{user}/metrics/{date}`; simple dashboard JSON.
- Docs update: metrics definitions, how to read, tests, known constraints.

## 9) API & Auth
- FastAPI endpoints: task, time, energy, decision, external brain, sessions.
- Firebase Auth stub; map JWT → `user_id` for storage scoping.
- Docs update: endpoint specs, auth, example requests, tests (integration), edge cases.

## 10) Advanced MCP Tools (Later Milestone)
- Slack/Jira MCP; Ambient sound API for focus.
- Docs update: configs, scopes, tests.

## 11) Deployment
- Dockerfile; Cloud Run; Agent Engine deployment scripts.
- Docs update: deployment steps, environment, tests (health checks), limitations.

## Documentation Content Per Feature
- Description, Technical specs & requirements, Configuration & dependencies, Testing steps & results, Known limitations.

## Verification
- Unit tests per module; integration tests across agents/tools; manual scenario runs matched to requirements (Task initiation, Hyperfocus protection, Decision paralysis, Time blindness).

## Change Control
- Record deviations in `docs/change_log.md` with justification; update requirements when needed after review.