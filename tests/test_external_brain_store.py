from services.external_brain_store import store_voice_task, get_context


def test_store_voice_task_and_get_context(monkeypatch):
    tid = store_voice_task("Test Task", "captured", "This is a transcript.")
    assert isinstance(tid, str)
    ctx = get_context(tid)
    assert ctx is None or ctx.get("title") == "Test Task"