import os
from sessions.session_storage import SessionEvent

def test_file_backend_roundtrip(tmp_path):
    path = tmp_path / "sessions"
    os.environ["SESSIONS_DIR"] = str(path)
    from sessions.file_session_storage import FileSessionStorage
    storage = FileSessionStorage()
    storage.create_session("app", "user", "sess_test")
    state = {"k": "v"}
    storage.update_state("app", "user", "sess_test", state)
    ev = SessionEvent(id="1", author="user", content=[{"text": "hi"}], tool_calls=[], created_at="2025-01-01T00:00:00Z")
    storage.append_event("app", "user", "sess_test", ev)
    got = storage.get_session("app", "user", "sess_test")
    assert got["state"]["k"] == "v"
    assert got["events"][0].author == "user"
