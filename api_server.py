"""
Altered API Server
==================

This module serves as the main entry point for the Altered backend application.
It uses FastAPI to expose a RESTful API that the Flutter frontend (and other clients)
interact with.

Architecture:
-------------
- **Framework:** FastAPI is used for high performance and automatic OpenAPI documentation.
- **Middleware:** CORS middleware is configured to allow cross-origin requests, essential for
  mobile and web clients. A custom middleware `_strip_api_prefix` is used to handle
  different routing configurations (e.g., behind a proxy).
- **Service Integration:** The server integrates various services and agents:
    - History Service (retrieving past sessions)
    - Auth Service (user identification)
    - Memory Bank (pattern recognition)
    - Agents (TaskFlow, TimePerception, EnergySensory, DecisionSupport)
    - External Tools (Calendar, Metrics)

Timezone & Calendar:
--------------------
- **Client Timezone Propagation:** The server respects the user's device timezone by reading
  the `X-Client-Timezone` header (IANA name) and, when needed, `X-Client-Offset-Minutes`.
  Time computations use `zoneinfo.ZoneInfo` when available, falling back to the offset header.
- **Calendar MCP Integration:** All calendar endpoints forward the client timezone via
  `timeZone` in MCP payloads to ensure correct event creation, updates, listings, free/busy,
  and analysis across DST boundaries.
- **Endpoints (selected):**
  - `/mcp/calendar/v1/list`, `/mcp/calendar/v1/search`, `/mcp/calendar/v1/analyze`,
    `/mcp/calendar/v1/availability` — listing, filtering, analysis, and free-time computation.
  - `/mcp/calendar/v1/create/batch`, `/mcp/calendar/v1/create/recurring` — creation APIs.
  - `/mcp/calendar/v1/update`, `/mcp/calendar/v1/update/recurring` — single and series updates
    with proper scope mapping (instance, following, all).
  - `/mcp/calendar/v1/delete`, `/mcp/calendar/v1/get`, `/mcp/calendar/v1/colors`,
    `/mcp/calendar/v1/freebusy`, `/mcp/calendar/v1/time` — utility operations.

Design Decisions:
-----------------
- **Statelessness:** The API is designed to be largely stateless, relying on the database
  (Firestore/File) and the `session_id` or `user_id` passed in requests to maintain context.
- **Modularity:** Endpoints delegate logic to specific service modules (`services/`) or
  agent modules (`agents/`), keeping the route handlers thin.
- **ADK Integration:** It conditionally imports Google's Agent Development Kit (ADK) components
  to support advanced agentic workflows if available.

Behavioral Specifications:
--------------------------
- **Input:** JSON payloads via HTTP POST/GET.
- **Output:** JSON responses. Standard HTTP status codes are used.
- **Error Handling:** FastAPI's default exception handling is leveraged, but specific
  services may raise exceptions that should be handled (though currently mostly implicit).
 - **Timezone Behavior:** When `X-Client-Timezone` is present, date/time parsing and calendar
   operations use `ZoneInfo` for accurate local times; otherwise the server uses
   `X-Client-Offset-Minutes` when provided.
"""

import os
import sys
import time
import asyncio

from uuid import uuid4
import logging
from dotenv import load_dotenv

# Load environment variables immediately to ensure all modules have access to them
load_dotenv()

# CRITICAL FIX: Remove GOOGLE_API_KEY to force Vertex AI usage
# Must match the same logic in adk_app.py
# api_server.py imports adk_app.py, and load_dotenv() re-loads the key from .env
# So we must delete it here too to prevent GEMINI_API backend selection
force_vertex = (os.getenv("FORCE_VERTEX_AI", "").lower() == "true")
if force_vertex and "GOOGLE_API_KEY" in os.environ:
    print("[API SERVER] Removing GOOGLE_API_KEY to force Vertex AI backend")
    del os.environ["GOOGLE_API_KEY"]

from fastapi import (  # noqa: E402
    FastAPI, Body, Request, Depends, HTTPException, status,
    UploadFile, File, Form, Response, WebSocket, WebSocketDisconnect
)
import json  # noqa: E402
import httpx  # noqa: E402
from contextlib import asynccontextmanager  # noqa: E402
from fastapi.middleware.cors import CORSMiddleware  # noqa: E402
from typing import List, Dict, Any, Optional  # noqa: E402
from datetime import datetime  # noqa: E402

from services.history_service import get_sessions_by_date, get_events_for_session  # noqa: E402
from services.auth import get_user_id_from_request  # noqa: E402
from services.memory_bank_service import get_patterns  # noqa: E402
from services.memory_bank import FirestoreMemoryBank  # noqa: E402
from services.compaction_service import compact_session  # noqa: E402
from agents.taskflow_agent import schedule_tasks  # noqa: E402
from agents.tools import atomize_task, reduce_options  # noqa: E402
from agents.time_perception_agent import create_countdown, reality_calibrator, check_upcoming_conflicts  # noqa: E402
from fastapi.responses import JSONResponse, RedirectResponse, HTMLResponse  # noqa: E402
from services.timer_store import store_countdown  # noqa: E402
from agents.energy_sensory_agent import detect_sensory_overload  # noqa: E402
from agents.decision_support_agent import paralysis_protocol  # noqa: E402
from agents.tools import match_task_to_energy  # noqa: E402
from services.external_brain_store import store_voice_task, get_context, list_voice_tasks  # noqa: E402
from services.a2a_service import (  # noqa: E402
    connect_partner, post_update, list_updates, disconnect_partner,
    list_partners, get_or_create_partner_id, set_selected_partner,
    get_selected_partner, set_default_partner, get_default_partner
)
from services.metrics_service import (  # noqa: E402
    compute_daily_overview,
    record_api_access,
    record_model_usage,
    record_task_completion,
    record_decision_resolution,
    record_hyperfocus_interrupt,
    record_agent_latency,
    record_stress_level,
    record_strategy_effectiveness
)
from services.oauth_handlers import GoogleOAuthHandler  # noqa: E402
from services.user_settings import UserSettings  # noqa: E402
from adk_app import adk_respond, current_user_timezone  # noqa: E402
from services.chat_commands import (  # noqa: E402
    parse as parse_chat_command,
    execute as execute_chat_command,
    help as chat_help
)
from services.country_service import get_country_info  # noqa: E402
from routers.vertex_routes import router as vertex_router  # noqa: E402
from routers.byok_routes import router as byok_router  # noqa: E402
from routers.tasks_router import router as tasks_router  # noqa: E402
from routers.notion_routes import router as notion_router  # noqa: E402
import services.firebase_client as firebase_client  # noqa: E402
from services.vertex_ai_client import VertexAIClient  # noqa: E402
from services.piper_service import PiperService  # noqa: E402
from services.google_tts_service import GoogleTtsService  # noqa: E402
from services.google_stt_service import GoogleSttService  # noqa: E402
from services.voice_manager import VoiceManager  # noqa: E402
from services.gemini_live_service import GeminiLiveService, handle_voice_websocket

logger = logging.getLogger(__name__)

# Wrap calendar MCP imports in try-except to prevent import failures from crashing the API
# This allows the server to start even if MCP dependencies are missing or misconfigured
_CALENDAR_MCP_AVAILABLE = False
_CALENDAR_MCP_ERROR = None

try:
    from services.calendar_mcp import (
        list_events_today,
        check_mcp_ready,
        account_status,
        account_clear,
        account_migrate,
        list_events_from_calendars,
        batch_create_events,
        create_recurring_event,
        update_recurring_event,
        update_event_payload,
        delete_event,
        get_event,
        list_colors,
        get_freebusy,
        get_current_time,
        find_availability,
        search_events,
        analyze_calendar,
        extract_event_from_image,
    )
    _CALENDAR_MCP_AVAILABLE = True
    print("✓ Calendar MCP module loaded successfully")
except Exception as e:
    print(f"⚠ Calendar MCP module failed to import: {e}")
    print("  Calendar endpoints will return 503 Service Unavailable")
    _CALENDAR_MCP_ERROR = str(e)
    # Define stub functions that return error responses
    def _mcp_unavailable_response():
        return {"ok": False, "error": f"Calendar MCP unavailable: {_CALENDAR_MCP_ERROR}"}

    def list_events_today(*args, **kwargs):
        return _mcp_unavailable_response()
    def check_mcp_ready(*args, **kwargs):
        return _mcp_unavailable_response()
    def account_status(*args, **kwargs):
        return _mcp_unavailable_response()
    def account_clear(*args, **kwargs):
        return _mcp_unavailable_response()
    def account_migrate(*args, **kwargs):
        return _mcp_unavailable_response()
    def list_events_from_calendars(*args, **kwargs):
        return _mcp_unavailable_response()
    def batch_create_events(*args, **kwargs):
        return _mcp_unavailable_response()
    def create_recurring_event(*args, **kwargs):
        return _mcp_unavailable_response()
    def update_recurring_event(*args, **kwargs):
        return _mcp_unavailable_response()
    def find_availability(*args, **kwargs):
        return _mcp_unavailable_response()
    def search_events(*args, **kwargs):
        return _mcp_unavailable_response()
    def analyze_calendar(*args, **kwargs):
        return _mcp_unavailable_response()
    def extract_event_from_image(*args, **kwargs):
        return _mcp_unavailable_response()
    def delete_event(*args, **kwargs):
        return _mcp_unavailable_response()
    def update_event_payload(*args, **kwargs):
        return _mcp_unavailable_response()
    def get_event(*args, **kwargs):
        return _mcp_unavailable_response()
    def list_colors(*args, **kwargs):
        return _mcp_unavailable_response()
    def get_freebusy(*args, **kwargs):
        return _mcp_unavailable_response()
    def get_current_time(*args, **kwargs):
        return _mcp_unavailable_response()

try:
    from google.adk.tools.google_search_tool import GoogleSearchTool
    from google.adk.agents import LlmAgent
    from google.adk.runners import Runner
    from google.adk.sessions import InMemorySessionService
    from google.adk.models.google_llm import Gemini
    from google.genai import types
    _SEARCH_TOOL = GoogleSearchTool(bypass_multi_tools_limit=True)
except ImportError:
    _SEARCH_TOOL = None




@asynccontextmanager
async def lifespan(app: FastAPI):
    load_dotenv()
    print("=" * 80)
    print("🚀 Altered API Server Starting...")
    print("=" * 80)

    print(f"📍 Python version: {sys.version}")
    print(f"📍 Working directory: {os.getcwd()}")
    print(f"📍 PORT environment variable: {os.getenv('PORT', 'NOT SET')}")

    env_vars = [
        "FIREBASE_PROJECT_ID",
        "GCP_PROJECT_ID",
        "GOOGLE_CLOUD_PROJECT",
        "VERTEX_AI_PROJECT_ID",
        "VERTEX_AI_LOCATION",
        "DEFAULT_MODEL",
        "GOOGLE_API_KEY",
        "GOOGLE_OAUTH_CLIENT_ID",
    ]
    print("\n📋 Environment Variables:")
    for var in env_vars:
        value = os.getenv(var)
        if value:
            if "KEY" in var or "SECRET" in var:
                print(f"  ✓ {var}: ***{value[-4:]}")
            else:
                print(f"  ✓ {var}: {value}")
        else:
            print(f"  ✗ {var}: NOT SET")

    print(f"\n📅 Calendar MCP Status: {'✓ Available' if _CALENDAR_MCP_AVAILABLE else '✗ Unavailable'}")
    if not _CALENDAR_MCP_AVAILABLE and _CALENDAR_MCP_ERROR:
        print(f"   Error: {_CALENDAR_MCP_ERROR}")

    mcp_path = os.path.join(os.getcwd(), "google-calendar-mcp")
    if os.path.exists(mcp_path):
        print(f"✓ google-calendar-mcp directory exists at: {mcp_path}")
        build_path = os.path.join(mcp_path, "build", "index.js")
        if os.path.exists(build_path):
            print("✓ MCP build artifact exists")
        else:
            print(f"✗ MCP build artifact NOT found at: {build_path}")
    else:
        print("✗ google-calendar-mcp directory NOT found")

    print(f"\n🔍 Google Search Tool: {'✓ Available' if _SEARCH_TOOL else '✗ Not available'}")

    PiperService.initialize()

    default_model = os.getenv("DEFAULT_MODEL", "gemini-2.0-flash")
    force_vertex = os.getenv("FORCE_VERTEX_AI", "").lower() == "true"
    vertex_region = os.getenv("VERTEX_AI_LOCATION", "NOT SET")

    print("\n🤖 Model Configuration:")
    print(f"   Model: {default_model}")
    print(f"   Force Vertex AI: {force_vertex}")
    print(f"   Vertex AI Region: {vertex_region}")

    if default_model == "gemini-2.5-flash" and force_vertex:
        print(f"   ⚠️  WARNING: 'gemini-2.5-flash' may not be available in Vertex AI {vertex_region}")
        print("   💡 Recommended: Set DEFAULT_MODEL GitHub variable to 'gemini-2.0-flash' or 'gemini-2.5-flash'")
    elif default_model == "gemini-2.5-flash":
        print("   ℹ️  Gemini API direct mode would be used if BYOK provided; otherwise disabled")

    # Runtime service validation
    print("\n🔎 Runtime Service Validation:")
    v_client = VertexAIClient()
    if v_client.vertex_ai_available:
        print(f"   ✓ Vertex AI is initialized for project: {v_client.project_id} in {v_client.location}")
    else:
        print("   ✗ Vertex AI not initialized (missing project/location or aiplatform SDK)")

    if os.getenv("GOOGLE_API_KEY"):
        print("   ⚠️ GOOGLE_API_KEY detected in environment; runtime usage is disabled except for BYOK operations")

    if firebase_client.init_firebase():
        print("\n🔥 Firebase initialized successfully")
    else:
        print("\n❌ Firebase initialization FAILED")

    print("\n" + "=" * 80)
    print("✅ Altered API Server startup complete - ready to accept connections")
    print("=" * 80)

    try:
        yield
    finally:
        # Optional: graceful shutdown logs
        print("Altered API Server shutting down...")

