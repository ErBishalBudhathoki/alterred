# Time Perception Feature Set

## Description
Compensates time blindness via realistic estimation, countdown warnings, transition helpers, hyperfocus protection, and calendar-aware time management.

## Routing & Activation
The Time Perception Agent is automatically activated when user input contains patterns related to:
- **Timers & Countdowns**: "timer", "countdown", "alarm", time units ("minutes", "hours", "seconds")
- **Time Estimation**: "how long", "time left", "time estimate", "estimation"
- **Calendar & Scheduling**: "schedule", "calendar", "when", "meeting", "conflicts", "upcoming", "next event"
- **Time Awareness**: "reality check", "time optimism", "usually wrong"
- **Focus Management**: "hyperfocus", "break", "transition", "focus session", "deep work", "pomodoro"
- **Time Management**: "time management", "time perception"

Examples of triggering phrases:
- "Set a 25-minute timer for deep work"
- "How long will this usually take me?"
- "I need a reality check on my time estimate"
- "Help me transition from this hyperfocus session"
- "Check for conflicts with my next meeting"

## Technical Specs
- Agent: `agents/time_perception_agent.py` (ADK LlmAgent)
- Tools:
  - `estimate_real_time(task, user_estimate_minutes, historical_accuracy)` - Corrects time optimism based on user's historical accuracy patterns
  - `create_countdown(target_iso)` → warnings: [15,10,5,2]
  - `detect_hyperfocus(work_duration_minutes, last_break_minutes_ago)` - Monitors work duration and provides intervention levels (NONE, MODERATE, HIGH, URGENT)
  - `transition_helper(next_event)` - Provides strategies for task switching with recommended buffer times
  - Calendar integration tools: `google_calendar_mcp_search_events`, `tool_create_event`, `tool_update_event`, `tool_delete_event`
- Storage: Firestore timers under `users/{user}/timers/{timer_id}` with `target`, `warnings`, `status`, and ticks

## Configuration
- Uses `DEFAULT_MODEL`
- No additional configuration required; user identity taken from environment for storage scoping
- Calendar integration requires Google Calendar MCP setup for meeting awareness and transition planning

## Testing Procedures
- Call `create_countdown` via Coordinator; verify CLI prints timer ID and target
- Inspect Firestore `users/{user}/timers` for scheduled timer docs
- Verify `estimate_real_time` returns corrected estimate based on historical accuracy factor (default 1.8x)
- Validate `detect_hyperfocus` returns appropriate intervention level (NONE/MODERATE/HIGH/URGENT) based on work duration
- Test `transition_helper` provides buffer time recommendations for upcoming events
- Verify calendar integration tools can search, create, update, and delete events for meeting awareness

## Results
- Countdown creation produces Firestore records with target and warnings
- Time estimation correction returns realistic estimates with buffer recommendations and explanations
- Hyperfocus detection provides intervention messages and interrupt recommendations
- Transition helper suggests wrap-up strategies with recommended buffer times (default 15 minutes)
- Calendar integration enables meeting-aware time management and transition planning

## Known Limitations
- Countdown ticking and transitions are not live timers in CLI; implementation provides stored configuration and stubs to be integrated with a scheduler or UI loop
- Historical accuracy factor defaults to 1.8x but should be learned from user's actual completion patterns over time
- Calendar integration depends on Google Calendar MCP availability and proper OAuth setup