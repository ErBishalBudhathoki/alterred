import 'dart:async';
import 'dart:math';
import 'logging_service.dart';

/// Agent evaluation and performance assessment service
/// 
/// Provides comprehensive evaluation framework for measuring agent effectiveness,
/// user productivity improvements, and system performance.
class EvaluationService {
  static EvaluationService? _instance;
  static EvaluationService get instance => _instance ??= EvaluationService._();
  
  EvaluationService._();

  final Logger _logger = Logger('EvaluationService');
  final Map<String, EvaluationSession> _activeSessions = {};
  final List<EvaluationResult> _evaluationHistory = [];
  bool _initialized = false;

  /// Initialize the evaluation service
  Future<void> initialize() async {
    if (_initialized) return;
    
    _initialized = true;
    _logger.info('Evaluation service initialized');
  }

  /// Start a new evaluation session
  String startEvaluationSession(String userId, EvaluationType type, {Map<String, dynamic>? baseline}) {
    final sessionId = _generateSessionId();
    final session = EvaluationSession(
      sessionId: sessionId,
      userId: userId,
      type: type,
      startTime: DateTime.now(),
      baseline: baseline ?? {},
    );

    _activeSessions[sessionId] = session;
    _logger.info('Started evaluation session', {
      'session_id': sessionId,
      'user_id': userId,
      'type': type.name,
      'baseline': baseline,
    });

    return sessionId;
  }

  /// Record a metric during evaluation
  void recordMetric(String sessionId, String metricName, dynamic value, {Map<String, dynamic>? context}) {
    final session = _activeSessions[sessionId];
    if (session == null) {
      _logger.warning('Attempted to record metric for non-existent session', {
        'session_id': sessionId,
        'metric': metricName,
      });
      return;
    }

    final metric = EvaluationMetric(
      timestamp: DateTime.now(),
      name: metricName,
      value: value,
      context: context ?? {},
    );

    session.metrics.add(metric);
    _logger.debug('Recorded evaluation metric', {
      'session_id': sessionId,
      'metric': metricName,
      'value': value,
      'context': context,
    });
  }

  /// Finish an evaluation session
  Future<EvaluationResult> finishEvaluationSession(String sessionId, {Map<String, dynamic>? summary}) async {
    final session = _activeSessions.remove(sessionId);
    if (session == null) {
      throw StateError('Evaluation session not found: $sessionId');
    }

    session.endTime = DateTime.now();
    session.duration = session.endTime!.difference(session.startTime);

    final result = await _calculateEvaluationResult(session, summary);
    _evaluationHistory.add(result);

    // Keep history manageable
    if (_evaluationHistory.length > 1000) {
      _evaluationHistory.removeRange(0, _evaluationHistory.length - 800);
    }

    _logger.info('Finished evaluation session', {
      'session_id': sessionId,
      'duration_ms': session.duration?.inMilliseconds,
      'metric_count': session.metrics.length,
      'overall_score': result.overallScore,
    });

    return result;
  }

  /// Evaluate agent performance
  Future<AgentEvaluationResult> evaluateAgent(String agentId, String agentName, Duration period) async {
    final endTime = DateTime.now();
    final startTime = endTime.subtract(period);

    // Collect agent metrics from the period
    final metrics = await _collectAgentMetrics(agentId, startTime, endTime);
    
    final result = AgentEvaluationResult(
      agentId: agentId,
      agentName: agentName,
      evaluationPeriod: period,
      startTime: startTime,
      endTime: endTime,
      executionCount: metrics['execution_count'] ?? 0,
      successRate: metrics['success_rate'] ?? 0.0,
      averageExecutionTime: Duration(milliseconds: metrics['avg_execution_time'] ?? 0),
      errorRate: metrics['error_rate'] ?? 0.0,
      userSatisfactionScore: metrics['user_satisfaction'] ?? 0.0,
      performanceScore: _calculateAgentPerformanceScore(metrics),
      recommendations: _generateAgentRecommendations(metrics),
    );

    _logger.info('Evaluated agent performance', {
      'agent_id': agentId,
      'agent_name': agentName,
      'period_hours': period.inHours,
      'performance_score': result.performanceScore,
      'success_rate': result.successRate,
    });

    return result;
  }