app = FastAPI(title="Altered API", lifespan=lifespan)

# Configure CORS to allow requests from any origin.
# In production, this should be restricted to specific domains for security.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(vertex_router)
app.include_router(byok_router)
app.include_router(tasks_router)
app.include_router(notion_router)


@app.post("/tts/speak")
async def tts_speak(request: Request, payload: Dict[str, Any] = Body(...)):
    """
    Synthesize text to speech using Piper TTS.
    
    Args:
        payload (Dict[str, Any]): JSON payload containing:
            - "text": Text to speak.
            - "speed": Speaking rate (optional, default 1.0).
            - "voice": Voice ID (optional, default en_US-lessac).
            - "quality": Quality (optional, default low).
            - "noise_scale": Generator noise (optional, default 0.667).
            - "noise_w": Phoneme width noise (optional, default 0.8).
            
    Returns:
        Response: Audio data (audio/wav) or error JSON.
    """
    rid = uuid4().hex
    uid = get_user_id_from_request(request) if request else _uid(None)

    text = payload.get("text", "")
    try:
        speed = float(payload.get("speed", 1.0))
        voice = payload.get("voice", "en_US-lessac")
        quality = payload.get("quality", "low")
        noise_scale = float(payload.get("noise_scale", 0.667))
        noise_w = float(payload.get("noise_w", 0.8))
    except Exception as e:
        logger.warning(
            "TTS invalid payload rid=%s uid=%s error=%s",
            rid,
            uid,
            str(e),
        )
        return JSONResponse(
            status_code=400,
            content={"ok": False, "error": "invalid_payload", "request_id": rid},
        )

    if not text:
        return JSONResponse(
            status_code=400,
            content={"ok": False, "error": "empty_text", "request_id": rid},
        )

    # Check voice provider
    voice_info = VoiceManager.get_voice_info(voice)
    provider = voice_info.get("provider", "piper") if voice_info else "piper"
    logger.info(
        "TTS request rid=%s uid=%s provider=%s voice=%s quality=%s speed=%s chars=%s",
        rid,
        uid,
        provider,
        voice,
        quality,
        speed,
        len(text),
    )

    import asyncio
    loop = asyncio.get_running_loop()

    try:
        if provider == "google":
            # voice is the key e.g., en-US-Neural2-C
            logger.info(f"Routing TTS to Google voice={voice}")
            audio_data = await loop.run_in_executor(
                None,
                GoogleTtsService.synthesize,
                text,
                voice,  # voice name
                voice_info.get("language", "en-US")
                .replace("English (US)", "en-US")
                .replace("English (GB)", "en-GB"),
                speed,
            )
        else:
            # Default to Piper
            logger.info(f"Routing TTS to Piper voice={voice} quality={quality}")
            audio_data = await loop.run_in_executor(
                None,
                PiperService.synthesize,
                text,
                speed,
                voice,
                quality,
                noise_scale,
                noise_w,
            )
    except Exception:
        logger.exception(
            "TTS synthesis exception rid=%s uid=%s provider=%s voice=%s",
            rid,
            uid,
            provider,
            voice,
        )
        return JSONResponse(
            status_code=500,
            content={"ok": False, "error": "tts_exception", "request_id": rid},
        )

    if not audio_data:
        logger.error(
            "TTS synthesis returned no audio rid=%s uid=%s provider=%s voice=%s",
            rid,
            uid,
            provider,
            voice,
        )
        return JSONResponse(
            status_code=500,
            content={"ok": False, "error": "tts_failed", "request_id": rid},
        )

    return Response(
        content=audio_data,
        media_type="audio/wav",
        headers={"X-Request-Id": rid},
    )


@app.get("/tts/voices")
def tts_voices():
    """
    List available Piper voices.
    """
    return {"voices": VoiceManager.list_voices()}


@app.post("/tts/prewarm")
def tts_prewarm(payload: Dict[str, Any] = Body(...)):
    voice = payload.get("voice")
    quality = payload.get("quality", "low")
    if not voice:
        return JSONResponse(status_code=400, content={"error": "voice required"})
    logger.info(f"Prewarm TTS model voice={voice} quality={quality}")
    vinfo = VoiceManager.get_voice_info(str(voice)) or {}
    if vinfo.get("provider") == "google":
        return {"ok": True}
    path = VoiceManager.get_model_path(str(voice), str(quality))
    if not path:
        return JSONResponse(status_code=500, content={"error": "prewarm failed"})
    return {"ok": True}


@app.post("/stt/transcribe")
async def stt_transcribe(
    request: Request,
    file: UploadFile = File(...),
    language: str = Form("en-US"),
):
    """
    Transcribe uploaded audio file using Google Cloud Speech-to-Text.
    """
    rid = uuid4().hex
    try:
        uid = get_user_id_from_request(request) if request else _uid(None)
        content_type = file.content_type
        content = await file.read()
        if not content:
            return JSONResponse(
                status_code=400,
                content={"ok": False, "error": "empty_audio", "request_id": rid},
            )

        if content_type and not content_type.startswith("audio/"):
            return JSONResponse(
                status_code=400,
                content={
                    "ok": False,
                    "error": "invalid_content_type",
                    "request_id": rid,
                },
            )

        if len(content) > 10 * 1024 * 1024:
            return JSONResponse(
                status_code=413,
                content={"ok": False, "error": "audio_too_large", "request_id": rid},
            )

        logger.info(
            "STT request rid=%s uid=%s content_type=%s bytes=%s language=%s",
            rid,
            uid,
            content_type,
            len(content),
            language,
        )

        loop = asyncio.get_running_loop()
        result = await loop.run_in_executor(
            None,
            GoogleSttService.transcribe_with_diagnostics,
            content,
            language,
            content_type,
        )

        transcript = result.get("transcript")
        error = result.get("error")
        details = result.get("details")

        if transcript is None:
            # Default error to no_speech if not set
            if not error:
                error = "no_speech"

            logger.error(
                "STT transcription failed rid=%s uid=%s content_type=%s error=%s details=%s meta=%s",
                rid,
                uid,
                content_type,
                error,
                details,
                {
                    "encoding": result.get("encoding"),
                    "sample_rate_hz": result.get("sample_rate_hz"),
                    "channel_count": result.get("channel_count"),
                    "results_count": result.get("results_count"),
                    "used_fallback": result.get("used_fallback"),
                },
            )

            if error in {"no_speech"}:
                return JSONResponse(
                    status_code=200,
                    content={
                        "ok": False,
                        "error": "no_speech",
                        "request_id": rid,
                    },
                )

            client_error_codes = {
                "invalid_argument",
                "bad_request",
            }
            if error in client_error_codes:
                return JSONResponse(
                    status_code=400,
                    content={
                        "ok": False,
                        "error": error,
                        "details": details,
                        "request_id": rid,
                    },
                )

            auth_error_codes = {
                "permission_denied",
                "unauthenticated",
            }
            if error in auth_error_codes:
                return JSONResponse(
                    status_code=502,
                    content={
                        "ok": False,
                        "error": error,
                        "details": "Upstream authentication/permission error when calling Google STT.",
                        "request_id": rid,
                    },
                )

            rate_limit_codes = {
                "rate_limited",
            }
            if error in rate_limit_codes:
                return JSONResponse(
                    status_code=502,
                    content={
                        "ok": False,
                        "error": error,
                        "details": "Upstream rate limit exceeded when calling Google STT.",
                        "request_id": rid,
                    },
                )

            return JSONResponse(
                status_code=500,
                content={
                    "ok": False,
                    "error": "transcription_failed",
                    "details": details,
                    "request_id": rid,
                },
            )

        return {
            "ok": True,
            "transcript": transcript,
            "request_id": rid,
        }
    except Exception as e:
        logger.exception(
            "STT transcription exception rid=%s content_type=%s error=%s",
            rid,
            getattr(file, "content_type", None),
            str(e),
        )
        return JSONResponse(
            status_code=500,
            content={"ok": False, "error": "transcription_error", "request_id": rid},
        )


@app.middleware("http")
async def _strip_api_prefix(request: Request, call_next):
    """
    Middleware to strip the '/api' prefix from incoming requests.

    This allows the API to be hosted under an '/api' path (e.g., via Nginx or a cloud load balancer)
    while the internal routing logic remains at the root level.

    Args:
        request (Request): The incoming HTTP request.
        call_next (Callable): The next middleware or route handler.

    Returns:
        Response: The HTTP response.
    """
    p = request.scope.get("path", "")
    if p.startswith("/api/"):
        request.scope["path"] = p[4:]
    elif p == "/api":
        request.scope["path"] = "/"
    return await call_next(request)


@app.get("/health")
async def health_check():
    """
    Simple health check endpoint.
    """
    return {
        "status": "ok",
        "ok": True,
        "timestamp": datetime.now().isoformat(),
        "mcp_calendar": "available" if _CALENDAR_MCP_AVAILABLE else "unavailable",
        "search_tool": "available" if _SEARCH_TOOL else "unavailable"
    }


def _uid(user_id: Optional[str]) -> str:
    """
    Helper to resolve the effective user ID.

    Priority:
    1. Explicitly provided `user_id`.
    2. `USER` environment variable (for local dev/terminal).
    3. Default to "terminal_user".

    Args:
        user_id (str | None): The user ID provided in the request query/body.

    Returns:
        str: The resolved user ID.
    """
    return user_id or os.getenv("USER") or "terminal_user"


# ===== MCP Calendar Guard & Rate Limiting =====
_MCP_RATE_BUCKETS: dict[str, list[float]] = {}

def _mcp_calendar_guard(request: Request) -> None:
    """
    Enforces access control and rate limiting for MCP Calendar endpoints.

    Authentication:
    - Requires header `X-Calendar-MCP-Token` matching env var `CALENDAR_MCP_TOKEN`.
    - Optional client identifier header `X-Client: calendar-mcp`.

    Rate Limiting:
    - Default: 100 requests per IP per 15 minutes.
    - Override via env vars `MCP_RATE_LIMIT_COUNT` and `MCP_RATE_LIMIT_WINDOW_SECONDS`.

    Raises:
    - HTTP 401 if authentication fails
    - HTTP 429 if rate limit exceeded
    """
    token_header = request.headers.get("X-Calendar-MCP-Token")
    expected = os.getenv("CALENDAR_MCP_TOKEN")
    allow_query = os.getenv("ALLOW_MCP_TOKEN_QUERY", "").lower() == "true"
    token_query = request.query_params.get("token") if allow_query else None
    provided = token_header or token_query
    if not expected or provided != expected:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail={"ok": False, "error": "unauthorized"})

    # Rate limiting
    count = int(os.getenv("MCP_RATE_LIMIT_COUNT", "100"))
    window = int(os.getenv("MCP_RATE_LIMIT_WINDOW_SECONDS", "900"))
    ip = (request.client.host if request.client else "0.0.0.0")
    now = time.time()
    bucket = _MCP_RATE_BUCKETS.get(ip, [])
    # prune
    bucket = [t for t in bucket if now - t <= window]
    if len(bucket) >= count:
        _MCP_RATE_BUCKETS[ip] = bucket
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail={"ok": False, "error": "rate_limited"})
    bucket.append(now)
    _MCP_RATE_BUCKETS[ip] = bucket




@app.get("/sessions/yesterday")
def sessions_yesterday(request: Request, user_id: str | None = None):
    """
    Retrieve session data from yesterday.

    This is used for the "yesterday's recap" feature, helping users review
    their previous day's activities.

    Args:
        request (Request): The HTTP request object (used to extract auth headers).
        user_id (str | None): Optional user ID override.

    Returns:
        dict: A dictionary containing a list of sessions.
    """
    from datetime import datetime, timezone, timedelta, tzinfo
    from zoneinfo import ZoneInfo
    offset_str = request.headers.get("X-Client-Offset-Minutes") if request else None
    offset = int(offset_str) if (offset_str and offset_str.strip().lstrip("-+").isdigit()) else 0
    tz_name = request.headers.get("X-Client-Timezone") if request else None
    now_utc = datetime.utcnow().replace(tzinfo=timezone.utc)
    local_tz: tzinfo
    if tz_name:
        try:
            local_tz = ZoneInfo(tz_name)
        except Exception:
            local_tz = timezone(timedelta(minutes=offset))
    else:
        local_tz = timezone(timedelta(minutes=offset))
    now_local = now_utc.astimezone(local_tz)
    y = (now_local.date() - timedelta(days=1))
    start = datetime(y.year, y.month, y.day, 0, 0, 0, tzinfo=local_tz).isoformat()
    end = datetime(y.year, y.month, y.day, 23, 59, 59, tzinfo=local_tz).isoformat()
    uid = get_user_id_from_request(request) if request else _uid(user_id)
    sessions = get_sessions_by_date(uid, "altered", start, end)
    return {"sessions": sessions}


