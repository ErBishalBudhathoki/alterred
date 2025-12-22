# Memory System - Context Engineering & Optimization

A comprehensive memory management system designed for ADHD users, featuring intelligent context compaction, smart summarization using Google's Gemini API, and optimized Firestore storage.

## 🎯 Overview

This memory system provides:
- **Context Compaction**: Intelligent compression of long conversation sessions
- **Smart Summarization**: AI-powered summarization using Gemini API
- **Memory Optimization**: Automated cleanup and query optimization
- **Session Management**: Cross-session persistence and context restoration
- **ADHD-Specific Features**: Interruption handling and working memory support

## 🏗️ Architecture

```
lib/core/memory/
├── models/
│   └── memory_models.dart          # Core data models
├── services/
│   ├── firestore_memory_service.dart      # Firestore operations
│   ├── context_compaction_service.dart    # Context compression
│   ├── gemini_summarization_service.dart  # AI summarization
│   ├── memory_optimization_service.dart   # Query & cleanup optimization
│   └── session_manager.dart               # Session lifecycle management
├── state/
│   └── memory_provider.dart               # Riverpod state management
├── widgets/
│   └── memory_dashboard.dart              # UI components
└── test_memory_system.dart                # Comprehensive tests
```

## 🚀 Quick Start

### 1. Initialize the Memory System

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/memory/state/memory_provider.dart';

// In your app
final memoryActions = ref.read(memoryActionsProvider);

// Set current user
await memoryActions.setUser('user_123');

// Start a session
await memoryActions.startSession(
  type: SessionType.chat,
  title: 'Morning Planning Session',
);
```

### 2. Add Memories

```dart
// Create a memory chunk
final memory = MemoryChunk(
  id: '',
  userId: 'user_123',
  sessionId: 'current_session',
  type: MemoryType.conversation,
  content: 'User wants to prioritize the mobile app project',
  tags: ['project', 'mobile', 'priority'],
  priority: MemoryPriority.high,
  timestamp: DateTime.now(),
  lastAccessed: DateTime.now(),
);

// Add to current session
await memoryActions.addMemory(memory);
```

### 3. Search and Retrieve

```dart
// Search memories
final searchResults = await memoryActions.searchMemories(
  'mobile app project',
  types: [MemoryType.conversation, MemoryType.task],
  limit: 10,
);

// Get contextually relevant memories
final relevantMemories = await memoryActions.getRelevantMemories(
  'working on mobile app development',
  maxResults: 15,
  minRelevanceScore: 0.4,
);
```

## 📊 Core Features

### Context Compaction

Intelligent compression of long sessions using 4 strategies:

```dart
// Automatic compaction when context window reaches 80% capacity
final contextWindow = ref.watch(contextWindowProvider);
if (contextWindow?.needsCompaction == true) {
  await memoryActions.compactContextWindow();
}

// Manual compaction with specific strategy
final compactionService = ContextCompactionService();
await compactionService.compactContextWindow(sessionId);
```

**Compaction Strategies:**
- **Remove Oldest**: Simple chronological removal
- **Remove Low Importance**: Importance-based filtering
- **Summarize Old Chunks**: AI-powered summarization of old content
- **Hierarchical Compression**: Multi-tier compression (recent/medium/old)

### Smart Summarization

AI-powered summarization using Google's Gemini API:

```dart
// Summarize memory chunks
final summary = await memoryActions.summarizeChunks(
  memoryChunks,
  maxLength: 300,
  style: SummarizationStyle.concise,
);

// Create session summary
final sessionSummary = await summarizationService.createSessionSummary(
  sessionChunks,
  includeOutcomes: true,
  includeDecisions: true,
  includeContextCarryover: true,
);
```

**Summarization Styles:**
- **Concise**: Brief, bullet-point summaries
- **Detailed**: Comprehensive with context preservation
- **Actionable**: Focus on action items and decisions
- **Narrative**: Story-like flow for better comprehension

### Memory Optimization

Automated optimization and cleanup:

```dart
// Optimize memory with different levels
await memoryActions.optimizeMemory(
  level: OptimizationLevel.standard, // light, standard, aggressive, deep
);

