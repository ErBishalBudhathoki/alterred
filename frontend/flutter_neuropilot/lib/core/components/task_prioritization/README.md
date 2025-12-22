# Enhanced Task Prioritization System

## Overview

This is a comprehensive, modular task prioritization system designed for the NeuroPilot app. It provides dynamic UI/UX with animations and reusable components that work seamlessly across chat mode, voice mode, and standalone UI.

## Architecture

### Core Components (`core/`)

#### 1. **Models** (`models/prioritized_task_model.dart`)
- `PrioritizedTaskModel`: Enhanced task model with rich metadata
- `TaskPriority`, `TaskEffort`, `TaskStatus`, `TaskUrgency`: Type-safe enums
- `TaskPrioritizationResponse`: API response wrapper
- Backward compatible with legacy `PrioritizedTaskItem`

#### 2. **Animations** (`core/task_priority_animations.dart`)
- `TaskPriorityAnimations`: Centralized animation configurations
- `AnimatedTaskEntry`: Staggered entrance animations for list items
- `AnimatedSelection`: Selection feedback with scale and glow effects
- `AnimatedCountdown`: Countdown timer with visual urgency indicators
- `TaskCardShimmer`: Loading skeleton animations

#### 3. **Priority Indicators** (`core/priority_indicator.dart`)
- `PriorityIndicator`: Visual priority level display with multiple styles
- `CompoundPriorityIndicator`: Combined priority + urgency display
- `PriorityLevelBar`: Progress bar style indicator
- `AnimatedPriorityBadge`: Pulsing badge for critical items
- Supports flag, circle, diamond, star, and warning styles

#### 4. **Meta Badges** (`core/task_meta_badge.dart`)
- `TaskMetaBadge`: Reusable badge component for task metadata
- Factory methods for effort, duration, due date, status, tags, progress
- `TaskMetaBadgeGroup`: Collection of badges with smart layout
- `AnimatedTaskMetaBadge`: Entrance animations for badges
- `InteractiveTaskMetaBadge`: Touch feedback for interactive badges

#### 5. **Countdown Timer** (`core/countdown_timer_widget.dart`)
- `CountdownTimerWidget`: Reusable timer with multiple display modes
- Modes: compact, detailed, circular, linear, voice-optimized
- Auto-pause, resume, reset functionality
- Visual urgency indicators (color changes, pulse effects)
- `CountdownTimerController`: External control interface

#### 6. **Task Cards** (`core/task_priority_card.dart`)
- `TaskPriorityCard`: Main task display component
- Display modes: compact, standard, detailed, voice, minimal
- Hover effects, selection animations, progress bars
- `TaskPriorityCardSkeleton`: Loading placeholder

### Mode-Specific Implementations (`modes/`)

#### 1. **Chat Mode** (`modes/chat_task_prioritization.dart`)
- `ChatTaskPrioritization`: Optimized for chat interface
- Compact layout with inline actions
- Quick action buttons (schedule, notes, atomize)
- Error handling with retry functionality
- Loading states with skeletons

#### 2. **Voice Mode** (`modes/voice_task_prioritization.dart`)
- `VoiceTaskPrioritization`: Optimized for voice interaction
- Large touch targets (44px minimum)
- Floating card design with glassmorphism
- Voice command options generation
- Audio-friendly visual feedback

#### 3. **Standalone Mode** (`modes/standalone_task_prioritization.dart`)
- `StandaloneTaskPrioritization`: Full-screen experience
- Rich animations and background effects
- Detailed task information display
- Comprehensive action buttons
- Stats dashboard with metrics

### State Management (`state/`)

#### Task Prioritization Provider (`state/task_prioritization_provider.dart`)
- `TaskPrioritizationState`: Immutable state container
- `TaskPrioritizationNotifier`: State management logic
- API integration with error handling
- Cache management (memory + persistent)
- Countdown timer state management
- Multiple convenience providers for specific state slices

## Features

### 1. **Dynamic Animations**
- Staggered entrance animations for task lists
- Selection feedback with scale and glow effects
- Countdown timer with urgency-based pulse animations
- Smooth transitions between states
- Loading skeletons with shimmer effects

### 2. **Reusable Components**
- All components designed for maximum reusability
- Consistent design language across modes
- Configurable display modes and sizes
- Theme-aware color schemes

### 3. **Mode-Specific Optimizations**
- **Chat Mode**: Compact, inline, message-like appearance
- **Voice Mode**: Large targets, clear hierarchy, audio-friendly
- **Standalone**: Rich, full-featured experience with details

### 4. **Smart Prioritization**
- Backend-powered task scoring
- Energy level matching
- Calendar conflict detection
- Deadline urgency calculation
- Effort vs. energy optimization

