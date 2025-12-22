# NeuroPilot API

## Endpoints
- `GET /health`
- `GET /sessions/yesterday` → list sessions active yesterday
- `GET /sessions/{session_id}/events` → events filtered to yesterday
- `POST /tasks/atomize` { description }
- `POST /tasks/schedule` { items[], energy, weights[] }
- `GET /tasks/prioritized` → returns 3 prioritized tasks based on energy, deadlines, effort
- `POST /tasks/select` { task_id, selection_method } → select a task and start focus session
- `POST /time/countdown` { target_iso }
- `POST /time/estimate` { task, user_estimate_minutes, historical_accuracy? } → corrected time estimate with explanation
- `POST /time/hyperfocus` { work_duration_minutes, last_break_minutes_ago } → intervention level and recommendations
- `POST /time/transition` { next_event } → transition strategies and buffer time recommendations
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

## Notion API Proxy Endpoints

Backend proxy for Notion API calls. Required because Flutter Web cannot make direct calls to api.notion.com due to CORS restrictions.

**Authentication:** All endpoints require a Notion token via:
- `Authorization: Bearer <notion_token>` header, or
- `X-Notion-Token: <notion_token>` header

**Rate Limiting:** 30 requests per minute per IP

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/notion/search` | POST | Search pages and databases |
| `/notion/pages` | POST | Create a new page |
| `/notion/pages/{page_id}` | GET | Get a page by ID |
| `/notion/pages/{page_id}` | PATCH | Update a page |
| `/notion/blocks/{block_id}/children` | GET | Get child blocks |
| `/notion/blocks/{block_id}/children` | PATCH | Append blocks to page |
| `/notion/databases` | POST | Create a database |
| `/notion/databases/{database_id}` | GET | Get a database |
| `/notion/databases/{database_id}/query` | POST | Query a database |
| `/notion/users/me` | GET | Get bot user info (validates token) |
| `/notion/health` | GET | Health check |

## WebSocket Endpoints

### Real-Time Voice: `WS /ws/voice`
Bidirectional WebSocket for real-time voice conversations using Gemini Live API.

**Features:**
- Real-time audio streaming (PCM 16-bit, 16kHz mono)
- Built-in voice activity detection
- Native audio input/output (no separate STT/TTS needed)
- Low-latency conversational AI

**Client → Server Messages:**
- `{"type": "audio", "data": "<base64 PCM audio>"}` - Send audio chunk
- `{"type": "text", "data": "<text message>"}` - Send text message
- `{"type": "config", "voice": "...", "system_prompt": "..."}` - Update config
- `{"type": "ping"}` - Keep-alive ping

**Server → Client Messages:**
- `{"type": "audio", "data": "<base64 PCM audio>"}` - Audio response chunk
- `{"type": "text", "data": "<text>"}` - Text response
- `{"type": "transcript", "data": "<transcript>", "is_final": bool}` - Speech transcript
- `{"type": "state", "state": "<state>"}` - Session state change
- `{"type": "error", "message": "<error>"}` - Error message
- `{"type": "pong"}` - Ping response

**Session States:** `disconnected`, `connecting`, `connected`, `listening`, `processing`, `speaking`, `error`

**Voice Options:** Puck, Charon, Kore, Fenrir, Aoede (default)

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