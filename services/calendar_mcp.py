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
                    expires_at = datetime.now()
                    
                # Check if expired OR will expire in next 5 minutes
                needs_refresh = datetime.now() >= (expires_at - timedelta(minutes=5))
                
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

        fallback_dir = "/Users/pratikshatiwari/Documents/trae_projects/altered/credentials"
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


async def _create_event_async(summary: str, start_iso: str, end_iso: str, location: Optional[str], description: Optional[str], user_id: Optional[str] = None) -> Dict[str, Any]:
    logger.info(f"Starting event creation for user {user_id}: {summary}")
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
    elif user_id:
        env_dict["GOOGLE_OAUTH_CREDENTIALS"] = ""
    
    params = _get_mcp_server_params(env_dict)

    try:
        async with stdio_client(params) as (read, write):
            async with ClientSession(read, write) as session:
                await session.initialize()
                tools = await session.list_tools()
                names = [t.name for t in tools.tools]
                if "create-event" not in names:
                    logger.error("create-event tool not available")
                    return {"ok": False, "error": "create-event tool not available"}

                res = await session.call_tool("create-event", {
                    "calendarId": "primary",
                    "summary": summary,
                    "start": start_iso,
                    "end": end_iso,
                    "location": location or "",
                    "description": description or "",
                })
                logger.info(f"Event created successfully: {summary}")
                return {"ok": True, "result": res.content}
    except Exception as e:
        logger.error(f"Error in _create_event_async: {e}")
        raise e
    finally:
        # Clean up temp file if it was created for user
        if user_id and creds_path and creds_path.startswith(tempfile.gettempdir()):
            try:
                os.unlink(creds_path)
            except Exception:
                pass


def create_calendar_event_intent(user_text: str, default_title: str = "Appointment") -> Dict[str, Any]:
    parsed = _parse_time_natural(user_text)
    if not parsed:
        return {"ok": False, "error": "Could not parse time", "intent": None}
    title = _extract_title(user_text) or default_title
    recurrence = _extract_recurrence(user_text)
    return {
        "ok": True,
        "intent": {
            "summary": title,
            "start": parsed["start"],
            "end": parsed["end"],
            "location": None,
            "description": user_text,
            "recurrence": recurrence
        }
    }

def _extract_recurrence(text: str) -> Optional[str]:
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
        return f"RRULE:FREQ=WEEKLY;BYDAY={','.join(found_days)}"

    if "every day" in t or "daily" in t:
        return "RRULE:FREQ=DAILY"
    if "every week" in t or "weekly" in t:
        return "RRULE:FREQ=WEEKLY"
    if "every month" in t or "monthly" in t:
        return "RRULE:FREQ=MONTHLY"
    if "every year" in t or "yearly" in t:
        return "RRULE:FREQ=YEARLY"
        
    return None


def create_calendar_event(summary: str, start_iso: str, end_iso: str, location: Optional[str] = None, description: Optional[str] = None, user_id: Optional[str] = None) -> Dict[str, Any]:
    try:
        return asyncio.run(_create_event_async(summary, start_iso, end_iso, location, description, user_id))
    except Exception as e:
        return {"ok": False, "error": str(e)}


async def _list_events_async(calendar_id: str, time_min_iso: str, time_max_iso: str, user_id: Optional[str] = None) -> Dict[str, Any]:
    logger.info(f"Listing events for user {user_id}: {time_min_iso} - {time_max_iso}")
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
    elif user_id:
        env_dict["GOOGLE_OAUTH_CREDENTIALS"] = ""
    
    params = _get_mcp_server_params(env_dict)

    try:
        async with stdio_client(params) as (read, write):
            async with ClientSession(read, write) as session:
                await session.initialize()
                tools = await session.list_tools()
                names = [t.name for t in tools.tools]
                if "list-events" not in names:
                    logger.error("list-events tool not available")
                    return {"ok": False, "error": "list-events tool not available"}

                res = await session.call_tool("list-events", {
                    "calendarId": calendar_id,
                    "timeMin": time_min_iso,
                    "timeMax": time_max_iso,
                    "singleEvents": True,
                    "orderBy": "startTime"
                })
                parsed = _parse_content_json(res.content)
                logger.info(f"Listed {len(parsed.get('events', [])) if parsed else 0} events")
                return {"ok": True, "result": parsed or {"events": [], "raw": str(res.content)}}
    except Exception as e:
        logger.error(f"Error in _list_events_async: {e}")
        raise e
    finally:
        # Clean up temp file if it was created for user
        if user_id and creds_path and creds_path.startswith(tempfile.gettempdir()):
            try:
                os.unlink(creds_path)
            except Exception:
                pass


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
                        expires_at = datetime.now()
                    
                    if datetime.now() >= expires_at:
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
    m_schedule = re.search(r'''\b(?:schedule|create|add|book)\s+(.+?)(?:\s+(?:at|on|from|starting|beginning|in|to my calendar|every)|$)''', t, re.IGNORECASE)
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
            
        return raw_title

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
    elif user_id:
        env_dict["GOOGLE_OAUTH_CREDENTIALS"] = ""
    params = StdioServerParameters(command="npx", args=["@cocal/google-calendar-mcp"], env=env_dict)
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


def _genai_client():
    """
    Initializes and returns the Gemini GenAI client.
    """
    # Prefer Vertex AI if configured
    project_id = os.getenv("VERTEX_AI_PROJECT_ID") or os.getenv("GOOGLE_CLOUD_PROJECT")
    location = os.getenv("VERTEX_AI_LOCATION", "us-central1")
    
    if project_id:
        return _GenClient(vertexai=True, project=project_id, location=location)
        
    # Fallback to API Key
    return _GenClient(api_key=os.getenv("GOOGLE_API_KEY"))


def extract_event_from_image(image: Any, user_instruction: Optional[str] = None) -> Dict[str, Any]:
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
        client = _genai_client()
        resp = client.models.generate_content(model=os.getenv("DEFAULT_MODEL", "gemini-flash-latest"), contents=[{"role": "user", "parts": [{"text": prompt}, {"inline_data": {"mime_type": mime, "data": data_b64}}]}])
        text = getattr(resp, "text", "")
        try:
            parsed = json.loads(text)
            return {"ok": True, "result": parsed}
        except Exception:
            return {"ok": True, "result": {"raw": text}}
    except Exception as e:
        return {"ok": False, "error": str(e)}
