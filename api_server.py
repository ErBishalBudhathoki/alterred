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
"""

import os
import sys
print(f"DEBUG: sys.path: {sys.path}")
print(f"DEBUG: CWD: {os.getcwd()}")
try:
    print(f"DEBUG: Files in CWD: {os.listdir('.')}")
except Exception as e:
    print(f"DEBUG: Failed to list CWD: {e}")

from uuid import uuid4
from dotenv import load_dotenv

load_dotenv()

from fastapi import FastAPI, Body, Request, Depends, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from typing import List, Dict, Any, Optional
from datetime import datetime, timezone

from services.history_service import yesterday_range, get_sessions_by_date, get_events_for_session
from services.auth import get_user_id_from_request
from services.memory_bank_service import get_patterns
from services.compaction_service import compact_session
from agents.taskflow_agent import schedule_tasks
from neuropilot_starter_code import atomize_task, reduce_options
from agents.time_perception_agent import create_countdown
from fastapi.responses import JSONResponse
from services.timer_store import store_countdown
from agents.energy_sensory_agent import detect_sensory_overload
from agents.decision_support_agent import paralysis_protocol
from neuropilot_starter_code import match_task_to_energy
from services.external_brain_store import store_voice_task, get_context, list_voice_tasks
from services.a2a_service import connect_partner, post_update
from services.metrics_service import compute_daily_overview, record_api_access

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
        find_availability,
        search_events,
        analyze_calendar,
        extract_event_from_image,
    )
    _CALENDAR_MCP_AVAILABLE = True
    print("✓ Calendar MCP module loaded successfully")
except Exception as e:
    print(f"⚠ Calendar MCP module failed to import: {e}")
    print(f"  Calendar endpoints will return 503 Service Unavailable")
    _CALENDAR_MCP_ERROR = str(e)
    # Define stub functions that return error responses
    def _mcp_unavailable_response():
        return {"ok": False, "error": f"Calendar MCP unavailable: {_CALENDAR_MCP_ERROR}"}
    
    list_events_today = lambda *args, **kwargs: _mcp_unavailable_response()
    check_mcp_ready = lambda *args, **kwargs: _mcp_unavailable_response()
    account_status = lambda *args, **kwargs: _mcp_unavailable_response()
    account_clear = lambda *args, **kwargs: _mcp_unavailable_response()
    account_migrate = lambda *args, **kwargs: _mcp_unavailable_response()
    list_events_from_calendars = lambda *args, **kwargs: _mcp_unavailable_response()
    batch_create_events = lambda *args, **kwargs: _mcp_unavailable_response()
    create_recurring_event = lambda *args, **kwargs: _mcp_unavailable_response()
    update_recurring_event = lambda *args, **kwargs: _mcp_unavailable_response()
    find_availability = lambda *args, **kwargs: _mcp_unavailable_response()
    search_events = lambda *args, **kwargs: _mcp_unavailable_response()
    analyze_calendar = lambda *args, **kwargs: _mcp_unavailable_response()
    extract_event_from_image = lambda *args, **kwargs: _mcp_unavailable_response()

from services.oauth_handlers import GoogleOAuthHandler
from services.user_settings import UserSettings
from adk_app import adk_respond

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

from services.chat_commands import parse as parse_chat_command, execute as execute_chat_command, help as chat_help
from routers.vertex_routes import router as vertex_router
from routers.byok_routes import router as byok_router


app = FastAPI(title="Altered API")

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


@app.on_event("startup")
async def startup_event():
    """
    Startup event handler for logging and diagnostics.
    This runs when the FastAPI application starts up.
    """
    print("=" * 80)
    print("🚀 Altered API Server Starting...")
    print("=" * 80)
    
    # Log environment information
    print(f"📍 Python version: {sys.version}")
    print(f"📍 Working directory: {os.getcwd()}")
    print(f"📍 PORT environment variable: {os.getenv('PORT', 'NOT SET')}")
    
    # Log critical environment variables (masked)
    env_vars = [
        "FIREBASE_PROJECT_ID",
        "GCP_PROJECT_ID",
        "GOOGLE_CLOUD_PROJECT",
        "DEFAULT_MODEL",
        "GOOGLE_API_KEY",
        "GOOGLE_OAUTH_CLIENT_ID"
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
    
    # Log MCP status
    print(f"\n📅 Calendar MCP Status: {'✓ Available' if _CALENDAR_MCP_AVAILABLE else '✗ Unavailable'}")
    if not _CALENDAR_MCP_AVAILABLE and _CALENDAR_MCP_ERROR:
        print(f"   Error: {_CALENDAR_MCP_ERROR}")
    
    # Check if google-calendar-mcp directory exists
    mcp_path = os.path.join(os.getcwd(), "google-calendar-mcp")
    if os.path.exists(mcp_path):
        print(f"✓ google-calendar-mcp directory exists at: {mcp_path}")
        build_path = os.path.join(mcp_path, "build", "index.js")
        if os.path.exists(build_path):
            print(f"✓ MCP build artifact exists")
        else:
            print(f"✗ MCP build artifact NOT found at: {build_path}")
    else:
        print(f"✗ google-calendar-mcp directory NOT found")
    
    # Log search tool status
    print(f"\n🔍 Google Search Tool: {'✓ Available' if _SEARCH_TOOL else '✗ Not available'}")
    
    print("\n" + "=" * 80)
    print("✅ Altered API Server startup complete - ready to accept connections")
    print("=" * 80)


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
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "mcp_calendar": "available" if _CALENDAR_MCP_AVAILABLE else "unavailable",
        "search_tool": "available" if _SEARCH_TOOL else "unavailable"
    }


def _uid(user_id: str | None) -> str:
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
    import time
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


@app.get("/health")
def health():
    """
    Health check endpoint.

    Used by monitoring systems (e.g., Kubernetes, load balancers) to verify
    that the service is running and responsive.

    Returns:
        dict: A dictionary containing status "ok" and the current server time.
    """
    return {"ok": True, "time": datetime.now(timezone.utc).isoformat()}


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
    start, end = yesterday_range()
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
    start, end = yesterday_range()
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
        payload (Dict[str, Any]): JSON payload containing "description" of the task.

    Returns:
        dict: The atomized task structure.
    """
    desc = payload.get("description", "")
    return atomize_task(desc)


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
def api_countdown(payload: Dict[str, Any] = Body(...)):
    """
    Create a countdown timer based on a natural language query.

    Args:
        payload (Dict[str, Any]): JSON payload containing "query" (e.g., "10 minutes").

    Returns:
        dict: The timer configuration and ID.
    """
    query = payload.get("query")
    conf = create_countdown(query)
    if conf.get("ok") is False:
        return JSONResponse(status_code=400, content={"ok": False, "error": conf.get("error", "invalid_duration")})
    tid = store_countdown(conf["target"], conf["warnings"])
    res = {"timer_id": tid, **conf}
    return res


