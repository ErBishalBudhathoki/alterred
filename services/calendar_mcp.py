"""
Calendar MCP Service
====================
Provides integration with Google Calendar using the Model Context Protocol (MCP).
Handles OAuth credential management, event creation, listing, updating, and deletion.
Also includes natural language processing for time and duration parsing.

Implementation Details:
- Uses `mcp` Python SDK to communicate with the `@cocal/google-calendar-mcp` server.
- Manages OAuth tokens using `UserSettings` and `GoogleOAuthHandler`.
- Implements a temporary credential file mechanism for the MCP server.
- Provides async wrappers (`_create_event_async`, etc.) and synchronous entry points.

Design Decisions:
- Uses `tempfile` to securely pass credentials to the MCP server process.
- Implements a "check and refresh" logic for OAuth tokens before every operation.
- fallback to `GOOGLE_OAUTH_CREDENTIALS` env var for local dev/testing.

Behavioral Specifications:
- `create_calendar_event`: Parses natural language time/duration if needed, creates event.
- `list_events_today`: Lists events for the current day.
- `check_mcp_ready`: Verifies if the MCP server and credentials are ready.
"""
import os
import asyncio
import tempfile
import json
import logging
from typing import Optional, Dict, Any
from datetime import datetime, timedelta, timezone
from google.genai import Client as _GenClient

# Configure logging
logger = logging.getLogger(__name__)

try:
    from mcp import ClientSession, StdioServerParameters
    from mcp.client.stdio import stdio_client
except Exception:
    ClientSession = None  # type: ignore


def _get_mcp_server_params(env_dict: Dict[str, str]) -> StdioServerParameters:
    """
    Get MCP server parameters, preferring local build if available.
    """
    current_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(current_dir)
    local_mcp_path = os.path.join(project_root, "google-calendar-mcp", "build", "index.js")
    
    if os.path.exists(local_mcp_path):
        logger.info(f"Using local MCP server at: {local_mcp_path}")
        command = "node"
        args = [local_mcp_path]
    else:
        logger.info("Using NPM package @cocal/google-calendar-mcp")
        command = "npx"
        args = ["@cocal/google-calendar-mcp"]
        
    # Disable interactive auth to prevent server-side popups
    env_dict["MCP_DISABLE_INTERACTIVE_AUTH"] = "true"

    return StdioServerParameters(
        command=command,
        args=args,
        env=env_dict,
    )


def _is_valid_credential_file(path: str) -> bool:
    """
    Validate if the credential file has the required structure for Google OAuth.
    Checks for 'installed' or 'web' keys with 'redirect_uris', or 'authorized_user' type.
    """
    try:
        with open(path, 'r') as f:
            data = json.load(f)
            
        # Case 1: Client Secrets (for flow initiation)
        if "installed" in data:
            return "redirect_uris" in data["installed"]
        if "web" in data:
            return "redirect_uris" in data["web"]
            
        # Case 2: User Credentials (authorized user)
        if data.get("type") == "authorized_user":
            return all(k in data for k in ["client_id", "client_secret", "refresh_token"])
            
        return False
    except Exception as e:
        logger.warning(f"Invalid credential file {path}: {e}")
        return False


def _is_valid_mcp_credential_file(path: str) -> bool:
    try:
        with open(path, 'r') as f:
            data = json.load(f)
        if "installed" in data:
            rus = data["installed"].get("redirect_uris", [])
            return any(u.startswith("http://localhost") or u.startswith("http://127.0.0.1") for u in rus) or ("http://localhost" in rus)
        if "web" in data:
            rus = data["web"].get("redirect_uris", [])
            return any(u.startswith("http://localhost") or u.startswith("http://127.0.0.1") for u in rus)
        if data.get("type") == "authorized_user":
            return True
        return False
    except Exception:
        return False
