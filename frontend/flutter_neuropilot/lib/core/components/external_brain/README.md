# External Brain Component System

A comprehensive, modular external brain system for NeuroPilot with universal capture, context restoration, A2A communication, and appointment guardian features.

## Architecture

### Core Components (`core/`)
- `brain_capture_card.dart` - Universal capture interface with voice-to-text
- `context_snapshot_widget.dart` - Visual context restoration display
- `working_memory_panel.dart` - Active working memory support
- `appointment_guardian_widget.dart` - Calendar integration and reminders
- `a2a_connection_card.dart` - Agent-to-agent connection UI
- `brain_animations.dart` - Shared animation definitions

### Mode-Specific Implementations (`modes/`)
- `chat_external_brain.dart` - Chat mode integration
- `voice_external_brain.dart` - Voice mode integration
- `standalone_external_brain.dart` - Full-screen standalone experience

### State Management (`state/`)
- `external_brain_provider.dart` - Riverpod state management
- `capture_state.dart` - Capture session state
- `context_state.dart` - Context restoration state
- `a2a_state.dart` - A2A connection state

### Models (`models/`)
- `brain_capture_model.dart` - Capture data model
- `context_snapshot_model.dart` - Context snapshot model
- `working_memory_item.dart` - Working memory item model
- `a2a_connection_model.dart` - A2A connection model

## Features

### 1. Universal Capture System
- Voice-to-structured-task conversion
- Quick text capture
- Image/screenshot capture
- Automatic categorization

### 2. Context Restoration
- Snapshot interrupted task context
- Visual context display
- One-tap context restoration
- Timeline view of context history

### 3. A2A Protocol (Agent-to-Agent)
- Connect with accountability partners
- Share progress updates
- Receive encouragement
- Synchronized goal tracking

### 4. Appointment Guardian
- Google Calendar integration
- Smart reminders with ADHD-friendly timing
- Pre-appointment preparation prompts
- Transition time calculations

### 5. Working Memory Support
- Active task list
- Quick reference notes
- Temporary information storage
- Auto-cleanup of completed items

## Integration

### Chat Mode
```dart
ExternalBrainChatMode(
  onCapture: (capture) => handleCapture(capture),
  onContextRestore: (context) => restoreContext(context),
)
```

### Voice Mode
```dart
ExternalBrainVoiceMode(
  isListening: isListening,
  onVoiceCapture: (transcript) => processVoice(transcript),
)
```

### Standalone
```dart
Navigator.pushNamed(context, Routes.externalBrain);
```

## Design Principles

1. **Minimal Cognitive Load**: Simple, clear interfaces
2. **Instant Capture**: No friction between thought and storage
3. **Visual Feedback**: Rich animations and progress indicators
4. **Context Awareness**: Smart suggestions based on current state
5. **Accessibility**: Full screen reader and keyboard support
