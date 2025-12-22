from services.calendar_mcp import create_calendar_event_intent


def test_recurrence_weekdays_range_and_title():
    text = "Add appointment for PTE class from Monday to Friday starting at 9:15 PM for an hour"
    res = create_calendar_event_intent(text)
    assert res["ok"]
    i = res["intent"]
    assert i["summary"].lower() == "pte class"
    assert isinstance(i["recurrence"], list)
    assert i["recurrence"][0].startswith("RRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR")


def test_recurrence_weekdays_keyword():
    text = "Create session for language practice every weekday at 8am"
    res = create_calendar_event_intent(text)
    assert res["ok"]
    assert isinstance(res["intent"]["recurrence"], list)
    assert res["intent"]["recurrence"][0].startswith("RRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR")


def test_bounded_weeks_until():
    text = "Add appointment for study session every weekday at 9am for 2 weeks"
    res = create_calendar_event_intent(text)
    assert res["ok"]
    rr = res["intent"]["recurrence"]
    assert isinstance(rr, list)
    assert rr[0].startswith("RRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR")
    assert ";UNTIL=" in rr[0] or ";COUNT=" in rr[0]


def test_repeat_count():
    text = "Create event for workout every weekday at 7am, repeat 5 times"
    res = create_calendar_event_intent(text)
    assert res["ok"]
    rr = res["intent"]["recurrence"]
    assert isinstance(rr, list)
    assert rr[0].endswith(";COUNT=5")
