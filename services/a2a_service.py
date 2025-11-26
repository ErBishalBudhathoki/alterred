"""
A2A (Agent-to-Agent) Service
============================
Manages connections and updates between agents (or "partners").
Allows agents to discover and communicate with each other via Firestore.

Implementation Details:
- Uses `firebase_client` to interact with Firestore.
- Stores connections in `users/{uid}/a2a/{partner_id}`.
- Logs updates in a subcollection `updates`.

Design Decisions:
- Simple document structure for connections: status, timestamp.
- Updates are append-only in a subcollection to maintain history.
- Defaults to `os.getenv("USER")` or "terminal_user" for the current user ID.

Behavioral Specifications:
- `connect_partner`: Establishes a connection with another agent.
- `post_update`: Sends an update payload to a connected partner.
"""
import os
from typing import Dict, Any
from datetime import datetime

from services.firebase_client import get_client


def connect_partner(partner_id: str) -> Dict[str, Any]:
    uid = os.getenv("USER") or "terminal_user"
    db = get_client()
    ref = db.collection("users").document(uid).collection("a2a").document(partner_id)
    ref.set({
        "partner_id": partner_id,
        "status": "connected",
        "connected_at": datetime.utcnow().isoformat(),
    })
    return {"ok": True, "partner_id": partner_id}


def post_update(partner_id: str, update: Dict[str, Any]) -> Dict[str, Any]:
    uid = os.getenv("USER") or "terminal_user"
    db = get_client()
    db.collection("users").document(uid).collection("a2a").document(partner_id).collection("updates").add({
        "update": update,
        "timestamp": datetime.utcnow().isoformat(),
    })
    return {"ok": True}