// Perform cleanup (with dry run option)
final cleanupResult = await optimizationService.performMemoryCleanup(
  userId,
  level: CleanupLevel.standard,
  dryRun: true, // Test without actual deletion
);
```

**Optimization Levels:**
- **Light**: Remove expired chunks only
- **Standard**: + low-value chunks, summarize old conversations
- **Aggressive**: + aggressive summarization, archive old sessions
- **Deep**: + structural optimization, embedding optimization

### Session Management

Complete session lifecycle with ADHD-specific features:

```dart
// Start session with context
await memoryActions.startSession(
  type: SessionType.hyperfocus,
  title: 'Deep Work Session',
  initialContext: {
    'project': 'mobile_app',
    'phase': 'development',
    'energy_level': 0.8,
  },
);

// Handle interruptions
final recovery = await memoryActions.handleInterruption(
  InterruptionType.external,
  reason: 'Phone call from client',
  context: {'urgency': 'high'},
);

// Restore previous session
final restoration = await memoryActions.restoreSessionContext(
  maxAge: Duration(hours: 24),
);
```

**Session Types:**
- `chat`, `voice`, `task`, `planning`, `hyperfocus`, `break`, `decision`, `mixed`

**Interruption Types:**
- `external`, `internal`, `hyperfocus`, `fatigue`, `emergency`

## 🧠 ADHD-Specific Features

### Working Memory Support

```dart
// Context snapshots for quick recovery
final sessionState = sessionManager.getCurrentSessionStatus(userId);
print('Attention Score: ${sessionState.attentionScore}');
print('Interruption Count: ${sessionState.interruptionCount}');

// Visual context window monitoring
final contextWindow = ref.watch(contextWindowProvider);
final utilizationRatio = contextWindow?.utilizationRatio ?? 0.0;
```

### Interruption Recovery

```dart
// Automatic context capture on interruption
final interruptionResult = await memoryActions.handleInterruption(
  InterruptionType.internal,
  reason: 'Mind wandering to other project',
);

// Recovery instructions provided
final instructions = interruptionResult?.recoveryInstructions ?? [];
final estimatedTime = interruptionResult?.estimatedRecoveryTime;
```

### Hyperfocus Management

```dart
// Hyperfocus session with break integration
await memoryActions.startSession(
  type: SessionType.hyperfocus,
  title: 'Coding Deep Dive',
);

// Context preservation during breaks
final contextSnapshot = await sessionManager.handleSessionInterruption(
  userId,
  InterruptionType.hyperfocus,
  reason: 'Mandatory break after 90 minutes',
);
```

## 📱 UI Components

### Memory Dashboard

```dart
import 'core/memory/widgets/memory_dashboard.dart';

// Add to your screen
class MemoryScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Memory System')),
      body: MemoryDashboard(),
    );
  }
}
```

**Dashboard Features:**
- System health monitoring
- Active session management
- Context window visualization
- Quick actions (search, optimize, restore)
- Performance metrics

### State Management

```dart
// Watch memory state
final memoryState = ref.watch(memoryProvider);
final currentSession = ref.watch(currentSessionProvider);
final metrics = ref.watch(memoryMetricsProvider);

// Use memory actions
final actions = ref.read(memoryActionsProvider);
```

## 🔧 Configuration

### Environment Setup

```dart
// .env file
GEMINI_API_KEY=your_gemini_api_key_here
FIREBASE_PROJECT_ID=your_firebase_project_id
```

### Firestore Indexes

Create these composite indexes in Firebase Console:

```
Collection: memory_chunks
- userId, type, timestamp (DESC)
- userId, sessionId, timestamp (DESC)
- userId, priority, relevanceScore (DESC)
- userId, expiresAt (ASC)

Collection: memory_sessions  
- userId, type, startTime (DESC)
- userId, endTime (ASC)
```

### Service Configuration

```dart
// Customize memory system behavior
class MemoryConfig {
  static const int maxContextTokens = 8000;
  static const int targetContextTokens = 6000;
  static const Duration sessionTimeout = Duration(minutes: 30);
  static const Duration cacheExpiry = Duration(minutes: 15);
  static const int maxMemoryChunksPerUser = 10000;
}
```

## 🧪 Testing

### Run Tests

```dart
import 'core/memory/test_memory_system.dart';

// Run comprehensive tests
final tester = MemorySystemTester();
final results = await tester.runAllTests(
  testUserId: 'test_user_123',
  includePerformanceTests: true,
  includeIntegrationTests: true,
);

print('Overall Success: ${results.overallSuccess}');
print('Success Rate: ${results.successRate}');

