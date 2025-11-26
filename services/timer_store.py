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


def store_countdown(target_iso: str, warnings: List[int]) -> str:
    uid = os.getenv("USER") or "terminal_user"
    timer_id = uuid.uuid4().hex
    ref = _root(uid).document(timer_id)
    ref.set({
        "target": target_iso,
        "warnings": warnings,
        "status": "scheduled",
        "created_at": datetime.utcnow().isoformat(),
    })
    return timer_id


def store_tick(timer_id: str, remaining_seconds: int):
    uid = os.getenv("USER") or "terminal_user"
    ref = _root(uid).document(timer_id)
    ref.update({
        "last_tick": datetime.utcnow().isoformat(),
        "remaining_seconds": remaining_seconds,
    })


def list_today_timers() -> List[Dict[str, Any]]:
    uid = os.getenv("USER") or "terminal_user"
    today = datetime.utcnow().date().isoformat()
    res = []
    for d in _root(uid).stream():
        doc = d.to_dict()
        created = doc.get("created_at", "")
        if created.startswith(today):
            res.append(doc)
    return res


def get_timer(timer_id: str) -> Optional[Dict[str, Any]]:
    uid = os.getenv("USER") or "terminal_user"
    doc = _root(uid).document(timer_id).get()
    return doc.to_dict() if doc.exists else None