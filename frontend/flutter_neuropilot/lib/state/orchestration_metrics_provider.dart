import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../core/orchestration/state/orchestration_provider.dart';
import '../core/orchestration/models/agent_model.dart';
import '../core/orchestration/models/workflow_model.dart';
import '../core/orchestration/agents/base/agent_base.dart';

/// Real-time orchestration metrics state
class OrchestrationMetrics {
  final Map<String, AgentMetrics> agentMetrics;
  final Map<String, WorkflowMetrics> workflowMetrics;
  final SystemPerformanceMetrics systemMetrics;
  final List<MetricEvent> recentEvents;
  final DateTime lastUpdated;

  const OrchestrationMetrics({
    this.agentMetrics = const {},
    this.workflowMetrics = const {},
    this.systemMetrics = const SystemPerformanceMetrics(),
    this.recentEvents = const [],
    required this.lastUpdated,
  });

  OrchestrationMetrics copyWith({
    Map<String, AgentMetrics>? agentMetrics,
    Map<String, WorkflowMetrics>? workflowMetrics,
    SystemPerformanceMetrics? systemMetrics,
    List<MetricEvent>? recentEvents,
    DateTime? lastUpdated,
  }) {
    return OrchestrationMetrics(
      agentMetrics: agentMetrics ?? this.agentMetrics,
      workflowMetrics: workflowMetrics ?? this.workflowMetrics,
      systemMetrics: systemMetrics ?? this.systemMetrics,
      recentEvents: recentEvents ?? this.recentEvents,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

/// Agent-specific metrics
class AgentMetrics {
  final String agentId;
  final String agentName;
  final AgentStatus status;
  final int totalExecutions;
  final int successfulExecutions;
  final int failedExecutions;
  final double successRate;
  final Duration averageExecutionTime;
  final DateTime lastActive;
  final List<double> executionTimeHistory;
  final Map<String, dynamic> customMetrics;

  const AgentMetrics({
    required this.agentId,
    required this.agentName,
    required this.status,
    this.totalExecutions = 0,
    this.successfulExecutions = 0,
    this.failedExecutions = 0,
    this.successRate = 0.0,
    this.averageExecutionTime = Duration.zero,
    required this.lastActive,
    this.executionTimeHistory = const [],
    this.customMetrics = const {},
  });

  AgentMetrics copyWith({
    String? agentId,
    String? agentName,
    AgentStatus? status,
    int? totalExecutions,
    int? successfulExecutions,
    int? failedExecutions,
    double? successRate,
    Duration? averageExecutionTime,
    DateTime? lastActive,
    List<double>? executionTimeHistory,
    Map<String, dynamic>? customMetrics,
  }) {
    return AgentMetrics(
      agentId: agentId ?? this.agentId,
      agentName: agentName ?? this.agentName,
      status: status ?? this.status,
      totalExecutions: totalExecutions ?? this.totalExecutions,
      successfulExecutions: successfulExecutions ?? this.successfulExecutions,
      failedExecutions: failedExecutions ?? this.failedExecutions,
      successRate: successRate ?? this.successRate,
      averageExecutionTime: averageExecutionTime ?? this.averageExecutionTime,
      lastActive: lastActive ?? this.lastActive,
      executionTimeHistory: executionTimeHistory ?? this.executionTimeHistory,
      customMetrics: customMetrics ?? this.customMetrics,
    );
  }
}

/// Workflow-specific metrics
class WorkflowMetrics {
  final String workflowId;
  final String workflowName;
  final int totalExecutions;
  final int successfulExecutions;
  final int failedExecutions;
  final double successRate;
  final Duration averageExecutionTime;
  final DateTime lastExecuted;
  final List<WorkflowExecution> recentExecutions;
  final Map<String, int> stepSuccessRates;

  const WorkflowMetrics({
    required this.workflowId,
    required this.workflowName,
    this.totalExecutions = 0,
    this.successfulExecutions = 0,
    this.failedExecutions = 0,
    this.successRate = 0.0,
    this.averageExecutionTime = Duration.zero,
    required this.lastExecuted,
    this.recentExecutions = const [],
    this.stepSuccessRates = const {},
  });

  WorkflowMetrics copyWith({
    String? workflowId,
    String? workflowName,
    int? totalExecutions,
    int? successfulExecutions,
    int? failedExecutions,
    double? successRate,
    Duration? averageExecutionTime,
    DateTime? lastExecuted,
    List<WorkflowExecution>? recentExecutions,
    Map<String, int>? stepSuccessRates,
  }) {
    return WorkflowMetrics(
      workflowId: workflowId ?? this.workflowId,
      workflowName: workflowName ?? this.workflowName,
      totalExecutions: totalExecutions ?? this.totalExecutions,
      successfulExecutions: successfulExecutions ?? this.successfulExecutions,
      failedExecutions: failedExecutions ?? this.failedExecutions,
      successRate: successRate ?? this.successRate,
      averageExecutionTime: averageExecutionTime ?? this.averageExecutionTime,
      lastExecuted: lastExecuted ?? this.lastExecuted,
      recentExecutions: recentExecutions ?? this.recentExecutions,
      stepSuccessRates: stepSuccessRates ?? this.stepSuccessRates,
    );
  }
}

/// System performance metrics
class SystemPerformanceMetrics {
  final double cpuUsage;
  final double memoryUsage;
  final int activeAgents;
  final int runningWorkflows;
  final int safetyViolations24h;
  final double systemHealth;
  final List<double> performanceHistory;

  const SystemPerformanceMetrics({
    this.cpuUsage = 0.0,
    this.memoryUsage = 0.0,
    this.activeAgents = 0,
    this.runningWorkflows = 0,
    this.safetyViolations24h = 0,
    this.systemHealth = 1.0,
    this.performanceHistory = const [],
  });

  SystemPerformanceMetrics copyWith({
    double? cpuUsage,
    double? memoryUsage,
    int? activeAgents,
    int? runningWorkflows,
    int? safetyViolations24h,
    double? systemHealth,
    List<double>? performanceHistory,
  }) {
    return SystemPerformanceMetrics(
      cpuUsage: cpuUsage ?? this.cpuUsage,
      memoryUsage: memoryUsage ?? this.memoryUsage,
      activeAgents: activeAgents ?? this.activeAgents,
      runningWorkflows: runningWorkflows ?? this.runningWorkflows,
      safetyViolations24h: safetyViolations24h ?? this.safetyViolations24h,
      systemHealth: systemHealth ?? this.systemHealth,
      performanceHistory: performanceHistory ?? this.performanceHistory,
    );
  }
}

/// Metric event for real-time updates
class MetricEvent {
  final String type;
  final String source;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  const MetricEvent({
    required this.type,
    required this.source,
    required this.data,
    required this.timestamp,
  });
}

/// Orchestration metrics notifier
class OrchestrationMetricsNotifier extends StateNotifier<OrchestrationMetrics> {
  OrchestrationMetricsNotifier(this._ref)
      : super(OrchestrationMetrics(lastUpdated: DateTime.now())) {
    _initialize();
  }

  final Ref _ref;
  Timer? _updateTimer;
  final Map<String, AgentMetrics> _agentMetricsHistory = {};
  final Map<String, WorkflowMetrics> _workflowMetricsHistory = {};

  void _initialize() {
    // Start periodic updates
    _updateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _updateMetrics();
    });

    // Initial update
    _updateMetrics();
  }

  void _updateMetrics() {
    final orchestrationState = _ref.read(orchestrationProvider);
    final systemHealth = _ref.read(systemHealthProvider);
    final orchestrationStats = _ref.read(orchestrationStatsProvider);

    // Update agent metrics
    final agentMetrics = <String, AgentMetrics>{};
    for (final agent in orchestrationState.agents.values) {
      final metrics = agent.getMetrics();
      final agentMetric = _buildAgentMetrics(agent, metrics);
      agentMetrics[agent.metadata.id] = agentMetric;
      _agentMetricsHistory[agent.metadata.id] = agentMetric;
    }

    // Update workflow metrics
    final workflowMetrics = <String, WorkflowMetrics>{};
    for (final workflow in orchestrationState.workflows.values) {
      final workflowMetric =
          _buildWorkflowMetrics(workflow, orchestrationState.activeExecutions);
      workflowMetrics[workflow.id] = workflowMetric;
      _workflowMetricsHistory[workflow.id] = workflowMetric;
    }

    // Update system metrics
    final systemMetrics = _buildSystemMetrics(systemHealth, orchestrationStats);

    // Update state
    state = state.copyWith(
      agentMetrics: agentMetrics,
      workflowMetrics: workflowMetrics,
      systemMetrics: systemMetrics,
      lastUpdated: DateTime.now(),
    );
  }

  AgentMetrics _buildAgentMetrics(
      AgentBase agent, Map<String, dynamic> metrics) {
    final existing = _agentMetricsHistory[agent.metadata.id];

    return AgentMetrics(
      agentId: agent.metadata.id,
      agentName: agent.metadata.name,
      status: agent.status,
      totalExecutions: metrics['execution_count'] as int? ?? 0,
      successfulExecutions: _calculateSuccessfulExecutions(metrics),
      failedExecutions: _calculateFailedExecutions(metrics),
      successRate: metrics['success_rate'] as double? ?? 0.0,
      averageExecutionTime: Duration(
          milliseconds: metrics['average_execution_time'] as int? ?? 0),
      lastActive: agent.lastActive,
      executionTimeHistory: _updateExecutionTimeHistory(
          existing?.executionTimeHistory ?? [], metrics),
      customMetrics: _extractCustomMetrics(metrics),
    );
  }

  WorkflowMetrics _buildWorkflowMetrics(
      Workflow workflow, List<WorkflowExecution> activeExecutions) {
    final workflowExecutions =
        activeExecutions.where((e) => e.workflowId == workflow.id).toList();

    return WorkflowMetrics(
      workflowId: workflow.id,
      workflowName: workflow.name,
      totalExecutions: workflow.executionCount,
      successfulExecutions: _calculateWorkflowSuccesses(workflow),
      failedExecutions: _calculateWorkflowFailures(workflow),
      successRate: workflow.successRate,
      averageExecutionTime: _calculateAverageWorkflowTime(workflowExecutions),
      lastExecuted: workflow.lastExecuted ?? DateTime.now(),
      recentExecutions: workflowExecutions.take(10).toList(),
      stepSuccessRates: _calculateStepSuccessRates(workflowExecutions),
    );
  }

  SystemPerformanceMetrics _buildSystemMetrics(
    Map<String, dynamic> systemHealth,
    Map<String, dynamic> orchestrationStats,
  ) {
    final agentStats =
        orchestrationStats['agents'] as Map<String, dynamic>? ?? {};
    final executionStats =
        orchestrationStats['executions'] as Map<String, dynamic>? ?? {};
    final safetyStats =
        orchestrationStats['safety'] as Map<String, dynamic>? ?? {};

    return SystemPerformanceMetrics(
      cpuUsage: _simulateCpuUsage(), // Would be real CPU usage in production
      memoryUsage:
          _simulateMemoryUsage(), // Would be real memory usage in production
      activeAgents: agentStats['active_agents'] as int? ?? 0,
      runningWorkflows: executionStats['running_executions'] as int? ?? 0,
      safetyViolations24h: safetyStats['recent_violations_24h'] as int? ?? 0,
      systemHealth: _calculateSystemHealthScore(systemHealth),
      performanceHistory: _updatePerformanceHistory(),
    );
  }

  int _calculateSuccessfulExecutions(Map<String, dynamic> metrics) {
    final total = metrics['execution_count'] as int? ?? 0;
    final successRate = metrics['success_rate'] as double? ?? 0.0;
    return (total * successRate).round();
  }

  int _calculateFailedExecutions(Map<String, dynamic> metrics) {
    final total = metrics['execution_count'] as int? ?? 0;
    final successful = _calculateSuccessfulExecutions(metrics);
    return total - successful;
  }

  List<double> _updateExecutionTimeHistory(
      List<double> existing, Map<String, dynamic> metrics) {
    final newTime = (metrics['average_execution_time'] as int? ?? 0).toDouble();
    final updated = [...existing, newTime];

    // Keep only last 50 data points
    if (updated.length > 50) {
      return updated.sublist(updated.length - 50);
    }

    return updated;
  }

  Map<String, dynamic> _extractCustomMetrics(Map<String, dynamic> metrics) {
    final custom = <String, dynamic>{};

    // Extract agent-specific metrics
    if (metrics.containsKey('monitoring_stats')) {
      custom['monitoring_stats'] = metrics['monitoring_stats'];
    }
    if (metrics.containsKey('learning_data_points')) {
      custom['learning_data_points'] = metrics['learning_data_points'];
    }
    if (metrics.containsKey('compliance_rate')) {
      custom['compliance_rate'] = metrics['compliance_rate'];
    }
    if (metrics.containsKey('hyperfocus_frequency')) {
      custom['hyperfocus_frequency'] = metrics['hyperfocus_frequency'];
    }

    return custom;
  }

  int _calculateWorkflowSuccesses(Workflow workflow) {
    return (workflow.executionCount * workflow.successRate).round();
  }

  int _calculateWorkflowFailures(Workflow workflow) {
    return workflow.executionCount - _calculateWorkflowSuccesses(workflow);
  }

  Duration _calculateAverageWorkflowTime(List<WorkflowExecution> executions) {
    if (executions.isEmpty) return Duration.zero;

    final completedExecutions =
        executions.where((e) => e.executionTime != null).toList();
    if (completedExecutions.isEmpty) return Duration.zero;

    final totalTime = completedExecutions
        .map((e) => e.executionTime!.inMilliseconds)
        .reduce((a, b) => a + b);

    return Duration(milliseconds: totalTime ~/ completedExecutions.length);
  }

  Map<String, int> _calculateStepSuccessRates(
      List<WorkflowExecution> executions) {
    final stepStats = <String, Map<String, int>>{};

    for (final execution in executions) {
      for (final stepExecution in execution.stepExecutions) {
        final stepId = stepExecution.stepId;
        stepStats[stepId] ??= {'total': 0, 'successful': 0};
        stepStats[stepId]!['total'] = stepStats[stepId]!['total']! + 1;

        if (stepExecution.status == WorkflowStepExecutionStatus.completed) {
          stepStats[stepId]!['successful'] =
              stepStats[stepId]!['successful']! + 1;
        }
      }
    }

    final successRates = <String, int>{};
    stepStats.forEach((stepId, stats) {
      final total = stats['total']!;
      final successful = stats['successful']!;
      successRates[stepId] =
          total > 0 ? ((successful / total) * 100).round() : 0;
    });

    return successRates;
  }

  double _simulateCpuUsage() {
    // In production, this would get real CPU usage
    const baseUsage = 20.0; // Base usage
    final agentLoad =
        state.systemMetrics.activeAgents * 5.0; // Each agent adds 5%
    final workflowLoad =
        state.systemMetrics.runningWorkflows * 10.0; // Each workflow adds 10%

    return (baseUsage + agentLoad + workflowLoad).clamp(0.0, 100.0);
  }

  double _simulateMemoryUsage() {
    // In production, this would get real memory usage
    const baseUsage = 30.0; // Base usage
    final agentLoad =
        state.systemMetrics.activeAgents * 3.0; // Each agent adds 3%
    final workflowLoad =
        state.systemMetrics.runningWorkflows * 8.0; // Each workflow adds 8%

    return (baseUsage + agentLoad + workflowLoad).clamp(0.0, 100.0);
  }

  double _calculateSystemHealthScore(Map<String, dynamic> systemHealth) {
    final overallHealth =
        systemHealth['overall_health'] as String? ?? 'unknown';

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
        return 0.5;
    }
  }

