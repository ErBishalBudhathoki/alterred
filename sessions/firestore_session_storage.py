"""
Firestore-backed Session Storage
================================
Implements the `SessionStorage` interface using Google Cloud Firestore.

Implementation Details:
- Stores session metadata, state, and events in a hierarchical collection path:
  `users/{user_id}/apps/{app_name}/sessions/{session_id}`.
- Maintains `last_activity` and optional TTL-based expiry.

Design Decisions:
- Use collections for `events` and a single document for `state` to optimize reads/writes.
- `delete_expired` removes entire session subtrees to minimize residual data.

Behavioral Specifications:
- `create_session` initializes metadata and an empty state document.
- `append_event` updates `last_activity` with event timestamps.
"""
from typing import Any, Dict, List, Optional
from datetime import datetime
import os

from services.firebase_client import get_client
from .session_storage import SessionStorage, SessionMeta, SessionEvent, serialize_event, deserialize_event, compute_expiry


class FirestoreSessionStorage(SessionStorage):
    """
    Firestore implementation of session storage.

    Methods provide creation, retrieval, updates, listing, expiry handling, and deletion.
    """
    def __init__(self):
        self.db = get_client()
        self.ttl_days = int(os.getenv("MEMORY_RETENTION_DAYS", "30"))

    def _path(self, app_name: str, user_id: str, session_id: str):
        """
        Computes the Firestore document reference for a session.

        Args:
            app_name: Application namespace.
            user_id: Owner of the session.
            session_id: Unique session id.

        Returns:
            A Firestore document reference for the session root.
        """
        return self.db.collection("users").document(user_id).collection("apps").document(app_name).collection("sessions").document(session_id)

    def create_session(self, app_name: str, user_id: str, session_id: str, ttl_days: Optional[int] = None) -> SessionMeta:
        """
        Creates a new session with metadata and empty state.

        Args:
            app_name: Application namespace.
            user_id: Owner of the session.
            session_id: Unique session id.
            ttl_days: Optional TTL override in days.

        Returns:
            SessionMeta: The created session metadata object.
        """
        now = datetime.utcnow().isoformat()
        expires = compute_expiry(datetime.utcnow(), ttl_days or self.ttl_days)
        meta = {
            "session_id": session_id,
            "user_id": user_id,
            "app_name": app_name,
            "created_at": now,
            "last_activity": now,
            "expires_at": expires,
            "status": "active",
            "version": 1,
        }
        ref = self._path(app_name, user_id, session_id)
        ref.collection("events")
        ref.set({"meta": meta})
        ref.collection("state").document("state").set({"data": {}})
        return SessionMeta(**meta)

    def get_session(self, app_name: str, user_id: str, session_id: str) -> Dict[str, Any]:
        """
        Retrieves session metadata, current state, and recent events.

        Args:
            app_name: Application namespace.
            user_id: Owner of the session.
            session_id: Unique session id.

        Returns:
            Dict[str, Any]: A dict with keys: meta, state, events.
        """
        ref = self._path(app_name, user_id, session_id)
        doc = ref.get()
        meta = doc.to_dict().get("meta", {}) if doc.exists else {}
        state_doc = ref.collection("state").document("state").get()
        state = state_doc.to_dict().get("data", {}) if state_doc.exists else {}
        events_stream = ref.collection("events").order_by("created_at").limit(100).stream()
        events: List[SessionEvent] = []
        for e in events_stream:
            events.append(deserialize_event(e.to_dict()))
        return {"meta": meta, "state": state, "events": events}

    def append_event(self, app_name: str, user_id: str, session_id: str, event: SessionEvent) -> None:
        """
        Appends an event to the session and updates `last_activity`.
        """
        ref = self._path(app_name, user_id, session_id)
        ref.collection("events").add(serialize_event(event))
        ref.update({"meta.last_activity": event.created_at})

    def update_state(self, app_name: str, user_id: str, session_id: str, state: Dict[str, Any]) -> None:
        """
        Merges new state into the session state document and updates `last_activity`.
        """
        ref = self._path(app_name, user_id, session_id)
        ref.collection("state").document("state").set({"data": state}, merge=True)
        ref.update({"meta.last_activity": datetime.utcnow().isoformat()})

    def list_sessions(self, user_id: str, app_name: str, limit: int = 20, order: str = "desc") -> List[SessionMeta]:
        """
        Lists sessions for a user/app ordered by recent activity.
        """
        col = self.db.collection("users").document(user_id).collection("apps").document(app_name).collection("sessions")
        q = col.order_by("meta.last_activity", direction=("DESCENDING" if order == "desc" else "ASCENDING")).limit(limit)
        res = []
        for d in q.stream():
            m = d.to_dict().get("meta", {})
            if m:
                res.append(SessionMeta(**m))
        return res

    def expire_sessions(self, now: datetime) -> int:
        """
        Marks sessions as expired if their `expires_at` is earlier than `now`.
        Returns the number of sessions marked expired.
        """
        users = self.db.collection("users").stream()
        count = 0
        for u in users:
            apps = self.db.collection("users").document(u.id).collection("apps").stream()
            for a in apps:
                sessions = self.db.collection("users").document(u.id).collection("apps").document(a.id).collection("sessions").stream()
                for s in sessions:
                    meta = s.to_dict().get("meta", {})
                    exp = meta.get("expires_at")
                    if exp and exp < now.isoformat() and meta.get("status") != "expired":
                        s.reference.update({"meta.status": "expired"})
                        count += 1
        return count

    def delete_session(self, app_name: str, user_id: str, session_id: str) -> None:
        """
        Deletes a session and all child documents (events, state).
        """
        ref = self._path(app_name, user_id, session_id)
        events = ref.collection("events").stream()
        for e in events:
            e.reference.delete()
        ref.collection("state").document("state").delete()
        ref.delete()

    def delete_expired(self) -> int:
        """
        Deletes all sessions previously marked as `expired`.
        Returns the number of deleted sessions.
        """
        users = self.db.collection("users").stream()
        count = 0
        for u in users:
            apps = self.db.collection("users").document(u.id).collection("apps").stream()
            for a in apps:
                sessions = self.db.collection("users").document(u.id).collection("apps").document(a.id).collection("sessions").stream()
                for s in sessions:
                    meta = s.to_dict().get("meta", {})
                    if meta.get("status") == "expired":
                        # delete session tree
                        ref = s.reference
                        events = ref.collection("events").stream()
                        for e in events:
                            e.reference.delete()
                        ref.collection("state").document("state").delete()
                        ref.delete()
                        count += 1
        return count