@app.get("/sessions/{session_id}/events")
def session_events(request: Request, session_id: str, user_id: str | None = None):
    """
    Retrieve specific events for a given session.

    Args:
        request (Request): The HTTP request object.
        session_id (str): The ID of the session to retrieve events for.
        user_id (str | None): Optional user ID override.

    Returns:
        dict: A dictionary containing a list of events.
    """
    from datetime import datetime, timezone, timedelta, tzinfo
    from zoneinfo import ZoneInfo
    offset_str = request.headers.get("X-Client-Offset-Minutes") if request else None
    offset = int(offset_str) if (offset_str and offset_str.strip().lstrip("-+").isdigit()) else 0
    tz_name = request.headers.get("X-Client-Timezone") if request else None
    now_utc = datetime.utcnow().replace(tzinfo=timezone.utc)
    local_tz: tzinfo
    if tz_name:
        try:
            local_tz = ZoneInfo(tz_name)
        except Exception:
            local_tz = timezone(timedelta(minutes=offset))
    else:
        local_tz = timezone(timedelta(minutes=offset))
    now_local = now_utc.astimezone(local_tz)
    y = (now_local.date() - timedelta(days=1))
    start = datetime(y.year, y.month, y.day, 0, 0, 0, tzinfo=local_tz).isoformat()
    end = datetime(y.year, y.month, y.day, 23, 59, 59, tzinfo=local_tz).isoformat()
    uid = get_user_id_from_request(request) if request else _uid(user_id)
    events = get_events_for_session(uid, "altered", session_id, start, end)
    return {"events": events}


@app.post("/tasks/atomize")
def api_atomize(payload: Dict[str, Any] = Body(...)):
    """
    Break down a high-level task into smaller, manageable sub-tasks (atomization).

    This uses the `atomize_task` function (likely powered by an LLM) to help
    users who are overwhelmed by large tasks.

    Args:
        payload (Dict[str, Any]): JSON payload containing "description" of the task
                                  and optional "country_code".

    Returns:
        dict: The atomized task structure.
    """
    desc = payload.get("description", "")
    country_code = payload.get("country_code")
    return atomize_task(desc, country_code=country_code)


@app.post("/tasks/schedule")
def api_schedule(payload: Dict[str, Any] = Body(...)):
    """
    Schedule a list of tasks based on energy levels and priorities.

    Delegates to `agents.taskflow_agent.schedule_tasks`.

    Args:
        payload (Dict[str, Any]): JSON payload containing:
            - "items": List of task descriptions.
            - "energy": User's current energy level (int).
            - "weights": Optional weights for prioritization.

    Returns:
        dict: The scheduled task list.
    """
    items = payload.get("items", [])
    energy = int(payload.get("energy", 5))
    weights = payload.get("weights", None)
    return schedule_tasks(items, energy, weights)



@app.post("/time/countdown")
def api_countdown(request: Request, payload: Dict[str, Any] = Body(...), user_id: str | None = None):
    """
    Create a countdown timer based on a natural language query.

    Args:
        payload (Dict[str, Any]): JSON payload containing "query" (e.g., "10 minutes").

    Returns:
        dict: The timer configuration and ID.
    """
    query = payload.get("query")
    target_iso = payload.get("target_iso")
    if query is None and target_iso is None:
        return JSONResponse(status_code=400, content={"ok": False, "error": "query_required"})

    conf = create_countdown(query if query is not None else target_iso)
    if conf.get("ok") is False:
        content = {"ok": False, "error": conf.get("error", "invalid_duration")}
        if conf.get("message"):
            content["message"] = conf.get("message")
        return JSONResponse(status_code=400, content=content)
    uid = get_user_id_from_request(request) if request else _uid(user_id)
    try:
        tid = store_countdown(conf["target"], conf["warnings"], uid)
    except Exception as e:
        logger.exception(f"Timer store failed uid={uid}: {e}")
        return JSONResponse(status_code=503, content={"ok": False, "error": "timer_store_unavailable"})
    res = {"timer_id": tid, **conf}
    return res


@app.post("/time/estimate")
def api_time_estimate(request: Request, payload: Dict[str, Any] = Body(...), user_id: str | None = None):
    """
    Calibrate user's time estimate based on historical patterns.

    Args:
        payload (Dict[str, Any]): JSON payload containing "task_description" and "user_estimate_minutes".

    Returns:
        dict: Calibrated time estimate with explanation.
    """
    task_description = payload.get("task_description", "")
    user_estimate = payload.get("user_estimate_minutes")
    
    if not task_description or user_estimate is None:
        return JSONResponse(status_code=400, content={
            "ok": False, 
            "error": "task_description and user_estimate_minutes required"
        })
    
    try:
        user_estimate = int(user_estimate)
        if user_estimate <= 0:
            raise ValueError("Estimate must be positive")
    except (ValueError, TypeError):
        return JSONResponse(status_code=400, content={
            "ok": False, 
            "error": "user_estimate_minutes must be a positive integer"
        })
    
    uid = get_user_id_from_request(request) if request else _uid(user_id)
    result = reality_calibrator(task_description, user_estimate, uid)
    
    return {"ok": True, **result}


@app.post("/time/conflicts")
def api_check_conflicts(request: Request, payload: Dict[str, Any] = Body(...), user_id: str | None = None):
    """
    Check for upcoming calendar conflicts and transition warnings.

    Args:
        payload (Dict[str, Any]): JSON payload containing optional "hours_ahead".

    Returns:
        dict: Upcoming conflicts and recommendations.
    """
    hours_ahead = payload.get("hours_ahead", 2)
    
    try:
        hours_ahead = int(hours_ahead)
        if hours_ahead <= 0 or hours_ahead > 24:
            hours_ahead = 2
    except (ValueError, TypeError):
        hours_ahead = 2
    
    result = check_upcoming_conflicts(hours_ahead)
    
    return {"ok": True, **result}


@app.post("/energy/detect")
def api_detect(request: Request, payload: Dict[str, Any] = Body(...), user_id: str | None = None):
    """
    Detect sensory overload from text input.

    Delegates to `agents.energy_sensory_agent.detect_sensory_overload`.

    Args:
        payload (Dict[str, Any]): JSON payload containing "text".

    Returns:
        dict: Assessment of sensory load.
    """
    text = payload.get("text", "")
    res = detect_sensory_overload(text)
    try:
        uid = get_user_id_from_request(request) if request else _uid(user_id)
        if res.get("overload"):
            t = text.lower()
            triggers = []
            for k in ["loud", "bright", "crowded", "overstimulated", "noisy", "glare", "busy"]:
                if k in t:
                    triggers.append(k)
            if triggers:
                bank = FirestoreMemoryBank(uid)
                for tr in triggers:
                    bank.add_sensory_trigger(tr)
    except Exception:
        pass
    return res

@app.post("/energy/log")
def api_energy_log(request: Request, payload: Dict[str, Any] = Body(...), user_id: str | None = None):
    """
    Log a specific energy level manually or from agent inference.
    
    Args:
        payload: containing 'level' (int) and optional 'context' (str).
    """
    level = int(payload.get("level", 0))
    context = payload.get("context")
    uid = get_user_id_from_request(request) if request else _uid(user_id)
    try:
        bank = FirestoreMemoryBank(uid)
        bank.record_energy_level(level)
        if context:
            bank.store_decision_event("energy_log", {"level": level, "context": context})
        return {"ok": True, "logged": True, "level": level}
    except Exception as e:
        return {"ok": False, "error": str(e)}


@app.post("/decision/reduce")
def api_reduce(payload: Dict[str, Any] = Body(...)):
    """
    Reduce a list of options to a manageable subset to help with decision fatigue.

    Args:
        payload (Dict[str, Any]): JSON payload containing:
            - "options": List of option strings.
            - "limit": Maximum number of options to return (default 3).

    Returns:
        dict: Reduced list of options.
    """
    opts: List[str] = payload.get("options", [])
    limit = int(payload.get("limit", 3))
    return reduce_options(opts, max_options=limit)


_GEO_CACHE: Dict[str, Dict[str, Any]] = {}
_GEO_CACHE_TTL = 3600  # 1 hour

@app.get("/geo/ip")
async def geo_ip(request: Request):
    """
    Determine country from IP address.
    Uses ip-api.com as a fallback mechanism for country detection.
    Results are cached for 1 hour to minimize API calls.
    
    Returns:
        dict: {"country_code": "US", "country": "United States", ...}
    """
    # Try to get the real client IP if behind proxy
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded:
        client_ip = forwarded.split(",")[0].strip()
    else:
        client_ip = request.client.host if request.client else None

    # Determine if we are looking up the server's own IP (local dev) or a specific client IP
    is_local = not client_ip or client_ip in ("127.0.0.1", "::1", "localhost")
    cache_key = "server_public_ip" if is_local else client_ip

    # Check cache
    now = time.time()
    if cache_key in _GEO_CACHE:
        entry = _GEO_CACHE[cache_key]
        if now - entry["ts"] < _GEO_CACHE_TTL:
            print(f"DEBUG: Returning cached geo for {cache_key}")
            return entry["data"]

    url = "http://ip-api.com/json/"
    if not is_local:
        url = f"http://ip-api.com/json/{client_ip}"

    print(f"DEBUG: resolving geo for IP: {client_ip} via {url}")

    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.get(url)
            if resp.status_code == 200:
                data = resp.json()
                if data.get("status") == "success":
                    result = {
                        "country_code": data.get("countryCode"),
                        "country": data.get("country"),
                        "city": data.get("city"),
                        "ip": data.get("query"),
                        "source": "ip-api"
                    }
                    # Update cache
                    _GEO_CACHE[cache_key] = {"ts": now, "data": result}
                    return result
    except Exception as e:
        print(f"IP Geo lookup failed: {e}")

    return {"country_code": None, "error": "lookup_failed"}


@app.post("/decision/protocol")
def api_protocol(payload: Dict[str, Any] = Body(...)):
    """
    Apply a specific protocol to overcome decision paralysis.

    Args:
        payload (Dict[str, Any]): JSON payload containing "options".

    Returns:
        dict: The result of the paralysis protocol.
    """
    opts: List[str] = payload.get("options", [])
    return paralysis_protocol(opts)


@app.post("/energy/match")
def api_energy_match(payload: Dict[str, Any] = Body(...)):
    """
    Match tasks to the user's current energy level.

    Args:
        payload (Dict[str, Any]): JSON payload containing:
            - "tasks": List of task descriptions.
            - "energy": User's energy level (int).

    Returns:
        dict: Tasks that match the energy level.
    """
    tasks = payload.get("tasks", [])
    energy = int(payload.get("energy", 5))
    return match_task_to_energy(tasks, energy)


@app.post("/decision/commit")
def api_decision_commit(payload: Dict[str, Any] = Body(...)):
    """
    Commit to a specific decision choice.

    This is a placeholder for tracking user decisions.

    Args:
        payload (Dict[str, Any]): JSON payload containing "choice".

    Returns:
        dict: Confirmation of the commitment.
    """
    choice = payload.get("choice")
    return {"committed": True, "choice": choice}


@app.post("/external/capture")
def api_capture(payload: Dict[str, Any] = Body(...)):
    """
    Capture an external input (e.g., voice transcript) as a task or note.

    Args:
        payload (Dict[str, Any]): JSON payload containing "transcript".

    Returns:
        dict: The created task ID and title.
    """
    transcript = payload.get("transcript", "")
    title = transcript.split(".")[0]
    tid = store_voice_task(title, "captured", transcript)
    return {"task_id": tid, "title": title}


@app.get("/external/context/{task_id}")
def api_context(task_id: str):
    """
    Retrieve context for a specific external task/note.

    Args:
        task_id (str): The ID of the task.

    Returns:
        dict: The context associated with the task.
    """
    ctx = get_context(task_id)
    return {"context": ctx}


@app.get("/external/notes")
def api_external_notes(request: Request, user_id: str | None = None):
    """
    List all external notes/tasks for the user.

    Args:
        request (Request): HTTP request.
        user_id (str | None): Optional user ID override.

    Returns:
        dict: List of notes.
    """
    uid = get_user_id_from_request(request) if request else _uid(user_id)
    notes = list_voice_tasks(uid)
    return {"notes": notes}


@app.post("/a2a/connect")
def api_a2a_connect(payload: Dict[str, Any] = Body(...)):
    """
    Connect to an Agent-to-Agent (A2A) partner.

    Args:
        payload (Dict[str, Any]): JSON payload containing "partner_id".

    Returns:
        dict: Connection status.
    """
    pid = payload.get("partner_id")
    return connect_partner(pid)


