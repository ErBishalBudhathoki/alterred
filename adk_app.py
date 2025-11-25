import os
import urllib.parse
import urllib.request
import json as _json
import asyncio
from typing import Dict, Any

from google.adk.agents import LlmAgent
from google.adk.tools import google_search
from google.adk.tools.google_search_tool import GoogleSearchTool
from google.adk.runners import Runner
from sessions.firestore_session_service import FirestoreSessionService
from services.history_service import yesterday_range, get_sessions_by_date, get_events_for_session, search_events
from agents.taskflow_agent import taskflow_agent, body_double, body_double_checkin, dopamine_reframe
from agents.time_perception_agent import time_perception_agent, create_countdown, transition_helper
from agents.energy_sensory_agent import energy_sensory_agent, detect_sensory_overload, routine_vs_novelty_balancer
from agents.decision_support_agent import decision_support_agent
from agents.external_brain_agent import external_brain_agent
try:
    from orchestration.workflows import task_execution_workflow, continuous_monitors
except Exception:
    def task_execution_workflow(*args, **kwargs):
        return {"ok": False, "error": "workflow_unavailable"}
    def continuous_monitors(*args, **kwargs):
        return {"ok": False, "error": "workflow_unavailable"}
from google.adk.models.google_llm import Gemini
from google.genai import types
from datetime import datetime

from services.calendar_mcp import (
    create_calendar_event_intent,
    _create_event_async,
    _list_events_async,
    _delete_event_async,
    _update_event_async,
)
from neuropilot_starter_code import atomize_task, reduce_options, estimate_real_time, detect_hyperfocus, match_task_to_energy
from services.chat_commands import parse as parse_chat_command, execute as execute_chat_command, help as chat_help


def load_firestore_memory(query: str, timeframe: str = "yesterday") -> Dict[str, Any]:
    start, end = yesterday_range() if timeframe == "yesterday" else (None, None)
    if not start:
        return {"ok": False, "error": "Unsupported timeframe"}
    sessions = get_sessions_by_date(user_id=os.getenv("USER") or "terminal_user", app_name="altered", start_iso=start, end_iso=end)
    snippets = []
    uid = os.getenv("USER") or "terminal_user"
    for m in sessions:
        sid = m.get("session_id")
        evs = get_events_for_session(user_id=uid, app_name="altered", session_id=sid, start_iso=start, end_iso=end)
        hits = search_events(evs, query)
        for h in hits:
            snippets.append({"session_id": sid, **h})
    return {"ok": True, "results": snippets}


def preload_firestore_memory(timeframe: str = "yesterday") -> Dict[str, Any]:
    start, end = yesterday_range() if timeframe == "yesterday" else (None, None)
    uid = os.getenv("USER") or "terminal_user"
    sessions = get_sessions_by_date(user_id=uid, app_name="altered", start_iso=start, end_iso=end)
    return {"ok": True, "sessions": sessions}


async def tool_create_event(text: str) -> Dict[str, Any]:
    intent = create_calendar_event_intent(text, default_title="Appointment")
    if intent.get("ok") and intent.get("intent"):
        i = intent["intent"]
        res = await _create_event_async(i["summary"], i["start"], i["end"], i.get("location"), i.get("description"))
        return {"intent": i, "result": res}
    return {"error": "intent_parse_failed", "raw": intent}


async def tool_list_today() -> Dict[str, Any]:
    start = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0).isoformat()
    end = datetime.now().replace(hour=23, minute=59, second=59, microsecond=0).isoformat()
    return await _list_events_async("primary", start, end)


async def tool_delete_event(event_id: str) -> Dict[str, Any]:
    return await _delete_event_async("primary", event_id)


async def tool_update_event(event_id: str, start_iso: str, end_iso: str, description: str = "") -> Dict[str, Any]:
    return await _update_event_async("primary", event_id, start_iso, end_iso, description)


def tool_task_atomize(description: str) -> Dict[str, Any]:
    return atomize_task(description)


def tool_decision_reduce(options: str, limit: int = 3) -> Dict[str, Any]:
    opts = [o.strip() for o in options.split(",") if o.strip()]
    return reduce_options(opts, max_options=limit)


def tool_chat_command(text: str) -> Dict[str, Any]:
    cmd, args = parse_chat_command(text)
    res = execute_chat_command(os.getenv("USER") or "terminal_user", "session_adk", cmd, args)
    return {"kind": "chat_command", **res}


def tool_chat_help() -> Dict[str, Any]:
    return {"kind": "chat_help", **chat_help()}


    


async def auto_compact_callback(callback_context):
    try:
        user_id = callback_context._invocation_context.user_id
        app_name = callback_context._invocation_context.app_name
        session = callback_context._invocation_context.session
        from services.compaction_service import maybe_auto_compact
        maybe_auto_compact(user_id, app_name, session.id)
    except Exception:
        pass

