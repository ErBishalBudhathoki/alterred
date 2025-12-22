import 'dart:async';
import 'package:flutter/foundation.dart';
import 'logging_service.dart';
import 'tracing_service.dart';
import 'evaluation_service.dart';

/// Central observability manager
/// 
/// Coordinates all observability services and provides a unified interface
/// for logging, tracing, and evaluation across the NeuroPilot application.
class ObservabilityManager {
  static ObservabilityManager? _instance;
  static ObservabilityManager get instance => _instance ??= ObservabilityManager._();
  
  ObservabilityManager._();

  final Logger _logger = Logger('ObservabilityManager');
  bool _initialized = false;

  /// Initialize all observability services
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize core services
      await LoggingService.instance.initialize();
      await TracingService.instance.initialize();
      await EvaluationService.instance.initialize();

      _initialized = true;
      _logger.info('Observability manager initialized successfully');
      
      // Log system startup
      _logger.info('NeuroPilot system starting up', {
        'platform': defaultTargetPlatform.name,
        'debug_mode': kDebugMode,
        'timestamp': DateTime.now().toIso8601String(),
      });

    } catch (e, stackTrace) {
      _logger.critical('Failed to initialize observability manager', {
        'error': e.toString(),
      }, stackTrace);
      rethrow;
    }
  }

  /// Get logging service
  LoggingService get logging => LoggingService.instance;

  /// Get tracing service
  TracingService get tracing => TracingService.instance;

  /// Get evaluation service
  EvaluationService get evaluation => EvaluationService.instance;

  /// Create a logger for a specific source
  Logger createLogger(String source) {
    return Logger(source);
  }

  /// Create a tracer for a specific operation
  Tracer createTracer(String operation) {
    return Tracer(operation);
  }

  /// Start agent execution tracing
  String startAgentExecution(String agentId, String agentName, String operation, {Map<String, dynamic>? parameters}) {
    final traceId = tracing.startAgentTrace(agentId, agentName, operation, parameters: parameters);
    logging.logAgentExecutionStart(agentId, agentName, parameters ?? {});
    return traceId;
  }

  /// Finish agent execution tracing
  void finishAgentExecution(String traceId, String agentId, String agentName, Duration executionTime, {
    bool success = true,
    Map<String, dynamic>? result,
    String? error,
    StackTrace? stackTrace,
  }) {
    if (success) {
      tracing.finishTrace(traceId, status: TraceStatus.completed);
      logging.logAgentExecutionComplete(agentId, agentName, executionTime, result ?? {});
    } else {
      tracing.finishTrace(traceId, status: TraceStatus.error, message: error);
      logging.logAgentExecutionFailure(agentId, agentName, executionTime, error ?? 'Unknown error', stackTrace);
    }
  }

  /// Start workflow execution tracing
  String startWorkflowExecution(String workflowId, String workflowName, {Map<String, dynamic>? context}) {
    final traceId = tracing.startWorkflowTrace(workflowId, workflowName, context: context);
    logging.logWorkflowEvent(workflowId, workflowName, 'started', context ?? {});
    return traceId;
  }

  /// Finish workflow execution tracing
  void finishWorkflowExecution(String traceId, String workflowId, String workflowName, Duration executionTime, {
    bool success = true,
    Map<String, dynamic>? result,
    String? error,
  }) {
    if (success) {
      tracing.finishTrace(traceId, status: TraceStatus.completed);
      logging.logWorkflowEvent(workflowId, workflowName, 'completed', {
        'execution_time_ms': executionTime.inMilliseconds,
        'result': result ?? {},
      });
    } else {
      tracing.finishTrace(traceId, status: TraceStatus.error, message: error);
      logging.logWorkflowEvent(workflowId, workflowName, 'failed', {
        'execution_time_ms': executionTime.inMilliseconds,
        'error': error ?? 'Unknown error',
      });
    }
  }

  /// Log user interaction
  void logUserInteraction(String screen, String action, {Map<String, dynamic>? context}) {
    logging.logUserInteraction(screen, action, context);
  }

  /// Log ADHD-specific event
  void logADHDEvent(String eventType, Map<String, dynamic> data) {
    logging.logADHDEvent(eventType, data);
  }

  /// Start evaluation session
  String startEvaluation(String userId, EvaluationType type, {Map<String, dynamic>? baseline}) {
    return evaluation.startEvaluationSession(userId, type, baseline: baseline);
  }

  /// Record evaluation metric
  void recordEvaluationMetric(String sessionId, String metricName, dynamic value, {Map<String, dynamic>? context}) {
    evaluation.recordMetric(sessionId, metricName, value, context: context);
  }

  /// Finish evaluation session
  Future<EvaluationResult> finishEvaluation(String sessionId, {Map<String, dynamic>? summary}) {
    return evaluation.finishEvaluationSession(sessionId, summary: summary);
  }

  /// Get system health status
  Map<String, dynamic> getSystemHealth() {
    final logStats = logging.getLogStatistics();
    final traceStats = tracing.getTraceStatistics();
    final evalStats = evaluation.getEvaluationStatistics();

    final errorRate = (logStats['errors_24h'] as int? ?? 0) / (logStats['logs_24h'] as int? ?? 1);
    final avgResponseTime = traceStats['avg_duration_ms'] as double? ?? 0.0;

    String overallHealth = 'excellent';
    if (errorRate > 0.1 || avgResponseTime > 5000) {
      overallHealth = 'critical';
    } else if (errorRate > 0.05 || avgResponseTime > 3000) {
      overallHealth = 'poor';
    } else if (errorRate > 0.02 || avgResponseTime > 1000) {
      overallHealth = 'fair';
    } else if (errorRate > 0.01 || avgResponseTime > 500) {
      overallHealth = 'good';
    }

    return {
      'overall_health': overallHealth,
      'error_rate': errorRate,
      'avg_response_time': avgResponseTime,
      'active_traces': traceStats['active_traces'],
      'total_evaluations': evalStats['total_evaluations'],
      'logs_24h': logStats['logs_24h'],
      'traces_24h': traceStats['traces_24h'],
    };
  }

  /// Export all observability data
  Map<String, dynamic> exportObservabilityData({DateTime? since}) {
    final exportTime = DateTime.now();
    
    return {
      'export_timestamp': exportTime.toIso8601String(),
      'system_health': getSystemHealth(),
      'logs': {
        'statistics': logging.getLogStatistics(),
        'recent_logs': logging.getRecentLogs(limit: 1000).map((log) => log.toJson()).toList(),
        'error_logs': logging.getErrorLogs(limit: 100).map((log) => log.toJson()).toList(),
      },
      'traces': tracing.exportTraces(since: since),
      'evaluations': {
        'statistics': evaluation.getEvaluationStatistics(),
        'recent_evaluations': evaluation.getEvaluationHistory(limit: 50).map((eval) => {
          'session_id': eval.sessionId,
          'user_id': eval.userId,
          'type': eval.type.name,
          'start_time': eval.startTime.toIso8601String(),
          'end_time': eval.endTime.toIso8601String(),
          'duration_ms': eval.duration.inMilliseconds,
          'overall_score': eval.overallScore,
          'recommendations': eval.recommendations,
        }).toList(),
      },
    };
  }

  /// Clear all observability data
  void clearAllData() {
    logging.clearLogs();
    tracing.clearCompletedTraces();
    _logger.info('All observability data cleared');
  }

  /// Get observability statistics
  Map<String, dynamic> getObservabilityStatistics() {
    return {
      'logging': logging.getLogStatistics(),
      'tracing': tracing.getTraceStatistics(),
      'evaluation': evaluation.getEvaluationStatistics(),
      'system_health': getSystemHealth(),
    };
  }

  /// Check if observability is healthy
  bool get isHealthy {
    final health = getSystemHealth();
    final overallHealth = health['overall_health'] as String;
    return ['excellent', 'good', 'fair'].contains(overallHealth);
  }

  /// Get health score (0.0 - 1.0)
  double get healthScore {
    final health = getSystemHealth();
    final overallHealth = health['overall_health'] as String;
    
    switch (overallHealth) {
      case 'excellent':
        return 1.0;
      case 'good':
        return 0.8;
      case 'fair':
        return 0.6;
      case 'poor':
        return 0.4;
      case 'critical':
        return 0.2;
      default:
        return 0.0;
    }
  }

  /// Dispose of all resources
  void dispose() {
    _logger.info('Observability manager shutting down');
    _initialized = false;
  }
}