@app.post("/a2a/update")
def api_a2a_update(payload: Dict[str, Any] = Body(...)):
    """
    Post an update to an A2A partner.

    Args:
        payload (Dict[str, Any]): JSON payload containing "partner_id" and "update" data.

    Returns:
        dict: Update status.
    """
    pid = payload.get("partner_id")
    upd = payload.get("update", {})
    return post_update(pid, upd)


@app.get("/a2a/updates")
def api_a2a_updates(request: Request, partner_id: str, limit: int = 20):
    """
    List recent updates from a connected A2A partner.
    """
    uid = get_user_id_from_request(request) if request else _uid(None)
    return list_updates(partner_id, limit)


@app.delete("/a2a/connection")
def api_a2a_disconnect(partner_id: str):
    """
    Disconnect from an A2A partner.
    """
    return disconnect_partner(partner_id)


@app.get("/a2a/partners")
def api_a2a_partners(request: Request):
    """
    List all connected A2A partners.
    """
    return list_partners()


@app.get("/a2a/partner-id")
def api_partner_id(request: Request):
    return get_or_create_partner_id()


@app.post("/a2a/selected-partner")
def api_set_selected_partner(payload: Dict[str, Any] = Body(...)):
    pid = payload.get("partner_id") or ""
    return set_selected_partner(pid)


@app.get("/a2a/selected-partner")
def api_get_selected_partner():
    return get_selected_partner()


@app.post("/a2a/default-partner")
def api_set_default_partner(payload: Dict[str, Any] = Body(...)):
    pid = payload.get("partner_id") or ""
    return set_default_partner(pid)


@app.get("/a2a/default-partner")
def api_get_default_partner():
    return get_default_partner()


@app.post("/metrics/log")
def api_metrics_log(request: Request, payload: Dict[str, Any] = Body(...), user_id: str | None = None):
    """
    Log a generic metric event.

    The payload must contain a 'kind' field specifying the type of metric
    (e.g., 'task_completion', 'stress_level', 'strategy_effectiveness').
    Other fields in the payload will be passed to the corresponding record function.

    Args:
        request (Request): HTTP request.
        payload (Dict[str, Any]): JSON payload containing the metric data.
        user_id (str | None): Optional user ID override.

    Returns:
        dict: Confirmation of logging.
    """
    uid = get_user_id_from_request(request) if request else _uid(user_id)
    kind = payload.get("kind")

    if not kind:
        raise HTTPException(status_code=400, detail={"ok": False, "error": "Metric 'kind' is required"})

    # Dispatch to appropriate record function based on 'kind'
    try:
        if kind == "task_completion":
            record_task_completion(
                task_id=payload.get("task_id"),
                estimated_minutes=payload.get("estimated_minutes"),
                actual_minutes=payload.get("actual_minutes")
            )
        elif kind == "decision_resolution":
            record_decision_resolution(duration_seconds=payload.get("duration_seconds"))
        elif kind == "hyperfocus_interrupt":
            record_hyperfocus_interrupt()
        elif kind == "agent_latency":
            record_agent_latency(latency_ms=payload.get("latency_ms"))
        elif kind == "decision_resolution_time":
            record_decision_resolution(duration_seconds=payload.get("duration_seconds"))
        elif kind == "stress_level":
            record_stress_level(level=payload.get("level"))
        elif kind == "strategy_effectiveness":
            record_strategy_effectiveness(strategy_name=payload.get("strategy_name"), effectiveness=payload.get("effectiveness"))
        elif kind == "model_usage":
            record_model_usage(
                model_name=payload.get("model_name"),
                latency_ms=payload.get("latency_ms"),
                tokens_input=payload.get("tokens_input", 0),
                tokens_output=payload.get("tokens_output", 0),
                status=payload.get("status", "success"),
                error=payload.get("error")
            )
        elif kind == "api_access":
            record_api_access(
                endpoint=payload.get("endpoint"),
                status=payload.get("status"),
                latency_ms=payload.get("latency_ms"),
                error=payload.get("error")
            )
        else:
            raise HTTPException(status_code=400, detail={"ok": False, "error": f"Unknown metric kind: {kind}"})
        return {"ok": True, "logged": True, "kind": kind}
    except Exception as e:
        raise HTTPException(status_code=500, detail={"ok": False, "error": str(e)})

@app.get("/metrics/daily/{date_key}")
def api_metrics_daily(request: Request, date_key: str, user_id: str | None = None):
    """
    Retrieve daily metrics for a specific date.
    """
    uid = get_user_id_from_request(request) if request else _uid(user_id)
    overview = compute_daily_overview(uid, date_key)
    return overview


@app.get("/metrics/overview")
def api_metrics_overview(request: Request, user_id: str | None = None):
    """
    Get a daily overview of metrics (productivity, energy, etc.).

    Args:
        request (Request): HTTP request.
        user_id (str | None): Optional user ID override.

    Returns:
        dict: Daily overview metrics.
    """
    uid = get_user_id_from_request(request) if request else _uid(user_id)
    from datetime import datetime, timezone, timedelta, tzinfo
    from zoneinfo import ZoneInfo
    offset_str = request.headers.get("X-Client-Offset-Minutes") if request else None
    offset = int(offset_str) if (offset_str and offset_str.strip().lstrip("-+").isdigit()) else 0
    tz_name = request.headers.get("X-Client-Timezone") if request else None
    now_utc = datetime.utcnow().replace(tzinfo=timezone.utc)
    local_tz: tzinfo
    if tz_name:
        try:
            local_tz = ZoneInfo(tz_name)
        except Exception:
            local_tz = timezone(timedelta(minutes=offset))
    else:
        local_tz = timezone(timedelta(minutes=offset))
    dk = now_utc.astimezone(local_tz).date().isoformat()
    return compute_daily_overview(uid, dk)


@app.post("/metrics/stress")
def api_metrics_stress(request: Request, payload: Dict[str, Any] = Body(...), user_id: str | None = None):
    """Log stress level manually."""
    uid = get_user_id_from_request(request) if request else _uid(user_id)
    level = int(payload.get("level", 5))
    context = payload.get("context")
    try:
        from services.metrics_service import record_stress_level
        record_stress_level(level, context)
        return {"ok": True}
    except Exception as e:
        return {"ok": False, "error": str(e)}


@app.post("/metrics/strategy")
def api_metrics_strategy(request: Request, payload: Dict[str, Any] = Body(...), user_id: str | None = None):
    """Log strategy effectiveness."""
    uid = get_user_id_from_request(request) if request else _uid(user_id)
    strategy = payload.get("strategy")
    successful = bool(payload.get("successful"))
    try:
        from services.metrics_service import record_strategy_effectiveness
        record_strategy_effectiveness(strategy, successful)
        return {"ok": True}
    except Exception as e:
        return {"ok": False, "error": str(e)}


@app.get("/memory/patterns")
def api_memory_patterns(request: Request, user_id: str | None = None):
    """
    Retrieve recognized patterns from the user's memory bank.

    Args:
        request (Request): HTTP request.
        user_id (str | None): Optional user ID override.

    Returns:
        dict: List of identified patterns.
    """
    uid = get_user_id_from_request(request) if request else _uid(user_id)
    return {"patterns": get_patterns(uid)}

@app.post("/memory/patterns/recompute")
def api_memory_patterns_recompute(request: Request, user_id: str | None = None):
    uid = get_user_id_from_request(request) if request else _uid(user_id)
    try:
        from services.patterns_service import recompute_patterns
        res = recompute_patterns(uid)
        return {"ok": True, **res}
    except Exception as e:
        return {"ok": False, "error": str(e)}


@app.post("/memory/compact")
def api_memory_compact(request: Request, payload: Dict[str, Any] = Body(...)):
    """
    Trigger compaction of a session's memory.

    This process summarizes the session events to save space and distill key information.

    Args:
        request (Request): HTTP request.
        payload (Dict[str, Any]): JSON payload containing "session_id".

    Returns:
        dict: Result of the compaction process.
    """
    uid = get_user_id_from_request(request) if request else _uid(None)
    session_id = payload.get("session_id")
    res = compact_session(uid, "altered", session_id)
    return res



@app.get("/calendar/ready")
def api_calendar_ready(request: Request):
    """
    Check if the Calendar MCP (Model Context Protocol) is ready.

    Args:
        request (Request): HTTP request.

    Returns:
        dict: Readiness status of the calendar service.
    """
    uid = get_user_id_from_request(request) if request else _uid(None)
    return check_mcp_ready(user_id=uid)


@app.post("/calendar/events/delete")
async def api_calendar_delete_event(request: Request):
    """
    Delete a calendar event.
    """
    user_id = get_user_id_from_request(request)
    try:
        data = await request.json()
        calendar_id = data.get("calendarId", "primary")
        event_id = data.get("eventId")
        if not event_id:
            return {"ok": False, "error": "eventId required"}

        from services.calendar_mcp import _delete_event_async
        res = await _delete_event_async(calendar_id, event_id, user_id=user_id)
        return res
    except Exception as e:
        return {"ok": False, "error": str(e)}


@app.post("/calendar/events/update")
async def api_calendar_update_event(request: Request):
    """
    Update a calendar event.
    """
    user_id = get_user_id_from_request(request)
    try:
        data = await request.json()
        calendar_id = data.get("calendarId", "primary")
        event_id = data.get("eventId")
        updates = data.get("updates", {})

        if not event_id:
             return {"ok": False, "error": "eventId required"}

        from services.calendar_mcp import _update_event_payload_async
        res = await _update_event_payload_async(calendar_id, event_id, updates, user_id=user_id)
        return res
    except Exception as e:
        return {"ok": False, "error": str(e)}


@app.get("/calendar/events/today")
def api_calendar_events_today(request: Request):
    """
    List calendar events for today from ALL visible calendars.

    Args:
        request (Request): HTTP request.

    Returns:
        dict: List of events for today from all calendars.
    """
    uid = get_user_id_from_request(request) if request else _uid(None)
    tz_name = request.headers.get("X-Client-Timezone") if request else None

    try:
        # Use list_events_today with include_all_calendars=True to get events from all subscribed calendars
        res = list_events_today(calendar_id="primary", user_id=uid, time_zone=tz_name, include_all_calendars=True)
    except Exception as e:
        logger.error(f"Error listing calendar events for {uid}: {e}")
        res = {"ok": False, "error": str(e)}

    if not res.get("ok"):
        msg = str(res.get("error", "")).lower()
        if ("invalid grant" in msg) or ("authenticate" in msg) or ("taskgroup" in msg) or ("credentials" in msg):
            return {"ok": False, "error": "Google Calendar is not connected. Please go to Settings → Google Calendar → Connect to use calendar features."}
    return res


# ===== MCP Calendar v1 Endpoints =====

@app.get("/mcp/calendar/v1/status")
def mcp_calendar_status(request: Request, user_id: str | None = None, _: None = Depends(_mcp_calendar_guard)):
    """
    MCP Calendar Status (v1)

    Authentication:
    - Header `X-Calendar-MCP-Token: <secret>` required.

    Rate Limiting:
    - 100 requests/IP/15 minutes (configurable via env).

    Usage:
    - curl example:
      curl -H "X-Calendar-MCP-Token: $CALENDAR_MCP_TOKEN" http://localhost:8000/mcp/calendar/v1/status
    """
    t0 = time.time()
    uid = get_user_id_from_request(request) if request else _uid(user_id)
    try:
        res = account_status(uid)
        ms = int((time.time() - t0) * 1000)
        record_api_access("/mcp/calendar/v1/status", "success", ms)
        return res
    except Exception as e:
        ms = int((time.time() - t0) * 1000)
        record_api_access("/mcp/calendar/v1/status", "error", ms, str(e))
        return JSONResponse(status_code=500, content={"ok": False, "error": str(e)})


@app.get("/mcp/calendar/v1/diagnostics")
def mcp_calendar_diagnostics(request: Request, account: str = "normal", user_id: str | None = None, probe: bool = False, _: None = Depends(_mcp_calendar_guard)):
    uid = get_user_id_from_request(request) if request else _uid(user_id)
    try:
        from services.calendar_mcp import _get_user_credentials_file
        creds_env = os.getenv("GOOGLE_OAUTH_CREDENTIALS")
        creds_env_abs = os.path.abspath(creds_env) if creds_env else None
        resolved_path = _get_user_credentials_file(uid, account)
        resolved_abs = os.path.abspath(resolved_path) if resolved_path else None
        can_read = False
        minimal_valid = False
        if resolved_abs and os.path.exists(resolved_abs):
            try:
                with open(resolved_abs, "r") as f:
                    j = json.load(f)
                can_read = True
                minimal_valid = bool(j.get("refresh_token") or j.get("installed") or j.get("web"))
            except Exception:
                can_read = False
        client_id = os.getenv("GOOGLE_OAUTH_CLIENT_ID")
        client_secret_present = bool(os.getenv("GOOGLE_OAUTH_CLIENT_SECRET"))
        token_path_env = os.getenv("GOOGLE_CALENDAR_MCP_TOKEN_PATH")
        mcp_root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "google-calendar-mcp")
        build_index = os.path.join(mcp_root, "build", "index.js")
        build_exists = os.path.exists(build_index)
        tools = []
        if probe:
            try:
                res = check_mcp_ready(user_id=uid)
                if res.get("ok"):
                    tools = res.get("tools", [])
            except Exception:
                pass
        return {
            "ok": True,
            "account": account,
            "env": {
                "GOOGLE_OAUTH_CREDENTIALS": creds_env_abs,
                "GOOGLE_OAUTH_CLIENT_ID": client_id,
                "GOOGLE_OAUTH_CLIENT_SECRET_present": client_secret_present,
                "GOOGLE_CALENDAR_MCP_TOKEN_PATH": token_path_env
            },
            "credentials": {
                "resolved_path": resolved_abs,
                "readable": can_read,
                "minimally_valid": minimal_valid
            },
            "mcp": {
                "local_build_index_exists": build_exists,
                "tools": tools
            }
        }
    except Exception as e:
        return JSONResponse(status_code=500, content={"ok": False, "error": str(e)})