  /// Evaluate workflow performance
  Future<WorkflowEvaluationResult> evaluateWorkflow(String workflowId, String workflowName, Duration period) async {
    final endTime = DateTime.now();
    final startTime = endTime.subtract(period);

    final metrics = await _collectWorkflowMetrics(workflowId, startTime, endTime);
    
    final result = WorkflowEvaluationResult(
      workflowId: workflowId,
      workflowName: workflowName,
      evaluationPeriod: period,
      startTime: startTime,
      endTime: endTime,
      executionCount: metrics['execution_count'] ?? 0,
      successRate: metrics['success_rate'] ?? 0.0,
      averageExecutionTime: Duration(milliseconds: metrics['avg_execution_time'] ?? 0),
      stepSuccessRates: Map<String, double>.from(metrics['step_success_rates'] ?? {}),
      bottleneckSteps: List<String>.from(metrics['bottleneck_steps'] ?? []),
      performanceScore: _calculateWorkflowPerformanceScore(metrics),
      recommendations: _generateWorkflowRecommendations(metrics),
    );

    _logger.info('Evaluated workflow performance', {
      'workflow_id': workflowId,
      'workflow_name': workflowName,
      'period_hours': period.inHours,
      'performance_score': result.performanceScore,
      'success_rate': result.successRate,
    });

    return result;
  }

  /// Evaluate user productivity improvement
  Future<ProductivityEvaluationResult> evaluateProductivityImprovement(String userId, Duration period) async {
    final endTime = DateTime.now();
    final startTime = endTime.subtract(period);

    final beforeMetrics = await _collectUserProductivityMetrics(userId, startTime.subtract(period), startTime);
    final afterMetrics = await _collectUserProductivityMetrics(userId, startTime, endTime);

    final improvement = ProductivityImprovement(
      taskCompletionRate: _calculateImprovement(beforeMetrics['task_completion_rate'], afterMetrics['task_completion_rate']),
      timeAccuracy: _calculateImprovement(beforeMetrics['time_accuracy'], afterMetrics['time_accuracy']),
      decisionSpeed: _calculateImprovement(beforeMetrics['decision_speed'], afterMetrics['decision_speed']),
      stressLevel: _calculateImprovement(beforeMetrics['stress_level'], afterMetrics['stress_level'], lowerIsBetter: true),
      focusTime: _calculateImprovement(beforeMetrics['focus_time'], afterMetrics['focus_time']),
      burnoutPrevention: _calculateImprovement(beforeMetrics['burnout_incidents'], afterMetrics['burnout_incidents'], lowerIsBetter: true),
    );

    final result = ProductivityEvaluationResult(
      userId: userId,
      evaluationPeriod: period,
      startTime: startTime,
      endTime: endTime,
      beforeMetrics: beforeMetrics,
      afterMetrics: afterMetrics,
      improvement: improvement,
      overallImprovementScore: _calculateOverallImprovementScore(improvement),
      recommendations: _generateProductivityRecommendations(improvement),
    );

    _logger.info('Evaluated productivity improvement', {
      'user_id': userId,
      'period_hours': period.inHours,
      'overall_improvement': result.overallImprovementScore,
      'task_completion_improvement': improvement.taskCompletionRate,
    });

    return result;
  }

  /// Get evaluation history
  List<EvaluationResult> getEvaluationHistory({int limit = 100, EvaluationType? type}) {
    var results = _evaluationHistory.toList();
    
    if (type != null) {
      results = results.where((result) => result.type == type).toList();
    }
    
    results.sort((a, b) => b.endTime.compareTo(a.endTime));
    return results.take(limit).toList();
  }

  /// Get evaluation statistics
  Map<String, dynamic> getEvaluationStatistics() {
    final now = DateTime.now();
    final last30Days = now.subtract(const Duration(days: 30));
    
    final recentResults = _evaluationHistory.where((result) => result.endTime.isAfter(last30Days)).toList();
    
    final typeStats = <String, int>{};
    double totalScore = 0;
    int scoreCount = 0;
    
    for (final result in recentResults) {
      typeStats[result.type.name] = (typeStats[result.type.name] ?? 0) + 1;
      totalScore += result.overallScore;
      scoreCount++;
    }
    
    return {
      'total_evaluations': _evaluationHistory.length,
      'evaluations_30d': recentResults.length,
      'active_sessions': _activeSessions.length,
      'average_score': scoreCount > 0 ? totalScore / scoreCount : 0.0,
      'evaluation_types': typeStats,
    };
  }

