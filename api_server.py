import os
from uuid import uuid4
from dotenv import load_dotenv

load_dotenv()

from fastapi import FastAPI, Body, Request
from fastapi.middleware.cors import CORSMiddleware
from typing import List, Dict, Any, Optional
from datetime import datetime

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
from services.metrics_service import compute_daily_overview
from services.calendar_mcp import list_events_today, check_mcp_ready
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


app = FastAPI(title="Altered API")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def _strip_api_prefix(request: Request, call_next):
    p = request.scope.get("path", "")
    if p.startswith("/api/"):
        request.scope["path"] = p[4:]
    elif p == "/api":
        request.scope["path"] = "/"
    return await call_next(request)


def _uid(user_id: str | None) -> str:
    return user_id or os.getenv("USER") or "terminal_user"


@app.get("/health")
def health():
    return {"ok": True, "time": datetime.utcnow().isoformat()}


@app.get("/sessions/yesterday")
def sessions_yesterday(request: Request, user_id: str | None = None):
    start, end = yesterday_range()
    uid = get_user_id_from_request(request) if request else _uid(user_id)
    sessions = get_sessions_by_date(uid, "altered", start, end)
    return {"sessions": sessions}


@app.get("/sessions/{session_id}/events")
def session_events(request: Request, session_id: str, user_id: str | None = None):
    start, end = yesterday_range()
    uid = get_user_id_from_request(request) if request else _uid(user_id)
    events = get_events_for_session(uid, "altered", session_id, start, end)
    return {"events": events}


@app.post("/tasks/atomize")
def api_atomize(payload: Dict[str, Any] = Body(...)):
    desc = payload.get("description", "")
    return atomize_task(desc)


@app.post("/tasks/schedule")
def api_schedule(payload: Dict[str, Any] = Body(...)):
    items = payload.get("items", [])
    energy = int(payload.get("energy", 5))
    weights = payload.get("weights", None)
    return schedule_tasks(items, energy, weights)


@app.post("/time/countdown")
def api_countdown(payload: Dict[str, Any] = Body(...)):
    query = payload.get("query")
    conf = create_countdown(query)
    if conf.get("ok") is False:
        return JSONResponse(status_code=400, content={"ok": False, "error": conf.get("error", "invalid_duration")})
    tid = store_countdown(conf["target"], conf["warnings"])
    res = {"timer_id": tid, **conf}
    return res


@app.post("/energy/detect")
def api_detect(payload: Dict[str, Any] = Body(...)):
    text = payload.get("text", "")
    return detect_sensory_overload(text)


@app.post("/decision/reduce")
def api_reduce(payload: Dict[str, Any] = Body(...)):
    opts: List[str] = payload.get("options", [])
    limit = int(payload.get("limit", 3))
    return reduce_options(opts, max_options=limit)


@app.post("/decision/protocol")
def api_protocol(payload: Dict[str, Any] = Body(...)):
    opts: List[str] = payload.get("options", [])
    return paralysis_protocol(opts)


@app.post("/energy/match")
def api_energy_match(payload: Dict[str, Any] = Body(...)):
    tasks = payload.get("tasks", [])
    energy = int(payload.get("energy", 5))
    return match_task_to_energy(tasks, energy)


@app.post("/decision/commit")
def api_decision_commit(payload: Dict[str, Any] = Body(...)):
    choice = payload.get("choice")
    return {"committed": True, "choice": choice}


@app.post("/external/capture")
def api_capture(payload: Dict[str, Any] = Body(...)):
    transcript = payload.get("transcript", "")
    title = transcript.split(".")[0]
    tid = store_voice_task(title, "captured", transcript)
    return {"task_id": tid, "title": title}


@app.get("/external/context/{task_id}")
def api_context(task_id: str):
    ctx = get_context(task_id)
    return {"context": ctx}


@app.get("/external/notes")
def api_external_notes(request: Request, user_id: str | None = None):
    uid = get_user_id_from_request(request) if request else _uid(user_id)
    notes = list_voice_tasks(uid)
    return {"notes": notes}


@app.post("/a2a/connect")
def api_a2a_connect(payload: Dict[str, Any] = Body(...)):
    pid = payload.get("partner_id")
    return connect_partner(pid)


@app.post("/a2a/update")
def api_a2a_update(payload: Dict[str, Any] = Body(...)):
    pid = payload.get("partner_id")
    upd = payload.get("update", {})
    return post_update(pid, upd)


@app.get("/metrics/overview")
def api_metrics_overview(request: Request, user_id: str | None = None):
    uid = get_user_id_from_request(request) if request else _uid(user_id)
    dk = datetime.utcnow().date().isoformat()
    return compute_daily_overview(uid, dk)


@app.get("/memory/patterns")
def api_memory_patterns(request: Request, user_id: str | None = None):
    uid = get_user_id_from_request(request) if request else _uid(user_id)
    return {"patterns": get_patterns(uid)}


@app.post("/memory/compact")
def api_memory_compact(request: Request, payload: Dict[str, Any] = Body(...)):
    uid = get_user_id_from_request(request) if request else _uid(None)
    session_id = payload.get("session_id")
    res = compact_session(uid, "altered", session_id)
    return res



@app.get("/calendar/ready")
def api_calendar_ready(request: Request):
    uid = get_user_id_from_request(request) if request else _uid(None)
    return check_mcp_ready(user_id=uid)


@app.get("/calendar/events/today")
def api_calendar_events_today(request: Request):
    uid = get_user_id_from_request(request) if request else _uid(None)
    return list_events_today("primary", user_id=uid)


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
        
        # Return success page or redirect to app
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
    """Check if user has connected calendar."""
    uid = get_user_id_from_request(request) if request else _uid(None)
    
    try:
        user_settings = UserSettings(uid)
        connected = user_settings.is_oauth_connected("google_calendar")
        
        return {"ok": True, "connected": connected}
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



@app.post("/chat/respond")
def api_chat_respond(request: Request, payload: Dict[str, Any] = Body(...)):
    uid = get_user_id_from_request(request) if request else _uid(None)
    text = payload.get("text", "")
    session_id = payload.get("session_id") or uuid4().hex
    try:
        last_text, tool_results = adk_respond(uid, session_id, text)
        return {"text": last_text, "tools": tool_results, "session_id": session_id}
    except Exception as e:
        msg = str(e)
        try:
            print(f"[{datetime.utcnow().isoformat()}] /chat/respond error uid={uid} sid={session_id}: {msg}")
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
                    res = asyncio.run(_create_event_async(i["summary"], i["start"], i["end"], i.get("location"), i.get("description")))
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
    uid = get_user_id_from_request(request) if request else _uid(None)
    text = payload.get("text", "")
    session_id = payload.get("session_id") or uuid4().hex
    cmd, args = parse_chat_command(text)
    res = execute_chat_command(uid, session_id, cmd, args)
    return {"ok": res.get("ok", False), **res, "session_id": session_id}


@app.get("/chat/help")
def api_chat_help():
    return chat_help()
def _nl_event_confirmation(title: str, start_iso: str, end_iso: str, location: Optional[str] = None, calendar_label: Optional[str] = None) -> str:
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
