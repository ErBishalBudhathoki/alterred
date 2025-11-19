from agents.taskflow_agent import schedule_tasks


def test_schedule_tasks_orders_by_score():
    items = ["A", "B", "C"]
    energy = 5
    weights = [1, 3, 2]
    res = schedule_tasks(items, energy, weights)
    ordered = res["ordered"]
    assert isinstance(ordered, list)
    assert set(ordered) == set(items)
    # B has highest weight (3 + 5), then C (2 + 5), then A (1 + 5)
    assert ordered[0] == "B"
    assert ordered[1] == "C"