@app.post("/energy/detect")
def api_detect(payload: Dict[str, Any] = Body(...)):
    """
    Detect sensory overload from text input.

    Delegates to `agents.energy_sensory_agent.detect_sensory_overload`.

    Args:
        payload (Dict[str, Any]): JSON payload containing "text".

    Returns:
        dict: Assessment of sensory load.
    """
    text = payload.get("text", "")
    return detect_sensory_overload(text)


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
    dk = datetime.now(timezone.utc).date().isoformat()
    return compute_daily_overview(uid, dk)


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


@app.get("/calendar/events/today")
def api_calendar_events_today(request: Request):
    """
    List calendar events for today.

    Args:
        request (Request): HTTP request.

    Returns:
        dict: List of events for today.
    """
    uid = get_user_id_from_request(request) if request else _uid(None)
    return list_events_today("primary", user_id=uid)


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
    import time
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


@app.get("/mcp/calendar/v1/credentials")
def mcp_calendar_credentials(request: Request, account: str = "normal", user_id: str | None = None, _: None = Depends(_mcp_calendar_guard)):
    import time
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
    import time
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
    import time
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
    import time
    t0 = time.time()
    uid = get_user_id_from_request(request) if request else _uid(user_id)
    cids = (payload or {}).get("calendarIds", ["primary"])
    tmin = (payload or {}).get("timeMin")
    tmax = (payload or {}).get("timeMax")
    acct = (payload or {}).get("account", "normal")
    try:
        res = list_events_from_calendars(cids, tmin, tmax, uid, acct)
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
    import time
    t0 = time.time()
    uid = get_user_id_from_request(request) if request else _uid(user_id)
    events = (payload or {}).get("events", [])
    cal = (payload or {}).get("calendarId", "primary")
    acct = (payload or {}).get("account", "normal")
    try:
        res = batch_create_events(events, cal, uid, acct)
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
    import time
    t0 = time.time()
    uid = get_user_id_from_request(request) if request else _uid(user_id)
    try:
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
    import time
    t0 = time.time()
    uid = get_user_id_from_request(request) if request else _uid(user_id)
    try:
        res = update_recurring_event(
            (payload or {}).get("calendarId", "primary"),
            (payload or {}).get("eventId"),
            (payload or {}).get("scope", "THIS"),
            (payload or {}).get("updates", {}),
            uid,
            (payload or {}).get("account", "normal"),
        )
        ms = int((time.time() - t0) * 1000)
        record_api_access("/mcp/calendar/v1/update/recurring", "success", ms)
        return res
    except Exception as e:
        ms = int((time.time() - t0) * 1000)
        record_api_access("/mcp/calendar/v1/update/recurring", "error", ms, str(e))
        return JSONResponse(status_code=500, content={"ok": False, "error": str(e)})


