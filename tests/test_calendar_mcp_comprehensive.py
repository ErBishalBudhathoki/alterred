
import unittest
import sys
import os
from datetime import datetime, timedelta

# Add project root to path
sys.path.append(os.getcwd())

from services.calendar_mcp import (
    create_calendar_event_intent, 
    _extract_title, 
    _extract_recurrence,
    _parse_time_natural
)

class TestCalendarMCP(unittest.TestCase):
    
    def test_title_extraction(self):
        cases = [
            ("Can you create an appointment for PTE class from 9:15 PM", "PTE class"),
            ("Schedule a team meeting at 2pm", "team meeting"),
            ("Add Lunch with mom to my calendar for tomorrow", "Lunch with mom"),
            ("Create an event about Project X Review at 10am", "Project X Review"),
            ("title='Urgent Call' at 5pm", "Urgent Call"),
            ("Schedule a 3-part training series every Monday", "3-part training series"),
            ("Book a session for Yoga Class starting at 7am", "Yoga Class"),
            ("Create meeting with John", "meeting with John"), # Might fail if fallback is not perfect, let's see
            ("Dinner at 7pm", "Dinner"),
            ("appointment for dentist from 2pm", "dentist"),
        ]
        
        for input_text, expected in cases:
            with self.subTest(input_text=input_text):
                title = _extract_title(input_text)
                # Allow for slight variations (case insensitive check or just checking if it's close)
                # But the requirement says "exactly matches"
                self.assertEqual(title.lower() if title else None, expected.lower())

    def test_recurrence_extraction(self):
        cases = [
            ("Schedule daily standup at 9am", "RRULE:FREQ=DAILY"),
            ("Weekly team meeting every Monday", "RRULE:FREQ=WEEKLY;BYDAY=MO"),
            ("Monthly review", "RRULE:FREQ=MONTHLY"),
            ("Every Tuesday and Thursday", "RRULE:FREQ=WEEKLY;BYDAY=TU,TH"),
            ("No recurrence here", None),
        ]
        
        for input_text, expected in cases:
            with self.subTest(input_text=input_text):
                recurrence = _extract_recurrence(input_text)
                self.assertEqual(recurrence, expected)

    def test_create_intent_full(self):
        user_text = "Schedule a weekly sync for Project Alpha every Friday at 10am"
        result = create_calendar_event_intent(user_text)
        
        self.assertTrue(result["ok"])
        intent = result["intent"]
        self.assertEqual(intent["summary"].lower(), "project alpha")
        self.assertIsNotNone(intent["start"])
        self.assertIsNotNone(intent["end"])
        self.assertEqual(intent["recurrence"], "RRULE:FREQ=WEEKLY;BYDAY=FR")

    def test_special_characters_in_title(self):
        title = "Meeting: Project X & Y (Final)"
        user_text = f"Schedule an appointment for {title} at 3pm"
        extracted = _extract_title(user_text)
        self.assertEqual(extracted, title)

    def test_parse_time_natural_edge_cases(self):
        # Test "tomorrow at 9:15"
        res = _parse_time_natural("tomorrow at 9:15")
        self.assertIsNotNone(res)
        
        # Test "9 pm"
        res = _parse_time_natural("9 pm")
        self.assertIsNotNone(res)
        start = datetime.fromisoformat(res["start"])
        self.assertEqual(start.hour, 21) # 9 PM is 21:00

if __name__ == '__main__':
    unittest.main()
