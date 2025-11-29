"""
Altered ADK Application
=======================
This module defines the integration with Google's Agent Development Kit (ADK).
It orchestrates the `LlmAgent`, tools, and session management for the "altered" application.
Architecture:
-------------
- **LlmAgent:** Uses the Gemini model to drive a conversational agent.
- **Tools:** Integrates various tools for calendar management, task atomization,
  decision support, and memory retrieval.
- **Session Management:** Uses `FirestoreSessionService` to persist session state
  across interactions.
- **Callbacks:** Implements `auto_compact_callback` to optimize memory usage
  after agent execution.
Design Decisions:
-----------------
- **Tool Wrappers:** Functions like `tool_create_event` wrap underlying service
  calls to provide a clean interface for the LLM.
- **Manual Overrides:** The `adk_respond` function includes manual overrides for
  specific triggers (e.g., body doubling, dopamine reframe) to ensure reliability
  and immediate response for critical user needs.
- **Async Execution:** Uses `asyncio` to handle asynchronous tool execution and
  agent processing efficiently.
"""
import os
import urllib.parse
import urllib.request
import json as _json
import asyncio
import contextvars
from typing import Dict, Any

# Context variable to store the current user ID for tool access
current_user_id: contextvars.ContextVar[str] = contextvars.ContextVar("current_user_id", default=None)

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

# Initialize Vertex AI environment if configured
project_id = os.getenv("VERTEX_AI_PROJECT_ID") or os.getenv("GOOGLE_CLOUD_PROJECT")
location = os.getenv("VERTEX_AI_LOCATION", "us-central1")
force_vertex = (os.getenv("FORCE_VERTEX_AI", "").lower() == "true")

# If project is set, we try to configure for Vertex AI
gemini_kwargs = {}
if project_id or force_vertex:
    gemini_kwargs = {
        "vertexai": True,
        "project": project_id,
        "location": location
    }

from services.calendar_mcp import (
    create_calendar_event_intent,
    _create_event_async,
    _list_events_async,
    _delete_event_async,
    _update_event_async,
    smart_parse_calendar_intent,
)
from services.tools import atomize_task, reduce_options, estimate_real_time, detect_hyperfocus, match_task_to_energy
from services.chat_commands import parse as parse_chat_command, execute as execute_chat_command, help as chat_help
from services.user_settings import UserSettings


def load_firestore_memory(query: str, timeframe: str = "yesterday") -> Dict[str, Any]:
    """
    Loads memory from Firestore based on a query and timeframe.
    Retrieves past sessions and events, filtering them by the query string.
    Args:
        query (str): The search query to filter events.
        timeframe (str, optional): The timeframe to search (default: "yesterday").
    Returns:
        Dict[str, Any]: A dictionary containing the search results or error message.
    """
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
    """
    Preloads session metadata from Firestore for a given timeframe.
    Args:
        timeframe (str, optional): The timeframe to load (default: "yesterday").
    Returns:
        Dict[str, Any]: A dictionary containing the list of sessions.
    """
    start, end = yesterday_range() if timeframe == "yesterday" else (None, None)
    uid = os.getenv("USER") or "terminal_user"
    sessions = get_sessions_by_date(user_id=uid, app_name="altered", start_iso=start, end_iso=end)
    return {"ok": True, "sessions": sessions}


async def tool_create_event(text: str) -> Dict[str, Any]:
    """
    Tool to create a calendar event from natural language text.
    Uses intent classification to extract event details.
    Args:
        text (str): The natural language description of the event.
    Returns:
        Dict[str, Any]: Result of the event creation, including intent details.
    """
    intent = create_calendar_event_intent(text, default_title="Appointment")
    if intent.get("ok") and intent.get("intent"):
        i = intent["intent"]
        # Use _create_event_async for everything (supports recurrence now)
        res = await _create_event_async(
            i["summary"], i["start"], i["end"], 
            i.get("location"), i.get("description"), 
            user_id=current_user_id.get(),
            recurrence=i.get("recurrence")
        )
        return {"intent": i, "result": res}
    return {"error": "intent_parse_failed", "raw": intent}


