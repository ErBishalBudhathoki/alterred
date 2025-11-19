from typing import Any, Dict
from datetime import datetime

from google.adk.sessions import InMemorySessionService

from .firestore_session_storage import FirestoreSessionStorage
from .session_storage import SessionEvent


class FirestoreSessionService(InMemorySessionService):
    def __init__(self):
        super().__init__()
        self.storage = FirestoreSessionStorage()

    async def create_session(self, app_name: str, user_id: str, session_id: str):
        self.storage.create_session(app_name, user_id, session_id)
        return await super().create_session(app_name=app_name, user_id=user_id, session_id=session_id)

    async def get_session(self, app_name: str, user_id: str, session_id: str):
        return await super().get_session(app_name=app_name, user_id=user_id, session_id=session_id)

    def persist_event(self, app_name: str, user_id: str, session_id: str, author: str, content_parts: Dict[str, Any], tool_calls: Dict[str, Any]):
        now = datetime.utcnow().isoformat()
        ev = SessionEvent(id=now, author=author, content=[content_parts], tool_calls=[tool_calls] if tool_calls else [], created_at=now)
        self.storage.append_event(app_name, user_id, session_id, ev)

    def persist_state(self, app_name: str, user_id: str, session_id: str, state: Dict[str, Any]):
        self.storage.update_state(app_name, user_id, session_id, state)