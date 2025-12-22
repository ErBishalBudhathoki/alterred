# Calendar MCP API Integration Guide (v1)

This guide documents the Altered backend endpoints designed exclusively for integration with the Calendar MCP tool. It covers authentication, rate limiting, usage examples, logging/monitoring, versioning, and performance/security expectations.

## Overview
- Purpose: Provide a secured, versioned HTTP surface that the Calendar MCP tool can call to manage calendar features (multi-account, batch ops, recurrence, availability, search, analytics, image extraction).
- Scope: Only the `/mcp/calendar/v1/...` endpoints. All non-MCP endpoints remain unchanged and publicly accessible per existing rules.

## Access Control
- Required header: `X-Calendar-MCP-Token: <secret>`
- Config: Set `CALENDAR_MCP_TOKEN` in environment.
- Enforcement: Guard dependency `_mcp_calendar_guard` verifies header and applies IP-based rate limiting.
  - Reference: `api_server.py:160` (guard) applied to all v1 routes.
- Behavior:
  - Missing/invalid header → `401 Unauthorized`
  - Rate limit exceeded → `429 Too Many Requests`

## Rate Limiting
- Defaults: `100` requests per IP per `900` seconds (15 minutes).
- Configurable via env:
  - `MCP_RATE_LIMIT_COUNT`
  - `MCP_RATE_LIMIT_WINDOW_SECONDS`
- Reference: `api_server.py:160`

## Logging & Monitoring
- Every MCP call records an access event:
  - Fields: `endpoint`, `status`, `latency_ms`, `timestamp`, optional `error`
  - Storage: Firestore under `users/{uid}/metrics/{date}/events`
  - Reference: `services/metrics_service.py:161` (record_api_access)

## Versioning
- All MCP endpoints are namespaced under `/mcp/calendar/v1/...`.
- v1 is backward-compatible with existing non-MCP endpoints.
- New versions will be added as `/mcp/calendar/v2/...` without breaking v1 clients.

## Environment Variables
- `CALENDAR_MCP_TOKEN`: required secret for MCP auth
- `MCP_RATE_LIMIT_COUNT`: max requests per window (default 100)
- `MCP_RATE_LIMIT_WINDOW_SECONDS`: window in seconds (default 900)
- `GOOGLE_API_KEY`: for image-based extraction via Gemini
- OAuth-related envs used internally by services:
  - `GOOGLE_OAUTH_CLIENT_ID`, `GOOGLE_OAUTH_CLIENT_SECRET`
  - `GOOGLE_OAUTH_CREDENTIALS` (optional authorized_user JSON)

## Calendar Services (Server-Side)
- Unified MCP call helper with backoff: `services/calendar_mcp.py:865` (`_call_mcp`)
- Multi-account credential handling: `services/calendar_mcp.py:68` (`_get_user_credentials_file`)
- Account utilities: `account_status` `services/calendar_mcp.py:492`, `account_clear` `services/calendar_mcp.py:509`, `account_migrate` `services/calendar_mcp.py:519`
- Batch list/create: `list_events_from_calendars` `services/calendar_mcp.py:773`, `batch_create_events` `services/calendar_mcp.py:796`
- Recurrence create/update: `create_recurring_event` `services/calendar_mcp.py:625`, `update_recurring_event` `services/calendar_mcp.py:642`
- Availability: `find_availability` `services/calendar_mcp.py:816`
- Advanced search: `search_events` `services/calendar_mcp.py:649`
- Analysis: `analyze_calendar` `services/calendar_mcp.py:684`
- Image extraction: `extract_event_from_image` `services/calendar_mcp.py:911`

## Endpoints (v1)

### Status
- `GET /mcp/calendar/v1/status`
- Auth: `X-Calendar-MCP-Token`
- Params: `user_id` (optional)
- Response: token presence for `normal` and `test`, and MCP readiness
- Reference: `api_server.py:564`
- Example:
```
curl -H "X-Calendar-MCP-Token: $CALENDAR_MCP_TOKEN" \
     "http://localhost:8000/mcp/calendar/v1/status?user_id=<UID>"
```

### Clear Tokens
- `POST /mcp/calendar/v1/clear`
- Auth: `X-Calendar-MCP-Token`
- Body: `{ "account": "normal" | "test" }`
- Response: `{ ok: true }` on success
- Reference: `api_server.py:593`
- Example:
```
curl -X POST -H "X-Calendar-MCP-Token: $CALENDAR_MCP_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"account":"test"}' \
     http://localhost:8000/mcp/calendar/v1/clear
```

### Migrate Authorized User JSON
- `POST /mcp/calendar/v1/migrate`
- Auth: `X-Calendar-MCP-Token`
- Response: `{ ok: true, migrated: <0|1> }`
- Reference: `api_server.py:624`
- Example:
```
curl -X POST -H "X-Calendar-MCP-Token: $CALENDAR_MCP_TOKEN" \
     http://localhost:8000/mcp/calendar/v1/migrate
```