def _get_user_credentials_file(user_id: Optional[str], account: str = "normal") -> Optional[str]:
    """
    Get OAuth credentials for user.
    Prioritizes:
    1. Authenticated user settings (if user_id provided and connected)
    2. Fallback to credentials directory (e.g. gcp-oauth.keys.json) - ONLY if valid
    3. Fallback to GOOGLE_OAUTH_CREDENTIALS env var - ONLY if valid
    """
    creds_path = None
    auth_method = "none"

    # 1. Try User Settings (Priority)
    if user_id:
        try:
            from services.user_settings import UserSettings
            from services.oauth_handlers import GoogleOAuthHandler
            
            user_settings = UserSettings(user_id)
            provider = "google_calendar" if account == "normal" else "google_calendar_test"
            tokens = user_settings.get_oauth_tokens(provider)
            
            if tokens:
                # ALWAYS refresh tokens before passing to MCP to ensure they're fresh
                # This prevents MCP from trying its own OAuth flow
                try:
                    expires_at = datetime.fromisoformat(tokens["expires_at"])
                    if expires_at.tzinfo is None:
                        expires_at = expires_at.replace(tzinfo=timezone.utc)
                except Exception:
                    expires_at = datetime.now(timezone.utc)
                now_utc = datetime.now(timezone.utc)
                needs_refresh = now_utc >= (expires_at - timedelta(minutes=5))
                
                if needs_refresh:
                    logger.info(f"Refreshing token for user {user_id} before creating MCP temp file...")
                    oauth_handler = GoogleOAuthHandler()
                    refresh_result = oauth_handler.refresh_access_token(tokens["refresh_token"])
                    
                    if refresh_result.get("ok"):
                        logger.info(f"Token refreshed successfully for user {user_id}")
                        # Save refreshed tokens to Firestore
                        user_settings.save_oauth_tokens(
                            provider=provider,
                            access_token=refresh_result["access_token"],
                            refresh_token=tokens["refresh_token"],
                            expires_at=refresh_result["expires_at"],
                            scopes=tokens["scopes"]
                        )
                        # Update local tokens variable
                        tokens["access_token"] = refresh_result["access_token"]
                        tokens["expires_at"] = refresh_result["expires_at"]
                    else:
                        error_msg = refresh_result.get("error", "Unknown error")
                        logger.error(f"Token refresh failed for user {user_id}: {error_msg}")
                        
                        # If invalid grant or unauthorized client, delete tokens
                        err_str = str(error_msg).lower()
                        if "invalid_grant" in err_str or "invalid grant" in err_str or "unauthorized_client" in err_str:
                            logger.warning(f"Deleting invalid tokens for user {user_id}")
                            user_settings.delete_oauth_tokens(provider)
                            return None
                        
                        # Other errors - set tokens to None
                        tokens = None
                
                # Only create temp file if we have VALID, FRESH tokens
                if tokens:
                    # Include the fresh access_token so MCP doesn't try to refresh
                    credentials = {
                        "type": "authorized_user",
                        "client_id": os.getenv("GOOGLE_OAUTH_CLIENT_ID"),
                        "client_secret": os.getenv("GOOGLE_OAUTH_CLIENT_SECRET"),
                        "refresh_token": tokens["refresh_token"],
                        "access_token": tokens["access_token"],  # Fresh token from our refresh
                    }
                    fd, path = tempfile.mkstemp(suffix=".json", prefix="oauth_")
                    with os.fdopen(fd, 'w') as f:
                        json.dump(credentials, f)
                    creds_path = path
                    auth_method = "user_settings"
                    logger.info(f"Created temp credentials file for MCP (refresh_token only): {path}")
        except Exception as e:
            logger.error(f"Error accessing user settings: {e}")

    # 2. Fallback to global/local credentials if not found in settings
    if not creds_path:
        # For real app users, do NOT fallback to local files. 
        # This ensures they get a proper error message asking to connect Settings,
        # instead of the server trying to auth with its own local keys.
        is_real_user = user_id and user_id != "terminal_user" and user_id != os.getenv("USER")
        if is_real_user:
            logger.warning(f"No UserSettings credentials found for {user_id}. Skipping fallback to prevent server-side auth popup.")
            return None

        # Use relative path from this file (services/calendar_mcp.py) -> project_root/credentials
        current_dir = os.path.dirname(os.path.abspath(__file__))
        project_root = os.path.dirname(current_dir)
        fallback_dir = os.path.join(project_root, "credentials")
        logger.info(f"Fallback directory: {fallback_dir}")
        try:
            files = []
            for name in os.listdir(fallback_dir):
                if name.endswith(".json"):
                    files.append(os.path.join(fallback_dir, name))
        except Exception:
            files = []
        preferred_name = os.getenv("MCP_CREDENTIALS_PREFERRED", "oauth-neuropilot.keys.json")
        preferred_path = os.path.join(fallback_dir, preferred_name)
        if os.path.exists(preferred_path) and _is_valid_mcp_credential_file(preferred_path):
            creds_path = preferred_path
            auth_method = "fallback_file"
        else:
            if account == "normal":
                # Don't fallback to gcp-oauth.keys.json automatically as it triggers interactive auth
                # which fails in the API server context (wrong redirect URI).
                # User should connect via Settings UI.
                candidates = [] 
                logger.info(f"Normal account candidates: {candidates}")
            else:
                candidates = ["oauth-neuropilot.keys.json", "gcp-oauth.keys.json", "google-services-prod(altered).json"]
                logger.info(f"Test account candidates: {candidates}")
            files = [os.path.join(fallback_dir, c) for c in candidates] + files
            for fpath in files:
                try:
                    if os.path.exists(fpath) and _is_valid_mcp_credential_file(fpath):
                        creds_path = fpath
                        auth_method = "fallback_file"
                        break
                except Exception:
                    continue
        if not creds_path:
            env_creds = os.getenv("GOOGLE_OAUTH_CREDENTIALS")
            if env_creds and os.path.exists(env_creds) and _is_valid_credential_file(env_creds):
                creds_path = env_creds
                auth_method = "env_var"
            elif env_creds:
                logger.warning(f"Skipping invalid GOOGLE_OAUTH_CREDENTIALS file: {env_creds}")

    if creds_path:
        logger.info(f"Calendar MCP using authentication method: {auth_method} (Path: {creds_path})")
        return creds_path
    
    logger.warning(f"No calendar credentials found for user {user_id} (account={account})")
    return None


def _parse_time_natural(text: str) -> Optional[Dict[str, str]]:
    """Parse natural language like:
    - "tomorrow at 9:15"
    - "for 9:15" (assumed today, local time)
    - "9 pm" or "9:15 am"
    - duration phrases ("for 1 hour", "for 30 minutes")

    Returns start/end ISO strings with local timezone.
    """
    # Use UTC to avoid server-side timezone bias (e.g. server in Sydney +11 shifting user's intended time).
    # This assumes the user's "natural language" intent maps to UTC if no timezone is provided.
    now = datetime.now()
    lower = text.lower()
    day_offset = 0
    if "day after tomorrow" in lower:
        day_offset = 2
    elif "tomorrow" in lower:
        day_offset = 1
    base_day = now + timedelta(days=day_offset)
    import re
    m_weekday = re.search(r"\b(next\s+|this\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b", lower)
    if m_weekday:
        force_next = bool(m_weekday.group(1) and m_weekday.group(1).strip().startswith("next"))
        name = m_weekday.group(2)
        dow = {"monday":0,"tuesday":1,"wednesday":2,"thursday":3,"friday":4,"saturday":5,"sunday":6}
        target = dow.get(name, base_day.weekday())
        delta = (target - base_day.weekday()) % 7
        if delta == 0 and force_next:
            delta = 7
        base_day = (base_day + timedelta(days=delta)).replace(hour=base_day.hour, minute=base_day.minute, second=base_day.second, microsecond=0)

    # Duration
    minutes = _parse_duration_minutes(lower)

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

    # 3) Month name: "in December", "December", "December 2025"
    m_month = re.search(r"\b(in\s+)?(january|february|march|april|may|june|july|august|september|october|november|december)\s*(\d{4})?\b", lower)
    if m_month:
        month_name = m_month.group(2)
        year_str = m_month.group(3)
        month_map = {
            "january": 1, "february": 2, "march": 3, "april": 4, "may": 5, "june": 6,
            "july": 7, "august": 8, "september": 9, "october": 10, "november": 11, "december": 12
        }
        m_idx = month_map[month_name]
        y = int(year_str) if year_str else now.year
        
        # If month is in the past for this year, and year wasn't specified, assume next year
        if not year_str and m_idx < now.month:
            y += 1
            
        import calendar
        last_day = calendar.monthrange(y, m_idx)[1]
        start = datetime(y, m_idx, 1)
        end = datetime(y, m_idx, last_day, 23, 59, 59)
        return {"start": start.isoformat(), "end": end.isoformat()}

    return None


async def _create_event_async(summary: str, start_iso: str, end_iso: str, location: Optional[str], description: Optional[str], user_id: Optional[str] = None, recurrence: Optional[list[str]] = None) -> Dict[str, Any]:
    logger.info(f"Starting event creation for user {user_id}: {summary}")
    payload = {
        "calendarId": "primary",
        "summary": summary,
        "start": start_iso,
        "end": end_iso,
        "location": location or "",
        "description": description or "",
    }
    if recurrence:
        payload["recurrence"] = recurrence
    return await _call_mcp("create-event", payload, user_id)


