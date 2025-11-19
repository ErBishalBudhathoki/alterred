from agents.energy_sensory_agent import detect_sensory_overload, routine_vs_novelty_balancer


def test_detect_sensory_overload_true():
    res = detect_sensory_overload("It is very loud and bright here")
    assert res["overload"] is True


def test_detect_sensory_overload_false():
    res = detect_sensory_overload("It is calm and quiet")
    assert res["overload"] is False


def test_routine_vs_novelty_balancer():
    res = routine_vs_novelty_balancer("afternoon")
    assert "balance" in res