import 'dart:async';
import 'dart:math';
import 'logging_service.dart';

/// Distributed tracing service for agent interactions
/// 
/// Provides request tracing, span management, and performance monitoring
/// for complex multi-agent workflows.
class TracingService {
  static TracingService? _instance;
  static TracingService get instance => _instance ??= TracingService._();
  
  TracingService._();

  final Map<String, Trace> _activeTraces = {};
  final List<Trace> _completedTraces = [];
  final List<TraceListener> _listeners = [];
  final Logger _logger = Logger('TracingService');
  bool _initialized = false;

  /// Initialize the tracing service
  Future<void> initialize() async {
    if (_initialized) return;
    
    _initialized = true;
    _logger.info('Tracing service initialized');
  }

  /// Add a trace listener
  void addListener(TraceListener listener) {
    _listeners.add(listener);
  }

  /// Remove a trace listener
  void removeListener(TraceListener listener) {
    _listeners.remove(listener);
  }

  /// Start a new trace
  String startTrace(String operation, {Map<String, dynamic>? metadata}) {
    final traceId = _generateTraceId();
    final trace = Trace(
      traceId: traceId,
      operation: operation,
      startTime: DateTime.now(),
      metadata: metadata ?? {},
    );

    _activeTraces[traceId] = trace;
    _logger.debug('Started trace: $operation', {'trace_id': traceId, 'metadata': metadata});
    
    _notifyListeners(TraceEvent.traceStarted, trace);
    return traceId;
  }

  /// Start a new span within a trace
  String startSpan(String traceId, String operation, {String? parentSpanId, Map<String, dynamic>? metadata}) {
    final trace = _activeTraces[traceId];
    if (trace == null) {
      _logger.warning('Attempted to start span for non-existent trace', {'trace_id': traceId});
      return '';
    }

    final spanId = _generateSpanId();
    final span = Span(
      spanId: spanId,
      traceId: traceId,
      parentSpanId: parentSpanId,
      operation: operation,
      startTime: DateTime.now(),
      metadata: metadata ?? {},
    );

    trace.spans[spanId] = span;
    _logger.debug('Started span: $operation', {
      'trace_id': traceId,
      'span_id': spanId,
      'parent_span_id': parentSpanId,
      'metadata': metadata,
    });

    _notifyListeners(TraceEvent.spanStarted, trace, span);
    return spanId;
  }

  /// Add an event to a span
  void addSpanEvent(String traceId, String spanId, String event, {Map<String, dynamic>? data}) {
    final trace = _activeTraces[traceId];
    final span = trace?.spans[spanId];
    
    if (span == null) {
      _logger.warning('Attempted to add event to non-existent span', {
        'trace_id': traceId,
        'span_id': spanId,
        'event': event,
      });
      return;
    }

    final spanEvent = SpanEvent(
      timestamp: DateTime.now(),
      event: event,
      data: data ?? {},
    );

    span.events.add(spanEvent);
    _logger.debug('Added span event: $event', {
      'trace_id': traceId,
      'span_id': spanId,
      'event': event,
      'data': data,
    });

    _notifyListeners(TraceEvent.spanEvent, trace!, span);
  }

  /// Set span status
  void setSpanStatus(String traceId, String spanId, SpanStatus status, {String? message}) {
    final trace = _activeTraces[traceId];
    final span = trace?.spans[spanId];
    
    if (span == null) {
      _logger.warning('Attempted to set status for non-existent span', {
        'trace_id': traceId,
        'span_id': spanId,
        'status': status.name,
      });
      return;
    }

    span.status = status;
    span.statusMessage = message;
    
    _logger.debug('Set span status: ${status.name}', {
      'trace_id': traceId,
      'span_id': spanId,
      'status': status.name,
      'message': message,
    });

    _notifyListeners(TraceEvent.spanStatusChanged, trace!, span);
  }

  /// Finish a span
  void finishSpan(String traceId, String spanId, {SpanStatus? status, String? message}) {
    final trace = _activeTraces[traceId];
    final span = trace?.spans[spanId];
    
    if (span == null) {
      _logger.warning('Attempted to finish non-existent span', {
        'trace_id': traceId,
        'span_id': spanId,
      });
      return;
    }

    span.endTime = DateTime.now();
    span.duration = span.endTime!.difference(span.startTime);
    
    if (status != null) {
      span.status = status;
      span.statusMessage = message;
    }

    _logger.debug('Finished span: ${span.operation}', {
      'trace_id': traceId,
      'span_id': spanId,
      'duration_ms': span.duration?.inMilliseconds,
      'status': span.status.name,
    });

    _notifyListeners(TraceEvent.spanFinished, trace!, span);
  }

