# Neuropilot Code Walkthrough Script

**Video Duration Goal**: 3-5 Minutes

## Intro (0:00 - 0:45)
- **Visual**: Show the Landing Page / Home Screen of the App (clean, minimal UI).
- **Audio**: "Welcome to Neuropilot (formerly Altered), an AI companion designed specifically for executive function support. Unlike standard assistants, Neuropilot doesn't just list tasks—it actively helps you initiate, prioritize, and regulate energy."
- **Action**: Log in and show the "Focus Mode" toggle.

## Feature 1: The Coordinator & Task Atomization (0:45 - 1:30)
- **Visual**: Chat Interface.
- **Action**: Type: "I have to write a project proposal and I'm totally stuck."
- **Audio**: "Here, the Coordinator Agent detects 'Analysis Paralysis'. Instead of a generic reply, it routes to the TaskFlow agent."
- **Visual**: Show the AI response: "Let's just do step one: Create a blank document." followed by a breakdown list.
- **Key Tech**: Mention `agents/taskflow_agent.py` and the atomization prompt.

## Feature 2: Voice & Empathy (1:30 - 2:30)
- **Visual**: Switch to Voice Mode (Microphone icon).
- **Action**: Speak: "I'm feeling really low energy right now."
- **Audio**: "The Energy Agent detects the sentiment. Notice the response isn't 'Push harder', but 'Let's take it easy'."
- **Visual**: Show the *Energy Level* indicator change from green to amber/low.
- **Key Tech**: Mention the Hybrid TTS (Piper/Google) and `services/metrics_service.py` for energy logging.

## Feature 3: Memory & Context (2:30 - 3:15)
- **Visual**: "External Brain" / History View.
- **Audio**: "One huge ADHD struggle is 'Context Loss'. Neuropilot remembers where you left off."
- **Action**: Ask: "What was I doing yesterday morning?"
- **Visual**: AI replies with the summary from the Memory Bank.
- **Key Tech**: Mention `services/memory_bank.py`, Context Compaction, and Firestore persistence.

## Feature 4: Architecture & Architecture Diagram (3:15 - 4:00)
- **Visual**: Show the Mermaid architecture diagram from `docs/architecture.md`.
- **Audio**: "Under the hood, we use a multi-agent system built on Google's ADK and Gemini 2.0 Flash. The FastAPI backend orchestrates these agents, while Firestore keeps everything in sync across devices."

## Outro (4:00 - End)
- **Visual**: Show the GitHub repo URL.
- **Audio**: "Neuropilot is open source. You can find the setup guide and docs in the repository. Thanks for watching."
