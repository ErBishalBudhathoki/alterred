"""
History Service
===============
Manages retrieval and searching of historical session data and events.
Interacts with Firestore to fetch session metadata and event logs.

Implementation Details:
- Uses `firebase_client` to access Firestore.
- Queries `users/{uid}/apps/{app}/sessions` and subcollections.

Design Decisions:
- Filters sessions by `last_activity` timestamp on the client side (in Python loop)
  rather than complex Firestore indexes, for simplicity in early dev.
- Supports date range filtering and text search within events.
"""
from typing import List, Dict, Any, Optional, Tuple
from datetime import datetime, timedelta

from services.firebase_client import get_client


def _sessions_root(user_id: str, app_name: str):
    """
    Helper to get the Firestore collection reference for user sessions.
    
    Args:
        user_id (str): The user's unique identifier.
        app_name (str): The application name.
        
    Returns:
        CollectionReference: The Firestore collection reference.
    """
    db = get_client()
    return db.collection("users").document(user_id).collection("apps").document(app_name).collection("sessions")


def get_sessions_by_date(user_id: str, app_name: str, start_iso: str, end_iso: str) -> List[Dict[str, Any]]:
    """
    Retrieves sessions that were active within the specified date range.
    
    Args:
        user_id (str): The user's ID.
        app_name (str): The app name.
        start_iso (str): Start of the range (ISO format).
        end_iso (str): End of the range (ISO format).
        
    Returns:
        List[Dict[str, Any]]: List of session metadata dictionaries.
    """
    sessions = []
    root = _sessions_root(user_id, app_name)
    for s in root.stream():
        meta = s.to_dict().get("meta", {})
        last = meta.get("last_activity")
        if last and start_iso <= last <= end_iso and meta.get("status", "active") == "active":
            sessions.append(meta)
    return sessions


def get_events_for_session(user_id: str, app_name: str, session_id: str, start_iso: Optional[str] = None, end_iso: Optional[str] = None) -> List[Dict[str, Any]]:
    """
    Retrieves events for a specific session, optionally filtered by time.
    
    Args:
        user_id (str): The user's ID.
        app_name (str): The app name.
        session_id (str): The session ID.
        start_iso (Optional[str]): Start time filter.
        end_iso (Optional[str]): End time filter.
        
    Returns:
        List[Dict[str, Any]]: List of event dictionaries.
    """
    root = _sessions_root(user_id, app_name)
    ref = root.document(session_id)
    events = []
    for e in ref.collection("events").order_by("created_at").stream():
        data = e.to_dict()
        if start_iso and end_iso:
            ts = data.get("created_at")
            if not (ts and start_iso <= ts <= end_iso):
                continue
        events.append(data)
    return events


def yesterday_range(tz_name: Optional[str] = None) -> Tuple[str, str]:
    """
    Helper to get the ISO timestamp range for yesterday (00:00:00 to 23:59:59).
    
    Parameters:
        tz_name (Optional[str]): IANA timezone name to compute day boundaries.
    Returns:
        tuple(str, str): (start_iso, end_iso)
    """
    try:
        if tz_name:
            from zoneinfo import ZoneInfo
            now = datetime.now(ZoneInfo(tz_name)).replace(microsecond=0)
        else:
            now = datetime.now().astimezone().replace(microsecond=0)
    except Exception:
        now = datetime.now().astimezone().replace(microsecond=0)
    y = (now.date() - timedelta(days=1))
    start = datetime(y.year, y.month, y.day, 0, 0, 0).isoformat()
    end = datetime(y.year, y.month, y.day, 23, 59, 59).isoformat()
    return start, end


def search_events(events: List[Dict[str, Any]], query: str) -> List[Dict[str, Any]]:
    """
    Searches for a query string within a list of events.
    
    Args:
        events (List[Dict[str, Any]]): The list of events to search.
        query (str): The search query.
        
    Returns:
        List[Dict[str, Any]]: List of matching events with simplified structure.
    """
    q = query.lower()
    results = []
    for ev in events:
        parts = ev.get("content", [])
        text = " ".join([p.get("text", "") for p in parts if isinstance(p, dict)])
        if q in text.lower():
            results.append({"id": ev.get("id"), "author": ev.get("author"), "text": text, "created_at": ev.get("created_at")})
    return results