def smart_parse_calendar_intent(text: str, user_id: Optional[str] = None) -> Dict[str, Any]:
    """
    Uses Gemini to parse natural language calendar requests into structured data.
    """
    try:
        api_key = None
        if user_id:
            try:
                from services.user_settings import UserSettings
                settings = UserSettings(user_id)
                api_key = settings.get_api_key()
            except Exception:
                pass

        client = _genai_client(api_key=api_key)
            
        now = datetime.now().isoformat()
        # Use a robust model name for Vertex AI compatibility
        model_name = os.getenv("DEFAULT_MODEL", "gemini-flash-latest")
        if model_name == "gemini-flash-latest" or "flash" in model_name:
            # Fallback to gemini-flash-latest as flash seems unavailable in this region/setup
            model_name = "gemini-flash-latest"
            
        prompt = f"""
        You are a smart calendar assistant. Parse the following user request into a JSON object.
        Current time: {now}
        User Request: "{text}"
        
        Return JSON with these keys:
        - operation: "create", "list", "update", "delete", or "unknown"
        - summary: (for create/update) Event title
        - start: (ISO 8601 string) Start time. If all day, use YYYY-MM-DD. Calculate based on current time.
        - end: (ISO 8601 string) End time.
        - recurrence: (list of strings, optional) RRULE strings if repeating. e.g. ["RRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR"]
        - location: (optional)
        - description: (optional)
        - query: (for list/search) Search keywords
        - event_id: (for update/delete)
        - calendar_id: (default "primary")
        
        Rules:
        - For "Monday to Friday", if it implies daily events (like "meeting from Mon to Fri"), create a DAILY recurrence or WEEKLY with BYDAY.
        - For "from December month", set start to Dec 1st and end to Dec 31st of current/next year.
        - Be precise with ISO dates.
        """
        
        resp = client.models.generate_content(
            model=model_name,
            contents=prompt
        )
        import json
        txt = resp.text
        if "```json" in txt:
            txt = txt.split("```json")[1].split("```")[0]
        elif "```" in txt:
            txt = txt.split("```")[1].split("```")[0]
        return json.loads(txt)
    except Exception as e:
        logger.error(f"Smart parse failed: {e}")
        # Fallback to regex parsing for search queries if LLM fails
        # This ensures "events in December" still works even if Gemini is down
        fallback = _parse_time_natural(text)
        if fallback:
            return {
                "operation": "list", # Default to list/search if we just found a date
                "start": fallback["start"],
                "end": fallback["end"],
                "query": text
            }
        return {"operation": "unknown", "error": str(e)}


def create_calendar_event_intent(user_text: str, default_title: str = "Appointment", user_id: Optional[str] = None) -> Dict[str, Any]:
    # Try smart parse first
    try:
        parsed = smart_parse_calendar_intent(user_text, user_id=user_id)
        if parsed.get("operation") == "create":
            return {
                "ok": True,
                "intent": {
                    "summary": parsed.get("summary") or default_title,
                    "start": parsed.get("start"),
                    "end": parsed.get("end"),
                    "location": parsed.get("location"),
                    "description": parsed.get("description") or user_text,
                    "recurrence": parsed.get("recurrence")
                }
            }
    except Exception:
        pass

    parsed = _parse_time_natural(user_text)
    if not parsed:
        return {"ok": False, "error": "Could not parse time", "intent": None}
    title = _extract_title(user_text) or default_title
    recurrence_str = _extract_recurrence(user_text, parsed["start"], parsed["end"])
    recurrence_list = [recurrence_str] if recurrence_str else None
    
    return {
        "ok": True,
        "intent": {
            "summary": title,
            "start": parsed["start"],
            "end": parsed["end"],
            "location": None,
            "description": user_text,
            "recurrence": recurrence_list
        }
    }

def _extract_recurrence(text: str, start_iso: Optional[str] = None, end_iso: Optional[str] = None) -> Optional[str]:
    t = text.lower()
    
    # Handle "every Monday", "every Tuesday and Thursday" FIRST
    days_map = {
        "monday": "MO", "tuesday": "TU", "wednesday": "WE", "thursday": "TH",
        "friday": "FR", "saturday": "SA", "sunday": "SU",
        "mon": "MO", "tue": "TU", "wed": "WE", "thu": "TH", "fri": "FR", "sat": "SA", "sun": "SU"
    }
    
    found_days = []
    if "every" in t:
        for day_name, code in days_map.items():
            import re
            # Check if it's part of "every ..." 
            if re.search(r"every\b.*" + day_name, t):
                if code not in found_days:
                    found_days.append(code)
    
    if found_days:
        base_rule = f"RRULE:FREQ=WEEKLY;BYDAY={','.join(found_days)}"
        bounded = _maybe_bounded_until_or_count(t, start_iso, end_iso, base_rule)
        return bounded or base_rule

    # Weekday/weekend shortcuts
    import re
    if re.search(r"\bweekdays?\b", t):
        base_rule = "RRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR"
        bounded = _maybe_bounded_until_or_count(t, start_iso, end_iso, base_rule)
        return bounded or base_rule
    if re.search(r"\bweekends?\b", t):
        base_rule = "RRULE:FREQ=WEEKLY;BYDAY=SA,SU"
        bounded = _maybe_bounded_until_or_count(t, start_iso, end_iso, base_rule)
        return bounded or base_rule

    # Ranges like "from Monday to Friday" or "Mon-Fri"
    if re.search(r"\b(?:from\s+)?monday\s*(?:to|-)\s*friday\b", t) or re.search(r"\b(?:from\s+)?mon\s*(?:to|-)\s*fri\b", t):
        base_rule = "RRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR"
        bounded = _maybe_bounded_until_or_count(t, start_iso, end_iso, base_rule)
        return bounded or base_rule

    if "every day" in t or "daily" in t:
        base_rule = "RRULE:FREQ=DAILY"
        bounded = _maybe_bounded_until_or_count(t, start_iso, end_iso, base_rule)
        return bounded or base_rule
    if "every week" in t or "weekly" in t:
        base_rule = "RRULE:FREQ=WEEKLY"
        bounded = _maybe_bounded_until_or_count(t, start_iso, end_iso, base_rule)
        return bounded or base_rule
    if "every month" in t or "monthly" in t:
        base_rule = "RRULE:FREQ=MONTHLY"
        bounded = _maybe_bounded_until_or_count(t, start_iso, end_iso, base_rule)
        return bounded or base_rule
    if "every year" in t or "yearly" in t:
        base_rule = "RRULE:FREQ=YEARLY"
        bounded = _maybe_bounded_until_or_count(t, start_iso, end_iso, base_rule)
        return bounded or base_rule
        
    return None