async def tool_search_events(query: str) -> Dict[str, Any]:
    """
    Tool to search or list calendar events using natural language.
    Examples: "events today", "schedule for December", "meeting with Bob"
    Args:
        query (str): The search query or time range description.
    Returns:
        Dict[str, Any]: List of events found.
    """
    parsed = smart_parse_calendar_intent(query)
    start = parsed.get("start")
    end = parsed.get("end")
    
    if not (start and end):
        now = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
        start = now.isoformat()
        end = now.replace(hour=23, minute=59, second=59).isoformat()
        
    return await _list_events_async("primary", start, end, user_id=current_user_id.get())


async def tool_delete_event(event_id: str) -> Dict[str, Any]:
    """
    Tool to delete a calendar event by its ID.
    Args:
        event_id (str): The unique identifier of the event to delete.
    Returns:
        Dict[str, Any]: Result of the deletion operation.
    """
    return await _delete_event_async("primary", event_id, user_id=current_user_id.get())


async def tool_update_event(event_id: str, start_iso: str, end_iso: str, description: str = "") -> Dict[str, Any]:
    """
    Tool to update an existing calendar event.
    Args:
        event_id (str): The unique identifier of the event.
        start_iso (str): New start time in ISO format.
        end_iso (str): New end time in ISO format.
        description (str, optional): New description for the event.
    Returns:
        Dict[str, Any]: Result of the update operation.
    """
    return await _update_event_async("primary", event_id, start_iso, end_iso, description, user_id=current_user_id.get())


def tool_task_atomize(description: str) -> Dict[str, Any]:
    """
    Tool to break down a complex task into smaller, actionable steps.
    Args:
        description (str): Description of the task to atomize.
    Returns:
        Dict[str, Any]: A structured breakdown of the task.
    """
    return atomize_task(description)


def tool_decision_reduce(options: str, limit: int = 3) -> Dict[str, Any]:
    """
    Tool to reduce a list of options to a manageable number.
    Helps reduce choice overload.
    Args:
        options (str): Comma-separated list of options.
        limit (int, optional): Maximum number of options to return (default: 3).
    Returns:
        Dict[str, Any]: The reduced list of options.
    """
    opts = [o.strip() for o in options.split(",") if o.strip()]
    return reduce_options(opts, max_options=limit)


def tool_chat_command(text: str) -> Dict[str, Any]:
    """
    Tool to execute a chat-based command.
    Parses the command and executes it using the `chat_commands` service.
    Args:
        text (str): The command text.
    Returns:
        Dict[str, Any]: Result of the command execution.
    """
    cmd, args = parse_chat_command(text)
    res = execute_chat_command(os.getenv("USER") or "terminal_user", "session_adk", cmd, args)
    return {"kind": "chat_command", **res}


def tool_chat_help() -> Dict[str, Any]:
    """
    Tool to retrieve help information for chat commands.
    Returns:
        Dict[str, Any]: A dictionary containing help text and available commands.
    """
    return {"kind": "chat_help", **chat_help()}


def tool_get_connected_email() -> Dict[str, Any]:
    uid = current_user_id.get() or (os.getenv("USER") or "terminal_user")
    try:
        s = UserSettings(uid)
        email = s.get_profile_email()
        return {"ok": True, "email": email}
    except Exception as e:
        return {"ok": False, "error": str(e)}


    