/// Convenience extensions for common observability patterns
extension ObservabilityExtensions on ObservabilityManager {
  /// Trace a function execution
  Future<T> traceFunction<T>(
    String operation,
    Future<T> Function() function, {
    Map<String, dynamic>? metadata,
  }) async {
    final traceId = tracing.startTrace(operation, metadata: metadata);
    final stopwatch = Stopwatch()..start();
    
    try {
      final result = await function();
      stopwatch.stop();
      
      tracing.finishTrace(traceId, status: TraceStatus.completed);
      logging.debug('TracedFunction', 'Function completed: $operation', {
        'duration_ms': stopwatch.elapsedMilliseconds,
        'trace_id': traceId,
      });
      
      return result;
    } catch (error, stackTrace) {
      stopwatch.stop();
      
      tracing.finishTrace(traceId, status: TraceStatus.error, message: error.toString());
      logging.error('TracedFunction', 'Function failed: $operation', {
        'duration_ms': stopwatch.elapsedMilliseconds,
        'trace_id': traceId,
        'error': error.toString(),
      }, stackTrace);
      
      rethrow;
    }
  }

  /// Log and trace an agent operation
  Future<T> traceAgentOperation<T>(
    String agentId,
    String agentName,
    String operation,
    Future<T> Function() function, {
    Map<String, dynamic>? parameters,
  }) async {
    final traceId = startAgentExecution(agentId, agentName, operation, parameters: parameters);
    final stopwatch = Stopwatch()..start();
    
    try {
      final result = await function();
      stopwatch.stop();
      
      finishAgentExecution(
        traceId,
        agentId,
        agentName,
        stopwatch.elapsed,
        success: true,
        result: {'result': result.toString()},
      );
      
      return result;
    } catch (error, stackTrace) {
      stopwatch.stop();
      
      finishAgentExecution(
        traceId,
        agentId,
        agentName,
        stopwatch.elapsed,
        success: false,
        error: error.toString(),
        stackTrace: stackTrace,
      );
      
      rethrow;
    }
  }
}