@app.get("/mcp/calendar/v1/credentials")
def mcp_calendar_credentials(request: Request, account: str = "normal", user_id: str | None = None, _: None = Depends(_mcp_calendar_guard)):
    t0 = time.time()
    uid = get_user_id_from_request(request) if request else _uid(user_id)
    try:
        from services.calendar_mcp import _get_user_credentials_file
        path = _get_user_credentials_file(uid, account)
        if not path:
            ms = int((time.time() - t0) * 1000)
            record_api_access("/mcp/calendar/v1/credentials", "error", ms, "no_credentials")
            return JSONResponse(status_code=404, content={"ok": False, "error": "no_credentials"})
        ms = int((time.time() - t0) * 1000)
        record_api_access("/mcp/calendar/v1/credentials", "success", ms)
        return {"ok": True, "path": os.path.abspath(path), "filename": os.path.basename(path)}
    except Exception as e:
        ms = int((time.time() - t0) * 1000)
        record_api_access("/mcp/calendar/v1/credentials", "error", ms, str(e))
        return JSONResponse(status_code=500, content={"ok": False, "error": str(e)})


@app.post("/mcp/calendar/v1/clear")
def mcp_calendar_clear(request: Request, payload: Dict[str, Any] = Body(...), user_id: str | None = None, _: None = Depends(_mcp_calendar_guard)):
    """
    Clear MCP Calendar account tokens (v1)

    Authentication:
    - Header `X-Calendar-MCP-Token` required.

    Body:
    - { "account": "normal" | "test" }

    Example:
      curl -X POST -H "Content-Type: application/json" \
           -H "X-Calendar-MCP-Token: $CALENDAR_MCP_TOKEN" \
           -d '{"account":"test"}' http://localhost:8000/mcp/calendar/v1/clear
    """
    t0 = time.time()
    acct = (payload or {}).get("account", "normal")
    uid = get_user_id_from_request(request) if request else _uid(user_id)
    try:
        res = account_clear(acct, uid)
        ms = int((time.time() - t0) * 1000)
        record_api_access("/mcp/calendar/v1/clear", "success", ms)
        return res
    except Exception as e:
        ms = int((time.time() - t0) * 1000)
        record_api_access("/mcp/calendar/v1/clear", "error", ms, str(e))
        return JSONResponse(status_code=500, content={"ok": False, "error": str(e)})


@app.post("/mcp/calendar/v1/migrate")
def mcp_calendar_migrate(request: Request, user_id: str | None = None, _: None = Depends(_mcp_calendar_guard)):
    """
    Migrate authorized-user credentials to stored tokens (v1)

    Authentication:
    - Header `X-Calendar-MCP-Token` required.

    Example:
      curl -X POST -H "X-Calendar-MCP-Token: $CALENDAR_MCP_TOKEN" http://localhost:8000/mcp/calendar/v1/migrate
    """
    t0 = time.time()
    uid = get_user_id_from_request(request) if request else _uid(user_id)
    try:
        res = account_migrate(uid)
        ms = int((time.time() - t0) * 1000)
        record_api_access("/mcp/calendar/v1/migrate", "success", ms)
        return res
    except Exception as e:
        ms = int((time.time() - t0) * 1000)
        record_api_access("/mcp/calendar/v1/migrate", "error", ms, str(e))
        return JSONResponse(status_code=500, content={"ok": False, "error": str(e)})


@app.post("/mcp/calendar/v1/list")
def mcp_calendar_list(request: Request, payload: Dict[str, Any] = Body(...), user_id: str | None = None, _: None = Depends(_mcp_calendar_guard)):
    """
    List events across calendars within a time range (v1)

    Auth: `X-Calendar-MCP-Token` header
    Body: { "calendarIds": ["primary","work"], "timeMin": "...", "timeMax": "...", "account": "normal|test" }
    Example:
      curl -X POST -H "X-Calendar-MCP-Token: $CALENDAR_MCP_TOKEN" -H "Content-Type: application/json" \
           -d '{"calendarIds":["work","personal"],"timeMin":"2025-12-01T00:00:00+05:30","timeMax":"2025-12-08T00:00:00+05:30"}' \
           http://localhost:8000/mcp/calendar/v1/list
    """
    t0 = time.time()
    uid = get_user_id_from_request(request) if request else _uid(user_id)
    cids = (payload or {}).get("calendarIds", ["primary"])
    tmin = (payload or {}).get("timeMin")
    tmax = (payload or {}).get("timeMax")
    acct = (payload or {}).get("account", "normal")
    try:
        tz_name = request.headers.get("X-Client-Timezone") if request else None
        res = list_events_from_calendars(cids, tmin, tmax, uid, acct, tz_name)
        ms = int((time.time() - t0) * 1000)
        record_api_access("/mcp/calendar/v1/list", "success", ms)
        return res
    except Exception as e:
        ms = int((time.time() - t0) * 1000)
        record_api_access("/mcp/calendar/v1/list", "error", ms, str(e))
        return JSONResponse(status_code=500, content={"ok": False, "error": str(e)})


@app.post("/mcp/calendar/v1/create/batch")
def mcp_calendar_create_batch(request: Request, payload: Dict[str, Any] = Body(...), user_id: str | None = None, _: None = Depends(_mcp_calendar_guard)):
    """
    Batch create events (v1)

    Auth: `X-Calendar-MCP-Token`
    Body: { "events": [ {"summary":"...","start":"...","end":"..."}, ... ], "calendarId": "primary", "account":"normal|test" }
    """
    t0 = time.time()
    uid = get_user_id_from_request(request) if request else _uid(user_id)
    events = (payload or {}).get("events", [])
    cal = (payload or {}).get("calendarId", "primary")
    acct = (payload or {}).get("account", "normal")
    try:
        tz_name = request.headers.get("X-Client-Timezone") if request else None
        res = batch_create_events(events, cal, uid, acct, tz_name)
        ms = int((time.time() - t0) * 1000)
        record_api_access("/mcp/calendar/v1/create/batch", "success", ms)
        return res
    except Exception as e:
        ms = int((time.time() - t0) * 1000)
        record_api_access("/mcp/calendar/v1/create/batch", "error", ms, str(e))
        return JSONResponse(status_code=500, content={"ok": False, "error": str(e)})


@app.post("/mcp/calendar/v1/create/recurring")
def mcp_calendar_create_recurring(request: Request, payload: Dict[str, Any] = Body(...), user_id: str | None = None, _: None = Depends(_mcp_calendar_guard)):
    """
    Create a recurring event with an RRULE (v1)

    Auth: `X-Calendar-MCP-Token`
    Body: { "summary":"...","start":"...","end":"...","recurrenceRule":"RRULE:FREQ=WEEKLY;BYDAY=MO" , "calendarId":"primary", "account":"normal|test" }
    """
    t0 = time.time()
    uid = get_user_id_from_request(request) if request else _uid(user_id)
    try:
        tz_name = request.headers.get("X-Client-Timezone") if request else None
        res = create_recurring_event(
            (payload or {}).get("summary"),
            (payload or {}).get("start"),
            (payload or {}).get("end"),
            (payload or {}).get("recurrenceRule"),
            (payload or {}).get("calendarId", "primary"),
            (payload or {}).get("location"),
            (payload or {}).get("description"),
            uid,
            (payload or {}).get("account", "normal"),
            time_zone=tz_name,
        )
        ms = int((time.time() - t0) * 1000)
        record_api_access("/mcp/calendar/v1/create/recurring", "success", ms)
        return res
    except Exception as e:
        ms = int((time.time() - t0) * 1000)
        record_api_access("/mcp/calendar/v1/create/recurring", "error", ms, str(e))
        return JSONResponse(status_code=500, content={"ok": False, "error": str(e)})


@app.post("/mcp/calendar/v1/update/recurring")
def mcp_calendar_update_recurring(request: Request, payload: Dict[str, Any] = Body(...), user_id: str | None = None, _: None = Depends(_mcp_calendar_guard)):
    """
    Update a recurring event with scope (v1)

    Auth: `X-Calendar-MCP-Token`
    Body: { "calendarId":"primary","eventId":"...","scope":"THIS|THIS_AND_FUTURE|ALL","updates":{...}, "account":"normal|test" }
    """
    t0 = time.time()
    uid = get_user_id_from_request(request) if request else _uid(user_id)
    try:
        tz_name = request.headers.get("X-Client-Timezone") if request else None
        upd = (payload or {}).get("updates", {})
        if (payload or {}).get("originalStartTime") and not upd.get("originalStartTime"):
            upd["originalStartTime"] = (payload or {}).get("originalStartTime")
        if (payload or {}).get("futureStartDate") and not upd.get("futureStartDate"):
            upd["futureStartDate"] = (payload or {}).get("futureStartDate")
        res = update_recurring_event(
            (payload or {}).get("calendarId", "primary"),
            (payload or {}).get("eventId"),
            (payload or {}).get("scope", "THIS"),
            upd,
            uid,
            (payload or {}).get("account", "normal"),
            time_zone=tz_name,
        )
        ms = int((time.time() - t0) * 1000)
        record_api_access("/mcp/calendar/v1/update/recurring", "success", ms)
        return res
    except Exception as e:
        ms = int((time.time() - t0) * 1000)
        record_api_access("/mcp/calendar/v1/update/recurring", "error", ms, str(e))
        return JSONResponse(status_code=500, content={"ok": False, "error": str(e)})


@app.post("/mcp/calendar/v1/update")
def mcp_calendar_update(request: Request, payload: Dict[str, Any] = Body(...), user_id: str | None = None, _: None = Depends(_mcp_calendar_guard)):
    t0 = time.time()
    uid = get_user_id_from_request(request) if request else _uid(user_id)
    try:
        tz_name = request.headers.get("X-Client-Timezone") if request else None
        res = update_event_payload(
            (payload or {}).get("calendarId", "primary"),
            (payload or {}).get("eventId"),
            (payload or {}).get("updates", {}),
            uid,
            (payload or {}).get("account", "normal"),
            time_zone=tz_name,
        )
        ms = int((time.time() - t0) * 1000)
        record_api_access("/mcp/calendar/v1/update", "success", ms)
        return res
    except Exception as e:
        ms = int((time.time() - t0) * 1000)
        record_api_access("/mcp/calendar/v1/update", "error", ms, str(e))
        return JSONResponse(status_code=500, content={"ok": False, "error": str(e)})


@app.post("/mcp/calendar/v1/delete")
def mcp_calendar_delete(request: Request, payload: Dict[str, Any] = Body(...), user_id: str | None = None, _: None = Depends(_mcp_calendar_guard)):
    t0 = time.time()
    uid = get_user_id_from_request(request) if request else _uid(user_id)
    try:
        res = delete_event(
            (payload or {}).get("calendarId", "primary"),
            (payload or {}).get("eventId"),
            uid,
        )
        ms = int((time.time() - t0) * 1000)
        record_api_access("/mcp/calendar/v1/delete", "success", ms)
        return res
    except Exception as e:
        ms = int((time.time() - t0) * 1000)
        record_api_access("/mcp/calendar/v1/delete", "error", ms, str(e))
        return JSONResponse(status_code=500, content={"ok": False, "error": str(e)})


@app.post("/mcp/calendar/v1/get")
def mcp_calendar_get(request: Request, payload: Dict[str, Any] = Body(...), user_id: str | None = None, _: None = Depends(_mcp_calendar_guard)):
    t0 = time.time()
    uid = get_user_id_from_request(request) if request else _uid(user_id)
    try:
        res = get_event(
            (payload or {}).get("calendarId", "primary"),
            (payload or {}).get("eventId"),
            (payload or {}).get("fields"),
            uid,
            (payload or {}).get("account", "normal"),
        )
        ms = int((time.time() - t0) * 1000)
        record_api_access("/mcp/calendar/v1/get", "success", ms)
        return res
    except Exception as e:
        ms = int((time.time() - t0) * 1000)
        record_api_access("/mcp/calendar/v1/get", "error", ms, str(e))
        return JSONResponse(status_code=500, content={"ok": False, "error": str(e)})


