# Observability System

Comprehensive observability system for NeuroPilot providing logging, tracing, and evaluation capabilities.

## Overview

The observability system consists of three core services:

1. **LoggingService**: Multi-level structured logging with file persistence
2. **TracingService**: Distributed tracing for agent and workflow executions
3. **EvaluationService**: Performance evaluation and improvement tracking

All services are coordinated through the **ObservabilityManager** which provides a unified interface.

## Quick Start

### Initialization

The observability system is automatically initialized in `main.dart`:

```dart
await ObservabilityManager.instance.initialize();
```

### Basic Usage

#### Logging

```dart
// Create a logger for your component
final logger = Logger('MyComponent');

// Log at different levels
logger.debug('Debug message', {'key': 'value'});
logger.info('Info message');
logger.warning('Warning message');
logger.error('Error message', {'error': 'details'}, stackTrace);
logger.critical('Critical error', {'error': 'details'}, stackTrace);
```

#### Tracing

```dart
// Create a tracer
final tracer = Tracer('my_operation');

// Start a trace
final traceId = tracer.startTrace(metadata: {'user_id': '123'});

// Start a span
final spanId = tracer.startSpan(traceId, 'sub_operation');

// Add events
tracer.addEvent(traceId, spanId, 'checkpoint_reached', data: {'progress': 50});

// Finish span
tracer.finishSpan(traceId, spanId, status: SpanStatus.completed);

// Finish trace
tracer.finishTrace(traceId, status: TraceStatus.completed);
```

#### Evaluation

```dart
final evaluation = EvaluationService.instance;

// Start evaluation session
final sessionId = evaluation.startEvaluationSession(
  'user_123',
  EvaluationType.productivity,
  baseline: {'task_completion_rate': 0.6},
);

// Record metrics
evaluation.recordMetric(sessionId, 'task_completion_rate', 0.8);
evaluation.recordMetric(sessionId, 'time_accuracy', 0.75);

// Finish session
final result = await evaluation.finishEvaluationSession(sessionId);
print('Overall score: ${result.overallScore}');
```

## Advanced Usage

### ObservabilityManager

The ObservabilityManager provides convenience methods for common patterns:

#### Agent Execution Tracing

```dart
final observability = ObservabilityManager.instance;

final traceId = observability.startAgentExecution(
  'agent_123',
  'Decision Helper',
  'reduce_options',
  parameters: {'option_count': 10},
);

// ... agent execution ...

observability.finishAgentExecution(
  traceId,
  'agent_123',
  'Decision Helper',
  Duration(milliseconds: 1500),
  success: true,
  result: {'reduced_options': 3},
);
```

#### Workflow Execution Tracing

```dart
final traceId = observability.startWorkflowExecution(
  'workflow_123',
  'Morning Routine',
  context: {'energy_level': 'high'},
);

// ... workflow execution ...

observability.finishWorkflowExecution(
  traceId,
  'workflow_123',
  'Morning Routine',
  Duration(seconds: 30),
  success: true,
  result: {'tasks_planned': 5},
);
```

#### Convenience Extensions

```dart
// Trace any function
final result = await observability.traceFunction(
  'complex_operation',
  () async {
    return await performOperation();
  },
  metadata: {'user_id': '123'},
);

// Trace agent operation
final agentResult = await observability.traceAgentOperation(
  'agent_123',
  'Energy Assessment',
  'assess_energy',
  () async {
    return await assessUserEnergy();
  },
  parameters: {'time_of_day': 'morning'},
);
```

### User Interaction Logging

```dart
observability.logUserInteraction(
  'dashboard_screen',
  'task_completed',
  context: {'task_id': '123', 'duration_ms': 5000},
);
```

### ADHD-Specific Event Logging

```dart
observability.logADHDEvent('hyperfocus_detected', {
  'duration_minutes': 120,
  'task': 'coding',
  'break_needed': true,
});
```

## Observability Dashboard

Access the observability dashboard from the main navigation (monitor heart icon).

### Overview Tab
- System health status
- Performance metrics (CPU, memory)
- Activity timeline

### Logs Tab
- Real-time log viewing
- Filter by level and source
- Export logs

### Traces Tab
- Active and completed traces
- Span visualization
- Filter by operation and status

### Evaluation Tab
- Evaluation summary
- Recent evaluations
- Performance trends

## Architecture

