"""
External Brain Store
====================
Manages the storage and retrieval of "external brain" items (tasks, notes, voice transcripts).
Uses Firestore to persist structured data and snapshots of context.

Implementation Details:
- Stores items in `users/{uid}/external_brain` collection.
- Supports storing voice task transcripts and context snapshots.
- Provides listing capabilities with sorting by creation time.

Design Decisions:
- Uses `os.getenv("USER")` as a fallback user ID for local testing/CLI usage.
- Separates main task data from detailed context snapshots (subcollection).
"""
import os
from typing import Dict, Any, Optional
from datetime import datetime

from services.firebase_client import get_client
from typing import List
from firebase_admin import firestore


def _root(user_id: str):
    """
    Helper to get the root collection for the user's external brain.
    """
    db = get_client()
    return db.collection("users").document(user_id).collection("external_brain")


def store_voice_task(title: str, status: str, transcript: str) -> str:
    """
    Stores a new voice task/note.
    
    Args:
        title (str): The title of the task.
        status (str): The initial status (e.g., "pending").
        transcript (str): The full transcript of the voice note.
        
    Returns:
        str: The ID of the created document.
    """
    uid = os.getenv("USER") or "terminal_user"
    created = datetime.now().isoformat()
    ref = _root(uid).document()
    ref.set({
        "title": title,
        "status": status,
        "transcript": transcript,
        "created_at": created,
    })
    return ref.id


def store_context_snapshot(task_id: str, snapshot: Dict[str, Any]):
    """
    Stores a context snapshot for a specific task.
    
    Snapshots capture the state of the user's context (e.g., screen content, open apps)
    associated with a task.
    
    Args:
        task_id (str): The ID of the parent task.
        snapshot (Dict[str, Any]): The snapshot data.
    """
    uid = os.getenv("USER") or "terminal_user"
    _root(uid).document(task_id).collection("snapshots").add({
        "snapshot": snapshot,
        "timestamp": datetime.now().isoformat(),
    })


def get_context(task_id: str) -> Optional[Dict[str, Any]]:
    """
    Retrieves a specific task/context item by ID.
    
    Args:
        task_id (str): The task ID.
        
    Returns:
        Optional[Dict[str, Any]]: The task data, or None if not found.
    """
    uid = os.getenv("USER") or "terminal_user"
    doc = _root(uid).document(task_id).get()
    return doc.to_dict() if doc.exists else None


def list_voice_tasks(user_id: Optional[str] = None, limit: int = 50) -> List[Dict[str, Any]]:
    """
    Lists recent voice tasks.
    
    Args:
        user_id (Optional[str]): The user ID (optional, defaults to env/fallback).
        limit (int): Maximum number of tasks to return.
        
    Returns:
        List[Dict[str, Any]]: List of task dictionaries (including IDs).
    """
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