  Future<EvaluationResult> _calculateEvaluationResult(EvaluationSession session, Map<String, dynamic>? summary) async {
    final metricsByName = <String, List<EvaluationMetric>>{};
    for (final metric in session.metrics) {
      metricsByName[metric.name] ??= [];
      metricsByName[metric.name]!.add(metric);
    }

    final aggregatedMetrics = <String, dynamic>{};
    for (final entry in metricsByName.entries) {
      aggregatedMetrics[entry.key] = _aggregateMetrics(entry.value);
    }

    final overallScore = _calculateOverallScore(session.type, aggregatedMetrics, session.baseline);
    
    return EvaluationResult(
      sessionId: session.sessionId,
      userId: session.userId,
      type: session.type,
      startTime: session.startTime,
      endTime: session.endTime!,
      duration: session.duration!,
      baseline: session.baseline,
      metrics: aggregatedMetrics,
      overallScore: overallScore,
      summary: summary ?? {},
      recommendations: _generateRecommendations(session.type, aggregatedMetrics, overallScore),
    );
  }

  Future<Map<String, dynamic>> _collectAgentMetrics(String agentId, DateTime startTime, DateTime endTime) async {
    // In a real implementation, this would query actual agent execution logs
    // For now, we'll simulate realistic metrics
    final random = Random();
    
    return {
      'execution_count': 50 + random.nextInt(100),
      'success_rate': 0.7 + random.nextDouble() * 0.3,
      'avg_execution_time': 1000 + random.nextInt(2000),
      'error_rate': random.nextDouble() * 0.1,
      'user_satisfaction': 3.5 + random.nextDouble() * 1.5,
    };
  }

  Future<Map<String, dynamic>> _collectWorkflowMetrics(String workflowId, DateTime startTime, DateTime endTime) async {
    final random = Random();
    
    return {
      'execution_count': 20 + random.nextInt(50),
      'success_rate': 0.8 + random.nextDouble() * 0.2,
      'avg_execution_time': 5000 + random.nextInt(10000),
      'step_success_rates': {
        'step_1': 0.9 + random.nextDouble() * 0.1,
        'step_2': 0.8 + random.nextDouble() * 0.2,
        'step_3': 0.85 + random.nextDouble() * 0.15,
      },
      'bottleneck_steps': ['step_2'],
    };
  }

  Future<Map<String, dynamic>> _collectUserProductivityMetrics(String userId, DateTime startTime, DateTime endTime) async {
    final random = Random();
    
    return {
      'task_completion_rate': 0.6 + random.nextDouble() * 0.3,
      'time_accuracy': 0.5 + random.nextDouble() * 0.4,
      'decision_speed': 120 + random.nextInt(180), // seconds
      'stress_level': 3 + random.nextDouble() * 4, // 1-7 scale
      'focus_time': 180 + random.nextInt(240), // minutes per day
      'burnout_incidents': random.nextInt(3),
    };
  }

  double _calculateImprovement(dynamic before, dynamic after, {bool lowerIsBetter = false}) {
    if (before == null || after == null) return 0.0;
    
    final beforeValue = before is num ? before.toDouble() : 0.0;
    final afterValue = after is num ? after.toDouble() : 0.0;
    
    if (beforeValue == 0) return 0.0;
    
    final improvement = (afterValue - beforeValue) / beforeValue;
    return lowerIsBetter ? -improvement : improvement;
  }

  double _calculateOverallImprovementScore(ProductivityImprovement improvement) {
    final scores = [
      improvement.taskCompletionRate,
      improvement.timeAccuracy,
      improvement.decisionSpeed,
      improvement.stressLevel,
      improvement.focusTime,
      improvement.burnoutPrevention,
    ];
    
    return scores.fold(0.0, (sum, score) => sum + score) / scores.length;
  }

  double _calculateAgentPerformanceScore(Map<String, dynamic> metrics) {
    final successRate = metrics['success_rate'] ?? 0.0;
    final errorRate = metrics['error_rate'] ?? 1.0;
    final userSatisfaction = (metrics['user_satisfaction'] ?? 0.0) / 5.0; // Normalize to 0-1
    
    return (successRate * 0.4) + ((1 - errorRate) * 0.3) + (userSatisfaction * 0.3);
  }

  double _calculateWorkflowPerformanceScore(Map<String, dynamic> metrics) {
    final successRate = metrics['success_rate'] ?? 0.0;
    final stepSuccessRates = Map<String, double>.from(metrics['step_success_rates'] ?? {});
    
    final avgStepSuccess = stepSuccessRates.values.isEmpty 
        ? 0.0 
        : stepSuccessRates.values.fold(0.0, (sum, rate) => sum + rate) / stepSuccessRates.length;
    
    return (successRate * 0.6) + (avgStepSuccess * 0.4);
  }