search_tool = GoogleSearchTool(bypass_multi_tools_limit=True)

agent = LlmAgent(
    model=Gemini(model=os.getenv("DEFAULT_MODEL", "gemini-2.0-flash")),
    name="neuropilot_coordinator_adk",
    description="Coordinator agent that manages conversation and calendar operations",
    instruction=(
        "You are अल्टर्ड, a hyper-intelligent AI assistant. You MUST use the body_double tool to start/stop sessions when requested. Do NOT just reply with text. "
        "When receiving a system check-in prompt, you MUST use the body_double_checkin tool. "
        "Maintain context across turns. Prefer using chat tools to interpret natural commands: "
        "use tool_chat_command to execute CLI-equivalent operations and tool_chat_help to surface suggestions. "
        "For calendar: add, list, delete, update using the provided tools. For tasks: atomize into micro-steps. "
        "For boring tasks: use dopamine_reframe to gamify or add novelty. "
        "For decisions: reduce options and propose defaults. For time/energy: estimate_real_time, detect_hyperfocus, "
        "create_countdown, transition_helper, match_task_to_energy, detect_sensory_overload, routine_vs_novelty_balancer. "
        "Use load_firestore_memory to recall past conversations (e.g., yesterday)."
        "If you do not have enough information to answer, use google_search to find reliable sources, then summarize for the user."
    ),
    tools=[
        tool_create_event,
        tool_list_today,
        tool_delete_event,
        tool_update_event,
        tool_task_atomize,
        tool_decision_reduce,
        load_firestore_memory,
        preload_firestore_memory,
        tool_chat_command,
        tool_chat_help,
        estimate_real_time,
        detect_hyperfocus,
        create_countdown,
        transition_helper,
        match_task_to_energy,
        detect_sensory_overload,
        routine_vs_novelty_balancer,
        body_double,
        body_double_checkin,
        dopamine_reframe,
        search_tool,
    ],
    after_agent_callback=auto_compact_callback,
)

session_service = FirestoreSessionService()
runner = Runner(agent=agent, app_name="altered", session_service=session_service)
_loop = asyncio.new_event_loop()


async def _run(user_id: str, session_id: str, text: str):
    try:
        await session_service.create_session(app_name=runner.app_name, user_id=user_id, session_id=session_id)
    except Exception:
        try:
            await session_service.get_session(app_name=runner.app_name, user_id=user_id, session_id=session_id)
        except Exception:
            pass
    content = types.Content(role="user", parts=[types.Part(text=text)])
    last_text = ""
    tool_results: Any = []
    async for event in runner.run_async(user_id=user_id, session_id=session_id, new_message=content):
        if event.content and event.content.parts:
            t = event.content.parts[0].text
            if t and t != "None":
                last_text = t
        
        # Check for function calls in event
        if getattr(event, "actions", None):
            actions = event.actions
            if getattr(actions, "tools", None):
                for tool in actions.tools:
                    tool_results.append(tool)
            # Also check for function_calls attribute
            if hasattr(actions, "function_calls"):
                for fc in actions.function_calls:
                    if hasattr(fc, "result"):
                        tool_results.append(fc.result)
    
    return last_text, tool_results



def adk_respond(uid: str, session_id: str, text: str):
    import time
    tries = 2
    last_err = None
    for _ in range(tries):
        try:
            # Manual override for body double commands to ensure reliability
            if "start body double" in text.lower() or "body doubling" in text.lower():
                from agents.taskflow_agent import body_double
                tool_res = body_double("start")
                return tool_res["presence"], [tool_res]
            
            if text.startswith("System: User has been silent"):
                import re
                from agents.taskflow_agent import body_double_checkin
                # Extract duration
                m = re.search(r"duration_minutes=(\d+)", text)
                minutes = int(m.group(1)) if m else 0
                tool_res = body_double_checkin(minutes)
                return tool_res["prompt"], [tool_res]
            
            # Manual override for dopamine reframe - only for explicit negative sentiment
            # Let the agent naturally handle task mentions and provide both dopamine + atomization
            boring_keywords = ["boring", "tedious", "hate", "dreading", "procrastinating", "don't want to"]
            
            text_lower = text.lower()
            should_reframe = any(keyword in text_lower for keyword in boring_keywords)
            
            if should_reframe:
                from agents.taskflow_agent import dopamine_reframe
                task_match = text
                tool_res = dopamine_reframe(task_match)
                return tool_res["reframe"], [tool_res]

            return _loop.run_until_complete(_run(uid, session_id, text))
        except Exception as e:
            last_err = e
            s = str(e)
            if "UNAVAILABLE" in s or "overloaded" in s:
                time.sleep(0.4)
                continue
            break
    raise last_err