@app.get("/mcp/calendar/v1/colors")
def mcp_calendar_colors(request: Request, account: str = "normal", user_id: str | None = None, _: None = Depends(_mcp_calendar_guard)):
    t0 = time.time()
    uid = get_user_id_from_request(request) if request else _uid(user_id)
    try:
        res = list_colors(uid, account)
        ms = int((time.time() - t0) * 1000)
        record_api_access("/mcp/calendar/v1/colors", "success", ms)
        return res
    except Exception as e:
        ms = int((time.time() - t0) * 1000)
        record_api_access("/mcp/calendar/v1/colors", "error", ms, str(e))
        return JSONResponse(status_code=500, content={"ok": False, "error": str(e)})


@app.post("/mcp/calendar/v1/freebusy")
def mcp_calendar_freebusy(request: Request, payload: Dict[str, Any] = Body(...), user_id: str | None = None, _: None = Depends(_mcp_calendar_guard)):
    t0 = time.time()
    uid = get_user_id_from_request(request) if request else _uid(user_id)
    try:
        tz_name = request.headers.get("X-Client-Timezone") if request else None
        calendars_obj = (payload or {}).get("calendars")
        if calendars_obj and isinstance(calendars_obj, list):
            cids = [c.get("id") for c in calendars_obj if isinstance(c, dict) and c.get("id")]
        else:
            cids = (payload or {}).get("calendarIds", ["primary"]) or ["primary"]
        res = get_freebusy(
            cids,
            (payload or {}).get("timeMin"),
            (payload or {}).get("timeMax"),
            uid,
            (payload or {}).get("account", "normal"),
            time_zone=tz_name,
            group_expansion_max=(payload or {}).get("groupExpansionMax"),
            calendar_expansion_max=(payload or {}).get("calendarExpansionMax"),
        )
        ms = int((time.time() - t0) * 1000)
        record_api_access("/mcp/calendar/v1/freebusy", "success", ms)
        return res
    except Exception as e:
        ms = int((time.time() - t0) * 1000)
        record_api_access("/mcp/calendar/v1/freebusy", "error", ms, str(e))
        return JSONResponse(status_code=500, content={"ok": False, "error": str(e)})


@app.get("/mcp/calendar/v1/time")
def mcp_calendar_current_time(request: Request, account: str = "normal", user_id: str | None = None, _: None = Depends(_mcp_calendar_guard)):
    t0 = time.time()
    uid = get_user_id_from_request(request) if request else _uid(user_id)
    try:
        tz_name = request.headers.get("X-Client-Timezone") if request else None
        res = get_current_time(uid, account, time_zone=tz_name)
        ms = int((time.time() - t0) * 1000)
        record_api_access("/mcp/calendar/v1/time", "success", ms)
        return res
    except Exception as e:
        ms = int((time.time() - t0) * 1000)
        record_api_access("/mcp/calendar/v1/time", "error", ms, str(e))
        return JSONResponse(status_code=500, content={"ok": False, "error": str(e)})


@app.post("/mcp/calendar/v1/availability")
def mcp_calendar_availability(request: Request, payload: Dict[str, Any] = Body(...), user_id: str | None = None, _: None = Depends(_mcp_calendar_guard)):
    """
    Find availability across calendars (v1)

    Auth: `X-Calendar-MCP-Token`
    Body: { "calendarIds": [...], "durationMinutes": 90, "timeMin":"...", "timeMax":"...", "preference":"afternoon" }
    """
    t0 = time.time()
    uid = get_user_id_from_request(request) if request else _uid(user_id)
    try:
        tz_name = request.headers.get("X-Client-Timezone") if request else None
        res = find_availability(
            (payload or {}).get("calendarIds", ["primary"]),
            int((payload or {}).get("durationMinutes", 60)),
            (payload or {}).get("timeMin"),
            (payload or {}).get("timeMax"),
            (payload or {}).get("preference"),
            uid,
            (payload or {}).get("account", "normal"),
            time_zone=tz_name,
        )
        ms = int((time.time() - t0) * 1000)
        record_api_access("/mcp/calendar/v1/availability", "success", ms)
        return res
    except Exception as e:
        ms = int((time.time() - t0) * 1000)
        record_api_access("/mcp/calendar/v1/availability", "error", ms, str(e))
        return JSONResponse(status_code=500, content={"ok": False, "error": str(e)})


@app.post("/mcp/calendar/v1/search")
def mcp_calendar_search(request: Request, payload: Dict[str, Any] = Body(...), user_id: str | None = None, _: None = Depends(_mcp_calendar_guard)):
    """
    Advanced search across calendars (v1)

    Auth: `X-Calendar-MCP-Token`
    Body: { "calendarIds": [...], "timeMin":"...","timeMax":"...", "attendee":"john@example.com", "location":"hq", "status":"confirmed", "minDurationMinutes":60 }
    """
    t0 = time.time()
    uid = get_user_id_from_request(request) if request else _uid(user_id)
    try:
        tz_name = request.headers.get("X-Client-Timezone") if request else None
        res = search_events(
            (payload or {}).get("calendarIds", ["primary"]),
            (payload or {}).get("timeMin"),
            (payload or {}).get("timeMax"),
            (payload or {}).get("attendee"),
            (payload or {}).get("location"),
            (payload or {}).get("status"),
            (payload or {}).get("minDurationMinutes"),
            uid,
            (payload or {}).get("account", "normal"),
            time_zone=tz_name,
        )
        ms = int((time.time() - t0) * 1000)
        record_api_access("/mcp/calendar/v1/search", "success", ms)
        return res
    except Exception as e:
        ms = int((time.time() - t0) * 1000)
        record_api_access("/mcp/calendar/v1/search", "error", ms, str(e))
        return JSONResponse(status_code=500, content={"ok": False, "error": str(e)})


@app.post("/mcp/calendar/v1/analyze")
def mcp_calendar_analyze(request: Request, payload: Dict[str, Any] = Body(...), user_id: str | None = None, _: None = Depends(_mcp_calendar_guard)):
    """
    Calendar analysis metrics (v1)

    Auth: `X-Calendar-MCP-Token`
    Body: { "calendarIds": [...], "timeMin":"...", "timeMax":"..." }
    """
    t0 = time.time()
    uid = get_user_id_from_request(request) if request else _uid(user_id)
    try:
        tz_name = request.headers.get("X-Client-Timezone") if request else None
        res = analyze_calendar(
            (payload or {}).get("calendarIds", ["primary"]),
            (payload or {}).get("timeMin"),
            (payload or {}).get("timeMax"),
            uid,
            (payload or {}).get("account", "normal"),
            time_zone=tz_name,
        )
        ms = int((time.time() - t0) * 1000)
        record_api_access("/mcp/calendar/v1/analyze", "success", ms)
        return res
    except Exception as e:
        ms = int((time.time() - t0) * 1000)
        record_api_access("/mcp/calendar/v1/analyze", "error", ms, str(e))
        return JSONResponse(status_code=500, content={"ok": False, "error": str(e)})


@app.post("/mcp/calendar/v1/extract")
def mcp_calendar_extract(request: Request, payload: Dict[str, Any] = Body(...), user_id: str | None = None, _: None = Depends(_mcp_calendar_guard)):
    """
    Extract event details from an image (v1)

    Auth: `X-Calendar-MCP-Token`
    Body: { "imageBase64":"...", "mimeType":"image/png" } OR { "imagePath":"/path/to.png" }
    """
    import base64
    t0 = time.time()
    uid = get_user_id_from_request(request) if request else _uid(user_id)
    img_b64 = (payload or {}).get("imageBase64")
    # mime optional; not used here
    img_path = (payload or {}).get("imagePath")
    try:
        if img_b64:
            data = base64.b64decode(img_b64)
            res = extract_event_from_image(data, (payload or {}).get("userInstruction"), user_id=uid)
        elif img_path:
            res = extract_event_from_image(img_path, (payload or {}).get("userInstruction"), user_id=uid)
        else:
            return JSONResponse(status_code=400, content={"ok": False, "error": "missing_image"})
        ms = int((time.time() - t0) * 1000)
        record_api_access("/mcp/calendar/v1/extract", "success", ms)
        return res
    except Exception as e:
        ms = int((time.time() - t0) * 1000)
        record_api_access("/mcp/calendar/v1/extract", "error", ms, str(e))
        return JSONResponse(status_code=500, content={"ok": False, "error": str(e)})


@app.get("/mcp/country/info")
def api_country_info(code: str):
    """
    Get information for a specific country.
    
    Args:
        code (str): ISO 3166-1 alpha-2 country code.
        
    Returns:
        JSON response with country data.
    """
    data = get_country_info(code)
    return {"ok": True, "data": data}


# ===== OAuth Endpoints =====

@app.get("/auth/google/calendar")
def api_oauth_calendar_init(request: Request, platform: str = 'web'):
    """Initiate Google Calendar OAuth flow."""
    # Require authenticated user for initiating OAuth
    auth_header = request.headers.get("Authorization") if request else None
    if not auth_header or not auth_header.lower().startswith("bearer "):
        return JSONResponse(status_code=401, content={"ok": False, "error": "Missing Authorization"})
    uid = get_user_id_from_request(request) if request else _uid(None)

    try:
        oauth_handler = GoogleOAuthHandler()

        # Use platform-specific redirect URI
        redirect_uri = None
        if platform == 'mobile':
            redirect_uri = 'altered://oauth-callback'

        # Use user_id as state for CSRF protection
        authorization_url = oauth_handler.get_authorization_url(
            state=uid,
            redirect_uri=redirect_uri
        )

        return {"ok": True, "authorization_url": authorization_url}
    except Exception as e:
        return JSONResponse(status_code=500, content={"ok": False, "error": str(e)})


@app.get("/auth/google/calendar/callback")
def api_oauth_calendar_callback(request: Request, code: str, state: str):
    """Handle OAuth callback and store tokens."""
    try:
        # Verify state matches user_id (basic CSRF protection)
        uid = state

        oauth_handler = GoogleOAuthHandler()

        # If state is 'mcp_redirect', this came from MCP server via our redirect server
        # Use the MCP redirect URI (localhost:3500) for token exchange
        if state == "mcp_redirect":
            token_result = oauth_handler.exchange_code_for_tokens(code, redirect_uri="http://localhost:3500/oauth2callback")
            # For MCP flows, we don't have a user_id in state, so we'll need to get it another way
            # For now, log a warning
            import logging
            logging.warning("MCP redirect callback received but no user_id in state. Tokens cannot be saved.")
            return JSONResponse(status_code=400, content={
                "ok": False,
                "error": "MCP redirect requires user_id in state. Please reconnect via Settings."
            })
        else:
            # Normal flow from Settings UI
            token_result = oauth_handler.exchange_code_for_tokens(code)

        if not token_result.get("ok"):
            return JSONResponse(status_code=400, content=token_result)

        # Store tokens in Firestore (encrypted)
        user_settings = UserSettings(uid)
        store_result = user_settings.save_oauth_tokens(
            provider="google_calendar",
            access_token=token_result["access_token"],
            refresh_token=token_result["refresh_token"],
            expires_at=token_result["expires_at"],
            scopes=token_result["scopes"]
        )

        if not store_result.get("ok"):
            return JSONResponse(status_code=500, content=store_result)

        # Fetch and store user email
        try:
            import requests as _requests
            resp = _requests.get(
                "https://www.googleapis.com/oauth2/v2/userinfo",
                headers={"Authorization": f"Bearer {token_result['access_token']}"},
                timeout=8,
            )
            if resp.status_code == 200:
                data = resp.json()
                email = data.get("email")
                if email:
                    user_settings.save_profile_email(email)
        except Exception:
            pass
        auth_header = request.headers.get("Authorization") if request else None
        if auth_header and auth_header.lower().startswith("bearer "):
            return {"ok": True, "connected": True}
        import os as _os
        fe = _os.getenv("FRONTEND_BASE_URL")
        url = (fe.rstrip("/") + "/#/settings?connected=true") if fe else "/#/settings?connected=true"
        return RedirectResponse(url=url, status_code=302)
    except Exception as e:
        auth_header = request.headers.get("Authorization") if request else None
        if auth_header and auth_header.lower().startswith("bearer "):
            return JSONResponse(status_code=400, content={"ok": False, "error": str(e)})
        import os as _os
        fe = _os.getenv("FRONTEND_BASE_URL")
        url = (fe.rstrip("/") + f"/#/settings?error={str(e)}") if fe else f"/#/settings?error={str(e)}"
        return RedirectResponse(url=url, status_code=302)


@app.get("/")
def root_page():
    return HTMLResponse(content="""<!doctype html><html><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>Altered</title><style>body{font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,Ubuntu,Helvetica,Arial,sans-serif;margin:0;padding:24px;background:#111;color:#eee} .card{max-width:720px;margin:0 auto;background:#1b1b1b;border:1px solid #2a2a2a;border-radius:12px;padding:24px;box-shadow:0 8px 24px rgba(0,0,0,0.4)} .title{font-size:22px;margin:0 0 8px} .ok{color:#4caf50} .err{color:#f44336} .muted{color:#aaa;font-size:14px} .btn{display:inline-block;margin-top:12px;padding:8px 12px;border-radius:8px;background:#2b2b2b;color:#eee;text-decoration:none;border:1px solid #3a3a3a}</style></head><body><div class=\"card\"><h1 class=\"title\">Altered API</h1><p id=\"message\" class=\"muted\">Server running.</p><a class=\"btn\" href=\"/#/settings\">Back to Settings</a></div><script>const h=(window.location.hash||'');const m=document.getElementById('message');if(h.includes('settings')&&h.includes('connected=true')){m.textContent='Google Calendar connected. You can close this tab.';m.className='ok';}else if(h.includes('error=')){const e=decodeURIComponent(h.split('error=')[1]||'');m.textContent='Google Calendar connection failed: '+e;m.className='err';}</script></body></html>""")


