# External Brain & A2A

## Description
Captures voice notes into structured tasks, persists context snapshots, and connects with accountability partners (A2A).

## Technical Specs
- Agent: `agents/external_brain_agent.py`
- Tools: `capture_voice_note(transcript)`, `restore_context(task_id)`, `a2a_connect(partner_id)`
- Storage:
  - Tasks: `users/{user}/external_brain/{task_id}` with `title`, `status`, `transcript`, `created_at`
  - Snapshots: `users/{user}/external_brain/{task_id}/snapshots`
  - A2A: `users/{user}/a2a/{partner_id}` and `updates`

## Configuration
- Uses `DEFAULT_MODEL`
- No additional env keys; relies on existing Firestore client

## Testing Procedures
- CLI:
  - `/capture <text>` → creates external brain task
  - `/context <task_id>` → prints persisted task context
  - `/a2a connect <partner_id>` → stores connection
  - `/a2a update <partner_id> <message>` → stores update
- Agent: invoke `capture_voice_note` and verify CLI stores the task automatically

## Known Limitations
- Voice-to-text assumes text input; MCP STT integration is planned
- A2A networked messaging is stubbed; in-app persistence works for local testing