```
ObservabilityManager (Central Hub)
    ├─→ LoggingService
    │   ├─ Multi-level logging
    │   ├─ File persistence
    │   ├─ Real-time streaming
    │   └─ Export capabilities
    │
    ├─→ TracingService
    │   ├─ Distributed tracing
    │   ├─ Span management
    │   ├─ Performance tracking
    │   └─ Export capabilities
    │
    └─→ EvaluationService
        ├─ Agent evaluation
        ├─ Workflow evaluation
        ├─ Productivity tracking
        └─ Recommendation engine
```

## Best Practices

### Logging

1. **Use appropriate log levels**:
   - `debug`: Detailed information for debugging
   - `info`: General informational messages
   - `warning`: Warning messages for potential issues
   - `error`: Error messages for failures
   - `critical`: Critical errors requiring immediate attention

2. **Include context**: Always include relevant context in log messages
   ```dart
   logger.info('Task completed', {
     'task_id': '123',
     'duration_ms': 5000,
     'user_id': 'user_123',
   });
   ```

3. **Use structured logging**: Prefer structured context over string interpolation
   ```dart
   // Good
   logger.info('User action', {'action': 'login', 'user_id': '123'});
   
   // Avoid
   logger.info('User 123 performed login');
   ```

### Tracing

1. **Trace important operations**: Focus on operations that are:
   - Long-running
   - Complex (multiple steps)
   - Critical to user experience
   - Prone to failures

2. **Use meaningful operation names**: Use descriptive names that clearly indicate what's being traced
   ```dart
   // Good
   tracer.startTrace('agent_execution_decision_helper');
   
   // Avoid
   tracer.startTrace('operation1');
   ```

3. **Add events for checkpoints**: Use span events to mark important checkpoints
   ```dart
   tracer.addEvent(traceId, spanId, 'data_loaded', data: {'count': 100});
   tracer.addEvent(traceId, spanId, 'processing_started');
   tracer.addEvent(traceId, spanId, 'processing_completed');
   ```

### Evaluation

1. **Set meaningful baselines**: Establish baselines for comparison
   ```dart
   evaluation.startEvaluationSession(
     userId,
     EvaluationType.productivity,
     baseline: {
       'task_completion_rate': 0.6,
       'time_accuracy': 0.5,
       'stress_level': 6.0,
     },
   );
   ```

2. **Record metrics consistently**: Use consistent metric names and units
   ```dart
   evaluation.recordMetric(sessionId, 'task_completion_rate', 0.8);
   evaluation.recordMetric(sessionId, 'time_accuracy', 0.75);
   ```

3. **Review recommendations**: Act on evaluation recommendations
   ```dart
   final result = await evaluation.finishEvaluationSession(sessionId);
   for (final recommendation in result.recommendations) {
     print('Recommendation: $recommendation');
   }
   ```

## Performance Considerations

- **Logging**: Asynchronous file I/O, 10,000 log buffer
- **Tracing**: Minimal overhead, <1ms per span operation
- **Evaluation**: Lazy calculation, <50ms per evaluation
- **Dashboard**: 10-second refresh cycle, optimized rendering

## Export and Analysis

### Export All Data

```dart
final data = observability.exportObservabilityData(
  since: DateTime.now().subtract(Duration(days: 7)),
);

// Save to file or send to external service
```

### Get Statistics

```dart
final stats = observability.getObservabilityStatistics();
print('Logs 24h: ${stats['logging']['logs_24h']}');
print('Active traces: ${stats['tracing']['active_traces']}');
print('Total evaluations: ${stats['evaluation']['total_evaluations']}');
```

### System Health

```dart
final health = observability.getSystemHealth();
print('Overall health: ${health['overall_health']}');
print('Error rate: ${health['error_rate']}');
print('Avg response time: ${health['avg_response_time']}ms');
```

## Integration with Existing Systems

The observability system is automatically integrated with:

- **Orchestration System**: Agent and workflow execution tracking
- **Memory System**: Memory operation logging and tracing
- **External Brain**: Capture event logging and A2A tracing
- **Task Prioritization**: Prioritization decision logging

## Troubleshooting

### Logs not appearing in dashboard

1. Check if logging service is initialized
2. Verify log level filter settings
3. Check source filter

### Traces not showing up

1. Ensure trace is finished (not just started)
2. Check trace status filter
3. Verify operation name filter

### Evaluation results unexpected

1. Review baseline values
2. Check metric recording
3. Verify evaluation type

## Support

For issues or questions about the observability system, check:

1. This README
2. Observability dashboard (Overview tab for system health)
3. Log files in app documents directory
4. Completion report: `OBSERVABILITY_EVALUATION_COMPLETION_REPORT.md`