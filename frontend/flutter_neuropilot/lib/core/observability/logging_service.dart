import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Comprehensive logging service for NeuroPilot
/// 
/// Provides structured logging with multiple levels, file persistence,
/// and real-time log streaming for observability.
class LoggingService {
  static LoggingService? _instance;
  static LoggingService get instance => _instance ??= LoggingService._();
  
  LoggingService._();

  final List<LogEntry> _logBuffer = [];
  final List<LogListener> _listeners = [];
  File? _logFile;
  bool _initialized = false;

  /// Initialize the logging service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      if (!kIsWeb) {
        final directory = await getApplicationDocumentsDirectory();
        final logDir = Directory('${directory.path}/logs');
        if (!await logDir.exists()) {
          await logDir.create(recursive: true);
        }
        
        final timestamp = DateTime.now().toIso8601String().split('T')[0];
        _logFile = File('${logDir.path}/neuropilot_$timestamp.log');
      }
      
      _initialized = true;
      info('LoggingService', 'Logging service initialized');
    } catch (e) {
      developer.log('Failed to initialize logging service: $e');
    }
  }

  /// Add a log listener for real-time log streaming
  void addListener(LogListener listener) {
    _listeners.add(listener);
  }

  /// Remove a log listener
  void removeListener(LogListener listener) {
    _listeners.remove(listener);
  }

  /// Log a debug message
  void debug(String source, String message, [Map<String, dynamic>? context]) {
    _log(LogLevel.debug, source, message, context);
  }

  /// Log an info message
  void info(String source, String message, [Map<String, dynamic>? context]) {
    _log(LogLevel.info, source, message, context);
  }

  /// Log a warning message
  void warning(String source, String message, [Map<String, dynamic>? context]) {
    _log(LogLevel.warning, source, message, context);
  }

  /// Log an error message
  void error(String source, String message, [Map<String, dynamic>? context, StackTrace? stackTrace]) {
    _log(LogLevel.error, source, message, context, stackTrace);
  }

  /// Log a critical error
  void critical(String source, String message, [Map<String, dynamic>? context, StackTrace? stackTrace]) {
    _log(LogLevel.critical, source, message, context, stackTrace);
  }

  /// Log agent execution start
  void logAgentExecutionStart(String agentId, String agentName, Map<String, dynamic> parameters) {
    info('AgentExecution', 'Agent execution started', {
      'agent_id': agentId,
      'agent_name': agentName,
      'parameters': parameters,
      'execution_type': 'start',
    });
  }

  /// Log agent execution completion
  void logAgentExecutionComplete(String agentId, String agentName, Duration executionTime, Map<String, dynamic> result) {
    info('AgentExecution', 'Agent execution completed', {
      'agent_id': agentId,
      'agent_name': agentName,
      'execution_time_ms': executionTime.inMilliseconds,
      'result': result,
      'execution_type': 'complete',
    });
  }

  /// Log agent execution failure
  void logAgentExecutionFailure(String agentId, String agentName, Duration executionTime, String error, [StackTrace? stackTrace]) {
    this.error('AgentExecution', 'Agent execution failed', {
      'agent_id': agentId,
      'agent_name': agentName,
      'execution_time_ms': executionTime.inMilliseconds,
      'error': error,
      'execution_type': 'failure',
    }, stackTrace);
  }

  /// Log workflow execution events
  void logWorkflowEvent(String workflowId, String workflowName, String eventType, Map<String, dynamic> data) {
    info('WorkflowExecution', 'Workflow event: $eventType', {
      'workflow_id': workflowId,
      'workflow_name': workflowName,
      'event_type': eventType,
      'data': data,
    });
  }

  /// Log system performance metrics
  void logPerformanceMetrics(Map<String, dynamic> metrics) {
    debug('Performance', 'System performance metrics', metrics);
  }

  /// Log user interaction events
  void logUserInteraction(String screen, String action, [Map<String, dynamic>? context]) {
    info('UserInteraction', 'User interaction: $action', {
      'screen': screen,
      'action': action,
      'context': context ?? {},
    });
  }

  /// Log ADHD-specific events
  void logADHDEvent(String eventType, Map<String, dynamic> data) {
    info('ADHD', 'ADHD event: $eventType', {
      'event_type': eventType,
      'data': data,
    });
  }

  void _log(LogLevel level, String source, String message, [Map<String, dynamic>? context, StackTrace? stackTrace]) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      source: source,
      message: message,
      context: context ?? {},
      stackTrace: stackTrace,
    );

    // Add to buffer
    _logBuffer.add(entry);
    
    // Keep buffer size manageable
    if (_logBuffer.length > 10000) {
      _logBuffer.removeRange(0, _logBuffer.length - 8000);
    }

    // Notify listeners
    for (final listener in _listeners) {
      try {
        listener.onLogEntry(entry);
      } catch (e) {
        developer.log('Error in log listener: $e');
      }
    }

    // Write to console in debug mode
    if (kDebugMode) {
      final contextStr = context?.isNotEmpty == true ? ' | Context: $context' : '';
      final stackStr = stackTrace != null ? '\nStack: $stackTrace' : '';
      developer.log('${level.name.toUpperCase()} | $source | $message$contextStr$stackStr');
    }

    // Write to file
    _writeToFile(entry);
  }

  Future<void> _writeToFile(LogEntry entry) async {
    if (_logFile == null || !_initialized) return;

    try {
      final logLine = _formatLogEntry(entry);
      await _logFile!.writeAsString('$logLine\n', mode: FileMode.append);
    } catch (e) {
      developer.log('Failed to write log to file: $e');
    }
  }

  String _formatLogEntry(LogEntry entry) {
    final timestamp = entry.timestamp.toIso8601String();
    final level = entry.level.name.toUpperCase().padRight(8);
    final source = entry.source.padRight(20);
    final contextStr = entry.context.isNotEmpty ? ' | ${entry.context}' : '';
    final stackStr = entry.stackTrace != null ? ' | STACK: ${entry.stackTrace}' : '';
    
    return '$timestamp | $level | $source | ${entry.message}$contextStr$stackStr';
  }

  /// Get recent log entries
  List<LogEntry> getRecentLogs({int limit = 1000, LogLevel? minLevel}) {
    var logs = _logBuffer.toList();
    
    if (minLevel != null) {
      logs = logs.where((log) => log.level.index >= minLevel.index).toList();
    }
    
    if (logs.length > limit) {
      logs = logs.sublist(logs.length - limit);
    }
    
    return logs.reversed.toList(); // Most recent first
  }

  /// Get logs by source
  List<LogEntry> getLogsBySource(String source, {int limit = 1000}) {
    final logs = _logBuffer.where((log) => log.source == source).toList();
    
    if (logs.length > limit) {
      return logs.sublist(logs.length - limit).reversed.toList();
    }
    
    return logs.reversed.toList();
  }

  /// Get error logs
  List<LogEntry> getErrorLogs({int limit = 500}) {
    final errorLogs = _logBuffer
        .where((log) => log.level == LogLevel.error || log.level == LogLevel.critical)
        .toList();
    
    if (errorLogs.length > limit) {
      return errorLogs.sublist(errorLogs.length - limit).reversed.toList();
    }
    
    return errorLogs.reversed.toList();
  }

  /// Clear log buffer
  void clearLogs() {
    _logBuffer.clear();
    info('LoggingService', 'Log buffer cleared');
  }

  /// Export logs to string
  String exportLogs({LogLevel? minLevel, DateTime? since}) {
    var logs = _logBuffer.toList();
    
    if (minLevel != null) {
      logs = logs.where((log) => log.level.index >= minLevel.index).toList();
    }
    
    if (since != null) {
      logs = logs.where((log) => log.timestamp.isAfter(since)).toList();
    }
    
    return logs.map(_formatLogEntry).join('\n');
  }

  /// Get log statistics
  Map<String, dynamic> getLogStatistics() {
    final now = DateTime.now();
    final last24h = now.subtract(const Duration(hours: 24));
    final last1h = now.subtract(const Duration(hours: 1));
    
    final logs24h = _logBuffer.where((log) => log.timestamp.isAfter(last24h)).toList();
    final logs1h = _logBuffer.where((log) => log.timestamp.isAfter(last1h)).toList();
    
    final errorLogs24h = logs24h.where((log) => log.level == LogLevel.error || log.level == LogLevel.critical).length;
    final warningLogs24h = logs24h.where((log) => log.level == LogLevel.warning).length;
    
    final sourceStats = <String, int>{};
    for (final log in logs24h) {
      sourceStats[log.source] = (sourceStats[log.source] ?? 0) + 1;
    }
    
    return {
      'total_logs': _logBuffer.length,
      'logs_24h': logs24h.length,
      'logs_1h': logs1h.length,
      'errors_24h': errorLogs24h,
      'warnings_24h': warningLogs24h,
      'top_sources': sourceStats.entries
          .toList()
          ..sort((a, b) => b.value.compareTo(a.value))
          ..take(10),
      'log_file_path': _logFile?.path,
    };
  }
}

