import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../core/observability/logging_service.dart';
import '../core/observability/tracing_service.dart';
import '../core/observability/evaluation_service.dart';

/// Observability state model
class ObservabilityState {
  final String systemHealth;
  final int activeTraces;
  final double errorRate;
  final int avgResponseTime;
  final double cpuUsage;
  final double memoryUsage;
  final List<double> activityHistory;
  final DateTime lastUpdated;

  const ObservabilityState({
    this.systemHealth = 'good',
    this.activeTraces = 0,
    this.errorRate = 0.0,
    this.avgResponseTime = 0,
    this.cpuUsage = 0.0,
    this.memoryUsage = 0.0,
    this.activityHistory = const [],
    required this.lastUpdated,
  });

  ObservabilityState copyWith({
    String? systemHealth,
    int? activeTraces,
    double? errorRate,
    int? avgResponseTime,
    double? cpuUsage,
    double? memoryUsage,
    List<double>? activityHistory,
    DateTime? lastUpdated,
  }) {
    return ObservabilityState(
      systemHealth: systemHealth ?? this.systemHealth,
      activeTraces: activeTraces ?? this.activeTraces,
      errorRate: errorRate ?? this.errorRate,
      avgResponseTime: avgResponseTime ?? this.avgResponseTime,
      cpuUsage: cpuUsage ?? this.cpuUsage,
      memoryUsage: memoryUsage ?? this.memoryUsage,
      activityHistory: activityHistory ?? this.activityHistory,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

/// Observability state notifier
class ObservabilityNotifier extends StateNotifier<ObservabilityState> {
  ObservabilityNotifier() : super(ObservabilityState(lastUpdated: DateTime.now())) {
    _initialize();
  }

  Timer? _updateTimer;
  final LoggingService _loggingService = LoggingService.instance;
  final TracingService _tracingService = TracingService.instance;

  void _initialize() {
    _updateTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _updateState();
    });
    _updateState();
  }

  void _updateState() {
    final logStats = _loggingService.getLogStatistics();
    final traceStats = _tracingService.getTraceStatistics();
    
    final errorLogs24h = logStats['errors_24h'] as int? ?? 0;
    final totalLogs24h = logStats['logs_24h'] as int? ?? 1;
    final errorRate = errorLogs24h / totalLogs24h;
    
    final avgDuration = traceStats['avg_duration_ms'] as double? ?? 0.0;
    
    // Simulate system metrics (in production, these would be real)
    final cpuUsage = 20.0 + (state.activeTraces * 2.0);
    final memoryUsage = 30.0 + (state.activeTraces * 1.5);
    
    // Update activity history
    final newActivity = [...state.activityHistory, traceStats['traces_1h'].toDouble()];
    if (newActivity.length > 24) {
      newActivity.removeAt(0);
    }
    
    // Determine system health
    String systemHealth = 'excellent';
    if (errorRate > 0.1 || cpuUsage > 80 || memoryUsage > 80) {
      systemHealth = 'critical';
    } else if (errorRate > 0.05 || cpuUsage > 60 || memoryUsage > 60) {
      systemHealth = 'poor';
    } else if (errorRate > 0.02 || cpuUsage > 40 || memoryUsage > 40) {
      systemHealth = 'fair';
    } else if (errorRate > 0.01 || cpuUsage > 20 || memoryUsage > 20) {
      systemHealth = 'good';
    }

    state = state.copyWith(
      systemHealth: systemHealth,
      activeTraces: traceStats['active_traces'] as int? ?? 0,
      errorRate: errorRate,
      avgResponseTime: avgDuration.round(),
      cpuUsage: cpuUsage.clamp(0.0, 100.0),
      memoryUsage: memoryUsage.clamp(0.0, 100.0),
      activityHistory: newActivity.cast<double>(),
      lastUpdated: DateTime.now(),
    );
  }

  void refresh() {
    _updateState();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }
}

/// Main observability provider
final observabilityProvider = StateNotifierProvider<ObservabilityNotifier, ObservabilityState>((ref) {
  return ObservabilityNotifier();
});

/// Log filter state
class LogFilter {
  final LogLevel? level;
  final String? source;

  const LogFilter({this.level, this.source});

  LogFilter copyWith({LogLevel? level, String? source}) {
    return LogFilter(
      level: level ?? this.level,
      source: source ?? this.source,
    );
  }
}

/// Log filter notifier
class LogFilterNotifier extends StateNotifier<LogFilter> {
  LogFilterNotifier() : super(const LogFilter());

  void setLevel(LogLevel? level) {
    state = state.copyWith(level: level);
  }

  void setSource(String? source) {
    state = state.copyWith(source: source);
  }

  void clear() {
    state = const LogFilter();
  }
}

/// Log filter provider
final logFilterProvider = StateNotifierProvider<LogFilterNotifier, LogFilter>((ref) {
  return LogFilterNotifier();
});

/// Log state provider
final logStateProvider = AsyncNotifierProvider<LogStateNotifier, List<LogEntry>>(() {
  return LogStateNotifier();
});

class LogStateNotifier extends AsyncNotifier<List<LogEntry>> {
  final LoggingService _loggingService = LoggingService.instance;