  double _calculateOverallScore(EvaluationType type, Map<String, dynamic> metrics, Map<String, dynamic> baseline) {
    switch (type) {
      case EvaluationType.agent:
        return _calculateAgentPerformanceScore(metrics);
      case EvaluationType.workflow:
        return _calculateWorkflowPerformanceScore(metrics);
      case EvaluationType.productivity:
        return _calculateProductivityScore(metrics, baseline);
      case EvaluationType.system:
        return _calculateSystemScore(metrics);
    }
  }

  double _calculateProductivityScore(Map<String, dynamic> metrics, Map<String, dynamic> baseline) {
    // Calculate improvement over baseline
    double score = 0.5; // Base score
    
    if (baseline.isNotEmpty) {
      final taskImprovement = _calculateImprovement(baseline['task_completion_rate'], metrics['task_completion_rate']);
      final timeImprovement = _calculateImprovement(baseline['time_accuracy'], metrics['time_accuracy']);
      score += (taskImprovement + timeImprovement) * 0.25;
    }
    
    return score.clamp(0.0, 1.0);
  }

  double _calculateSystemScore(Map<String, dynamic> metrics) {
    final uptime = metrics['uptime'] ?? 0.9;
    final responseTime = 1.0 - ((metrics['avg_response_time'] ?? 1000) / 5000).clamp(0.0, 1.0);
    final errorRate = 1.0 - (metrics['error_rate'] ?? 0.1);
    
    return (uptime * 0.4) + (responseTime * 0.3) + (errorRate * 0.3);
  }

  Map<String, dynamic> _aggregateMetrics(List<EvaluationMetric> metrics) {
    if (metrics.isEmpty) return {};
    
    final values = metrics.map((m) => m.value).whereType<num>().map((v) => v).toList();
    if (values.isEmpty) return {'count': metrics.length};
    
    values.sort();
    final sum = values.fold(0.0, (sum, val) => sum + val);
    
    return {
      'count': metrics.length,
      'sum': sum,
      'average': sum / values.length,
      'min': values.first,
      'max': values.last,
      'median': values[values.length ~/ 2],
    };
  }

  List<String> _generateRecommendations(EvaluationType type, Map<String, dynamic> metrics, double overallScore) {
    final recommendations = <String>[];
    
    if (overallScore < 0.6) {
      recommendations.add('Overall performance is below target. Consider reviewing configuration and usage patterns.');
    }
    
    switch (type) {
      case EvaluationType.agent:
        if (metrics['success_rate']?['average'] < 0.8) {
          recommendations.add('Agent success rate is low. Review error patterns and improve error handling.');
        }
        break;
      case EvaluationType.workflow:
        if (metrics['avg_execution_time']?['average'] > 10000) {
          recommendations.add('Workflow execution time is high. Consider optimizing bottleneck steps.');
        }
        break;
      case EvaluationType.productivity:
        if (metrics['task_completion_rate']?['average'] < 0.7) {
          recommendations.add('Task completion rate could be improved. Consider breaking tasks into smaller chunks.');
        }
        break;
      case EvaluationType.system:
        if (metrics['error_rate']?['average'] > 0.05) {
          recommendations.add('System error rate is elevated. Review logs and implement additional monitoring.');
        }
        break;
    }
    
    return recommendations;
  }

  List<String> _generateAgentRecommendations(Map<String, dynamic> metrics) {
    final recommendations = <String>[];
    
    if (metrics['success_rate'] < 0.8) {
      recommendations.add('Improve error handling and retry logic');
    }
    if (metrics['avg_execution_time'] > 3000) {
      recommendations.add('Optimize agent execution performance');
    }
    if (metrics['user_satisfaction'] < 4.0) {
      recommendations.add('Review user feedback and improve agent responses');
    }
    
    return recommendations;
  }

  List<String> _generateWorkflowRecommendations(Map<String, dynamic> metrics) {
    final recommendations = <String>[];
    
    if (metrics['success_rate'] < 0.85) {
      recommendations.add('Review and improve workflow step reliability');
    }
    if (metrics['bottleneck_steps']?.isNotEmpty == true) {
      recommendations.add('Optimize identified bottleneck steps: ${metrics['bottleneck_steps'].join(', ')}');
    }
    
    return recommendations;
  }

  List<String> _generateProductivityRecommendations(ProductivityImprovement improvement) {
    final recommendations = <String>[];
    
    if (improvement.taskCompletionRate < 0.1) {
      recommendations.add('Focus on task breakdown and prioritization strategies');
    }
    if (improvement.timeAccuracy < 0.1) {
      recommendations.add('Improve time estimation skills with more practice');
    }
    if (improvement.stressLevel > -0.1) {
      recommendations.add('Implement additional stress management techniques');
    }
    
    return recommendations;
  }

