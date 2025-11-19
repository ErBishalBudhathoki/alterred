from agents.time_perception_agent import create_countdown


def test_create_countdown_payload():
    payload = create_countdown("2025-11-18T21:15:00")
    assert isinstance(payload, dict)
    assert payload["target"] == "2025-11-18T21:15:00"
    assert payload["warnings"] == [15, 10, 5, 2]