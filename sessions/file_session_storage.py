"""
File-backed Session Storage
==========================
Implements the `SessionStorage` interface using local filesystem.

Implementation Details:
- Stores session data under `SESSIONS_DIR` (default `./sessions`), nested by `user_id/app_name/session_id`.
- Persists metadata to `meta.json`, state to `state.json`, events to newline-delimited `events.jsonl`.

Design Decisions:
- Use JSON and JSONL for simple, human-readable storage and easy debugging.
- Keep write operations atomic per file and update `last_activity` on mutations.

Behavioral Specifications:
- `create_session` initializes metadata, state, and event log files.
- `append_event` appends serialized events and updates metadata.
- `expire_sessions` marks expired sessions without deleting files.
"""
from typing import Any, Dict, List, Optional
from datetime import datetime
import os
import json
from pathlib import Path

from .session_storage import SessionStorage, SessionMeta, SessionEvent, serialize_event, deserialize_event, compute_expiry


class FileSessionStorage(SessionStorage):
    """
    Filesystem implementation of session storage.
    """

    def __init__(self):
        """Initializes base directory and ensures it exists."""
        self.base = Path(os.getenv("SESSIONS_DIR", "./sessions"))
        self.base.mkdir(parents=True, exist_ok=True)

    def _dir(self, app_name: str, user_id: str, session_id: str) -> Path:
        """
        Ensures and returns the session directory path.
        """
        d = self.base / user_id / app_name / session_id
        d.mkdir(parents=True, exist_ok=True)
        return d

    def create_session(self, app_name: str, user_id: str, session_id: str, ttl_days: Optional[int] = None) -> SessionMeta:
        """
        Creates a new session tree with default files.
        """
        now = datetime.now().isoformat()
        expires = compute_expiry(datetime.now(), ttl_days)
        meta = SessionMeta(session_id=session_id, user_id=user_id, app_name=app_name, created_at=now, last_activity=now, expires_at=expires, status="active", version=1)
        d = self._dir(app_name, user_id, session_id)
        (d / "meta.json").write_text(json.dumps(meta.__dict__))
        (d / "state.json").write_text(json.dumps({"data": {}}))
        (d / "events.jsonl").write_text("")
        return meta

    def get_session(self, app_name: str, user_id: str, session_id: str) -> Dict[str, Any]:
        """
        Reads and returns session metadata, state, and events.
        """
        d = self._dir(app_name, user_id, session_id)
        meta = json.loads((d / "meta.json").read_text())
        state = json.loads((d / "state.json").read_text()).get("data", {})
        events: List[SessionEvent] = []
        p = d / "events.jsonl"
        if p.exists():
            for line in p.read_text().splitlines():
                if line.strip():
                    events.append(deserialize_event(json.loads(line)))
        return {"meta": meta, "state": state, "events": events}

    def append_event(self, app_name: str, user_id: str, session_id: str, event: SessionEvent) -> None:
        """
        Appends a serialized event line and updates `last_activity`.
        """
        d = self._dir(app_name, user_id, session_id)
        with (d / "events.jsonl").open("a") as f:
            f.write(json.dumps(serialize_event(event)) + "\n")
        meta = json.loads((d / "meta.json").read_text())
        meta["last_activity"] = event.created_at
        (d / "meta.json").write_text(json.dumps(meta))

    def update_state(self, app_name: str, user_id: str, session_id: str, state: Dict[str, Any]) -> None:
        """
        Writes state JSON and bumps `last_activity`.
        """
        d = self._dir(app_name, user_id, session_id)
        (d / "state.json").write_text(json.dumps({"data": state}))
        meta = json.loads((d / "meta.json").read_text())
        meta["last_activity"] = datetime.now().isoformat()
        (d / "meta.json").write_text(json.dumps(meta))

    def list_sessions(self, user_id: str, app_name: str, limit: int = 20, order: str = "desc") -> List[SessionMeta]:
        """
        Lists sessions ordered by `last_activity` and limited by `limit`.
        """
        user_dir = self.base / user_id / app_name
        res: List[SessionMeta] = []
        if user_dir.exists():
            for sess in sorted(user_dir.iterdir()):
                meta_path = sess / "meta.json"
                if meta_path.exists():
                    m = json.loads(meta_path.read_text())
                    res.append(SessionMeta(**m))
        res.sort(key=lambda m: m.last_activity, reverse=(order == "desc"))
        return res[:limit]

    def expire_sessions(self, now: datetime) -> int:
        """
        Marks sessions with past `expires_at` as `expired`.
        Returns number of sessions updated.
        """
        count = 0
        for user in self.base.iterdir():
            for app in user.iterdir():
                for sess in app.iterdir():
                    meta_path = sess / "meta.json"
                    if meta_path.exists():
                        m = json.loads(meta_path.read_text())
                        exp = m.get("expires_at")
                        if exp and exp < now.isoformat() and m.get("status") != "expired":
                            m["status"] = "expired"
                            meta_path.write_text(json.dumps(m))
                            count += 1
        return count

    def delete_session(self, app_name: str, user_id: str, session_id: str) -> None:
        """
        Deletes all files in the session directory and removes the directory.
        """
        d = self._dir(app_name, user_id, session_id)
        for p in d.iterdir():
            p.unlink()
        d.rmdir()
