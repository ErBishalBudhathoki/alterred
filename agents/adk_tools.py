import os
import logging
from typing import Dict, Any, Optional, List
from datetime import datetime, timedelta
from agents.context import current_user_id, current_user_timezone, current_user_country
from services.history_service import yesterday_range, get_sessions_by_date, search_events, get_events_for_session
from services.calendar_mcp import (
    create_calendar_event_intent,
    _create_event_async,
    _list_events_async,
    _search_events_async,
    _delete_event_async,
    _update_event_async,
    smart_parse_calendar_intent,
    _genai_client # Needed? No.
)
from agents.tools import atomize_task, reduce_options
from services.chat_commands import parse as parse_chat_command, execute as execute_chat_command, help as chat_help
from services.user_settings import UserSettings
from services.memory_bank import FirestoreMemoryBank
from services.a2a_service import post_update, list_updates
from services.timer_store import list_today_timers, cancel_timer
from google.adk.tools.google_search_tool import GoogleSearchTool

logger = logging.getLogger(__name__)

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
    try:
        print(f"DEBUG: tool_create_event called with text='{text}' tz={current_user_timezone.get()}")
        intent = create_calendar_event_intent(
            text, 
            default_title="Appointment", 
            user_id=current_user_id.get(),
            time_zone=current_user_timezone.get()
        )
        if intent.get("ok") and intent.get("intent"):
            i = intent["intent"]
            # Use _create_event_async for everything (supports recurrence now)
            res = await _create_event_async(
                i["summary"], i["start"], i["end"], 
                i.get("location"), i.get("description"), 
                user_id=current_user_id.get(),
                recurrence=i.get("recurrence")
            )
            
            # Check for calendar not connected error
            if not res.get("ok") and "credentials" in str(res.get("error", "")).lower():
                return {
                    "ok": False,
                    "error": "Google Calendar is not connected. Please go to Settings → Google Calendar → Connect to use calendar features."
                }

            # Format result to trigger frontend widget display explicitly
            if res.get("ok") and "event" in res:
                # ENHANCEMENT: Fetch all events for the day of the created event
                # to trigger the full day's list view in UI with correct metadata (Calendar Name).
                try:
                    from services.google_calendar_direct import list_events_all_calendars
                    
                    e_start = res["event"].get("start", {})
                    dt_str = e_start.get("dateTime", e_start.get("date"))
                    
                    if dt_str:
                         # Parse ISO string (YYYY-MM-DD is first 10 chars)
                         day_str = dt_str[:10]
                         # Query full day (local/server time interpretation of string is fine as approximation)
                         start_time = f"{day_str}T00:00:00"
                         end_time = f"{day_str}T23:59:59"
                         
                         print(f"DEBUG: Fetching context events for {day_str}")
                         all_events = list_events_all_calendars(
                             user_id=current_user_id.get(),
                             start_time=start_time,
                             end_time=end_time
                         )
                         
                         return {
                             "ok": True, 
                             "ui_mode": "internal",
                             "result": {"events": all_events}, # Full list with metadata
                             "intent": i
                         }
                except Exception as listing_err:
                     print(f"DEBUG: Failed to list context events: {listing_err}")

                # Fallback to single event if listing fails
                return {
                    "ok": True,
                    "ui_mode": "internal",
                    "result": {"events": [res["event"]]},
                    "intent": i
                }

            return {"intent": i, "result": res}
        return {"error": "intent_parse_failed", "raw": intent}
    except Exception as e:
        error_msg = str(e).lower()
        if "credentials" in error_msg or "not connected" in error_msg:
            return {
                "ok": False,
                "error": "Google Calendar is not connected. Please go to Settings → Google Calendar → Connect to use calendar features."
            }
        return {"ok": False, "error": str(e)}

