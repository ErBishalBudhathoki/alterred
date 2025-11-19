import os
from typing import Dict, Any, Optional
from datetime import datetime

from services.firebase_client import get_client


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