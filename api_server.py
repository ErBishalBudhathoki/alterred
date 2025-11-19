import os
from uuid import uuid4
from fastapi import FastAPI, Body, Request
from fastapi.middleware.cors import CORSMiddleware
from typing import List, Dict, Any
from datetime import datetime

from services.history_service import yesterday_range, get_sessions_by_date, get_events_for_session
from services.auth import get_user_id_from_request
from services.memory_bank_service import get_patterns
from services.compaction_service import compact_session
from agents.taskflow_agent import schedule_tasks
from neuropilot_starter_code import atomize_task, reduce_options
from agents.time_perception_agent import create_countdown
from services.timer_store import store_countdown
from agents.energy_sensory_agent import detect_sensory_overload
from agents.decision_support_agent import paralysis_protocol
from neuropilot_starter_code import match_task_to_energy
from services.external_brain_store import store_voice_task, get_context
from services.a2a_service import connect_partner, post_update
from services.metrics_service import compute_daily_overview
from services.calendar_mcp import list_events_today, check_mcp_ready
from adk_app import adk_respond
from services.chat_commands import parse as parse_chat_command, execute as execute_chat_command, help as chat_help

app = FastAPI(title="NeuroPilot API")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def _uid(user_id: str | None) -> str:
    return user_id or os.getenv("USER") or "terminal_user"


@app.get("/health")
def health():
    return {"ok": True, "time": datetime.utcnow().isoformat()}


@app.get("/sessions/yesterday")
def sessions_yesterday(request: Request, user_id: str | None = None):
    start, end = yesterday_range()
    uid = get_user_id_from_request(request) if request else _uid(user_id)
    sessions = get_sessions_by_date(uid, "neuropilot", start, end)
    return {"sessions": sessions}


@app.get("/sessions/{session_id}/events")
def session_events(request: Request, session_id: str, user_id: str | None = None):
    start, end = yesterday_range()
    uid = get_user_id_from_request(request) if request else _uid(user_id)
    events = get_events_for_session(uid, "neuropilot", session_id, start, end)
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
    target = payload.get("target_iso")
    conf = create_countdown(target)
    tid = store_countdown(conf["target"], conf["warnings"])
    return {"timer_id": tid, **conf}


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
    res = compact_session(uid, "neuropilot", session_id)
    return res


@app.get("/calendar/ready")
def api_calendar_ready():
    return check_mcp_ready()


@app.get("/calendar/events/today")
def api_calendar_events_today():
    return list_events_today("primary")


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
        if "UNAVAILABLE" in msg or "overloaded" in msg:
            return {"text": "The model is temporarily overloaded. Please try again in a moment.", "tools": [], "session_id": session_id, "error": "model_overloaded"}
        return {"text": "An error occurred while processing your request.", "tools": [], "session_id": session_id, "error": msg}


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