def _maybe_bounded_until_or_count(t: str, start_iso: Optional[str], end_iso: Optional[str], base_rule: str) -> Optional[str]:
    """Augment RRULE with UNTIL or COUNT when the text specifies bounded ranges.
    Examples:
    - "from next Monday to next Friday"
    - "until Dec 5"
    - "for 3 weeks" / "repeat 5 times"
    """
    import re
    from datetime import datetime
    # 1) COUNT phrases
    m_count = re.search(r"\b(?:repeat|times|occurrences?)\b\s*(\d{1,3})", t)
    if m_count:
        cnt = int(m_count.group(1))
        return f"{base_rule};COUNT={cnt}"
    m_for_weeks = re.search(r"\bfor\s+(\d{1,3})\s+weeks?\b", t)
    if m_for_weeks:
        weeks = int(m_for_weeks.group(1))
        if start_iso:
            try:
                base = datetime.fromisoformat(start_iso)
                # End at the end of the last week window to include all BYDAY occurrences
                end_dt = base + timedelta(weeks=max(1, weeks) - 1, days=6)
                return f"{base_rule};UNTIL={_fmt_until(end_dt)}"
            except Exception:
                pass
        # Fallback to occurrences: approximate by occurrences per week when BYDAY present
        if "BYDAY=" in base_rule:
            byday = base_rule.split("BYDAY=")[-1]
            days_per_week = len(byday.split(","))
            return f"{base_rule};COUNT={weeks * days_per_week}"
        return f"{base_rule};COUNT={weeks}"
    m_for_days = re.search(r"\bfor\s+(\d{1,3})\s+days?\b", t)
    if m_for_days and ("FREQ=DAILY" in base_rule):
        days = int(m_for_days.group(1))
        return f"{base_rule};COUNT={days}"
    
    # 2) UNTIL by explicit end date or weekday range
    def _fmt_until(dt: datetime) -> str:
        # RFC5545 basic UTC format: YYYYMMDDT235959Z
        z = dt.astimezone().replace(hour=23, minute=59, second=59, microsecond=0)
        return z.strftime("%Y%m%dT%H%M%SZ")
    try:
        start_dt = datetime.fromisoformat(start_iso) if start_iso else None
    except Exception:
        start_dt = None
    
    # until <month day>, <year> or until <YYYY-MM-DD>
    m_until_date = re.search(r"\buntil\s+(\w+\s+\d{1,2}(?:,\s*\d{4})?|\d{4}-\d{2}-\d{2})\b", t)
    if m_until_date:
        try:
            val = m_until_date.group(1)
            end_dt = None
            from datetime import datetime
            if re.match(r"\d{4}-\d{2}-\d{2}", val):
                end_dt = datetime.strptime(val, "%Y-%m-%d")
            else:
                # Try "December 5, 2024" or "December 5"
                try:
                    end_dt = datetime.strptime(val, "%B %d, %Y")
                except Exception:
                    try:
                        tmp = datetime.strptime(val, "%B %d")
                        end_dt = tmp.replace(year=(start_dt.year if start_dt else datetime.now().year))
                    except Exception:
                        end_dt = None
            return f"{base_rule};UNTIL={_fmt_until(end_dt)}"
        except Exception:
            pass
    
    # from/next Weekday to/– next Weekday
    m_range = re.search(r"\b(?:from\s+)?(next\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\s*(?:to|-|until)\s*(next\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b", t)
    if m_range and start_dt:
        start_next = bool(m_range.group(1))
        start_day = m_range.group(2)
        end_next = bool(m_range.group(3))
        end_day = m_range.group(4)
        dow = {"monday":0,"tuesday":1,"wednesday":2,"thursday":3,"friday":4,"saturday":5,"sunday":6}
        def next_weekday(base: datetime, target_dow: int, force_next: bool) -> datetime:
            delta = (target_dow - base.weekday()) % 7
            if delta == 0 or force_next:
                delta = (delta or 7)
            return (base + timedelta(days=delta)).replace(hour=base.hour, minute=base.minute, second=base.second, microsecond=0)
        start_bound = next_weekday(start_dt, dow[start_day], start_next) if start_dt else None
        end_bound = next_weekday(start_dt, dow[end_day], True if end_next else False) if start_dt else None
        if end_bound and start_bound and end_bound >= start_bound:
            return f"{base_rule};UNTIL={_fmt_until(end_bound)}"
    
    return None


def create_calendar_event(summary: str, start_iso: str, end_iso: str, location: Optional[str] = None, description: Optional[str] = None, user_id: Optional[str] = None) -> Dict[str, Any]:
    try:
        return asyncio.run(_create_event_async(summary, start_iso, end_iso, location, description, user_id))
    except Exception as e:
        return {"ok": False, "error": str(e)}


async def _list_events_async(calendar_id: str, time_min_iso: str, time_max_iso: str, user_id: Optional[str] = None) -> Dict[str, Any]:
    logger.info(f"Listing events for user {user_id}: {time_min_iso} - {time_max_iso}")
    payload = {
        "calendarId": calendar_id,
        "timeMin": time_min_iso,
        "timeMax": time_max_iso,
        "singleEvents": True,
        "orderBy": "startTime"
    }
    res = await _call_mcp("list-events", payload, user_id)
    if res.get("ok"):
        parsed = _parse_content_json(res.get("result"))
        logger.info(f"Listed {len(parsed.get('events', [])) if parsed else 0} events")
        return {"ok": True, "result": parsed or {"events": []}}
    return res


def list_events_today(calendar_id: str = "primary", user_id: Optional[str] = None) -> Dict[str, Any]:
    now = datetime.now().astimezone().replace(microsecond=0)
    start = now.replace(hour=0, minute=0, second=0)
    end = now.replace(hour=23, minute=59, second=59)
    try:
        return asyncio.run(_list_events_async(calendar_id, start.isoformat(), end.isoformat(), user_id))
    except Exception as e:
        return {"ok": False, "error": str(e)}


