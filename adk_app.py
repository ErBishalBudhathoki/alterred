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
from typing import Dict, Any, Optional
import logging
from dotenv import load_dotenv

# Ensure environment is loaded before initializing module-level constants
load_dotenv()

logger = logging.getLogger(__name__)

# Import context vars
from agents.context import current_user_id, current_user_timezone, current_user_country, current_tool_outputs

# CRITICAL FIX: Remove GOOGLE_API_KEY BEFORE any Google library imports
# The Google ADK library checks for GOOGLE_API_KEY at import time and selects backend then
# If GOOGLE_API_KEY exists, it uses GEMINI_API backend (20 req/day free tier)
# If only Vertex AI credentials exist, it uses VERTEX_AI backend (generous quotas)
force_vertex = (os.getenv("FORCE_VERTEX_AI", "").lower() == "true")
if force_vertex and "GOOGLE_API_KEY" in os.environ:
    print(f"[VERTEX AI INIT] Removing GOOGLE_API_KEY before library imports to force Vertex AI backend")
    print(f"[VERTEX AI INIT] Project: {os.getenv('VERTEX_AI_PROJECT_ID')}, Location: {os.getenv('VERTEX_AI_LOCATION')}")
    del os.environ["GOOGLE_API_KEY"]

# Context variables are imported from services.context

from google.adk.agents import LlmAgent
from google.adk.tools import google_search
# GoogleSearchTool is imported from services.adk_tools
from google.adk.runners import Runner
from sessions.firestore_session_service import FirestoreSessionService
from services.history_service import yesterday_range, get_sessions_by_date, get_events_for_session, search_events
from agents.taskflow_agent import taskflow_agent, body_double, body_double_checkin, dopamine_reframe
from agents.time_perception_agent import time_perception_agent, create_countdown, transition_helper
from agents.energy_sensory_agent import energy_sensory_agent, detect_sensory_overload, routine_vs_novelty_balancer
from agents.decision_support_agent import decision_support_agent, reduce_options, motivation_matcher, reevaluate_options
from agents.external_brain_agent import external_brain_agent, capture_voice_note, a2a_connect
from services.a2a_service import post_update, list_updates
# timer_store imports moved to adk_tools
from agents.tools import restore_context, estimate_real_time, match_task_to_energy
from services.country_service import get_country_info, is_tax_relevant
from agents.adk_tools import (
    tool_create_event,
    google_calendar_mcp_search_events,
    tool_delete_event,
    tool_update_event,
    tool_task_atomize,
    tool_decision_reduce,
    load_firestore_memory,
    preload_firestore_memory,
    tool_chat_command,
    tool_chat_help,
    tool_get_connected_email,
    tool_log_energy,
    tool_a2a_post_update,
    tool_a2a_list_updates,
    tool_timer_list,
    tool_timer_cancel,
    search_tool
)
from agents.common import auto_compact_callback
try:
    from orchestration.workflows import task_execution_workflow, continuous_monitors
except Exception:
    def task_execution_workflow(*args, **kwargs):
        return {"ok": False, "error": "workflow_unavailable"}
    def continuous_monitors(*args, **kwargs):
        return {"ok": False, "error": "workflow_unavailable"}
from google.adk.models.google_llm import Gemini as _BaseGemini
from google.genai import types, Client
from functools import cached_property
from agents.adk_model import Gemini, get_adk_model
from datetime import datetime, timedelta

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

# Normalize model name
_raw_model = os.getenv("DEFAULT_MODEL", "gemini-2.5-flash")
_bm = _raw_model.split("/")[-1]
_pref = "models/" if _raw_model.startswith("models/") else ""
if ("flash-latest" in _bm) or (_bm in {"gemini-flash-latest", "gemini-1.5-flash-latest", "gemini-2.0-flash-latest"}):
    _bm = "gemini-2.5-flash"
_raw_model = f"{_pref}{_bm}"
print(f"[Model Config] Using model: {_raw_model}")

from services.calendar_mcp import (
    create_calendar_event_intent,
    _create_event_async,
    _list_events_async,
    _search_events_async,
    _delete_event_async,
    _update_event_async,
    smart_parse_calendar_intent,
)
from agents.tools import atomize_task, detect_hyperfocus
from services.memory_bank import FirestoreMemoryBank
from services.chat_commands import parse as parse_chat_command, execute as execute_chat_command, help as chat_help
from services.user_settings import UserSettings