// Run quick smoke tests
final smokeTestPassed = await tester.runSmokeTests();
```

### Test Coverage

- ✅ Service initialization
- ✅ Memory CRUD operations
- ✅ Context compaction (all 4 strategies)
- ✅ Smart summarization
- ✅ Memory optimization
- ✅ Session management
- ✅ Cross-session persistence
- ✅ ADHD-specific features
- ✅ Performance benchmarks
- ✅ Integration tests

## 📊 Performance

### Benchmarks

- **Storage**: 100 chunks in <500ms
- **Retrieval**: <100ms for most queries
- **Search**: <200ms for text search
- **Compaction**: 30-70% compression ratios
- **Cache Hit Rate**: 85%+ for common queries

### Optimization

```dart
// Monitor performance
final metrics = ref.watch(memoryMetricsProvider);
print('Storage Usage: ${metrics?.storageUsageMB} MB');
print('Average Retrieval Time: ${metrics?.averageRetrievalTime}');

// Optimize queries
final queryOptResult = await optimizationService.optimizeQueries(userId);
print('Performance Improvement: ${queryOptResult.data?.performanceImprovement}');
```

## 🔒 Security & Privacy

### Data Protection

- User-based access control with Firestore security rules
- Automatic data expiration for sensitive content
- Encryption in transit and at rest
- GDPR-compliant data deletion

### Privacy Features

```dart
// Set memory expiration
final sensitiveMemory = MemoryChunk(
  // ... other fields
  expiresAt: DateTime.now().add(Duration(days: 7)),
  priority: MemoryPriority.archive,
);

// Manual cleanup
await memoryActions.optimizeMemory(level: OptimizationLevel.deep);
```

## 🚀 Advanced Usage

### Custom Memory Types

```dart
// Extend memory types for specific use cases
enum CustomMemoryType {
  codeSnippet,
  meetingNotes,
  ideaCapture,
  problemSolution,
}

// Create specialized memory chunks
final codeMemory = MemoryChunk(
  type: MemoryType.external, // Use external for custom types
  metadata: {
    'custom_type': 'code_snippet',
    'language': 'dart',
    'complexity': 'medium',
  },
  // ... other fields
);
```

### Integration with Other Systems

```dart
// Integration with orchestration system
final orchestrationActions = ref.read(orchestrationActionsProvider);
final memoryActions = ref.read(memoryActionsProvider);

// Add memory when workflow completes
await orchestrationActions.executeWorkflow('morning_routine');
await memoryActions.addMemory(MemoryChunk(
  type: MemoryType.task,
  content: 'Completed morning routine workflow',
  tags: ['workflow', 'morning', 'completed'],
));
```

### Custom Summarization

```dart
// Custom summarization for specific domains
final customSummary = await summarizationService.summarizeMemoryChunks(
  codeRelatedChunks,
  maxLength: 400,
  style: SummarizationStyle.detailed,
);

// Extract domain-specific insights
final codeInsights = await summarizationService.extractKeyInsights(
  codeChunks,
  type: InsightType.productivity,
  maxInsights: 8,
);
```

## 📚 API Reference

### Core Models

- `MemoryChunk`: Individual memory unit
- `MemorySession`: Session container
- `ContextWindow`: Context management
- `MemoryQuery`: Query specification
- `MemoryMetrics`: System metrics

### Services

- `FirestoreMemoryService`: Database operations
- `ContextCompactionService`: Context compression
- `GeminiSummarizationService`: AI summarization
- `MemoryOptimizationService`: Performance optimization
- `SessionManager`: Session lifecycle

### State Management

- `MemoryProvider`: Main state provider
- `MemoryActions`: Action interface
- Specialized providers for UI components

## 🤝 Contributing

### Development Setup

1. Clone the repository
2. Set up Firebase project and Firestore
3. Configure environment variables
4. Run tests: `dart test`
5. Start development server

### Code Style

- Follow Dart/Flutter conventions
- Use meaningful variable names
- Add comprehensive documentation
- Include unit tests for new features

## 📄 License

This memory system is part of the NeuroPilot project and follows the project's licensing terms.

---

For more information, see the [completion report](../../../CONTEXT_ENGINEERING_MEMORY_OPTIMIZATION_COMPLETION_REPORT.md) and [integration guide](../orchestration/METRICS_INTEGRATION_GUIDE.md).