  List<double> _updatePerformanceHistory() {
    final currentScore = state.systemMetrics.systemHealth;
    final updated = [...state.systemMetrics.performanceHistory, currentScore];

    // Keep only last 100 data points
    if (updated.length > 100) {
      return updated.sublist(updated.length - 100);
    }

    return updated;
  }

  void addMetricEvent(String type, String source, Map<String, dynamic> data) {
    final event = MetricEvent(
      type: type,
      source: source,
      data: data,
      timestamp: DateTime.now(),
    );

    final updatedEvents = [...state.recentEvents, event];

    // Keep only last 100 events
    if (updatedEvents.length > 100) {
      updatedEvents.removeRange(0, updatedEvents.length - 100);
    }

    state = state.copyWith(recentEvents: updatedEvents);
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }
}

/// Provider for orchestration metrics
final orchestrationMetricsProvider =
    StateNotifierProvider<OrchestrationMetricsNotifier, OrchestrationMetrics>(
        (ref) {
  return OrchestrationMetricsNotifier(ref);
});

/// Provider for agent metrics by ID
final agentMetricsProvider =
    Provider.family<AgentMetrics?, String>((ref, agentId) {
  final metrics = ref.watch(orchestrationMetricsProvider);
  return metrics.agentMetrics[agentId];
});