agent = LlmAgent(
    model=get_adk_model(),
    name="neuropilot_coordinator_adk",
    description="Coordinator agent that manages conversation and calendar operations",
    instruction=(
        "You are Altered, a specialized AI copilot for neurodivergent brains (ADHD/Autism). "
        "Your goal is to be an 'Executive Function Prosthetic' - handling planning, initiating, and regulating so the user doesn't have to. "
        "NEVER say 'I am an AI language model'. You are Altered. "
        "\n"
        "CORE PERSONALITY: "
        "- Proactive: Don't just wait for commands. Anticipate needs based on time/context. "
        "- Direct & Low-Friction: Minimize cognitive load. Short, clear sentences. "
        "- Non-Judgmental: Normalize struggle. 'It's okay to be stuck. Let's do 5 minutes.' "
        "- Adaptive: Match the user's energy. High energy -> Fast/Gamified. Low energy -> Gentle/Structured. "
        "\n"
        "FORMATTING RULES (ADHD-FRIENDLY): "
        "1. Use clear section headers with visual separation (bold or markdown headers). "
        "2. Break content into short, bulleted lists (max 3-5 items per list). "
        "3. Use emojis or icons as visual anchors for key points. "
        "4. Maintain clean spacing between sections to reduce visual clutter. "
        "5. Highlight action items using bold text or callouts. "
        "6. Avoid walls of text; keep paragraphs short and punchy. "
        "7. If you do not have enough information to answer, use google_search to find reliable sources, then summarize for the user. "
        "8. When using tools that return structured data (like calendar events, task lists, or dopamine hacks), do NOT output the raw JSON or detailed list in your text response. "
        "Instead, provide a brief summary (e.g., 'Here are your events:' or 'Try these hacks:') and let the UI handle the detailed display. "
        "\n"
        "BEHAVIORAL RULES: "
        "You MUST use the body_double tool to start/stop sessions when requested. Do NOT just reply with text. "
        "When receiving a system check-in prompt, you MUST use the body_double_checkin tool. "
        "Maintain context across turns. Prefer using chat tools to interpret natural commands: "
        "use tool_chat_command to execute CLI-equivalent operations and tool_chat_help to surface suggestions. "
        "For calendar: add, list, delete, update using the provided tools. For tasks: atomize into micro-steps. "
        "For boring tasks: use dopamine_reframe to gamify or add novelty. "
        "For decisions: reduce options and propose defaults. For time/energy: estimate_real_time, detect_hyperfocus, "
        "create_countdown, transition_helper, match_task_to_energy, detect_sensory_overload, routine_vs_novelty_balancer, log_energy. "
        "Use load_firestore_memory to recall past conversations (e.g., yesterday). "
        "ALWAYS assess the user's energy level from their tone and context (1-10). If a clear energy level is detectable "
        "(e.g., 'I am exhausted' -> 2, 'Ready to go!' -> 8), PROACTIVELY use tool_log_energy to log it. "
        "Do not ask for permission, just log it and mention it briefly ('I noticed you seem tired, so I logged your energy at 3.')."
    ),
    tools=[
        tool_create_event,
        google_calendar_mcp_search_events,
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
        tool_log_energy,
        body_double,
        body_double_checkin,
        dopamine_reframe,
        search_tool,
    ],
    after_agent_callback=auto_compact_callback,
)

from orchestration.manager import OrchestrationManager

available_agents = {
    "neuropilot_coordinator_adk": agent,
    "taskflow_agent": taskflow_agent,
    "time_perception_agent": time_perception_agent,
    "energy_sensory_agent": energy_sensory_agent,
    "decision_support_agent": decision_support_agent,
    "external_brain_agent": external_brain_agent
}

orchestrator = OrchestrationManager(available_agents, None)

session_service = FirestoreSessionService()
runner = Runner(agent=agent, app_name="altered", session_service=session_service)
_loop = asyncio.new_event_loop()


