from agents.decision_support_agent import default_generator, motivation_matcher, paralysis_protocol


def test_default_generator_returns_value():
    res = default_generator("context")
    assert "default" in res


def test_motivation_matcher_detects_urgency():
    res = motivation_matcher("urgent work")
    assert res["motivation"] == "urgency"


def test_paralysis_protocol_payload():
    res = paralysis_protocol(["A","B","C","D"]) 
    assert res["reduce_to"] == 3
    assert res["deadline_seconds"] == 60
    assert res["auto_decide"] is True