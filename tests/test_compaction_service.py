from services.compaction_service import compact_session


def test_compact_session_handles_empty(monkeypatch):
    # With no events, expect ok False
    res = compact_session("nonexistent_user", "neuropilot", "sess_missing")
    assert res.get("ok") is False