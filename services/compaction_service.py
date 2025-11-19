import os
from typing import Dict, Any
from datetime import datetime

from google.genai import Client

from sessions.firestore_session_storage import FirestoreSessionStorage
from services.firebase_client import get_client


def _genai_client():
    return Client(api_key=os.getenv("GOOGLE_API_KEY"))


def compact_session(user_id: str, app_name: str, session_id: str, overlap: int = 1) -> Dict[str, Any]:
    storage = FirestoreSessionStorage()
    sess = storage.get_session(app_name, user_id, session_id)
    events = sess.get("events", [])
    if not events:
        return {"ok": False, "error": "no_events"}
    # Build text from last N events
    tail = events[-(min(len(events), 20)):]  # last up to 20 events
    text = "\n".join([e.content[0].get("text", "") if isinstance(e.content, list) and e.content else "" for e in tail])
    client = _genai_client()
    resp = client.models.generate_content(model=os.getenv("DEFAULT_MODEL", "gemini-2.5-flash"), contents=[{"role": "user", "parts": [{"text": f"Summarize concisely:\n{text}"}]}])
    summary = getattr(resp, "text", "")
    db = get_client()
    db.collection("users").document(user_id).collection("compactions").document(session_id).set({
        "summary_text": summary,
        "events_compacted": len(tail),
        "timestamp": datetime.utcnow().isoformat(),
    })
    return {"ok": True, "summary": summary}


def maybe_auto_compact(user_id: str, app_name: str, session_id: str) -> None:
    interval = int(os.getenv("COMPACTION_INTERVAL", "5"))
    db = get_client()
    ref = db.collection("users").document(user_id).collection("apps").document(app_name).collection("sessions").document(session_id)
    doc = ref.get()
    data = doc.to_dict() or {}
    meta = data.get("meta", {})
    turns = int(meta.get("compaction_turns", 0)) + 1
    meta["compaction_turns"] = turns
    ref.update({"meta.compaction_turns": turns})
    if turns >= interval:
        compact_session(user_id, app_name, session_id)
        ref.update({"meta.compaction_turns": 0})