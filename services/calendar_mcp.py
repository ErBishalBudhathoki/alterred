import os
import asyncio
from typing import Optional, Dict, Any
from datetime import datetime, timedelta

try:
    from mcp import ClientSession, StdioServerParameters
    from mcp.client.stdio import stdio_client
except Exception:
    ClientSession = None  # type: ignore


def _parse_time_natural(text: str) -> Optional[Dict[str, str]]:
    """Parse natural language like:
    - "tomorrow at 9:15"
    - "for 9:15" (assumed today, local time)
    - "9 pm" or "9:15 am"
    - duration phrases ("for 1 hour", "for 30 minutes")

    Returns start/end ISO strings with local timezone.
    """
    now = datetime.now()
    lower = text.lower()
    # Day offset
    day_offset = 0
    if "day after tomorrow" in lower:
        day_offset = 2
    elif "tomorrow" in lower:
        day_offset = 1
    base_day = now + timedelta(days=day_offset)

    # Duration
    minutes = _parse_duration_minutes(lower)

    import re
    # 1) HH:MM with optional am/pm
    m = re.search(r"(\b\d{1,2}):(\d{2})\s*(am|pm)?\b", lower)
    if m:
        hour = int(m.group(1))
        minute = int(m.group(2))
        ampm = m.group(3)
        if ampm:
            if ampm == "pm" and hour != 12:
                hour += 12
            if ampm == "am" and hour == 12:
                hour = 0
        start = base_day.replace(hour=hour, minute=minute, second=0, microsecond=0)
        end = start + timedelta(minutes=minutes)
        return {"start": start.isoformat(), "end": end.isoformat()}

    # 2) "at HH" or "HH am/pm"
    m2 = re.search(r"\b(?:at\s+)?(\d{1,2})\s*(am|pm)?\b", lower)
    if m2:
        hour = int(m2.group(1))
        ampm = m2.group(2)
        if ampm:
            if ampm == "pm" and hour != 12:
                hour += 12
            if ampm == "am" and hour == 12:
                hour = 0
        start = base_day.replace(hour=hour, minute=0, second=0, microsecond=0)
        end = start + timedelta(minutes=minutes)
        return {"start": start.isoformat(), "end": end.isoformat()}

    return None