@app.post("/mcp/calendar/v1/availability")
def mcp_calendar_availability(request: Request, payload: Dict[str, Any] = Body(...), user_id: str | None = None, _: None = Depends(_mcp_calendar_guard)):
    """
    Find availability across calendars (v1)

    Auth: `X-Calendar-MCP-Token`
    Body: { "calendarIds": [...], "durationMinutes": 90, "timeMin":"...", "timeMax":"...", "preference":"afternoon" }
    """
    import time
    t0 = time.time()
    uid = get_user_id_from_request(request) if request else _uid(user_id)
    try:
        res = find_availability(
            (payload or {}).get("calendarIds", ["primary"]),
            int((payload or {}).get("durationMinutes", 60)),
            (payload or {}).get("timeMin"),
            (payload or {}).get("timeMax"),
            (payload or {}).get("preference"),
            uid,
            (payload or {}).get("account", "normal"),
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
    import time
    t0 = time.time()
    uid = get_user_id_from_request(request) if request else _uid(user_id)
    try:
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
    import time
    t0 = time.time()
    uid = get_user_id_from_request(request) if request else _uid(user_id)
    try:
        res = analyze_calendar(
            (payload or {}).get("calendarIds", ["primary"]),
            (payload or {}).get("timeMin"),
            (payload or {}).get("timeMax"),
            uid,
            (payload or {}).get("account", "normal"),
        )
        ms = int((time.time() - t0) * 1000)
        record_api_access("/mcp/calendar/v1/analyze", "success", ms)
        return res
    except Exception as e:
        ms = int((time.time() - t0) * 1000)
        record_api_access("/mcp/calendar/v1/analyze", "error", ms, str(e))
        return JSONResponse(status_code=500, content={"ok": False, "error": str(e)})


@app.post("/mcp/calendar/v1/extract")
def mcp_calendar_extract(request: Request, payload: Dict[str, Any] = Body(...), _: None = Depends(_mcp_calendar_guard)):
    """
    Extract event details from an image (v1)

    Auth: `X-Calendar-MCP-Token`
    Body: { "imageBase64":"...", "mimeType":"image/png" } OR { "imagePath":"/path/to.png" }
    """
    import base64, time
    t0 = time.time()
    img_b64 = (payload or {}).get("imageBase64")
    mime = (payload or {}).get("mimeType", "image/png")
    img_path = (payload or {}).get("imagePath")
    try:
        if img_b64:
            data = base64.b64decode(img_b64)
            res = extract_event_from_image(data, (payload or {}).get("userInstruction"))
        elif img_path:
            res = extract_event_from_image(img_path, (payload or {}).get("userInstruction"))
        else:
            return JSONResponse(status_code=400, content={"ok": False, "error": "missing_image"})
        ms = int((time.time() - t0) * 1000)
        record_api_access("/mcp/calendar/v1/extract", "success", ms)
        return res
    except Exception as e:
        ms = int((time.time() - t0) * 1000)
        record_api_access("/mcp/calendar/v1/extract", "error", ms, str(e))
        return JSONResponse(status_code=500, content={"ok": False, "error": str(e)})


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

        return {"ok": True, "message": "Calendar connected successfully"}
    except Exception as e:
        return JSONResponse(status_code=500, content={"ok": False, "error": str(e)})


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
        tokens = user_settings.get_oauth_tokens("google_calendar")
        connected_flag = user_settings.is_oauth_connected("google_calendar")

        has_tokens = bool(tokens)
        expires_at = tokens["expires_at"] if tokens else None
        scopes = tokens["scopes"] if tokens else []

        # Don't call check_mcp_ready here - it launches the MCP server which triggers OAuth popup
        # MCP ready status will be checked when actually using calendar features
        mcp_ready = has_tokens  # Simplified - assume ready if tokens exist

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
            exp = datetime.fromisoformat(tokens["expires_at"]) if tokens.get("expires_at") else datetime.now(timezone.utc)
            if exp.tzinfo is None:
                from datetime import timezone as _tz
                exp = exp.replace(tzinfo=_tz.utc)
        except Exception:
            exp = datetime.now(timezone.utc)
        now = datetime.now(timezone.utc)
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
            exp = datetime.fromisoformat(tokens["expires_at"]) if tokens.get("expires_at") else datetime.now(timezone.utc)
            if exp.tzinfo is None:
                from datetime import timezone as _tz
                exp = exp.replace(tzinfo=_tz.utc)
        except Exception:
            exp = datetime.now(timezone.utc)
        now = datetime.now(timezone.utc)
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


@app.delete("/settings/api-key")
def api_delete_api_key(request: Request):
    """Remove user's custom API key."""
    uid = get_user_id_from_request(request) if request else _uid(None)
    
    try:
        user_settings = UserSettings(uid)
        result = user_settings.delete_api_key()
        
        return result
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
def api_chat_respond(request: Request, payload: Dict[str, Any] = Body(...)):
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
    try:
        last_text, tool_results = adk_respond(uid, session_id, text)
        return {"text": last_text, "tools": tool_results, "session_id": session_id}
    except Exception as e:
        msg = str(e)
        try:
            print(f"[{datetime.now(timezone.utc).isoformat()}] /chat/respond error uid={uid} sid={session_id}: {msg}")
        except Exception:
            pass
        # Basic structured error payload for client diagnostics
        err = {"message": msg}
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
                import asyncio
                from services.calendar_mcp import create_calendar_event_intent, _create_event_async
                intent = create_calendar_event_intent(text, default_title="Appointment")
                if intent.get("ok") and intent.get("intent"):
                    i = intent["intent"]
                    res = asyncio.run(_create_event_async(i["summary"], i["start"], i["end"], i.get("location"), i.get("description"), user_id=uid))
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
                    tool_results: list = []
                    import asyncio as _asyncio
                    async def _run():
                        async for ev in runner.run_async(user_id=uid, session_id=session_id, new_message=content):
                            if ev.content and ev.content.parts:
                                t = ev.content.parts[0].text
                                if t and t != "None":
                                    last_text = t
                            if getattr(ev, "actions", None) and getattr(ev.actions, "tools", None):
                                for tl in ev.actions.tools:
                                    tool_results.append(tl)
                        return last_text, tool_results
                    last_text, tool_results = _asyncio.run(_run())
                    msg_nl = last_text or "Here are a few things I found."
                    return {"text": msg_nl, "tools": tool_results, "session_id": session_id}
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
    res = execute_chat_command(uid, session_id, cmd, args)
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
        s = datetime.fromisoformat(start_iso)
        e = datetime.fromisoformat(end_iso)
        today = datetime.now().date()
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
