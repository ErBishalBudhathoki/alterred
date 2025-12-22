# TaskFlow Feature Set

## Description
Breaks tasks into micro-steps, provides body doubling presence, reframes tasks for dopamine, just-in-time prompts, schedules tasks by energy/deadline, and provides intelligent task prioritization to combat decision paralysis.

## Technical Specs
- Agent: `agents/taskflow_agent.py` (ADK LlmAgent)
- Tools:
  - `atomize_task(description)`
  - `dopamine_reframe(task)`
  - `body_double(mode)`
  - `just_in_time_prompt(activity)`
  - `schedule_tasks(items, energy, deadline_weights)`
- Storage: Firestore logs at `users/{user}/taskflow/{YYYY-MM-DD}/events`

## Task Prioritization Service
- Service: `services/task_prioritization_service.py`
- Purpose: Helps ADHD users overcome decision paralysis by curating exactly 3 prioritized tasks
- Features:
  - Filters out completed, cancelled, or blocked tasks
  - Scores tasks based on priority, effort-energy match, and due date urgency
  - Integrates with Google Calendar for conflict detection (graceful fallback on failure)
  - LLM-powered reasoning explains why tasks were chosen
  - Dual-layer caching for offline resilience:
    - Memory cache (5-minute TTL) for fast repeated access
    - Persistent file-based cache (24-hour TTL) for offline fallback
    - Cache invalidation based on task state changes (hash-based consistency check)
- Chat Integration:
  - Keyword detection in `adk_app.py` intercepts task prioritization requests
  - Trigger phrases: "prioritize", "choose a task", "pick a task", "what should i do", "too many tasks", "help me choose", "which task", "overwhelmed with tasks"
  - Returns `ui_mode: "task_prioritization"` for frontend widget rendering
  - Falls through to orchestrator if prioritization fails
  - Ad-hoc task prioritization: Users can provide tasks directly in chat message
    - Example: "help me prioritize: email boss, clean room, pay bills"
    - Patterns detected: "tasks: X, Y, Z", "I have: X, Y, Z", or comma-separated action items
    - Uses `reduce_options` from TaskFlow agent to select top 3 tasks
    - No Firestore storage required - instant prioritization of provided items
- API Endpoints:
  - `GET /tasks/prioritized?energy=5&limit=3` → returns prioritized tasks with scores and reasoning
  - `POST /tasks/select` { task_id, selection_method } → records selection and starts focus session
- Data Models:
  - `PrioritizedTask`: id, title, description, due_date, priority, status, effort, priority_score, priority_reasoning, is_recommended, estimated_duration_minutes
  - `PrioritizedTasksResponse`: tasks[], reasoning, original_task_count, timestamp

## Configuration
- Uses `DEFAULT_MODEL` from `.env`
- No additional env keys required

## Testing Procedures
- Call tools via Coordinator; verify tool results:
  - Atomize returns micro-steps
  - Body double returns presence payload
  - Reframe returns reframe text
  - JIT prompt returns prompt text
  - Schedule returns ordered list
- Check Firestore logs created under taskflow/events

## Known Limitations
- Presence cadence is single-shot payload; multi-tick cadence will be implemented in Time Perception loop.
- Scheduler scoring is heuristic; will be refined with learned patterns.

- Voice capture assumes text input; STT MCP integration is planned
- A2A networking is stubbed; persistence verifies local flows
- Compaction uses basic summarization; some detail may be lost
- Metrics aggregation is basic averages; future work can provide richer dashboards and time windows
- Firebase Admin service account file path must be present and accessible in the container; mount via volume or bake into image securely (prefer volume)
- Cloud Run deployment assumes proper project setup and permissions
- Depends on MCP server implementation and tool names; adjust MCP_SLACK_ARGS if needed
- Credentials and OAuth setup are external to this codebase

Next Features

- UI/Auth full integration with Firebase Auth for web/mobile clients (JWT validation and user routing).
- Live timers and decision protocol UI (countdowns, cancel/auto-decide flows).
- Rich observability dashboard (time windows, trend graphs) and export endpoints.
- Agent Engine/Cloud Run deployment polish and environment hardening.
- Additional MCP tools (e.g., Jira workflows, Slack thread replies, calendar streaming updates) as required.