def check_mcp_ready(user_id: Optional[str] = None) -> Dict[str, Any]:
    logger.info(f"Checking MCP readiness for user {user_id}")
    try:
        if ClientSession is None:
            logger.error("mcp Python SDK not installed")
            return {"ok": False, "error": "mcp Python SDK not installed"}
        
        # Pre-validate tokens before starting MCP server
        if user_id:
            try:
                from services.user_settings import UserSettings
                from services.oauth_handlers import GoogleOAuthHandler
                
                user_settings = UserSettings(user_id)
                provider = "google_calendar"
                tokens = user_settings.get_oauth_tokens(provider)
                
                if tokens:
                    # Check if expired and try to refresh
                    try:
                        expires_at = datetime.fromisoformat(tokens["expires_at"])
                        if expires_at.tzinfo is None:
                            expires_at = expires_at.replace(tzinfo=timezone.utc)
                    except Exception:
                        expires_at = datetime.now(timezone.utc)
                    now_utc = datetime.now(timezone.utc)
                    if now_utc >= expires_at:
                        logger.info(f"Token expired for user {user_id} in check_mcp_ready, attempting refresh...")
                        oauth_handler = GoogleOAuthHandler()
                        refresh_result = oauth_handler.refresh_access_token(tokens["refresh_token"])
                        
                        if not refresh_result.get("ok"):
                            error_msg = refresh_result.get("error", "Unknown error")
                            logger.error(f"Token refresh failed in check_mcp_ready for user {user_id}: {error_msg}")
                            
                            # Delete invalid tokens to prevent MCP server from trying to use them
                            err_str = str(error_msg).lower()
                            if "invalid_grant" in err_str or "invalid grant" in err_str or "unauthorized_client" in err_str:
                                logger.warning(f"Deleting invalid tokens for user {user_id}")
                                user_settings.delete_oauth_tokens(provider)
                            
                            # Return error immediately - do NOT proceed to launch MCP
                            return {"ok": False, "error": f"Calendar authentication expired. Please reconnect in Settings."}
                        
                        # Save refreshed tokens
                        logger.info(f"Token refreshed successfully in check_mcp_ready for user {user_id}")
                        user_settings.save_oauth_tokens(
                            provider=provider,
                            access_token=refresh_result["access_token"],
                            refresh_token=tokens["refresh_token"],
                            expires_at=refresh_result["expires_at"],
                            scopes=tokens["scopes"]
                        )
            except Exception as e:
                logger.error(f"Error validating tokens in check_mcp_ready: {e}")
                # Return error instead of continuing
                return {"ok": False, "error": f"Token validation error: {str(e)}"}
        
        # Check if tokens still exist after validation - if deleted, return error
        if user_id:
            try:
                from services.user_settings import UserSettings
                user_settings = UserSettings(user_id)
                tokens = user_settings.get_oauth_tokens("google_calendar")
                if not tokens:
                    logger.warning(f"No tokens found for user {user_id} after validation - returning error to prevent MCP launch")
                    return {"ok": False, "error": "Calendar not connected. Please connect in Settings."}
            except Exception:
                pass
        
        # Only proceed if token validation passed (or no user_id)
        creds_path = _get_user_credentials_file(user_id)
        if not creds_path:
            logger.warning(f"No credentials found for user {user_id}")
            return {"ok": False, "error": "No calendar credentials available"}
        
        import os as _os
        # Build env dict - prevent fallback to global credentials
        env_dict = {}
        if creds_path:
            env_dict["GOOGLE_OAUTH_CREDENTIALS"] = _os.path.abspath(creds_path)
        elif user_id:
            env_dict["GOOGLE_OAUTH_CREDENTIALS"] = ""
        
        params = _get_mcp_server_params(env_dict)
        async def _run():
            try:
                async with stdio_client(params) as (read, write):
                    async with ClientSession(read, write) as session:
                        await session.initialize()
                        tools = await session.list_tools()
                        names = [t.name for t in tools.tools]
                        logger.info(f"MCP ready. Tools: {names}")
                        return {"ok": True, "tools": names}
            except Exception as e:
                logger.error(f"Error in check_mcp_ready async: {e}")
                raise e
            finally:
                # Clean up temp file if it was created for user
                if user_id and creds_path and creds_path.startswith(tempfile.gettempdir()):
                    try:
                        os.unlink(creds_path)
                    except Exception:
                        pass
        import asyncio
        return asyncio.run(_run())
    except Exception as e:
        logger.error(f"Error in check_mcp_ready: {e}")
        return {"ok": False, "error": str(e)}


async def _delete_event_async(calendar_id: str, event_id: str, user_id: Optional[str] = None) -> Dict[str, Any]:
    logger.info(f"Deleting event {event_id} from calendar {calendar_id} for user {user_id}")
    if ClientSession is None:
        logger.error("mcp Python SDK not installed")
        return {"ok": False, "error": "mcp Python SDK not installed"}

    creds_path = _get_user_credentials_file(user_id)
    if not creds_path:
        logger.warning(f"No credentials found for user {user_id}")
        return {"ok": False, "error": "No calendar credentials available. Please connect your Google Calendar."}

    import os as _os
    # Build env dict - prevent fallback to global credentials
    env_dict = {}
    if creds_path:
        env_dict["GOOGLE_OAUTH_CREDENTIALS"] = _os.path.abspath(creds_path)
        env_dict["GOOGLE_ACCOUNT_MODE"] = "normal"
        cid = os.getenv("GOOGLE_OAUTH_CLIENT_ID")
        csec = os.getenv("GOOGLE_OAUTH_CLIENT_SECRET")
        if cid:
            env_dict["GOOGLE_OAUTH_CLIENT_ID"] = cid
        if csec:
            env_dict["GOOGLE_OAUTH_CLIENT_SECRET"] = csec
    elif user_id:
        env_dict["GOOGLE_OAUTH_CREDENTIALS"] = ""
    
    params = _get_mcp_server_params(env_dict)

    try:
        async with stdio_client(params) as (read, write):
            async with ClientSession(read, write) as session:
                await session.initialize()
                tools = await session.list_tools()
                names = [t.name for t in tools.tools]
                if "delete-event" not in names:
                    logger.error("delete-event tool not available")
                    return {"ok": False, "error": "delete-event tool not available"}
                res = await session.call_tool("delete-event", {
                    "calendarId": calendar_id,
                    "eventId": event_id
                })
                logger.info(f"Event {event_id} deleted successfully")
                return {"ok": True, "result": res.content}
    except Exception as e:
        logger.error(f"Error in _delete_event_async: {e}")
        raise e
    finally:
        # Clean up temp file if it was created for user
        if user_id and creds_path and creds_path.startswith(tempfile.gettempdir()):
            try:
                os.unlink(creds_path)
            except Exception:
                pass


def delete_event(calendar_id: str, event_id: str, user_id: Optional[str] = None) -> Dict[str, Any]:
    try:
        return asyncio.run(_delete_event_async(calendar_id, event_id, user_id))
    except Exception as e:
        return {"ok": False, "error": str(e)}


def account_status(user_id: Optional[str] = None) -> Dict[str, Any]:
    try:
        from services.user_settings import UserSettings
        s = UserSettings(user_id or (os.getenv("USER") or "terminal_user"))
        normal = s.get_oauth_tokens("google_calendar")
        test = s.get_oauth_tokens("google_calendar_test")
        res_normal = check_mcp_ready(user_id)
        email = s.get_profile_email()
        if not email and normal:
            try:
                access_token = normal.get("access_token")
                import requests as _requests
                resp = _requests.get(
                    "https://www.googleapis.com/oauth2/v2/userinfo",
                    headers={"Authorization": f"Bearer {access_token}"},
                    timeout=8,
                )
                if resp.status_code == 200:
                    data = resp.json()
                    email = data.get("email")
                    if email:
                        s.save_profile_email(email)
            except Exception:
                pass
        return {
            "ok": True,
            "normal": {"has_tokens": bool(normal), "expires_at": (normal or {}).get("expires_at"), "email": email},
            "test": {"has_tokens": bool(test), "expires_at": (test or {}).get("expires_at")},
            "mcp_ready": res_normal.get("ok")
        }
    except Exception as e:
        return {"ok": False, "error": str(e)}


