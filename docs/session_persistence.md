# Session Persistence Architecture

## Storage Layout
- Path: `users/{userId}/apps/{appName}/sessions/{sessionId}`
- Docs: `meta`, `state`
- Subcollection: `events`

## Meta
- `session_id`, `user_id`, `app_name`, `created_at`, `last_activity`, `expires_at`, `status`, `version`

## State
- Flat dict with string keys/values; nested values serialized

## Events
- `id`, `author`, `content[]`, `tool_calls[]`, `created_at`

## Expiration
- Controlled by `MEMORY_RETENTION_DAYS`; expired sessions marked in `meta.status` and eligible for cleanup

## Security
- Use Firebase Security Rules to restrict read/write by `user_id`
- Do not store secrets in state/events

## Integration
- ADK `LlmAgent` + `Runner` uses `FirestoreSessionService` which persists meta/state/events

## Retrieval
- On startup and resume, `get_session` assembles meta/state/events for the agent to continue