async def google_calendar_mcp_search_events(query: str) -> Dict[str, Any]:
    """
    Tool to search or list calendar events using natural language.
    Examples: "events today", "schedule for December", "meeting with Bob"
    Args:
        query (str): The search query or time range description.
    Returns:
        Dict[str, Any]: List of events found.
    """
    try:
        try:
            parsed = smart_parse_calendar_intent(
                query, 
                user_id=current_user_id.get(),
                time_zone=current_user_timezone.get()
            )
        except Exception as e:
            logger.error(f"Calendar intent parsing failed for query '{query}': {e}")
            parsed = {}
        start = parsed.get("start")
        end = parsed.get("end")
        qtext = parsed.get("query") or ""

        if not (start and end):
            lower = query.lower()
            now = datetime.now().astimezone().replace(microsecond=0)
            if "tomorrow" in lower:
                base = now + timedelta(days=1)
                start = base.replace(hour=0, minute=0, second=0).isoformat()
                end = base.replace(hour=23, minute=59, second=59).isoformat()
            else:
                start = now.replace(hour=0, minute=0, second=0).isoformat()
                end = now.replace(hour=23, minute=59, second=59).isoformat()

        # Heuristic: If query looks like a full sentence or contains generic calendar words, clear it
        if qtext:
            lq = qtext.lower()
            is_full_echo = qtext.strip().lower() == query.strip().lower()
            generic_terms = [
                "calendar", "calender", "event", "events", "schedule", "schedules",
                "meeting", "meetings", "appointment", "appointments", "agenda",
                "plan", "plans", "todo", "todos", "reminders",
                "session", "sessions",
                "today", "tomorrow", "yesterday", "week", "month", "year"
            ]
            has_generic = any(term in lq for term in generic_terms)
            tokens = [t.strip("?,.!").lower() for t in qtext.split()]
            allowed_words = [
                "my", "the", "show", "me", "what", "whats", "what's", 
                "is", "are", "on", "for", "in", "at", "with", "of",
                "list", "get", "check", "display", "view", "see",
                "do", "i", "have", "any", "a", "an",
                "can", "could", "you", "please", "there", "upcoming"
            ]
            is_purely_generic = len(tokens) > 0 and all(t in generic_terms or t in allowed_words for t in tokens)
            is_question = "?" in lq or lq.startswith("do ") or lq.startswith("what") or lq.startswith("show ")
            
            if (is_full_echo and (has_generic or is_question)) or (has_generic and len(qtext.split()) > 3) or is_purely_generic:
                logger.info(f"Clearing generic calendar query '{qtext}' to allow full listing")
                qtext = ""

        if qtext.strip():
            result = await _search_events_async("primary", qtext.strip(), start, end, user_id=current_user_id.get())
        else:
            uid = current_user_id.get()
            if uid:
                try:
                    from services.google_calendar_direct import list_events_all_calendars
                    logger.info(f"Querying all calendars for user {uid}")
                    events = list_events_all_calendars(
                        user_id=uid,
                        start_time=start,
                        end_time=end
                    )
                    logger.info(f"Found {len(events)} events from all calendars")
                    result = {"ok": True, "result": {"events": events}}
                except Exception as e:
                    logger.warning(f"Multi-calendar query failed, falling back to primary: {e}")
                    result = await _list_events_async("primary", start, end, user_id=uid)
            else:
                result = await _list_events_async("primary", start, end, user_id=uid)

        if not result.get("ok"):
            err_str = str(result.get("error", "")).lower()
            logger.error(f"Calendar MCP search/list error for query '{query}': {result.get('error')}")
            if "credentials" in err_str or "not connected" in err_str:
                return {
                    "ok": False,
                    "error": "Google Calendar is not connected. Please go to Settings → Google Calendar → Connect to use calendar features."
                }
            return {
                "ok": False,
                "error": "Google Calendar is not connected. Please go to Settings → Google Calendar → Connect to use calendar features."
            }
        return result
    except Exception as e:
        error_msg = str(e).lower()
        if "credentials" in error_msg or "not connected" in error_msg:
            return {
                "ok": False,
                "error": "Google Calendar is not connected. Please go to Settings → Google Calendar → Connect to use calendar features."
            }
        return {"ok": False, "error": str(e)}


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
    country_code = current_user_country.get()
    return atomize_task(description, country_code=country_code)


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
    """
    Tool to retrieve the email address associated with the current user's connected account.
    """
    uid = current_user_id.get() or (os.getenv("USER") or "terminal_user")
    try:
        s = UserSettings(uid)
        email = s.get_profile_email()
        return {"ok": True, "email": email}
    except Exception as e:
        return {"ok": False, "error": str(e)}


def tool_log_energy(level: int, context: Optional[str] = None) -> Dict[str, Any]:
    """
    Tool to explicitly log the user's energy level.
    Args:
        level (int): Energy level from 1 to 10.
        context (str, optional): Context or reason for the energy level.
    """
    uid = current_user_id.get() or (os.getenv("USER") or "terminal_user")
    try:
        bank = FirestoreMemoryBank(uid)
        bank.record_energy_level(int(level))
        if context:
            bank.store_decision_event("energy_log", {"level": int(level), "context": context})
        return {"ok": True, "logged": True, "level": int(level), "ui_mode": "auto_log_energy"}
    except Exception as e:
        return {"ok": False, "error": str(e)}

def tool_a2a_post_update(partner_id: str, update: Dict[str, Any]) -> Dict[str, Any]:
    """
    Tool to send an update to a connected A2A partner.
    Args:
        partner_id (str): The partner's ID.
        update (Dict[str, Any]): The update payload.
    """
    return post_update(partner_id, update)

def tool_a2a_list_updates(partner_id: str) -> Dict[str, Any]:
    """
    Tool to list recent updates from a partner.
    """
    return list_updates(partner_id)

def tool_timer_list() -> Dict[str, Any]:
    """
    List all timers created today.
    """
    timers = list_today_timers()
    return {"ok": True, "timers": timers}

def tool_timer_cancel(timer_id: str) -> Dict[str, Any]:
    """
    Cancel an active timer.
    """
    if cancel_timer(timer_id):
        return {"ok": True, "status": "cancelled"}
    return {"ok": False, "error": "timer_not_found"}

search_tool = GoogleSearchTool(bypass_multi_tools_limit=True)