@app.get("/favicon.ico")
def favicon():
    return Response(status_code=204, media_type="image/x-icon")


@app.delete("/auth/google/calendar")
def api_oauth_calendar_revoke(request: Request):
    """Revoke calendar access and delete tokens."""
    uid = get_user_id_from_request(request) if request else _uid(None)

    try:
        user_settings = UserSettings(uid)

        # Get tokens to revoke
        tokens = user_settings.get_oauth_tokens("google_calendar")

        if tokens:
            # Revoke access token
            oauth_handler = GoogleOAuthHandler()
            oauth_handler.revoke_token(tokens["access_token"])

        # Delete tokens from Firestore
        delete_result = user_settings.delete_oauth_tokens("google_calendar")

        return delete_result
    except Exception as e:
        return JSONResponse(status_code=500, content={"ok": False, "error": str(e)})


@app.get("/auth/google/calendar/status")
def api_oauth_calendar_status(request: Request):
    uid = get_user_id_from_request(request) if request else _uid(None)

    try:
        user_settings = UserSettings(uid)
        connected_flag = user_settings.is_oauth_connected("google_calendar")
        has_tokens = user_settings.has_oauth_tokens("google_calendar")
        meta = user_settings.get_oauth_token_metadata("google_calendar")

        # Proactive Token Refresh Logic
        # -----------------------------
        # Check if token is expired or expiring soon (within 5 minutes)
        # If so, refresh it immediately so the agent has a valid token for the first query.
        try:
            tokens = user_settings.get_oauth_tokens("google_calendar")
            if tokens and tokens.get("expires_at") and tokens.get("refresh_token"):
                from datetime import datetime, timedelta
                from services.oauth_handlers import GoogleOAuthHandler

                expires_at_str = tokens.get("expires_at")
                try:
                    expires_dt = datetime.fromisoformat(expires_at_str)
                    if expires_dt.tzinfo is not None:
                        expires_dt = expires_dt.astimezone().replace(tzinfo=None)

                    # If expiring within 5 minutes (or already expired)
                    if datetime.now() >= (expires_dt - timedelta(minutes=5)):
                        print(f"[{uid}] Proactively refreshing calendar token in status check")
                        oauth = GoogleOAuthHandler()
                        refresh_res = oauth.refresh_access_token(tokens["refresh_token"])

                        if refresh_res.get("ok"):
                            # Save new tokens
                            user_settings.save_oauth_tokens(
                                provider="google_calendar",
                                access_token=refresh_res["access_token"],
                                refresh_token=tokens["refresh_token"],
                                expires_at=refresh_res["expires_at"],
                                scopes=tokens.get("scopes", [])
                            )
                            # Update local meta for response
                            meta = user_settings.get_oauth_token_metadata("google_calendar")
                            has_tokens = True
                        else:
                            print(f"[{uid}] Proactive refresh failed: {refresh_res.get('error')}")
                except Exception as e:
                    print(f"[{uid}] Error checking token expiry: {e}")
        except Exception as e:
            print(f"[{uid}] Error processing token refresh: {e}")

        expires_at = meta.get("expires_at")
        scopes = meta.get("scopes", [])

        # Don't call check_mcp_ready here - it launches the MCP server which triggers OAuth popup
        # MCP ready status will be checked when actually using calendar features
        mcp_ready = has_tokens  # Simplified

        return {
            "ok": True,
            "connected": bool(connected_flag and has_tokens),
            "details": {
                "has_tokens": has_tokens,
                "expires_at": expires_at,
                "scopes": scopes,
                "mcp_ready": mcp_ready,
            },
        }
    except Exception as e:
        return JSONResponse(status_code=500, content={"ok": False, "error": str(e)})


@app.get("/auth/google/calendar/validate")
def api_oauth_calendar_validate(request: Request):
    uid = get_user_id_from_request(request) if request else _uid(None)

    try:
        user_settings = UserSettings(uid)
        tokens = user_settings.get_oauth_tokens("google_calendar")
        if not tokens:
            return {"ok": True, "connected": False, "status": "reauth_required", "reason": "no_tokens"}

        from services.oauth_handlers import GoogleOAuthHandler
        oauth = GoogleOAuthHandler()

        from datetime import datetime, timedelta
        try:
            exp = datetime.fromisoformat(tokens["expires_at"]) if tokens.get("expires_at") else datetime.now()
            if exp.tzinfo is not None:
                exp = exp.astimezone().replace(tzinfo=None)
        except Exception:
            exp = datetime.now()
        now = datetime.now()
        needs_refresh = now >= exp or (exp - now) <= timedelta(minutes=5)

        if needs_refresh:
            r = oauth.refresh_access_token(tokens["refresh_token"]) if tokens.get("refresh_token") else {"ok": False}
            if r.get("ok"):
                user_settings.save_oauth_tokens(
                    provider="google_calendar",
                    access_token=r["access_token"],
                    refresh_token=tokens["refresh_token"],
                    expires_at=r["expires_at"],
                    scopes=tokens.get("scopes", [])
                )
                return {"ok": True, "connected": True, "status": "ready", "refreshed": True}
            else:
                return {"ok": True, "connected": False, "status": "reauth_required", "reason": "refresh_failed"}

        return {"ok": True, "connected": True, "status": "ready", "refreshed": False}
    except Exception as e:
        return JSONResponse(status_code=500, content={"ok": False, "error": str(e)})


@app.get("/auth/google/userinfo")
def api_google_userinfo(request: Request):
    uid = get_user_id_from_request(request) if request else _uid(None)
    try:
        user_settings = UserSettings(uid)
        tokens = user_settings.get_oauth_tokens("google_calendar")
        if not tokens:
            return JSONResponse(status_code=401, content={"ok": False, "error": "not_connected"})

        from datetime import datetime, timedelta
        try:
            exp = datetime.fromisoformat(tokens["expires_at"]) if tokens.get("expires_at") else datetime.now()
            if exp.tzinfo is not None:
                exp = exp.astimezone().replace(tzinfo=None)
        except Exception:
            exp = datetime.now()
        now = datetime.now()
        access_token = tokens.get("access_token")
        if now >= exp or (exp - now) <= timedelta(minutes=5):
            from services.oauth_handlers import GoogleOAuthHandler
            oauth = GoogleOAuthHandler()
            r = oauth.refresh_access_token(tokens.get("refresh_token", ""))
            if r.get("ok"):
                user_settings.save_oauth_tokens(
                    provider="google_calendar",
                    access_token=r["access_token"],
                    refresh_token=tokens.get("refresh_token", ""),
                    expires_at=r["expires_at"],
                    scopes=tokens.get("scopes", [])
                )
                access_token = r["access_token"]
            else:
                return JSONResponse(status_code=401, content={"ok": False, "error": "refresh_failed"})

        import requests as _requests
        resp = _requests.get(
            "https://www.googleapis.com/oauth2/v2/userinfo",
            headers={"Authorization": f"Bearer {access_token}"},
            timeout=8,
        )
        if resp.status_code != 200:
            return JSONResponse(status_code=resp.status_code, content={"ok": False, "error": "userinfo_error", "detail": resp.text})
        data = resp.json()
        return {"ok": True, "email": data.get("email"), "name": data.get("name"), "picture": data.get("picture")}
    except Exception as e:
        return JSONResponse(status_code=500, content={"ok": False, "error": str(e)})

# ===== API Key Management Endpoints =====

@app.post("/settings/api-key")
def api_save_api_key(request: Request, payload: Dict[str, Any] = Body(...)):
    """Save user's custom Gemini API key."""
    uid = get_user_id_from_request(request) if request else _uid(None)
    api_key = payload.get("api_key", "")

    if not api_key:
        return JSONResponse(status_code=400, content={"ok": False, "error": "API key is required"})

    try:
        user_settings = UserSettings(uid)
        result = user_settings.save_api_key(api_key)
        try:
            from services.metrics_service import record_security_event
            record_security_event("api_key_saved", {"source": "user", "status": "ok" if result.get("ok") else "error"})
        except Exception:
            pass
        return result
    except Exception as e:
        return JSONResponse(status_code=500, content={"ok": False, "error": str(e)})


@app.get("/settings/api-key/status")
def api_api_key_status(request: Request):
    """Check if user has custom API key."""
    uid = get_user_id_from_request(request) if request else _uid(None)

    try:
        user_settings = UserSettings(uid)
        has_key = user_settings.has_custom_api_key()

        return {"ok": True, "has_custom_key": has_key}
    except Exception as e:
        return JSONResponse(status_code=500, content={"ok": False, "error": str(e)})


@app.get("/runtime/status")
def api_runtime_status(request: Request):
    uid = get_user_id_from_request(request) if request else _uid(None)
    try:
        user_settings = UserSettings(uid)
        has_key = user_settings.has_custom_api_key()
        v_client = VertexAIClient(user_id=uid)
        vertex_available = bool(v_client.vertex_ai_available)
        mode = "unconfigured"
        if has_key:
            mode = "byok"
        elif vertex_available:
            mode = "vertex_ai"
        from services.credit_service import get_credit_service
        credit_service = get_credit_service()
        balance = credit_service.get_balance(uid)
        endpoint = None
        if mode == "vertex_ai":
            endpoint = "aiplatform.googleapis.com"
        elif mode == "byok":
            endpoint = "generativelanguage.googleapis.com"
        return {
            "ok": True,
            "mode": mode,
            "vertex": {
                "available": vertex_available,
                "project": v_client.project_id,
                "location": v_client.location,
            },
            "byok": {
                "has_custom_key": has_key,
            },
            "credits": balance,
            "endpoint": endpoint,
        }
    except Exception as e:
        return JSONResponse(status_code=500, content={"ok": False, "error": str(e)})


@app.delete("/settings/api-key")
def api_delete_api_key(request: Request):
    """Remove user's custom API key."""
    uid = get_user_id_from_request(request) if request else _uid(None)

    try:
        user_settings = UserSettings(uid)
        result = user_settings.delete_api_key()
        try:
            from services.metrics_service import record_security_event
            record_security_event("api_key_deleted", {"source": "user", "status": "ok" if result.get("ok") else "error"})
        except Exception:
            pass
        return result
    except Exception as e:
        return JSONResponse(status_code=500, content={"ok": False, "error": str(e)})


@app.post("/settings/api-key/rotate")
def api_rotate_api_key(request: Request):
    """Re-wrap user's Gemini API key with a new salt (logical rotation)."""
    uid = get_user_id_from_request(request) if request else _uid(None)
    try:
        us = UserSettings(uid)
        current = us.get_api_key()
        if not current:
            return {"ok": False, "error": "no_key"}
        res = us.save_api_key(current)
        try:
            from services.metrics_service import record_security_event
            record_security_event("api_key_rotated", {"status": "ok" if res.get("ok") else "error"})
        except Exception:
            pass
        return res
    except Exception as e:
        return JSONResponse(status_code=500, content={"ok": False, "error": str(e)})


# ===== Credit Management Endpoints =====

@app.get("/credits/balance")
def api_get_credit_balance(request: Request):
    """Get user's current credit balance."""
    uid = get_user_id_from_request(request) if request else _uid(None)

    try:
        from services.credit_service import get_credit_service
        credit_service = get_credit_service()
        return credit_service.get_balance(uid)
    except Exception as e:
        return JSONResponse(status_code=500, content={"ok": False, "error": str(e)})


@app.get("/credits/history")
def api_get_credit_history(request: Request, limit: int = 50):
    """Get user's credit transaction history."""
    uid = get_user_id_from_request(request) if request else _uid(None)

    try:
        from services.credit_service import get_credit_service
        credit_service = get_credit_service()
        return credit_service.get_transaction_history(uid, limit=limit)
    except Exception as e:
        return JSONResponse(status_code=500, content={"ok": False, "error": str(e)})


# Admin endpoints (TODO: add proper admin authentication)
@app.post("/admin/credits/allocate")
def api_admin_allocate_credits(request: Request, payload: Dict[str, Any] = Body(...)):
    """Admin endpoint to allocate credits to a user."""
    admin_token = request.headers.get("X-Admin-Token")
    expected = os.getenv("ADMIN_API_TOKEN")
    if not expected or admin_token != expected:
        return JSONResponse(status_code=401, content={"ok": False, "error": "unauthorized"})
    admin_uid = get_user_id_from_request(request) if request else _uid(None)
    user_id = payload.get("user_id")
    amount = payload.get("amount")
    reason = payload.get("reason", "admin_grant")

    if not user_id or amount is None:
        return JSONResponse(status_code=400, content={"ok": False, "error": "user_id and amount required"})

    try:
        from services.credit_service import get_credit_service
        credit_service = get_credit_service()
        result = credit_service.add_credits(
            user_id=user_id,
            amount=amount,
            reason=reason,
            metadata={"admin_id": admin_uid}
        )
        return result
    except Exception as e:
        return JSONResponse(status_code=500, content={"ok": False, "error": str(e)})


