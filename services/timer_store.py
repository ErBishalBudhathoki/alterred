"""
Timer Store
===========
Manages persistent countdown timers for the user.
Stores timer state, configuration, and tick updates in Firestore.

Implementation Details:
- Uses `firebase_client` to access Firestore.
- Stores timers under `users/{uid}/timers/{timer_id}`.
- Timers have a target time, warning thresholds, and status.

Design Decisions:
- Timers are identified by UUID.
- `store_tick` updates the "last tick" timestamp to track liveliness.
- `list_today_timers` filters by creation date on the client side (simple approach).

Behavioral Specifications:
- `store_countdown`: Creates a new timer with a target time and warning intervals.
- `store_tick`: Updates the remaining time and last tick timestamp.
- `list_today_timers`: Returns all timers created today.
- `get_timer`: Retrieves a specific timer by ID.
"""
import os
import uuid
from typing import Dict, Any, List, Optional
from datetime import datetime

from services.firebase_client import get_client


def _root(user_id: str):
    db = get_client()
    return db.collection("users").document(user_id).collection("timers")


def _resolve_uid(uid: Optional[str]) -> str:
    return uid or os.getenv("USER") or "terminal_user"


def store_countdown(target_iso: str, warnings: List[int], uid: Optional[str] = None) -> str:
    uid = _resolve_uid(uid)
    timer_id = uuid.uuid4().hex
    ref = _root(uid).document(timer_id)
    ref.set({
        "target": target_iso,
        "warnings": warnings,
        "status": "scheduled",
        "created_at": datetime.now().isoformat(),
    })
    return timer_id


def store_tick(timer_id: str, remaining_seconds: int, uid: Optional[str] = None):
    uid = _resolve_uid(uid)
    ref = _root(uid).document(timer_id)
    ref.update({
        "last_tick": datetime.now().isoformat(),
        "remaining_seconds": remaining_seconds,
    })

def cancel_timer(timer_id: str, uid: Optional[str] = None) -> bool:
    uid = _resolve_uid(uid)
    ref = _root(uid).document(timer_id)
    try:
        doc = ref.get()
        if doc.exists:
            ref.update({"status": "cancelled", "cancelled_at": datetime.now().isoformat()})
            return True
        return False
    except Exception:
        return False


def list_today_timers(uid: Optional[str] = None) -> List[Dict[str, Any]]:
    uid = _resolve_uid(uid)
    today = datetime.now().date().isoformat()
    res = []
    for d in _root(uid).stream():
        doc = d.to_dict()
        created = doc.get("created_at", "")
        if created.startswith(today):
            res.append(doc)
    return res


def get_timer(timer_id: str, uid: Optional[str] = None) -> Optional[Dict[str, Any]]:
    uid = _resolve_uid(uid)
    doc = _root(uid).document(timer_id).get()
    return doc.to_dict() if doc.exists else None