def account_clear(account: str = "normal", user_id: Optional[str] = None) -> Dict[str, Any]:
    try:
        from services.user_settings import UserSettings
        s = UserSettings(user_id or (os.getenv("USER") or "terminal_user"))
        provider = "google_calendar" if account == "normal" else "google_calendar_test"
        return s.delete_oauth_tokens(provider)
    except Exception as e:
        return {"ok": False, "error": str(e)}


def account_migrate(user_id: Optional[str] = None) -> Dict[str, Any]:
    try:
        env_creds = os.getenv("GOOGLE_OAUTH_CREDENTIALS")
        if not env_creds or not os.path.exists(env_creds):
            return {"ok": True, "migrated": 0}
        with open(env_creds, "r") as f:
            data = json.load(f)
        if data.get("type") == "authorized_user" and all(k in data for k in ["client_id", "client_secret", "refresh_token"]):
            from services.user_settings import UserSettings
            s = UserSettings(user_id or (os.getenv("USER") or "terminal_user"))
            expires_at = (datetime.now() + timedelta(hours=1)).isoformat()
            s.save_oauth_tokens("google_calendar", data.get("access_token", ""), data["refresh_token"], expires_at, ["https://www.googleapis.com/auth/calendar"])
            return {"ok": True, "migrated": 1}
        return {"ok": True, "migrated": 0}
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


async def _update_event_async(calendar_id: str, event_id: str, start_iso: str, end_iso: str, description: Optional[str], user_id: Optional[str] = None) -> Dict[str, Any]:
    logger.info(f"Updating event {event_id} for user {user_id}")
    if ClientSession is None:
        logger.error("mcp Python SDK not installed")
        return {"ok": False, "error": "mcp Python SDK not installed"}
    
    creds_path = _get_user_credentials_file(user_id)
    if not creds_path:
        logger.warning(f"No credentials found for user {user_id}")
        return {"ok": False, "error": "No calendar credentials available. Please connect your Google Calendar."}
    
    import os as _os
    # Build env dict - prevent fallback to global credentials
    env_dict = {}
    if creds_path:
        env_dict["GOOGLE_OAUTH_CREDENTIALS"] = _os.path.abspath(creds_path)
        env_dict["GOOGLE_ACCOUNT_MODE"] = "normal"
    elif user_id:
        env_dict["GOOGLE_OAUTH_CREDENTIALS"] = ""
    
    params = StdioServerParameters(
        command="npx",
        args=["@cocal/google-calendar-mcp"],
        env=env_dict,
    )
    
    try:
        async with stdio_client(params) as (read, write):
            async with ClientSession(read, write) as session:
                await session.initialize()
                tools = await session.list_tools()
                names = [t.name for t in tools.tools]
                if "update-event" not in names:
                    logger.error("update-event tool not available")
                    return {"ok": False, "error": "update-event tool not available"}
                res = await session.call_tool("update-event", {
                    "calendarId": calendar_id,
                    "eventId": event_id,
                    "start": start_iso,
                    "end": end_iso,
                    "description": description or ""
                })
                logger.info(f"Event {event_id} updated successfully")
                return {"ok": True, "result": res.content}
    except Exception as e:
        logger.error(f"Error in _update_event_async: {e}")
        raise e
    finally:
        # Clean up temp file if it was created for user
        if user_id and creds_path and creds_path.startswith(tempfile.gettempdir()):
            try:
                os.unlink(creds_path)
            except Exception:
                pass


def update_event(calendar_id: str, event_id: str, start_iso: str, end_iso: str, description: Optional[str], user_id: Optional[str] = None) -> Dict[str, Any]:
    try:
        return asyncio.run(_update_event_async(calendar_id, event_id, start_iso, end_iso, description, user_id))
    except Exception as e:
        return {"ok": False, "error": str(e)}


async def _create_recurring_event_async(summary: str, start_iso: str, end_iso: str, recurrence_rule: str, calendar_id: str = "primary", location: Optional[str] = None, description: Optional[str] = None, user_id: Optional[str] = None, account: str = "normal") -> Dict[str, Any]:
    payload = {
        "calendarId": calendar_id,
        "summary": summary,
        "start": start_iso,
        "end": end_iso,
        "location": location or "",
        "description": description or "",
        "recurrence": [recurrence_rule]
    }
    return await _call_mcp("create-event", payload, user_id, account)


def create_recurring_event(summary: str, start_iso: str, end_iso: str, recurrence_rule: str, calendar_id: str = "primary", location: Optional[str] = None, description: Optional[str] = None, user_id: Optional[str] = None, account: str = "normal") -> Dict[str, Any]:
    try:
        return asyncio.run(_create_recurring_event_async(summary, start_iso, end_iso, recurrence_rule, calendar_id, location, description, user_id, account))
    except Exception as e:
        return {"ok": False, "error": str(e)}


async def _update_recurring_event_async(calendar_id: str, event_id: str, scope: str, updates: Dict[str, Any], user_id: Optional[str] = None, account: str = "normal") -> Dict[str, Any]:
    payload = {
        "calendarId": calendar_id,
        "eventId": event_id,
        "scope": scope,
    }
    payload.update(updates)
    return await _call_mcp("update-event", payload, user_id, account)


def update_recurring_event(calendar_id: str, event_id: str, scope: str, updates: Dict[str, Any], user_id: Optional[str] = None, account: str = "normal") -> Dict[str, Any]:
    try:
        return asyncio.run(_update_recurring_event_async(calendar_id, event_id, scope, updates, user_id, account))
    except Exception as e:
        return {"ok": False, "error": str(e)}


