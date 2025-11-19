# TaskFlow Feature Set

## Description
Breaks tasks into micro-steps, provides body doubling presence, reframes tasks for dopamine, just-in-time prompts, and schedules tasks by energy/deadline.

## Technical Specs
- Agent: `agents/taskflow_agent.py` (ADK LlmAgent)
- Tools:
  - `atomize_task(description)`
  - `dopamine_reframe(task)`
  - `body_double(mode)`
  - `just_in_time_prompt(activity)`
  - `schedule_tasks(items, energy, deadline_weights)`
- Storage: Firestore logs at `users/{user}/taskflow/{YYYY-MM-DD}/events`

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