/// Log entry model
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String source;
  final String message;
  final Map<String, dynamic> context;
  final StackTrace? stackTrace;

  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.source,
    required this.message,
    this.context = const {},
    this.stackTrace,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'level': level.name,
      'source': source,
      'message': message,
      'context': context,
      'has_stack_trace': stackTrace != null,
    };
  }
}

/// Log levels
enum LogLevel {
  debug,
  info,
  warning,
  error,
  critical,
}

/// Log listener interface
abstract class LogListener {
  void onLogEntry(LogEntry entry);
}

/// Convenience logger class for specific sources
class Logger {
  final String source;
  final LoggingService _service = LoggingService.instance;

  Logger(this.source);

  void debug(String message, [Map<String, dynamic>? context]) {
    _service.debug(source, message, context);
  }

  void info(String message, [Map<String, dynamic>? context]) {
    _service.info(source, message, context);
  }

  void warning(String message, [Map<String, dynamic>? context]) {
    _service.warning(source, message, context);
  }

  void error(String message, [Map<String, dynamic>? context, StackTrace? stackTrace]) {
    _service.error(source, message, context, stackTrace);
  }

  void critical(String message, [Map<String, dynamic>? context, StackTrace? stackTrace]) {
    _service.critical(source, message, context, stackTrace);
  }
}