  String _generateSessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(0xFFFF);
    return 'eval_${timestamp}_$random';
  }
}

/// Evaluation session model
class EvaluationSession {
  final String sessionId;
  final String userId;
  final EvaluationType type;
  final DateTime startTime;
  final Map<String, dynamic> baseline;
  final List<EvaluationMetric> metrics = [];
  
  DateTime? endTime;
  Duration? duration;

  EvaluationSession({
    required this.sessionId,
    required this.userId,
    required this.type,
    required this.startTime,
    this.baseline = const {},
  });
}

/// Evaluation metric model
class EvaluationMetric {
  final DateTime timestamp;
  final String name;
  final dynamic value;
  final Map<String, dynamic> context;

  const EvaluationMetric({
    required this.timestamp,
    required this.name,
    required this.value,
    this.context = const {},
  });
}

/// Evaluation result model
class EvaluationResult {
  final String sessionId;
  final String userId;
  final EvaluationType type;
  final DateTime startTime;
  final DateTime endTime;
  final Duration duration;
  final Map<String, dynamic> baseline;
  final Map<String, dynamic> metrics;
  final double overallScore;
  final Map<String, dynamic> summary;
  final List<String> recommendations;

  const EvaluationResult({
    required this.sessionId,
    required this.userId,
    required this.type,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.baseline,
    required this.metrics,
    required this.overallScore,
    required this.summary,
    required this.recommendations,
  });
}

/// Agent evaluation result
class AgentEvaluationResult {
  final String agentId;
  final String agentName;
  final Duration evaluationPeriod;
  final DateTime startTime;
  final DateTime endTime;
  final int executionCount;
  final double successRate;
  final Duration averageExecutionTime;
  final double errorRate;
  final double userSatisfactionScore;
  final double performanceScore;
  final List<String> recommendations;

  const AgentEvaluationResult({
    required this.agentId,
    required this.agentName,
    required this.evaluationPeriod,
    required this.startTime,
    required this.endTime,
    required this.executionCount,
    required this.successRate,
    required this.averageExecutionTime,
    required this.errorRate,
    required this.userSatisfactionScore,
    required this.performanceScore,
    required this.recommendations,
  });
}

/// Workflow evaluation result
class WorkflowEvaluationResult {
  final String workflowId;
  final String workflowName;
  final Duration evaluationPeriod;
  final DateTime startTime;
  final DateTime endTime;
  final int executionCount;
  final double successRate;
  final Duration averageExecutionTime;
  final Map<String, double> stepSuccessRates;
  final List<String> bottleneckSteps;
  final double performanceScore;
  final List<String> recommendations;

  const WorkflowEvaluationResult({
    required this.workflowId,
    required this.workflowName,
    required this.evaluationPeriod,
    required this.startTime,
    required this.endTime,
    required this.executionCount,
    required this.successRate,
    required this.averageExecutionTime,
    required this.stepSuccessRates,
    required this.bottleneckSteps,
    required this.performanceScore,
    required this.recommendations,
  });
}

/// Productivity evaluation result
class ProductivityEvaluationResult {
  final String userId;
  final Duration evaluationPeriod;
  final DateTime startTime;
  final DateTime endTime;
  final Map<String, dynamic> beforeMetrics;
  final Map<String, dynamic> afterMetrics;
  final ProductivityImprovement improvement;
  final double overallImprovementScore;
  final List<String> recommendations;

  const ProductivityEvaluationResult({
    required this.userId,
    required this.evaluationPeriod,
    required this.startTime,
    required this.endTime,
    required this.beforeMetrics,
    required this.afterMetrics,
    required this.improvement,
    required this.overallImprovementScore,
    required this.recommendations,
  });
}

/// Productivity improvement metrics
class ProductivityImprovement {
  final double taskCompletionRate;
  final double timeAccuracy;
  final double decisionSpeed;
  final double stressLevel;
  final double focusTime;
  final double burnoutPrevention;

  const ProductivityImprovement({
    required this.taskCompletionRate,
    required this.timeAccuracy,
    required this.decisionSpeed,
    required this.stressLevel,
    required this.focusTime,
    required this.burnoutPrevention,
  });
}

/// Evaluation types
enum EvaluationType {
  agent,
  workflow,
  productivity,
  system,
}