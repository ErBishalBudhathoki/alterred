from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta

from services.firebase_client import get_client


def _sessions_root(user_id: str, app_name: str):
    db = get_client()
    return db.collection("users").document(user_id).collection("apps").document(app_name).collection("sessions")


def get_sessions_by_date(user_id: str, app_name: str, start_iso: str, end_iso: str) -> List[Dict[str, Any]]:
    sessions = []
    root = _sessions_root(user_id, app_name)
    for s in root.stream():
        meta = s.to_dict().get("meta", {})
        last = meta.get("last_activity")
        if last and start_iso <= last <= end_iso and meta.get("status", "active") == "active":
            sessions.append(meta)
    return sessions


def get_events_for_session(user_id: str, app_name: str, session_id: str, start_iso: Optional[str] = None, end_iso: Optional[str] = None) -> List[Dict[str, Any]]:
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


def yesterday_range() -> (str, str):
    today = datetime.now().date()
    y = today - timedelta(days=1)
    start = datetime(y.year, y.month, y.day, 0, 0, 0).isoformat()
    end = datetime(y.year, y.month, y.day, 23, 59, 59).isoformat()
    return start, end


def search_events(events: List[Dict[str, Any]], query: str) -> List[Dict[str, Any]]:
    q = query.lower()
    results = []
    for ev in events:
        parts = ev.get("content", [])
        text = " ".join([p.get("text", "") for p in parts if isinstance(p, dict)])
        if q in text.lower():
            results.append({"id": ev.get("id"), "author": ev.get("author"), "text": text, "created_at": ev.get("created_at")})
    return results