async def auto_compact_callback(callback_context):
    """
    Callback function executed after the agent processes a request.
    Triggers the compaction service to summarize and optimize session memory.
    Args:
        callback_context: Context object provided by the ADK runner.
    """
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
    model=Gemini(model=os.getenv("DEFAULT_MODEL", "gemini-flash-latest"), **gemini_kwargs),
    name="neuropilot_coordinator_adk",
    description="Coordinator agent that manages conversation and calendar operations",
    instruction=(
        "You are Altered, a hyper-intelligent AI assistant. You MUST use the body_double tool to start/stop sessions when requested. Do NOT just reply with text. "
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
        tool_search_events,
        tool_delete_event,
        tool_update_event,
        tool_task_atomize,
        tool_decision_reduce,
        load_firestore_memory,
        preload_firestore_memory,
        tool_chat_command,
        tool_chat_help,
        tool_get_connected_email,
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
    """
    Internal function to run the agent asynchronously.
    Manages session creation/retrieval and processes the user's input.
    Args:
        user_id (str): The user's unique identifier.
    Manages session creation/retrieval, credit enforcement, and processes the user's input.
    """
    # Credit enforcement and BYOK check
    from services.credit_service import get_credit_service
    from services.user_settings import UserSettings
    
    credit_service = get_credit_service()
    user_settings = UserSettings(user_id)
    
    # Check if user has custom API key (BYOK)
    has_byok = user_settings.has_custom_api_key()
    
    # Get/initialize credit balance
    balance_result = credit_service.get_balance(user_id)
    current_balance = balance_result.get("balance", 0) if balance_result.get("ok") else 0
    
    # Credit consumption and blocking logic
    credit_warning = None
    if not has_byok:
        # User is relying on organization credits
        if current_balance <= 0:
            # No credits left
            return (
                "⚠️ You've used all 6 free credits!\n\n"
                "To continue using Altered, please add your own Gemini API key in Settings.\n\n"
                "Get your free API key at: https://makersuite.google.com/app/apikey",
                []
            )
        
        # Consume 1 credit for this interaction
        consume_result = credit_service.consume_credit(
            user_id=user_id,
            amount=1.0,
            reason="agent_interaction",
            metadata={"session_id": session_id, "message": text[:100]}
        )
        
        if not consume_result.get("ok"):
            return (
                "❌ Unable to process request due to credit system error. Please try again.",
                []
            )
        
        # Generate warning for low credits
        new_balance = consume_result.get("balance", 0)
        if new_balance == 0:
            credit_warning = "\n\n⚠️ This was your last free credit! Add your API key in Settings to continue."
        elif new_balance <= 2:
            credit_warning = f"\n\n💡 You have {int(new_balance)} free credits remaining."
    
    # Set user context for tools
    token = current_user_id.set(user_id)
    
    try:
        # Retrieve or create session
        try:
            await session_service.create_session(app_name=runner.app_name, user_id=user_id, session_id=session_id)
        except Exception:
            try:
                await session_service.get_session(app_name=runner.app_name, user_id=user_id, session_id=session_id)
            except Exception:
                pass
        
        # Build per-user agent configuration
        local_agent = None
        if has_byok:
            api_key = user_settings.get_api_key()
            if api_key:
                local_agent = LlmAgent(
                    model=Gemini(model=os.getenv("DEFAULT_MODEL", "gemini-flash-latest"), api_key=api_key),
                    name=agent.name,
                    description=agent.description,
                    instruction=agent.instruction,
                    tools=agent.tools,
                    after_agent_callback=auto_compact_callback,
                )
        # Fallback to global agent (Vertex or default)
        active_runner = runner if local_agent is None else Runner(agent=local_agent, app_name=runner.app_name, session_service=session_service)

        content = types.Content(role="user", parts=[types.Part(text=text)])
        last_text = ""
        tool_results: Any = []
        async for event in active_runner.run_async(user_id=user_id, session_id=session_id, new_message=content):
            if event.content and event.content.parts:
                for part in event.content.parts:
                    if hasattr(part, "text") and part.text:
                        last_text = part.text
                    if hasattr(part, "function_call") and part.function_call:
                        tool_results.append({"tool": part.function_call.name, "args": dict(part.function_call.args)})
        
        # Append credit warning if applicable
        if credit_warning and last_text:
            last_text += credit_warning
        
        return last_text, tool_results
    finally:
        # Reset user context
        current_user_id.reset(token)


def adk_respond(uid: str, session_id: str, text: str):
    """
    Main entry point for the ADK agent response logic.
    Handles manual overrides for specific features (body double, dopamine reframe)
    and delegates to the async agent runner for general queries.
    Args:
        uid (str): The user's unique identifier.
        session_id (str): The session identifier.
        text (str): The user's input text.
    Returns:
        tuple: (text_response, tool_results)
    Raises:
        Exception: Propagates exceptions from the underlying execution,
        handling transient errors with retries.
    """
    import time, random
    tries = 4
    last_err = None
    delay = 0.4
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
            if ("UNAVAILABLE" in s or "overloaded" in s or "INTERNAL" in s or "internal error" in s.lower()):
                time.sleep(delay + random.uniform(0.0, 0.2))
                delay = min(delay * 2, 2.0)
                continue
            break
    raise last_err