### List Across Calendars
- `POST /mcp/calendar/v1/list`
- Auth: `X-Calendar-MCP-Token`
- Body: `{ "calendarIds": [...], "timeMin": "ISO", "timeMax": "ISO", "account": "normal|test" }`
- Response: `{ ok: true, result: { events: [...] } }`
- Reference: `api_server.py:649`
- Example:
```
curl -X POST -H "X-Calendar-MCP-Token: $CALENDAR_MCP_TOKEN" -H "Content-Type: application/json" \
  -d '{"calendarIds":["work","personal"],"timeMin":"2025-12-01T00:00:00+05:30","timeMax":"2025-12-08T00:00:00+05:30"}' \
  http://localhost:8000/mcp/calendar/v1/list
```

### Batch Create
- `POST /mcp/calendar/v1/create/batch`
- Auth: `X-Calendar-MCP-Token`
- Body: `{ "events": [ {"summary":"...","start":"...","end":"...", ...}, ... ], "calendarId": "primary", "account": "normal|test" }`
- Response: per-event results
- Reference: `api_server.py:679`

### Create Recurring Event
- `POST /mcp/calendar/v1/create/recurring`
- Auth: `X-Calendar-MCP-Token`
- Body: `{ "summary":"...","start":"...","end":"...","recurrenceRule":"RRULE:...","calendarId":"primary", ... }`
- Response: MCP tool response content
- Reference: `api_server.py:704`

### Update Recurring Event
- `POST /mcp/calendar/v1/update/recurring`
- Auth: `X-Calendar-MCP-Token`
- Body: `{ "calendarId":"primary","eventId":"...","scope":"THIS|THIS_AND_FUTURE|ALL","updates":{...}, "account":"normal|test" }`
- Response: MCP tool response content
- Reference: `api_server.py:736`

### Availability
- `POST /mcp/calendar/v1/availability`
- Auth: `X-Calendar-MCP-Token`
- Body: `{ "calendarIds": [...], "durationMinutes": <int>, "timeMin":"ISO", "timeMax":"ISO", "preference":"afternoon" }`
- Response: `{ ok:true, result:{ slots:[{start,end}] } }`
- Reference: `api_server.py:765`

### Search
- `POST /mcp/calendar/v1/search`
- Auth: `X-Calendar-MCP-Token`
- Body: `{ "calendarIds": [...], "timeMin":"ISO", "timeMax":"ISO", "attendee":"email", "location":"str", "status":"str", "minDurationMinutes":<int> }`
- Response: filtered events
- Reference: `api_server.py:795`

### Analyze
- `POST /mcp/calendar/v1/analyze`
- Auth: `X-Calendar-MCP-Token`
- Body: `{ "calendarIds": [...], "timeMin":"ISO", "timeMax":"ISO" }`
- Response: `{ total_minutes, percent_recurring, busiest_day }`
- Reference: `api_server.py:827`

### Extract from Image
- `POST /mcp/calendar/v1/extract`
- Auth: `X-Calendar-MCP-Token`
- Body: `{ "imageBase64":"...","mimeType":"image/png" }` OR `{ "imagePath":"/path/to.png" }`
- Response: Strict JSON (if parsed) or raw text
- Reference: `api_server.py:855`

## Performance Requirements
- Rate limiting prevents overload; MCP calls internally use exponential backoff to handle transient failures efficiently.
- `_call_mcp` ensures up to 3 attempts with delay growth `services/calendar_mcp.py:865`.
- Typical latency target per endpoint: < 1000 ms under normal conditions (excluding external MCP tool latency).

## Security & Data Integrity
- Tokens are handled via secure storage (`UserSettings`) and never logged.
- Header token for MCP endpoints is mandatory; requests without it are rejected.
- Input validation and access checks ensure only the Calendar MCP tool accesses privileged actions (e.g., credential migration and clearing).
- Data integrity preserved by atomic operations per endpoint, and strict response envelopes (`ok`, `error`, `result`).

## Testing
- Automated tests validate auth enforcement and rate limiting:
  - File: `tests/test_mcp_calendar_api.py`
  - Run: `python -m unittest -q tests/test_mcp_calendar_api.py`
- Additional tests can be added to cover payload validation and edge cases per endpoint.

## Change Management
- Additive versioning: new features should be introduced under `/mcp/calendar/v2/...` keeping v1 stable.
- Deprecations must be announced and supported with a migration path.

## Examples
- Status:
```
curl -H "X-Calendar-MCP-Token: $CALENDAR_MCP_TOKEN" http://localhost:8000/mcp/calendar/v1/status
```
- Availability (afternoon preference):
```
curl -X POST -H "X-Calendar-MCP-Token: $CALENDAR_MCP_TOKEN" -H "Content-Type: application/json" \
  -d '{"calendarIds":["work","personal"],"durationMinutes":90,"timeMin":"2025-12-01T00:00:00+05:30","timeMax":"2025-12-08T00:00:00+05:30","preference":"afternoon"}' \
  http://localhost:8000/mcp/calendar/v1/availability
```
- Recurring create:
```
curl -X POST -H "X-Calendar-MCP-Token: $CALENDAR_MCP_TOKEN" -H "Content-Type: application/json" \
  -d '{"summary":"Team Sync","start":"2025-12-03T10:00:00+05:30","end":"2025-12-03T10:30:00+05:30","recurrenceRule":"RRULE:FREQ=WEEKLY;BYDAY=WE"}' \
  http://localhost:8000/mcp/calendar/v1/create/recurring
```