async def _create_event_async(summary: str, start_iso: str, end_iso: str, location: Optional[str], description: Optional[str]) -> Dict[str, Any]:
    if ClientSession is None:
        return {"ok": False, "error": "mcp Python SDK not installed"}

    creds = os.getenv("GOOGLE_OAUTH_CREDENTIALS")
    if not creds:
        return {"ok": False, "error": "GOOGLE_OAUTH_CREDENTIALS not set"}

    import os as _os
    params = StdioServerParameters(
        command="npx",
        args=["@cocal/google-calendar-mcp"],
        env={"GOOGLE_OAUTH_CREDENTIALS": _os.path.abspath(creds)},
    )

    async with stdio_client(params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            tools = await session.list_tools()
            names = [t.name for t in tools.tools]
            if "create-event" not in names:
                return {"ok": False, "error": "create-event tool not available"}

            res = await session.call_tool("create-event", {
                "calendarId": "primary",
                "summary": summary,
                "start": start_iso,
                "end": end_iso,
                "location": location or "",
                "description": description or "",
            })
            return {"ok": True, "result": res.content}


def create_calendar_event_intent(user_text: str, default_title: str = "Appointment") -> Dict[str, Any]:
    parsed = _parse_time_natural(user_text)
    if not parsed:
        return {"ok": False, "error": "Could not parse time", "intent": None}
    title = _extract_title(user_text) or default_title
    return {
        "ok": True,
        "intent": {
            "summary": title,
            "start": parsed["start"],
            "end": parsed["end"],
            "location": None,
            "description": user_text,
        }
    }


def create_calendar_event(summary: str, start_iso: str, end_iso: str, location: Optional[str] = None, description: Optional[str] = None) -> Dict[str, Any]:
    try:
        return asyncio.run(_create_event_async(summary, start_iso, end_iso, location, description))
    except Exception as e:
        return {"ok": False, "error": str(e)}


async def _list_events_async(calendar_id: str, time_min_iso: str, time_max_iso: str) -> Dict[str, Any]:
    if ClientSession is None:
        return {"ok": False, "error": "mcp Python SDK not installed"}

    creds = os.getenv("GOOGLE_OAUTH_CREDENTIALS")
    if not creds:
        return {"ok": False, "error": "GOOGLE_OAUTH_CREDENTIALS not set"}

    import os as _os
    params = StdioServerParameters(
        command="npx",
        args=["@cocal/google-calendar-mcp"],
        env={"GOOGLE_OAUTH_CREDENTIALS": _os.path.abspath(creds)},
    )

    async with stdio_client(params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            tools = await session.list_tools()
            names = [t.name for t in tools.tools]
            if "list-events" not in names:
                return {"ok": False, "error": "list-events tool not available"}

            res = await session.call_tool("list-events", {
                "calendarId": calendar_id,
                "timeMin": time_min_iso,
                "timeMax": time_max_iso,
                "singleEvents": True,
                "orderBy": "startTime"
            })
            parsed = _parse_content_json(res.content)
            return {"ok": True, "result": parsed or {"events": [], "raw": str(res.content)}}


def list_events_today(calendar_id: str = "primary") -> Dict[str, Any]:
    now = datetime.now().replace(microsecond=0)
    start = now.replace(hour=0, minute=0, second=0)
    end = now.replace(hour=23, minute=59, second=59)
    try:
        return asyncio.run(_list_events_async(calendar_id, start.isoformat(), end.isoformat()))
    except Exception as e:
        return {"ok": False, "error": str(e)}


def check_mcp_ready() -> Dict[str, Any]:
    try:
        if ClientSession is None:
            return {"ok": False, "error": "mcp Python SDK not installed"}
        creds = os.getenv("GOOGLE_OAUTH_CREDENTIALS")
        if not creds:
            return {"ok": False, "error": "GOOGLE_OAUTH_CREDENTIALS not set"}
        import os as _os
        params = StdioServerParameters(
            command="npx",
            args=["@cocal/google-calendar-mcp"],
            env={"GOOGLE_OAUTH_CREDENTIALS": _os.path.abspath(creds)},
        )
        async def _run():
            async with stdio_client(params) as (read, write):
                async with ClientSession(read, write) as session:
                    await session.initialize()
                    tools = await session.list_tools()
                    names = [t.name for t in tools.tools]
                    return {"ok": True, "tools": names}
        import asyncio
        return asyncio.run(_run())
    except Exception as e:
        return {"ok": False, "error": str(e)}


async def _delete_event_async(calendar_id: str, event_id: str) -> Dict[str, Any]:
    if ClientSession is None:
        return {"ok": False, "error": "mcp Python SDK not installed"}

    creds = os.getenv("GOOGLE_OAUTH_CREDENTIALS")
    if not creds:
        return {"ok": False, "error": "GOOGLE_OAUTH_CREDENTIALS not set"}

    import os as _os
    params = StdioServerParameters(
        command="npx",
        args=["@cocal/google-calendar-mcp"],
        env={"GOOGLE_OAUTH_CREDENTIALS": _os.path.abspath(creds)},
    )

    async with stdio_client(params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            tools = await session.list_tools()
            names = [t.name for t in tools.tools]
            if "delete-event" not in names:
                return {"ok": False, "error": "delete-event tool not available"}
            res = await session.call_tool("delete-event", {
                "calendarId": calendar_id,
                "eventId": event_id
            })
            return {"ok": True, "result": res.content}


def delete_event(calendar_id: str, event_id: str) -> Dict[str, Any]:
    try:
        return asyncio.run(_delete_event_async(calendar_id, event_id))
    except Exception as e:
        return {"ok": False, "error": str(e)}


def _parse_duration_minutes(text: str) -> int:
    t = text.lower()
    if "hour" in t:
        import re
        m = re.search(r"(\d+)\s*hour", t)
        return int(m.group(1)) * 60 if m else 60
    if "minute" in t:
        import re
        m = re.search(r"(\d+)\s*minute", t)
        return int(m.group(1)) if m else 30
    return 60


async def _update_event_async(calendar_id: str, event_id: str, start_iso: str, end_iso: str, description: Optional[str]) -> Dict[str, Any]:
    if ClientSession is None:
        return {"ok": False, "error": "mcp Python SDK not installed"}
    creds = os.getenv("GOOGLE_OAUTH_CREDENTIALS")
    if not creds:
        return {"ok": False, "error": "GOOGLE_OAUTH_CREDENTIALS not set"}
    import os as _os
    params = StdioServerParameters(
        command="npx",
        args=["@cocal/google-calendar-mcp"],
        env={"GOOGLE_OAUTH_CREDENTIALS": _os.path.abspath(creds)},
    )
    async with stdio_client(params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            tools = await session.list_tools()
            names = [t.name for t in tools.tools]
            if "update-event" not in names:
                return {"ok": False, "error": "update-event tool not available"}
            res = await session.call_tool("update-event", {
                "calendarId": calendar_id,
                "eventId": event_id,
                "start": start_iso,
                "end": end_iso,
                "description": description or ""
            })
            return {"ok": True, "result": res.content}


def update_event(calendar_id: str, event_id: str, start_iso: str, end_iso: str, description: Optional[str]) -> Dict[str, Any]:
    try:
        return asyncio.run(_update_event_async(calendar_id, event_id, start_iso, end_iso, description))
    except Exception as e:
        return {"ok": False, "error": str(e)}
def _parse_content_json(content_list: Any) -> Optional[Dict[str, Any]]:
    try:
        if not content_list:
            return None
        item = content_list[0]
        txt = getattr(item, "text", None)
        if not txt:
            return None
        import json
        return json.loads(txt)
    except Exception:
        return None
def _extract_title(text: str) -> Optional[str]:
    t = text.strip()
    import re
    # explicit title syntax
    m = re.search(r"title\s*[:=]?\s*['\"“”]([^'\"“”]+)['\"“”]", t, re.IGNORECASE)
    if m:
        return m.group(1).strip()
    # title before scheduling keywords
    m2 = re.search(r"title\s*[:=]?\s*['\"“”]?(.+?)['\"“”]?\s+(?:and\s+set|set|at|on|for|which|that|schedule|scheduled|lasting|lasts)\b", t, re.IGNORECASE)
    if m2:
        return m2.group(1).strip()
    # phrase like "about <title> ..."
    m3 = re.search(r"\babout\s+(.+?)(?:\s+(?:and|that's|for|at|on|lasting|lasts)\b|$)", t, re.IGNORECASE)
    if m3:
        return m3.group(1).strip().strip(".,")
    # leading phrase before "at <time>"
    m4 = re.search(r"(.+?)\s+at\s+\d", t, re.IGNORECASE)
    if m4:
        return m4.group(1).strip()
    return None
