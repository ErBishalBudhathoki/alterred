# NeuroPilot API

## Endpoints
- `GET /health`
- `GET /sessions/yesterday` → list sessions active yesterday
- `GET /sessions/{session_id}/events` → events filtered to yesterday
- `POST /tasks/atomize` { description }
- `POST /tasks/schedule` { items[], energy, weights[] }
- `POST /time/countdown` { target_iso }
- `POST /energy/detect` { text }
 - `POST /energy/match` { tasks[], energy }
- `POST /decision/reduce` { options[], limit }
- `POST /decision/protocol` { options[] }
 - `POST /decision/commit` { choice }
- `POST /external/capture` { transcript }
- `GET /external/context/{task_id}`
- `POST /a2a/connect` { partner_id }
- `POST /a2a/update` { partner_id, update }
- `GET /metrics/overview`
 - `GET /memory/patterns`
 - `POST /memory/compact` { session_id }
 - Auth: Optional `Authorization: Bearer <token>` to derive user identity

## Technical Specs
- FastAPI server (`api_server.py`)
- Uses ADK tools and Firestore storage services

## Configuration
- Requires `.env` with `GOOGLE_API_KEY` and `DEFAULT_MODEL`
- User identity derived from environment or query param
 - If Firebase Admin is configured, tokens in `Authorization` are verified

## Testing Procedures
- Use curl or HTTP client to hit endpoints
- Verify Firestore documents for timers, external brain, a2a, metrics
 - Check memory patterns and compactions via `/memory/patterns` and `/memory/compact`

## Known Limitations
- Auth stub; Firebase Auth integration planned for UI stage