"""
Session Storage Interfaces
==========================
Defines typed data models and an abstract storage interface for chat sessions.

Implementation Details:
- Provides `SessionMeta`, `SessionState`, and `SessionEvent` dataclasses for strong typing.
- Establishes the `SessionStorage` interface to support pluggable backends (Firestore, files, etc.).

Design Decisions:
- Use simple `str` ISO timestamps to keep transport/storage format consistent across backends.
- Keep the interface minimal and focused on session lifecycle (create, read, update, delete, expire).

Behavioral Specifications:
- `serialize_event`/`deserialize_event` handle conversion between Python objects and storage-friendly dicts.
- `compute_expiry` calculates optional TTL based on creation time and policy.
"""
from typing import Any, Dict, List, Optional
from dataclasses import dataclass
from datetime import datetime, timedelta


@dataclass
class SessionMeta:
    """
    Metadata for a session.

    Attributes:
        session_id: Unique session identifier.
        user_id: ID of the user owning the session.
        app_name: Name of the application (namespace).
        created_at: ISO timestamp when session was created.
        last_activity: ISO timestamp of last activity.
        expires_at: Optional ISO timestamp when session expires.
        status: Current status (e.g., "active", "expired").
        version: Incremented on structural changes.
    """
    session_id: str
    user_id: str
    app_name: str
    created_at: str
    last_activity: str
    expires_at: Optional[str]
    status: str
    version: int


@dataclass
class SessionState:
    """
    Arbitrary state container for a session.

    Attributes:
        data: Opaque dict of session-scoped state.
    """
    data: Dict[str, Any]


@dataclass
class SessionEvent:
    """
    Represents a single event in a session timeline.

    Attributes:
        id: Unique event identifier.
        author: Origin of the event (e.g., "user", "agent").
        content: Structured message content parts.
        tool_calls: Tool invocation records/results.
        created_at: ISO timestamp when event was created.
    """
    id: str
    author: str
    content: List[Dict[str, Any]]
    tool_calls: List[Dict[str, Any]]
    created_at: str


class SessionStorage:
    """
    Abstract interface for session storage backends.

    Implementations must provide persistence, retrieval, and lifecycle operations.
    """
    def create_session(self, app_name: str, user_id: str, session_id: str, ttl_days: Optional[int] = None) -> SessionMeta:
        raise NotImplementedError

    def get_session(self, app_name: str, user_id: str, session_id: str) -> Dict[str, Any]:
        raise NotImplementedError

    def append_event(self, app_name: str, user_id: str, session_id: str, event: SessionEvent) -> None:
        raise NotImplementedError

    def update_state(self, app_name: str, user_id: str, session_id: str, state: Dict[str, Any]) -> None:
        raise NotImplementedError

    def list_sessions(self, user_id: str, app_name: str, limit: int = 20, order: str = "desc") -> List[SessionMeta]:
        raise NotImplementedError

    def expire_sessions(self, now: datetime) -> int:
        raise NotImplementedError

    def delete_session(self, app_name: str, user_id: str, session_id: str) -> None:
        raise NotImplementedError


def serialize_event(event: SessionEvent) -> Dict[str, Any]:
    """
    Converts a `SessionEvent` object into a storage-friendly dict.

    Args:
        event: The event to serialize.

    Returns:
        Dict[str, Any]: Serialized event representation.
    """
    return {
        "id": event.id,
        "author": event.author,
        "content": event.content,
        "tool_calls": event.tool_calls,
        "created_at": event.created_at,
    }


def deserialize_event(doc: Dict[str, Any]) -> SessionEvent:
    """
    Converts a stored dict back into a `SessionEvent` object.

    Args:
        doc: The stored event document.

    Returns:
        SessionEvent: Reconstructed event object.
    """
    return SessionEvent(
        id=str(doc.get("id")),
        author=str(doc.get("author")),
        content=list(doc.get("content", [])),
        tool_calls=list(doc.get("tool_calls", [])),
        created_at=str(doc.get("created_at")),
    )


def compute_expiry(created_at: datetime, ttl_days: Optional[int]) -> Optional[str]:
    """
    Computes an expiry timestamp given a creation time and TTL policy.

    Args:
        created_at: Datetime when the resource was created.
        ttl_days: Time-to-live in days; if None or <= 0, no expiry.

    Returns:
        Optional[str]: ISO timestamp of expiry, or None if not applicable.
    """
    if ttl_days and ttl_days > 0:
        return (created_at + timedelta(days=ttl_days)).isoformat()
    return None