def search_events(calendar_ids: list[str], time_min_iso: str, time_max_iso: str, attendee: Optional[str] = None, location: Optional[str] = None, status: Optional[str] = None, min_duration_minutes: Optional[int] = None, user_id: Optional[str] = None, account: str = "normal") -> Dict[str, Any]:
    try:
        listed = list_events_from_calendars(calendar_ids, time_min_iso, time_max_iso, user_id, account)
        if not listed.get("ok"):
            return listed
        events = listed["result"].get("events", [])
        def _dur_minutes(e: Dict[str, Any]) -> int:
            s = e.get("start", {})
            en = e.get("end", {})
            sdt = s.get("dateTime") or s.get("date")
            edt = en.get("dateTime") or en.get("date")
            sd = _parse_iso_dt(sdt)
            ed = _parse_iso_dt(edt)
            if sd and ed:
                return int((ed - sd).total_seconds() // 60)
            return 0
        filtered = []
        for e in events:
            if attendee:
                attendees = e.get("attendees", [])
                emails = [a.get("email", "") for a in attendees]
                if attendee not in emails:
                    continue
            if location and location.lower() not in (e.get("location", "") or "").lower():
                continue
            if status and status.lower() != (e.get("status", "") or "").lower():
                continue
            if min_duration_minutes and _dur_minutes(e) < min_duration_minutes:
                continue
            filtered.append(e)
        return {"ok": True, "result": {"events": filtered}}
    except Exception as e:
        return {"ok": False, "error": str(e)}


def analyze_calendar(calendar_ids: list[str], time_min_iso: str, time_max_iso: str, user_id: Optional[str] = None, account: str = "normal") -> Dict[str, Any]:
    try:
        listed = list_events_from_calendars(calendar_ids, time_min_iso, time_max_iso, user_id, account)
        if not listed.get("ok"):
            return listed
        events = listed["result"].get("events", [])
        total_minutes = 0
        recurring_count = 0
        by_day: Dict[str, int] = {}
        for e in events:
            s = e.get("start", {})
            en = e.get("end", {})
            sdt = s.get("dateTime") or s.get("date")
            edt = en.get("dateTime") or en.get("date")
            sd = _parse_iso_dt(sdt)
            ed = _parse_iso_dt(edt)
            if sd and ed:
                total_minutes += int((ed - sd).total_seconds() // 60)
                day_key = sd.date().isoformat()
                by_day[day_key] = by_day.get(day_key, 0) + 1
            if e.get("recurringEventId"):
                recurring_count += 1
        total_events = len(events)
        percent_recurring = (recurring_count / total_events * 100.0) if total_events > 0 else 0.0
        busiest_day = None
        if by_day:
            busiest_day = max(by_day.items(), key=lambda kv: kv[1])[0]
        return {"ok": True, "result": {"total_minutes": total_minutes, "percent_recurring": percent_recurring, "busiest_day": busiest_day}}
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
    import re
    t = text.strip()
    
    # 1. Explicit title: title="My Event" or title: My Event
    m_explicit = re.search(r'''\btitle\s*[:=]\s*['"]?([^'"]+?)['"]?(?:\s+(?:at|on|from|with|in|for|every)|$)''', t, re.IGNORECASE)
    if m_explicit:
        return m_explicit.group(1).strip()

    # 2. "appointment for X" pattern (specific high confidence)
    m_for = re.search(r'''\b(?:appointment|meeting|session|event|class|sync)\s+for\s+(.+?)(?:\s+(?:from|at|on|starting|beginning|which|that|with|every)|$)''', t, re.IGNORECASE)
    if m_for:
        return m_for.group(1).strip()

    # 3. General "Schedule X"
    # Capture everything after the verb
    m_schedule = re.search(r'''\b(?:schedule|create|add|book)\s+(.+?)(?:\s+(?:at|on|from|starting|beginning|in|to my calendar|every|to|next|this)|$)''', t, re.IGNORECASE)
    if m_schedule:
        raw_title = m_schedule.group(1).strip()
        
        # Cleanup logic
        # Remove leading "a ", "an ", "the "
        raw_title = re.sub(r'^(?:a|an|the)\s+', '', raw_title, flags=re.IGNORECASE)
        
        # Remove "meeting/event... for/about" prefix
        m_prefix = re.match(r'^(?:meeting|event|session|appointment|sync|call)\s+(?:for|about)\s+(.+)', raw_title, re.IGNORECASE)
        if m_prefix:
            return m_prefix.group(1).strip()
            
        # If it is JUST "meeting" or "event", ignore it
        if raw_title.lower() in ["meeting", "event", "appointment", "session", "call", "sync"]:
            return None
        # Remove "recurring" adjective
        raw_title = re.sub(r"\brecurring\b", "", raw_title, flags=re.IGNORECASE).strip()
        # Remove trailing range like "from Monday to Friday"
        raw_title = re.sub(r"\bfrom\s+\w+\s+(?:to|-)\s+\w+\b", "", raw_title, flags=re.IGNORECASE).strip()
        # Remove trailing day lists
        raw_title = re.sub(r"\b(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday)(?:,?\s+(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday))+\b", "", raw_title, flags=re.IGNORECASE).strip()
        return raw_title or None

    # 4. "about X" pattern
    m_about = re.search(r'''\babout\s+(.+?)(?:\s+(?:at|on|from|with|every)|$)''', t, re.IGNORECASE)
    if m_about:
        return m_about.group(1).strip().strip(".,")

    # 5. Fallback: "X at <time>"
    m_at = re.search(r'''^(.+?)\s+(?:at|from)\s+\d''', t, re.IGNORECASE)
    if m_at:
        return m_at.group(1).strip()
        
    return None


async def _list_events_multi_async(calendar_ids: list[str], time_min_iso: str, time_max_iso: str, user_id: Optional[str] = None, account: str = "normal") -> Dict[str, Any]:
    tasks = []
    for cid in calendar_ids:
        payload = {
            "calendarId": cid,
            "timeMin": time_min_iso,
            "timeMax": time_max_iso,
            "singleEvents": True,
            "orderBy": "startTime"
        }
        tasks.append(_call_mcp("list-events", payload, user_id, account))
    results = await asyncio.gather(*tasks)
    merged = []
    for r in results:
        if r.get("ok"):
            parsed = _parse_content_json(r.get("result"))
            merged.extend(parsed.get("events", []) if parsed else [])
    merged.sort(key=lambda e: (e.get("start", {}).get("dateTime") or e.get("start", {}).get("date") or ""))
    return {"ok": True, "result": {"events": merged}}


def list_events_from_calendars(calendar_ids: list[str], time_min_iso: str, time_max_iso: str, user_id: Optional[str] = None, account: str = "normal") -> Dict[str, Any]:
    try:
        return asyncio.run(_list_events_multi_async(calendar_ids, time_min_iso, time_max_iso, user_id, account))
    except Exception as e:
        return {"ok": False, "error": str(e)}


async def _batch_create_events_async(events: list[Dict[str, Any]], calendar_id: str = "primary", user_id: Optional[str] = None, account: str = "normal") -> Dict[str, Any]:
    tasks = []
    for ev in events:
        payload = {
            "calendarId": ev.get("calendarId", calendar_id),
            "summary": ev["summary"],
            "start": ev["start"],
            "end": ev["end"],
            "location": ev.get("location", ""),
            "description": ev.get("description", "")
        }
        tasks.append(_call_mcp("create-event", payload, user_id, account))
    results = await asyncio.gather(*tasks)
    return {"ok": True, "result": results}


def batch_create_events(events: list[Dict[str, Any]], calendar_id: str = "primary", user_id: Optional[str] = None, account: str = "normal") -> Dict[str, Any]:
    try:
        return asyncio.run(_batch_create_events_async(events, calendar_id, user_id, account))
    except Exception as e:
        return {"ok": False, "error": str(e)}


def _parse_iso_dt(s: str) -> Optional[datetime]:
    try:
        if not s:
            return None
        if s.endswith("Z"):
            s = s[:-1] + "+00:00"
        if len(s) == 10:
            return datetime.fromisoformat(s).replace(tzinfo=datetime.now().astimezone().tzinfo)
        return datetime.fromisoformat(s)
    except Exception:
        return None


def find_availability(calendar_ids: list[str], duration_minutes: int, time_min_iso: str, time_max_iso: str, preference: Optional[str] = None, user_id: Optional[str] = None, account: str = "normal") -> Dict[str, Any]:
    try:
        listed = list_events_from_calendars(calendar_ids, time_min_iso, time_max_iso, user_id, account)
        if not listed.get("ok"):
            return listed
        events = listed["result"].get("events", [])
        busy = []
        for e in events:
            s = e.get("start", {})
            en = e.get("end", {})
            sdt = s.get("dateTime") or s.get("date")
            edt = en.get("dateTime") or en.get("date")
            if not (sdt and edt):
                continue
            sd = _parse_iso_dt(sdt)
            ed = _parse_iso_dt(edt)
            if sd and ed:
                busy.append((sd, ed))
        busy.sort(key=lambda x: x[0])
        start = _parse_iso_dt(time_min_iso)
        end = _parse_iso_dt(time_max_iso)
        if not (start and end):
            return {"ok": False, "error": "invalid_time_range"}
        free = []
        cur = start
        for (bs, be) in busy:
            if be <= cur:
                continue
            if bs > cur:
                if (bs - cur).total_seconds() >= duration_minutes * 60:
                    free.append((cur, bs))
                cur = be if be > cur else cur
            else:
                cur = be if be > cur else cur
        if end > cur:
            if (end - cur).total_seconds() >= duration_minutes * 60:
                free.append((cur, end))
        if preference == "afternoon":
            filtered = []
            for (fs, fe) in free:
                if fs.hour >= 12 and fs.hour <= 17:
                    filtered.append((fs, fe))
            free = filtered or free
        slots = []
        for (fs, fe) in free:
            slots.append({"start": fs.isoformat(), "end": (fs + timedelta(minutes=duration_minutes)).isoformat()})
        return {"ok": True, "result": {"slots": slots}}
    except Exception as e:
        return {"ok": False, "error": str(e)}
async def _call_mcp(tool: str, payload: Dict[str, Any], user_id: Optional[str] = None, account: str = "normal") -> Dict[str, Any]:
    if ClientSession is None:
        return {"ok": False, "error": "mcp Python SDK not installed"}
    creds_path = _get_user_credentials_file(user_id, account)
    if not creds_path:
        return {"ok": False, "error": "No calendar credentials available. Please connect your Google Calendar."}
    import os as _os
    env_dict = {}
    if creds_path:
        env_dict["GOOGLE_OAUTH_CREDENTIALS"] = _os.path.abspath(creds_path)
        env_dict["GOOGLE_ACCOUNT_MODE"] = account
        cid = os.getenv("GOOGLE_OAUTH_CLIENT_ID")
        csec = os.getenv("GOOGLE_OAUTH_CLIENT_SECRET")
        if cid:
            env_dict["GOOGLE_OAUTH_CLIENT_ID"] = cid
        if csec:
            env_dict["GOOGLE_OAUTH_CLIENT_SECRET"] = csec
    elif user_id:
        env_dict["GOOGLE_OAUTH_CREDENTIALS"] = ""
    params = _get_mcp_server_params(env_dict)
    attempt = 0
    delay = 0.5
    last_err = None
    try:
        while attempt < 3:
            try:
                async with stdio_client(params) as (read, write):
                    async with ClientSession(read, write) as session:
                        await session.initialize()
                        tools = await session.list_tools()
                        names = [t.name for t in tools.tools]
                        if tool not in names:
                            return {"ok": False, "error": f"{tool} tool not available"}
                        res = await session.call_tool(tool, payload)
                        return {"ok": True, "result": res.content}
            except Exception as e:
                last_err = e
                await asyncio.sleep(delay)
                delay *= 2
                attempt += 1
        return {"ok": False, "error": str(last_err) if last_err else "unknown_error"}
    finally:
        if user_id and creds_path and creds_path.startswith(tempfile.gettempdir()):
            try:
                os.unlink(creds_path)
            except Exception:
                pass


def _genai_client(api_key: Optional[str] = None):
    """
    Initializes and returns the Gemini GenAI client.
    """
    if api_key:
        return _GenClient(api_key=api_key)

    # Prefer Vertex AI if configured
    project_id = os.getenv("VERTEX_AI_PROJECT_ID") or os.getenv("GOOGLE_CLOUD_PROJECT")
    location = os.getenv("VERTEX_AI_LOCATION", "australia-southeast1")
    
    if project_id:
        return _GenClient(vertexai=True, project=project_id, location=location)
        
    # Fallback to API Key
    return _GenClient(api_key=os.getenv("GOOGLE_API_KEY"))


def extract_event_from_image(image: Any, user_instruction: Optional[str] = None, user_id: Optional[str] = None) -> Dict[str, Any]:
    try:
        if isinstance(image, str):
            import mimetypes, base64
            mime = mimetypes.guess_type(image)[0] or "image/png"
            with open(image, "rb") as f:
                data_b64 = base64.b64encode(f.read()).decode("ascii")
        else:
            import base64
            mime = "image/png"
            data_b64 = base64.b64encode(image).decode("ascii")
        prompt = user_instruction or "Extract event details from the image and return strict JSON with keys: title, description, date, start_time, end_time, timezone, location, attendees (array of emails)."
        
        api_key = None
        if user_id:
            try:
                from services.user_settings import UserSettings
                settings = UserSettings(user_id)
                api_key = settings.get_api_key()
            except Exception:
                pass
        
        client = _genai_client(api_key=api_key)
        resp = client.models.generate_content(model=os.getenv("DEFAULT_MODEL", "gemini-flash-latest"), contents=[{"role": "user", "parts": [{"text": prompt}, {"inline_data": {"mime_type": mime, "data": data_b64}}]}])
        text = getattr(resp, "text", "")
        try:
            parsed = json.loads(text)
            return {"ok": True, "result": parsed}
        except Exception:
            return {"ok": True, "result": {"raw": text}}
    except Exception as e:
        return {"ok": False, "error": str(e)}
