from typing import Any, Dict, List, Optional
from datetime import datetime
import os
import json
from pathlib import Path

from .session_storage import SessionStorage, SessionMeta, SessionEvent, serialize_event, deserialize_event, compute_expiry


class FileSessionStorage(SessionStorage):
    def __init__(self):
        self.base = Path(os.getenv("SESSIONS_DIR", "./sessions"))
        self.base.mkdir(parents=True, exist_ok=True)

    def _dir(self, app_name: str, user_id: str, session_id: str) -> Path:
        d = self.base / user_id / app_name / session_id
        d.mkdir(parents=True, exist_ok=True)
        return d

    def create_session(self, app_name: str, user_id: str, session_id: str, ttl_days: Optional[int] = None) -> SessionMeta:
        now = datetime.utcnow().isoformat()
        expires = compute_expiry(datetime.utcnow(), ttl_days)
        meta = SessionMeta(session_id=session_id, user_id=user_id, app_name=app_name, created_at=now, last_activity=now, expires_at=expires, status="active", version=1)
        d = self._dir(app_name, user_id, session_id)
        (d / "meta.json").write_text(json.dumps(meta.__dict__))
        (d / "state.json").write_text(json.dumps({"data": {}}))
        (d / "events.jsonl").write_text("")
        return meta

    def get_session(self, app_name: str, user_id: str, session_id: str) -> Dict[str, Any]:
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
        d = self._dir(app_name, user_id, session_id)
        with (d / "events.jsonl").open("a") as f:
            f.write(json.dumps(serialize_event(event)) + "\n")
        meta = json.loads((d / "meta.json").read_text())
        meta["last_activity"] = event.created_at
        (d / "meta.json").write_text(json.dumps(meta))

    def update_state(self, app_name: str, user_id: str, session_id: str, state: Dict[str, Any]) -> None:
        d = self._dir(app_name, user_id, session_id)
        (d / "state.json").write_text(json.dumps({"data": state}))
        meta = json.loads((d / "meta.json").read_text())
        meta["last_activity"] = datetime.utcnow().isoformat()
        (d / "meta.json").write_text(json.dumps(meta))

    def list_sessions(self, user_id: str, app_name: str, limit: int = 20, order: str = "desc") -> List[SessionMeta]:
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
        d = self._dir(app_name, user_id, session_id)
        for p in d.iterdir():
            p.unlink()
        d.rmdir()