async def _run(user_id: str, session_id: str, text: str, override_agent: Optional[LlmAgent] = None):
    """
    Internal function to run the agent asynchronously.
    Manages session creation/retrieval and processes the user's input.
    Args:
        user_id (str): The user's unique identifier.
    Manages session creation/retrieval, credit enforcement, and processes the user's input.
    """
    # Credit enforcement and BYOK check
    from services.credit_service import get_credit_service
    
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
                "⚠️ You've used all 13 free credits!\n\n"
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
    outputs_token = current_tool_outputs.set([])
    
    try:
        # Pre-flight endpoint verification: enforce Vertex-only unless BYOK
        vertex_enabled = bool(project_id or force_vertex)
        if not has_byok and not vertex_enabled:
            return (
                "❌ Service not configured: Vertex AI credentials missing and no BYOK API key provided.\n\n"
                "Set `VERTEX_AI_PROJECT_ID`/`GOOGLE_CLOUD_PROJECT` and `VERTEX_AI_LOCATION` or add your own Gemini API key in Settings.",
                []
            )
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
                    model=Gemini(model=_raw_model, api_key=api_key),
                    name=agent.name,
                    description=agent.description,
                    instruction=agent.instruction,
                    tools=agent.tools,
                    after_agent_callback=auto_compact_callback,
                )
        runtime_mode = "vertex_ai"
        if override_agent is not None:
            if has_byok:
                api_key = user_settings.get_api_key()
                if api_key:
                    local_agent = LlmAgent(
                        model=Gemini(model=_raw_model, api_key=api_key),
                        name=override_agent.name,
                        description=override_agent.description,
                        instruction=override_agent.instruction,
                        tools=override_agent.tools,
                        after_agent_callback=auto_compact_callback,
                    )
                    active_runner = Runner(agent=local_agent, app_name=runner.app_name, session_service=session_service)
                    runtime_mode = "byok"
                else:
                    active_runner = Runner(agent=override_agent, app_name=runner.app_name, session_service=session_service)
            else:
                active_runner = Runner(agent=override_agent, app_name=runner.app_name, session_service=session_service)
        else:
            active_runner = runner if local_agent is None else Runner(agent=local_agent, app_name=runner.app_name, session_service=session_service)
            if local_agent is not None:
                runtime_mode = "byok"

        content = types.Content(role="user", parts=[types.Part(text=text)])
        last_text = ""
        tool_results: Any = []
        async for event in active_runner.run_async(user_id=user_id, session_id=session_id, new_message=content):
            # DEBUG: Log all event attributes to inspect available data
            # print(f"DEBUG: ADK Event: {event}")
            # if hasattr(event, "actions"):
            #     print(f"DEBUG: Event Actions: {event.actions}")
            
            if event.content and event.content.parts:
                for part in event.content.parts:
                    if hasattr(part, "text") and part.text:
                        last_text = part.text
                    if hasattr(part, "function_call") and part.function_call:
                        tool_results.append({"tool": part.function_call.name, "args": dict(part.function_call.args)})
                        
            # Capture tool outputs directly from event actions if available
            if hasattr(event, "actions") and event.actions:
                if hasattr(event.actions, "tools") and event.actions.tools:
                    print(f"DEBUG: Found tool outputs in event: {event.actions.tools}")
                    tool_results.extend(event.actions.tools)

        tool_results.append({"runtime_mode": runtime_mode})
        
        # Merge explicitly captured tool outputs
        captured_outputs = current_tool_outputs.get()
        print(f"DEBUG: Captured outputs from contextvars: {captured_outputs}")
        if captured_outputs:
            tool_results.extend(captured_outputs)
        
        return last_text, tool_results
    finally:
        # Reset user context
        current_user_id.reset(token)
        current_tool_outputs.reset(outputs_token)


