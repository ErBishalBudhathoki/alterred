import os
from typing import Dict, Any, Optional
from datetime import datetime

from services.firebase_client import get_client
from typing import List
from firebase_admin import firestore


def _root(user_id: str):
    db = get_client()
    return db.collection("users").document(user_id).collection("external_brain")


def store_voice_task(title: str, status: str, transcript: str) -> str:
    uid = os.getenv("USER") or "terminal_user"
    created = datetime.utcnow().isoformat()
    ref = _root(uid).document()
    ref.set({
        "title": title,
        "status": status,
        "transcript": transcript,
        "created_at": created,
    })
    return ref.id


def store_context_snapshot(task_id: str, snapshot: Dict[str, Any]):
    uid = os.getenv("USER") or "terminal_user"
    _root(uid).document(task_id).collection("snapshots").add({
        "snapshot": snapshot,
        "timestamp": datetime.utcnow().isoformat(),
    })


def get_context(task_id: str) -> Optional[Dict[str, Any]]:
    uid = os.getenv("USER") or "terminal_user"
    doc = _root(uid).document(task_id).get()
    return doc.to_dict() if doc.exists else None


def list_voice_tasks(user_id: Optional[str] = None, limit: int = 50) -> List[Dict[str, Any]]:
    db = get_client()
    uid = user_id or os.getenv("USER") or "terminal_user"
    if db is None:
        return []
    col = _root(uid)
    try:
        q = col.order_by("created_at", direction=firestore.Query.DESCENDING).limit(limit)
        docs = list(q.stream())
    except Exception:
        docs = list(col.stream())
    res: List[Dict[str, Any]] = []
    for d in docs:
        data = d.to_dict() or {}
        data["id"] = d.id
        res.append(data)
    return res