/// Provider for workflow metrics by ID
final workflowMetricsProvider =
    Provider.family<WorkflowMetrics?, String>((ref, workflowId) {
  final metrics = ref.watch(orchestrationMetricsProvider);
  return metrics.workflowMetrics[workflowId];
});

/// Provider for system performance metrics
final systemPerformanceMetricsProvider =
    Provider<SystemPerformanceMetrics>((ref) {
  final metrics = ref.watch(orchestrationMetricsProvider);
  return metrics.systemMetrics;
});

/// Provider for real-time metric events
final metricEventsProvider = Provider<List<MetricEvent>>((ref) {
  final metrics = ref.watch(orchestrationMetricsProvider);
  return metrics.recentEvents;
});

/// Provider for test scenario metrics
final testScenarioMetricsProvider =
    Provider<Map<String, WorkflowMetrics?>>((ref) {
  final metrics = ref.watch(orchestrationMetricsProvider);

  return {
    'morning_routine': metrics.workflowMetrics['morning_routine'],
    'decision_paralysis': metrics.workflowMetrics['decision_paralysis'],
    'hyperfocus_protection': metrics.workflowMetrics['hyperfocus_protection'],
  };
});

/// Provider for agent performance summary
final agentPerformanceSummaryProvider = Provider<Map<String, dynamic>>((ref) {
  final metrics = ref.watch(orchestrationMetricsProvider);

  final totalExecutions = metrics.agentMetrics.values
      .map((m) => m.totalExecutions)
      .fold(0, (a, b) => a + b);

  final totalSuccessful = metrics.agentMetrics.values
      .map((m) => m.successfulExecutions)
      .fold(0, (a, b) => a + b);

  final overallSuccessRate =
      totalExecutions > 0 ? totalSuccessful / totalExecutions : 0.0;

  final activeAgents = metrics.agentMetrics.values
      .where((m) =>
          m.status == AgentStatus.active || m.status == AgentStatus.monitoring)
      .length;

  return {
    'total_agents': metrics.agentMetrics.length,
    'active_agents': activeAgents,
    'total_executions': totalExecutions,
    'overall_success_rate': overallSuccessRate,
    'average_execution_time':
        _calculateAverageExecutionTime(metrics.agentMetrics.values),
  };
});

Duration _calculateAverageExecutionTime(Iterable<AgentMetrics> agentMetrics) {
  if (agentMetrics.isEmpty) return Duration.zero;

  final totalMs = agentMetrics
      .map((m) => m.averageExecutionTime.inMilliseconds)
      .fold(0, (a, b) => a + b);

  return Duration(milliseconds: totalMs ~/ agentMetrics.length);
}
