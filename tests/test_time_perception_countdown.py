from agents.time_perception_agent import create_countdown


def test_create_countdown_payload():
    payload = create_countdown("2025-11-18T21:15:00")
    assert isinstance(payload, dict)
    assert payload["target"] == "2025-11-18T21:15:00"
    assert payload["warnings"] == [15, 10, 5, 2]


def test_create_countdown_detects_query_intent():
    payload = create_countdown("what's the remaining timer")
    assert payload.get("ok") is False
    assert payload.get("error") == "query_existing_timer"
