from typing import Any, Dict, List, Optional
from dataclasses import dataclass
from datetime import datetime, timedelta


@dataclass
class SessionMeta:
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
    data: Dict[str, Any]


@dataclass
class SessionEvent:
    id: str
    author: str
    content: List[Dict[str, Any]]
    tool_calls: List[Dict[str, Any]]
    created_at: str


class SessionStorage:
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
    return {
        "id": event.id,
        "author": event.author,
        "content": event.content,
        "tool_calls": event.tool_calls,
        "created_at": event.created_at,
    }


def deserialize_event(doc: Dict[str, Any]) -> SessionEvent:
    return SessionEvent(
        id=str(doc.get("id")),
        author=str(doc.get("author")),
        content=list(doc.get("content", [])),
        tool_calls=list(doc.get("tool_calls", [])),
        created_at=str(doc.get("created_at")),
    )


def compute_expiry(created_at: datetime, ttl_days: Optional[int]) -> Optional[str]:
    if ttl_days and ttl_days > 0:
        return (created_at + timedelta(days=ttl_days)).isoformat()
    return None