@app.post("/admin/credits/initialize")
def api_admin_initialize_credits(request: Request, payload: Dict[str, Any] = Body(...)):
    """Admin endpoint to manually initialize credits for a user."""
    admin_token = request.headers.get("X-Admin-Token")
    expected = os.getenv("ADMIN_API_TOKEN")
    if not expected or admin_token != expected:
        return JSONResponse(status_code=401, content={"ok": False, "error": "unauthorized"})
    user_id = payload.get("user_id")

    if not user_id:
        return JSONResponse(status_code=400, content={"ok": False, "error": "user_id required"})

    try:
        from services.credit_service import get_credit_service
        credit_service = get_credit_service()
        return credit_service.initialize_user_credits(user_id)
    except Exception as e:
        return JSONResponse(status_code=500, content={"ok": False, "error": str(e)})



@app.post("/chat/respond")
async def api_chat_respond(request: Request, payload: Dict[str, Any] = Body(...)):
    """
    Main chat endpoint for generating agent responses.

    This endpoint orchestrates the entire response generation process:
    1. Receives user input.
    2. Calls `adk_respond` (or fallback logic) to process the input.
    3. Executes any necessary tools (e.g., calendar, search).
    4. Returns the final text response and any tool outputs.

    Args:
        request (Request): HTTP request.
        payload (Dict[str, Any]): JSON payload containing "text" and optional "session_id".

    Returns:
        dict: Response containing "text", "tools", and "session_id".
    """
    uid = get_user_id_from_request(request) if request else _uid(None)
    text = payload.get("text", "")
    session_id = payload.get("session_id") or uuid4().hex
    country_code = payload.get("country")
    try:
        tz_name = request.headers.get("X-Client-Timezone") if request else None
        try:
            from services.metrics_service import enforce_rate_limit
            if not enforce_rate_limit(uid):
                return {"text": "Rate limit exceeded. Please wait a minute and try again.", "tools": [], "session_id": session_id, "error": "rate_limited"}
        except Exception:
            pass
        # Handle direct date/time queries using client timezone offset or IANA timezone (device time)
        try:
            lowq = (text or "").lower()
            if any(k in lowq for k in ["today's date", "todays date", "today date", "what's the date", "what is the date", "current time", "what time is it"]):
                from datetime import datetime, timezone, timedelta, tzinfo
                from zoneinfo import ZoneInfo
                offset_str = request.headers.get("X-Client-Offset-Minutes") if request else None
                offset = int(offset_str) if (offset_str and offset_str.strip().lstrip("-+").isdigit()) else 0
                now_utc = datetime.utcnow().replace(tzinfo=timezone.utc)
                local_tz: tzinfo
                if tz_name:
                    try:
                        local_tz = ZoneInfo(tz_name)
                    except Exception:
                        local_tz = timezone(timedelta(minutes=offset))
                else:
                    local_tz = timezone(timedelta(minutes=offset))
                now_local = now_utc.astimezone(local_tz)
                # Format friendly date (e.g., Monday, December 8, 2025)
                friendly = now_local.strftime("%A, %B %-d, %Y") if hasattr(now_local, "strftime") else now_local.isoformat()
                # Some platforms don't support %-d (day w/o leading zero); fallback
                try:
                    friendly = now_local.strftime("%A, %B %-d, %Y")
                except Exception:
                    friendly = now_local.strftime("%A, %B %d, %Y")
                time_str = now_local.strftime("%I:%M %p")
                return {"text": f"Today is {friendly}. The local time is {time_str}.", "tools": [{"ui_mode": "internal", "result": {"offset_minutes": offset, "timezone": tz_name, "iso": now_local.isoformat()}}], "session_id": session_id}
        except Exception:
            pass
        try:
            # Set timezone context for tools relative to THIS request
            token_tz = current_user_timezone.set(tz_name)
            try:
                last_text, tool_results = await adk_respond(uid, session_id, text, time_zone=tz_name, country_code=country_code)
            finally:
                current_user_timezone.reset(token_tz)
        except Exception as e:
            # Just log and continue if adk_respond fails (it handles its own errors usually but wrapping here is safe)
            raise e
        return {"text": last_text, "tools": tool_results, "session_id": session_id}
    except Exception as e:
        msg = str(e)
        try:
            print(f"[{datetime.now().isoformat()}] /chat/respond error uid={uid} sid={session_id}: {msg}")
        except Exception:
            pass
        # Basic structured error payload for client diagnostics
        err: Dict[str, Any] = {"message": msg}
        if "INTERNAL" in msg:
            err["code"] = 500
            err["status"] = "INTERNAL"
        # Graceful overload feedback
        if "UNAVAILABLE" in msg or "overloaded" in msg:
            return {"text": "The model is temporarily overloaded. Please try again in a moment.", "tools": [], "session_id": session_id, "error": "model_overloaded", "error_detail": err}
        # Fallbacks: calendar intent, then optional Google Search when enabled
        try:
            low = text.lower()
            if "calendar" in low or "event" in low or "add an event" in low:
                from services.calendar_mcp import create_calendar_event_intent, _create_event_async, _create_recurring_event_async
                intent = create_calendar_event_intent(text, default_title="Appointment")
                if intent.get("ok") and intent.get("intent"):
                    i = intent["intent"]
                    if i.get("recurrence"):
                        res = await _create_recurring_event_async(i["summary"], i["start"], i["end"], i["recurrence"], calendar_id="primary", location=i.get("location"), description=i.get("description"), user_id=uid, time_zone=tz_name)
                    else:
                        res = await _create_event_async(i["summary"], i["start"], i["end"], i.get("location"), i.get("description"), user_id=uid, time_zone=tz_name)
                    msg_nl = _nl_event_confirmation(i["summary"], i["start"], i["end"], i.get("location"), "your primary calendar")
                    return {"text": msg_nl, "tools": [{"ui_mode": "internal", "result": res}], "session_id": session_id}
            use_search = bool(payload.get('google_search'))
            if use_search:
                if _SEARCH_TOOL is None:
                    msg_nl = "Google Search is enabled but unavailable."
                    return {"text": msg_nl, "tools": [{"ui_mode": "internal", "result": {"ok": False, "error": "google.adk.tools not installed"}}], "session_id": session_id}
                try:
                    search_agent = LlmAgent(
                        model=Gemini(model=os.getenv("DEFAULT_MODEL", "gemini-2.0-flash")),
                        name="SearchAgent",
                        instruction="Use Google Search to find reliable sources and provide concise summaries.",
                        tools=[_SEARCH_TOOL],
                    )
                    runner = Runner(agent=search_agent, app_name="altered", session_service=InMemorySessionService())
                    content = types.Content(role="user", parts=[types.Part(text=text)])
                    last_text = ""
                    search_tool_results: list = []
                    async def _run():
                        async for ev in runner.run_async(user_id=uid, session_id=session_id, new_message=content):
                            if ev.content and ev.content.parts:
                                t = ev.content.parts[0].text
                                if t and t != "None":
                                    last_text = t
                            if getattr(ev, "actions", None) and getattr(ev.actions, "tools", None):
                                for tl in ev.actions.tools:
                                    search_tool_results.append(tl)
                        return last_text, search_tool_results
                    last_text, search_tool_results = await _run()
                    msg_nl = last_text or "Here are a few things I found."
                    return {"text": msg_nl, "tools": search_tool_results, "session_id": session_id}
                except Exception as ge:
                    msg_nl = f"Google Search fallback error: {str(ge)}"
                    return {"text": msg_nl, "tools": [{"ui_mode": "internal", "error": str(ge)}], "session_id": session_id}
        except Exception as fe:
            # include fallback error detail but do not crash
            err["fallback_error"] = str(fe)
        return {"text": f"An error occurred: {msg}", "tools": [], "session_id": session_id, "error": msg, "error_detail": err}


@app.post("/chat/command")
def api_chat_command(request: Request, payload: Dict[str, Any] = Body(...)):
    """
    Execute a specific chat command (e.g., /clear, /help).

    Args:
        request (Request): HTTP request.
        payload (Dict[str, Any]): JSON payload containing "text" (command) and "session_id".

    Returns:
        dict: Result of the command execution.
    """
    uid = get_user_id_from_request(request) if request else _uid(None)
    text = payload.get("text", "")
    session_id = payload.get("session_id") or uuid4().hex
    cmd, args = parse_chat_command(text)
    tz_name = request.headers.get("X-Client-Timezone") if request else None
    res = execute_chat_command(uid, session_id, cmd, args, tz_name)
    return {"ok": res.get("ok", False), **res, "session_id": session_id}


@app.get("/chat/help")
def api_chat_help():
    """
    Get help text for available chat commands.

    Returns:
        str: Help text.
    """
    return chat_help()

def _nl_event_confirmation(title: str, start_iso: str, end_iso: str, location: Optional[str] = None, calendar_label: Optional[str] = None) -> str:
    """
    Helper to generate a natural language confirmation for a created event.
    """
    try:
        s_str = start_iso
        e_str = end_iso
        if s_str.endswith("Z"):
            s_str = s_str[:-1] + "+00:00"
        if e_str.endswith("Z"):
            e_str = e_str[:-1] + "+00:00"
        s = datetime.fromisoformat(s_str)
        e = datetime.fromisoformat(e_str)
        now_same_tz = datetime.now(s.tzinfo) if s.tzinfo else datetime.now().astimezone()
        today = now_same_tz.date()
        day_phrase = s.strftime("%A %b %d")
        # safer tomorrow check
        try:
            from datetime import timedelta
            if s.date() == (today + timedelta(days=1)):
                day_phrase = "tomorrow"
            elif s.date() == today:
                day_phrase = "today"
        except Exception:
            pass
        dur_min = max(1, int((e - s).total_seconds() // 60))
        if dur_min % 60 == 0:
            dur_phrase = f"{dur_min // 60} hour" + ("s" if (dur_min // 60) != 1 else "")
        else:
            dur_phrase = f"{dur_min} minutes"
        tstr = s.strftime("%I:%M %p").lstrip("0")
        loc_phrase = f" at {location.strip()}" if location and location.strip() else ""
        cal_phrase = f" on {calendar_label}" if calendar_label else ""
        return f"I've scheduled '{title}' {day_phrase} at {tstr}{loc_phrase} for {dur_phrase}{cal_phrase}."
    except Exception:
        extra = f" at {location}" if location else ""
        return f"Event created: {title} ({start_iso} - {end_iso}){extra}."


# ===== Real-time Voice WebSocket =====

@app.websocket("/ws/voice")
async def voice_websocket(websocket: WebSocket):
    """
    WebSocket endpoint for real-time voice conversations using Gemini Live API.
    
    Protocol:
    - Client sends: {"type": "audio", "data": "<base64 PCM audio>"}
    - Client sends: {"type": "text", "data": "<text message>"}
    - Client sends: {"type": "config", "voice": "...", "system_prompt": "..."}
    - Server sends: {"type": "audio", "data": "<base64 PCM audio>"}
    - Server sends: {"type": "text", "data": "<text>"}
    - Server sends: {"type": "transcript", "data": "<transcript>", "is_final": bool}
    - Server sends: {"type": "state", "state": "<state>"}
    - Server sends: {"type": "error", "message": "<error>"}
    
    Query parameters:
    - user_id: User identifier
    - voice: Voice name (default: Aoede)
    - system_prompt: System instruction for the model
    """
    await websocket.accept()

    # Get query parameters
    user_id = websocket.query_params.get("user_id", "anonymous")
    voice = websocket.query_params.get("voice", "Aoede")
    system_prompt = websocket.query_params.get("system_prompt", "")

    # If system_prompt not in query, try to get from first message
    if not system_prompt:
        system_prompt = """You are NeuroPilot, a supportive AI assistant designed specifically for people with ADHD. 
You help with task management, focus sessions, and provide encouragement. 
Keep responses concise and actionable. Be warm, understanding, and patient.
When the user seems overwhelmed, help break things down into smaller steps."""

    logger.info(f"Voice WebSocket connection from user {user_id}, voice={voice}")

    try:
        await handle_voice_websocket(
            websocket=websocket,
            user_id=user_id,
            system_prompt=system_prompt,
            voice=voice,
        )
    except WebSocketDisconnect:
        logger.info(f"Voice WebSocket disconnected for user {user_id}")
    except Exception as e:
        logger.error(f"Voice WebSocket error for user {user_id}: {e}", exc_info=True)
        try:
            await websocket.send_json({"type": "error", "message": str(e)})
        except Exception:
            pass


@app.get("/voice/status")
async def voice_status():
    """
    Check the status of the Gemini Live API service.
    """
    initialized = GeminiLiveService.initialize()
    return {
        "ok": initialized,
        "service": "gemini_live",
        "status": "available" if initialized else "unavailable",
    }