  /// Finish a trace
  void finishTrace(String traceId, {TraceStatus? status, String? message}) {
    final trace = _activeTraces.remove(traceId);
    if (trace == null) {
      _logger.warning('Attempted to finish non-existent trace', {'trace_id': traceId});
      return;
    }

    trace.endTime = DateTime.now();
    trace.duration = trace.endTime!.difference(trace.startTime);
    
    if (status != null) {
      trace.status = status;
      trace.statusMessage = message;
    }

    // Auto-finish any unfinished spans
    for (final span in trace.spans.values) {
      if (span.endTime == null) {
        finishSpan(traceId, span.spanId, status: SpanStatus.cancelled, message: 'Trace finished');
      }
    }

    _completedTraces.add(trace);
    
    // Keep only recent traces
    if (_completedTraces.length > 1000) {
      _completedTraces.removeRange(0, _completedTraces.length - 800);
    }

    _logger.info('Finished trace: ${trace.operation}', {
      'trace_id': traceId,
      'duration_ms': trace.duration?.inMilliseconds,
      'span_count': trace.spans.length,
      'status': trace.status.name,
    });

    _notifyListeners(TraceEvent.traceFinished, trace);
  }

  /// Get active traces
  List<Trace> getActiveTraces() {
    return _activeTraces.values.toList();
  }

  /// Get completed traces
  List<Trace> getCompletedTraces({int limit = 100}) {
    final traces = _completedTraces.toList()..sort((a, b) => b.startTime.compareTo(a.startTime));
    return traces.take(limit).toList();
  }

  /// Get trace by ID
  Trace? getTrace(String traceId) {
    return _activeTraces[traceId] ?? _completedTraces.firstWhere(
      (trace) => trace.traceId == traceId,
      orElse: () => throw StateError('Trace not found'),
    );
  }

  /// Get traces by operation
  List<Trace> getTracesByOperation(String operation, {int limit = 50}) {
    final allTraces = [..._activeTraces.values, ..._completedTraces];
    final filtered = allTraces.where((trace) => trace.operation == operation).toList();
    filtered.sort((a, b) => b.startTime.compareTo(a.startTime));
    return filtered.take(limit).toList();
  }

  /// Get trace statistics
  Map<String, dynamic> getTraceStatistics() {
    final now = DateTime.now();
    final last24h = now.subtract(const Duration(hours: 24));
    final last1h = now.subtract(const Duration(hours: 1));

    final allTraces = [..._activeTraces.values, ..._completedTraces];
    final traces24h = allTraces.where((trace) => trace.startTime.isAfter(last24h)).toList();
    final traces1h = allTraces.where((trace) => trace.startTime.isAfter(last1h)).toList();

    final completedTraces24h = traces24h.where((trace) => trace.endTime != null).toList();
    final errorTraces24h = completedTraces24h.where((trace) => trace.status == TraceStatus.error).length;
    
    final operationStats = <String, int>{};
    for (final trace in traces24h) {
      operationStats[trace.operation] = (operationStats[trace.operation] ?? 0) + 1;
    }

    double avgDuration = 0;
    if (completedTraces24h.isNotEmpty) {
      final totalDuration = completedTraces24h
          .map((trace) => trace.duration?.inMilliseconds ?? 0)
          .fold(0, (a, b) => a + b);
      avgDuration = totalDuration / completedTraces24h.length;
    }

    return {
      'active_traces': _activeTraces.length,
      'completed_traces': _completedTraces.length,
      'traces_24h': traces24h.length,
      'traces_1h': traces1h.length,
      'error_traces_24h': errorTraces24h,
      'avg_duration_ms': avgDuration,
      'top_operations': operationStats.entries
          .toList()
          ..sort((a, b) => b.value.compareTo(a.value))
          ..take(10),
    };
  }

  /// Agent-specific tracing helpers
  String startAgentTrace(String agentId, String agentName, String operation, {Map<String, dynamic>? parameters}) {
    return startTrace('agent_execution', metadata: {
      'agent_id': agentId,
      'agent_name': agentName,
      'operation': operation,
      'parameters': parameters ?? {},
    });
  }

  String startWorkflowTrace(String workflowId, String workflowName, {Map<String, dynamic>? context}) {
    return startTrace('workflow_execution', metadata: {
      'workflow_id': workflowId,
      'workflow_name': workflowName,
      'context': context ?? {},
    });
  }