async def adk_respond(uid: str, session_id: str, text: str, time_zone: Optional[str] = None, country_code: Optional[str] = None):
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
    import time
    import random
    
    # Set country context
    # Note: We rely on task-local storage cleanup since re-indenting the whole block for try/finally is risky
    current_user_country.set(country_code)
    
    tries = 4
    last_err: BaseException | None = None
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
                p = tool_res.get("prompt", "")
                if p:
                    p = p + "\nEnergy check: reply 'energy: N' (1-10) to log."
                return p or tool_res.get("prompt"), [tool_res]
            
            # Manual override for dopamine reframe - only for explicit negative sentiment
            # Let the agent naturally handle task mentions and provide both dopamine + atomization
            boring_keywords = ["boring", "tedious", "hate", "dreading", "procrastinating", "don't want to"]
            
            text_lower = text.lower()
            
            # Manual override for explicit calendar check queries to guarantee MCP usage
            import re as _re
            # Pattern 1: Explicit calendar mention with query intent or possessive
            # e.g. "check calendar", "my calendar", "on the calendar", "what is on calendar"
            p1 = r"(check|what|show|list|any|my|on|in|from|to|have)\s+.*(calendar|calender)"
            
            # Pattern 2: Calendar mention with event/schedule context
            # e.g. "calendar events", "schedule on calendar"
            p2 = r"(calendar|calender)\s+.*(event|schedule|appointment)"
            
            # Pattern 3: "Events" or "Schedule" combined with timebox
            # e.g. "events today", "schedule for tomorrow"
            p3 = r"(event|schedule|appointment).*(today|tomorrow|week|month|day)"

            if _re.search(p1, text_lower) or _re.search(p2, text_lower) or _re.search(p3, text_lower):
                token = current_user_id.set(uid)
                try:
                    result = await google_calendar_mcp_search_events(text)
                finally:
                    current_user_id.reset(token)
                
                if not result.get("ok"):
                    return result.get("error", "Sorry, I couldn't access your calendar right now."), [result]
                
                events = result.get("result", {}).get("events", [])
                if not isinstance(events, list):
                    events = []
                
                if not events:
                    msg = "📅 **Calendar Events:**\nYou have **no events** scheduled for this period."
                else:
                    msg = f"📅 **Calendar Events:**\nI found {len(events)} events on your calendar."
                
                tool_results_override = [
                    {
                        "tool": "google_calendar_mcp:search_events",
                        "args": {
                            "query": text,
                            "status": "executed_live",
                            "events": events
                        },
                        "ui_mode": "calendar_events"
                    }
                ]
                return msg, tool_results_override
            
            import re as _re
            m_energy = _re.search(r"energy\s*:\s*(\d{1,2})", text_lower) or _re.search(r"my\s+energy\s+is\s+(\d{1,2})", text_lower)
            if m_energy:
                level = int(m_energy.group(1))
                res = tool_log_energy(level)
                return f"Logged energy level {level}/10.", [res]
            should_reframe = any(keyword in text_lower for keyword in boring_keywords)
            
            if should_reframe:
                from agents.taskflow_agent import dopamine_reframe
                task_match = text
                tool_res = dopamine_reframe(task_match)
                return tool_res["reframe"], [tool_res]
            
            # Manual override for task prioritization requests
            task_prioritization_keywords = [
                "prioritize", "prioritise", "choose a task", "pick a task",
                "what should i do", "too many tasks", "help me choose",
                "which task", "what task should", "overwhelmed with tasks"
            ]
            if any(keyword in text_lower for keyword in task_prioritization_keywords):
                try:
                    from services.task_prioritization_service import TaskPrioritizationService, PrioritizedTask
                    from dataclasses import asdict
                    import re
                    
                    # Check if user provided ad-hoc tasks in the message
                    # Pattern: "tasks: X, Y, Z" or "I have X, Y, Z" or list after colon
                    adhoc_tasks = []
                    
                    # Try to extract tasks from message
                    # Look for patterns like "tasks: a, b, c" or "I have: a, b, c" or just comma-separated items
                    task_patterns = [
                        r"tasks?[:\s]+(.+?)(?:\.|help|$)",  # "tasks: a, b, c"
                        r"have[:\s]+(.+?)(?:\.|help|$)",     # "I have: a, b, c"
                        r"(?:email|call|clean|pay|walk|do|finish|complete|write|send|buy|make|schedule|book|fix|organize|prepare|submit|review|update|check)[^,\.]+(?:,\s*(?:email|call|clean|pay|walk|do|finish|complete|write|send|buy|make|schedule|book|fix|organize|prepare|submit|review|update|check)[^,\.]+)+",
                    ]
                    
                    for pattern in task_patterns:
                        match = re.search(pattern, text_lower, re.IGNORECASE)
                        if match:
                            task_str = match.group(1) if match.lastindex else match.group(0)
                            # Split by comma, semicolon, or "and"
                            items = re.split(r'[,;]|\band\b', task_str)
                            adhoc_tasks = [t.strip() for t in items if t.strip() and len(t.strip()) > 2]
                            if len(adhoc_tasks) >= 2:
                                break
                    
                    if adhoc_tasks and len(adhoc_tasks) >= 2:
                        # User provided ad-hoc tasks - prioritize these directly
                        from agents.tools import reduce_options
                        
                        # Use the reduce_options agent to pick top 3
                        reduced = reduce_options(adhoc_tasks, min(3, len(adhoc_tasks)))
                        reduced_tasks = reduced.get("reduced_options", adhoc_tasks[:3])
                        
                        # Create PrioritizedTask objects for the ad-hoc tasks
                        prioritized_tasks = []
                        for i, task_title in enumerate(reduced_tasks):
                            task = PrioritizedTask(
                                id=f"adhoc_{i}",
                                title=task_title.strip().capitalize(),
                                description=None,
                                due_date=None,
                                priority="medium",
                                status="pending",
                                effort="low" if i == 0 else "medium",
                                priority_score=10.0 - i,
                                priority_reasoning="Low-friction, quick win" if i == 0 else "Good balance of impact and effort",
                                is_recommended=(i == 0),
                                estimated_duration_minutes=15 if i == 0 else 30,
                            )
                            prioritized_tasks.append(task)
                        
                        reasoning = (
                            f"I've selected these {len(prioritized_tasks)} tasks because they're "
                            "low-friction and provide meaningful impact. "
                            f"'{prioritized_tasks[0].title}' is my top pick - it's quick to complete "
                            "and will give you momentum for the rest."
                        )
                        
                        tool_result = {
                            "ui_mode": "task_prioritization",
                            "tasks": [asdict(task) for task in prioritized_tasks],
                            "reasoning": reasoning,
                            "original_task_count": len(adhoc_tasks),
                            "timestamp": "",
                        }
                        
                        # Return empty string to suppress text (widget shows everything)
                        return "", [tool_result]
                    
                    # No ad-hoc tasks found - use stored tasks from Firestore
                    service = TaskPrioritizationService(uid)
                    response = await service.get_prioritized_tasks(
                        limit=3,
                        include_calendar=True,
                        energy=5
                    )
                    
                    tool_result = {
                        "ui_mode": "task_prioritization",
                        "tasks": [asdict(task) for task in response.tasks],
                        "reasoning": response.reasoning,
                        "original_task_count": response.original_task_count,
                        "timestamp": response.timestamp,
                    }
                    
                    if not response.tasks:
                        return response.reasoning, [tool_result]
                    
                    # Return empty string to suppress redundant text
                    return "", [tool_result]
                except Exception as e:
                    print(f"[ADK] Task prioritization override failed: {e}")
                    import traceback
                    traceback.print_exc()
                    # Fall through to orchestrator
            
            # Use the OrchestrationManager for intelligent routing and parallel execution
            # Reverted augmented_text to avoid agent confusion. Timezone is handled by tools internally.
            print(f"DEBUG: adk_respond called with time_zone={time_zone}")
            
            # Country Context Injection
            if country_code and is_tax_relevant(text):
                info = get_country_info(country_code)
                if info and "name" in info:
                    context_msg = (
                        f"System Note: User is in {info['name']} ({country_code}). "
                        f"Currency: {info.get('currency')}. "
                        f"Tax Info: {info.get('tax_info')}. "
                        f"Regulations: {info.get('regulations')}. "
                        f"Please consider this local context for the response."
                    )
                    print(f"DEBUG: Injecting country context for {country_code}")
                    text = f"{context_msg}\n\n{text}"
            
            return await orchestrator.process_request(uid, session_id, text, _run)
        except Exception as e:
            last_err = e
            s = str(e)
            
            # Enhanced logging for debugging
            import traceback
            print(f"[ADK ERROR] Exception type: {type(e).__name__}")
            print(f"[ADK ERROR] Exception message: {s}")
            print(f"[ADK ERROR] Full traceback:")
            traceback.print_exc()
            
            # Check for quota/rate limit errors (429)
            if "429" in s or "RESOURCE_EXHAUSTED" in s or "Quota exceeded" in s.lower():
                # Log which service is causing the issue
                if "vertexai" in s.lower() or "aiplatform" in s.lower():
                    print("[ADK ERROR] Source: Vertex AI")
                elif "generativelanguage" in s.lower() or "makersuite" in s.lower():
                    print("[ADK ERROR] Source: API Key (not Vertex AI!)")
                else:
                    print(f"[ADK ERROR] Source: Unknown - {s[:200]}")
                    
                return (
                    "⏱️ **Rate Limit Reached**\n\n"
                    "You're making requests too quickly. Google Cloud has a limit on how many requests you can make per minute.\n\n"
                    "**What to do:**\n"
                    "• Wait 30-60 seconds before trying again\n"
                    "• Consider adding your own API key in Settings to get higher limits\n"
                    "• Get a free API key at: https://makersuite.google.com/app/apikey",
                    []
                )
            
            if ("UNAVAILABLE" in s or "overloaded" in s or "INTERNAL" in s or "internal error" in s.lower()):
                time.sleep(delay + random.uniform(0.0, 0.2))
                delay = min(delay * 2, 2.0)
                continue
            break
    if last_err is None:
        raise RuntimeError("unknown error")
    raise last_err
# tool_log_energy defined above