  @override
  Future<List<LogEntry>> build() async {
    return _loadLogs();
  }

  Future<List<LogEntry>> _loadLogs() async {
    final filter = ref.read(logFilterProvider);
    return _loggingService.getRecentLogs(
      limit: 1000,
      minLevel: filter.level,
    ).where((log) {
      if (filter.source != null && filter.source!.isNotEmpty) {
        return log.source.toLowerCase().contains(filter.source!.toLowerCase());
      }
      return true;
    }).toList();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final logs = await _loadLogs();
      state = AsyncValue.data(logs);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

/// Trace filter state
class TraceFilter {
  final String? operation;
  final TraceStatus? status;

  const TraceFilter({this.operation, this.status});

  TraceFilter copyWith({String? operation, TraceStatus? status}) {
    return TraceFilter(
      operation: operation ?? this.operation,
      status: status ?? this.status,
    );
  }
}

/// Trace filter notifier
class TraceFilterNotifier extends StateNotifier<TraceFilter> {
  TraceFilterNotifier() : super(const TraceFilter());

  void setOperation(String? operation) {
    state = state.copyWith(operation: operation);
  }

  void setStatus(TraceStatus? status) {
    state = state.copyWith(status: status);
  }

  void clear() {
    state = const TraceFilter();
  }
}

/// Trace filter provider
final traceFilterProvider = StateNotifierProvider<TraceFilterNotifier, TraceFilter>((ref) {
  return TraceFilterNotifier();
});

/// Trace state provider
final traceStateProvider = AsyncNotifierProvider<TraceStateNotifier, List<Trace>>(() {
  return TraceStateNotifier();
});

class TraceStateNotifier extends AsyncNotifier<List<Trace>> {
  final TracingService _tracingService = TracingService.instance;

  @override
  Future<List<Trace>> build() async {
    return _loadTraces();
  }

  Future<List<Trace>> _loadTraces() async {
    final filter = ref.read(traceFilterProvider);
    final activeTraces = _tracingService.getActiveTraces();
    final completedTraces = _tracingService.getCompletedTraces(limit: 100);
    
    var allTraces = [...activeTraces, ...completedTraces];
    
    if (filter.operation != null && filter.operation!.isNotEmpty) {
      allTraces = allTraces.where((trace) => 
        trace.operation.toLowerCase().contains(filter.operation!.toLowerCase())
      ).toList();
    }
    
    if (filter.status != null) {
      allTraces = allTraces.where((trace) => trace.status == filter.status).toList();
    }
    
    allTraces.sort((a, b) => b.startTime.compareTo(a.startTime));
    return allTraces;
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final traces = await _loadTraces();
      state = AsyncValue.data(traces);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

/// Evaluation state
class EvaluationState {
  final int totalEvaluations;
  final double averageScore;
  final int activeSessions;
  final int evaluations30d;
  final List<EvaluationResult> recentEvaluations;
  final List<double> performanceTrend;

  const EvaluationState({
    this.totalEvaluations = 0,
    this.averageScore = 0.0,
    this.activeSessions = 0,
    this.evaluations30d = 0,
    this.recentEvaluations = const [],
    this.performanceTrend = const [],
  });

  EvaluationState copyWith({
    int? totalEvaluations,
    double? averageScore,
    int? activeSessions,
    int? evaluations30d,
    List<EvaluationResult>? recentEvaluations,
    List<double>? performanceTrend,
  }) {
    return EvaluationState(
      totalEvaluations: totalEvaluations ?? this.totalEvaluations,
      averageScore: averageScore ?? this.averageScore,
      activeSessions: activeSessions ?? this.activeSessions,
      evaluations30d: evaluations30d ?? this.evaluations30d,
      recentEvaluations: recentEvaluations ?? this.recentEvaluations,
      performanceTrend: performanceTrend ?? this.performanceTrend,
    );
  }
}

/// Evaluation state provider
final evaluationStateProvider = AsyncNotifierProvider<EvaluationStateNotifier, EvaluationState>(() {
  return EvaluationStateNotifier();
});

class EvaluationStateNotifier extends AsyncNotifier<EvaluationState> {
  final EvaluationService _evaluationService = EvaluationService.instance;

  @override
  Future<EvaluationState> build() async {
    return _loadEvaluationState();
  }

  Future<EvaluationState> _loadEvaluationState() async {
    final stats = _evaluationService.getEvaluationStatistics();
    final recentEvaluations = _evaluationService.getEvaluationHistory(limit: 10);
    
    // Generate performance trend (last 30 days)
    final performanceTrend = List.generate(30, (index) {
      return 0.7 + (index * 0.01) + (index % 3 * 0.05); // Simulated improving trend
    });
    
    return EvaluationState(
      totalEvaluations: stats['total_evaluations'] as int? ?? 0,
      averageScore: stats['average_score'] as double? ?? 0.0,
      activeSessions: stats['active_sessions'] as int? ?? 0,
      evaluations30d: stats['evaluations_30d'] as int? ?? 0,
      recentEvaluations: recentEvaluations,
      performanceTrend: performanceTrend,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final evaluationState = await _loadEvaluationState();
      state = AsyncValue.data(evaluationState);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}