  void _notifyListeners(TraceEvent event, Trace trace, [Span? span]) {
    for (final listener in _listeners) {
      try {
        listener.onTraceEvent(event, trace, span);
      } catch (e) {
        _logger.error('Error in trace listener', {'error': e.toString()});
      }
    }
  }

  String _generateTraceId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = random.nextInt(0xFFFFFF);
    return '${timestamp.toRadixString(16)}-${randomPart.toRadixString(16)}';
  }

  String _generateSpanId() {
    final random = Random();
    return random.nextInt(0xFFFFFFFF).toRadixString(16);
  }

  /// Clear completed traces
  void clearCompletedTraces() {
    _completedTraces.clear();
    _logger.info('Cleared completed traces');
  }

  /// Export traces to JSON
  Map<String, dynamic> exportTraces({DateTime? since}) {
    final allTraces = [..._activeTraces.values, ..._completedTraces];
    var traces = allTraces;
    
    if (since != null) {
      traces = traces.where((trace) => trace.startTime.isAfter(since)).toList();
    }

    return {
      'export_timestamp': DateTime.now().toIso8601String(),
      'trace_count': traces.length,
      'traces': traces.map((trace) => trace.toJson()).toList(),
    };
  }
}

/// Trace model
class Trace {
  final String traceId;
  final String operation;
  final DateTime startTime;
  final Map<String, dynamic> metadata;
  final Map<String, Span> spans = {};
  
  DateTime? endTime;
  Duration? duration;
  TraceStatus status = TraceStatus.active;
  String? statusMessage;

  Trace({
    required this.traceId,
    required this.operation,
    required this.startTime,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'trace_id': traceId,
      'operation': operation,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'duration_ms': duration?.inMilliseconds,
      'status': status.name,
      'status_message': statusMessage,
      'metadata': metadata,
      'spans': spans.values.map((span) => span.toJson()).toList(),
    };
  }
}

/// Span model
class Span {
  final String spanId;
  final String traceId;
  final String? parentSpanId;
  final String operation;
  final DateTime startTime;
  final Map<String, dynamic> metadata;
  final List<SpanEvent> events = [];
  
  DateTime? endTime;
  Duration? duration;
  SpanStatus status = SpanStatus.active;
  String? statusMessage;

  Span({
    required this.spanId,
    required this.traceId,
    this.parentSpanId,
    required this.operation,
    required this.startTime,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'span_id': spanId,
      'trace_id': traceId,
      'parent_span_id': parentSpanId,
      'operation': operation,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'duration_ms': duration?.inMilliseconds,
      'status': status.name,
      'status_message': statusMessage,
      'metadata': metadata,
      'events': events.map((event) => event.toJson()).toList(),
    };
  }
}

/// Span event model
class SpanEvent {
  final DateTime timestamp;
  final String event;
  final Map<String, dynamic> data;

  const SpanEvent({
    required this.timestamp,
    required this.event,
    this.data = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'event': event,
      'data': data,
    };
  }
}

/// Trace status
enum TraceStatus {
  active,
  completed,
  error,
  cancelled,
}

/// Span status
enum SpanStatus {
  active,
  completed,
  error,
  cancelled,
}

/// Trace events
enum TraceEvent {
  traceStarted,
  traceFinished,
  spanStarted,
  spanFinished,
  spanEvent,
  spanStatusChanged,
}

/// Trace listener interface
abstract class TraceListener {
  void onTraceEvent(TraceEvent event, Trace trace, [Span? span]);
}

/// Convenience tracer class for specific operations
class Tracer {
  final String operation;
  final TracingService _service = TracingService.instance;

  Tracer(this.operation);

  String startTrace({Map<String, dynamic>? metadata}) {
    return _service.startTrace(operation, metadata: metadata);
  }

  String startSpan(String traceId, String spanOperation, {String? parentSpanId, Map<String, dynamic>? metadata}) {
    return _service.startSpan(traceId, spanOperation, parentSpanId: parentSpanId, metadata: metadata);
  }

  void addEvent(String traceId, String spanId, String event, {Map<String, dynamic>? data}) {
    _service.addSpanEvent(traceId, spanId, event, data: data);
  }

  void finishSpan(String traceId, String spanId, {SpanStatus? status, String? message}) {
    _service.finishSpan(traceId, spanId, status: status, message: message);
  }

  void finishTrace(String traceId, {TraceStatus? status, String? message}) {
    _service.finishTrace(traceId, status: status, message: message);
  }
}