### 5. **Offline Support**
- Persistent file-based caching
- Automatic cache invalidation
- Graceful fallback to cached data
- Network status awareness

### 6. **Accessibility**
- Screen reader support
- High contrast mode compatible
- Keyboard navigation support
- Touch target size compliance (44px minimum)

## Usage

### Chat Mode Integration

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/components/task_prioritization/modes/chat_task_prioritization.dart';

class MyChatScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ChatTaskPrioritization(
      onTaskSelected: (task, method) {
        // Handle task selection
        print('Selected: ${task.title} via $method');
      },
      onScheduleTask: () {
        // Handle schedule action
      },
      onTakeNote: () {
        // Handle note-taking
      },
      onRefresh: () {
        // Refresh priorities
      },
      enableAutoSelect: false,
      countdownSeconds: 60,
      showQuickActions: true,
    );
  }
}
```

### Voice Mode Integration

```dart
import 'core/components/task_prioritization/modes/voice_task_prioritization.dart';

VoiceTaskPrioritization(
  onTaskSelected: (task, method) {
    // Handle selection
  },
  onOptionSelected: (option) {
    // Handle voice command
  },
  enableAutoSelect: true,
  showVoiceOptions: true,
)
```

### Standalone Screen

```dart
import 'screens/task_prioritization_screen.dart';

// Navigate to full-screen experience
Navigator.pushNamed(context, Routes.taskPrioritization);

// Or use the quick access widget
TaskPrioritizationQuickAccess(
  showAsCard: true,
  onTaskSelected: () {
    // Handle navigation
  },
)
```

### Using State Management

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/components/task_prioritization/state/task_prioritization_provider.dart';

class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the state
    final state = ref.watch(taskPrioritizationProvider);
    
    // Access specific slices
    final isLoading = ref.watch(prioritizationLoadingProvider);
    final hasError = ref.watch(prioritizationErrorProvider);
    final isCompleted = ref.watch(prioritizationCompletedProvider);
    
    // Trigger actions
    final notifier = ref.read(taskPrioritizationProvider.notifier);
    
    return ElevatedButton(
      onPressed: () {
        // Fetch prioritized tasks
        notifier.fetchPrioritizedTasks(
          limit: 3,
          includeCalendar: true,
          energy: 7,
        );
      },
      child: Text('Get Priorities'),
    );
  }
}
```

## Backward Compatibility

The system maintains full backward compatibility with the existing `TaskPrioritizationWidget`:

```dart
// Legacy usage still works
TaskPrioritizationWidget(
  tasks: legacyTasks,
  reasoning: reasoning,
  originalTaskCount: count,
  onTaskSelected: (task, method) {
    // Handle selection
  },
)
```

The legacy widget now internally uses `ChatTaskPrioritization` with automatic model conversion.

## Design Decisions

### 1. **Modular Architecture**
- Separation of concerns: models, animations, components, modes
- Easy to maintain and extend
- Reusable across different contexts

### 2. **Type-Safe Enums**
- `TaskPriority`, `TaskEffort`, `TaskStatus`, `TaskUrgency`
- Compile-time safety
- Rich metadata (colors, labels, weights)

### 3. **Animation System**
- Centralized configuration
- Consistent timing and curves
- Performance-optimized

### 4. **State Management**
- Riverpod for reactive state
- Immutable state containers
- Optimistic updates for better UX

### 5. **Offline-First**
- Persistent caching
- Graceful degradation
- Network resilience

## Performance Considerations

- **Lazy Loading**: Components only render when needed
- **Efficient Animations**: Hardware-accelerated transforms
- **Memory Management**: Proper disposal of controllers
- **Cache Strategy**: Smart invalidation and TTL

## Testing

Property tests are included for:
- Task prioritization correctness
- Widget UI completeness
- Countdown timer behavior
- Calendar integration resilience
- Error handling completeness
- Offline caching consistency

See `tests/test_task_prioritization_properties.py` for backend tests.

## Future Enhancements

1. **Voice Commands**: Natural language task selection
2. **Gesture Controls**: Swipe to select, long-press for details
3. **Haptic Feedback**: Touch feedback for selections
4. **Smart Notifications**: Proactive task suggestions
5. **Analytics**: Track selection patterns and optimize
6. **Collaborative**: Share priorities with team members
7. **AI Insights**: Learn from user behavior

## Contributing

When adding new features:
1. Follow the modular architecture
2. Add animations for visual feedback
3. Ensure accessibility compliance
4. Test across all modes (chat, voice, standalone)
5. Update this README

## License

Part of the NeuroPilot project.
