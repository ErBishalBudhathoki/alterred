import os
from datetime import datetime, timedelta
from sessions.firestore_session_storage import FirestoreSessionStorage
from sessions.session_storage import SessionEvent

def test_firestore_session_create_and_retrieve(monkeypatch):
    os.environ["MEMORY_RETENTION_DAYS"] = "1"
    storage = FirestoreSessionStorage()
    meta = storage.create_session("app", "user", "sess_test")
    assert meta.session_id == "sess_test"
    state = {"foo": "bar"}
    storage.update_state("app", "user", "sess_test", state)
    ev = SessionEvent(id="1", author="user", content=[{"text": "hello"}], tool_calls=[], created_at="2025-01-01T00:00:00Z")
    storage.append_event("app", "user", "sess_test", ev)
    got = storage.get_session("app", "user", "sess_test")
    assert got["state"]["foo"] == "bar"
    assert got["events"][0].author == "user"
    count = storage.expire_sessions(datetime.now() + timedelta(days=2))
    assert count >= 0
