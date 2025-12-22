import 'dart:async';
import 'dart:math';
import '../models/agent_model.dart';
import 'base/reactive_agent.dart';

/// Agent that provides realistic time estimates for tasks, optimized for ADHD users
class TimeEstimationAgent extends ReactiveAgent {
  static const String agentId = 'time_estimation';
  
  TimeEstimationAgent() : super(
    Agent(
      id: agentId,
      name: 'Time Estimation Agent',
      description: 'Provides realistic time estimates for tasks based on ADHD-specific factors and historical data',
      type: AgentType.reactive,
      capabilities: const AgentCapabilities(
        canExecuteParallel: true,
        canBeInterrupted: true,
        canInterruptOthers: false,
        requiresUserInput: false,
        hasMemory: true,
        canLearn: true,
        inputTypes: ['task_description', 'task_complexity', 'energy_level', 'historical_data'],
        outputTypes: ['time_estimate', 'confidence_level', 'breakdown', 'recommendations'],
        maxExecutionTime: Duration(seconds: 30),
        maxConcurrentInstances: 5,
      ),
      lastActive: DateTime.now(),
      config: {
        'adhd_multiplier': 1.5,        // Base ADHD time multiplier
        'learning_enabled': true,
        'confidence_threshold': 0.7,   // Minimum confidence for estimates
        'historical_weight': 0.6,      // Weight of historical data vs. base estimates
        'energy_impact_factor': 0.3,   // How much energy affects estimates
      },
    ),
  );

  @override
  Future<AgentResult> processRequest(ExecutionContext context) async {
    final requestType = context.parameters['type'] as String? ?? 'estimate_task';
    
    switch (requestType) {
      case 'estimate_task':
        return await _estimateTask(context);
      case 'estimate_multiple':
        return await _estimateMultipleTasks(context);
      case 'update_actual_time':
        return await _updateActualTime(context);
      case 'get_estimation_accuracy':
        return await _getEstimationAccuracy(context);
      case 'analyze_patterns':
        return await _analyzeTimePatterns(context);
      default:
        return AgentResult(
          agentId: metadata.id,
          success: false,
          error: 'Unknown request type: $requestType',
          executionTime: Duration.zero,
          timestamp: DateTime.now(),
        );
    }
  }

  /// Estimate time for a single task
  Future<AgentResult> _estimateTask(ExecutionContext context) async {
    final startTime = DateTime.now();
    
    try {
      final taskDescription = context.parameters['task_description'] as String? ?? '';
      final taskComplexity = context.parameters['complexity'] as String? ?? 'medium';
      final taskType = context.parameters['task_type'] as String? ?? 'general';
      final energyLevel = context.userState['energy_level'] as double? ?? 0.5;
      
      if (taskDescription.isEmpty) {
        return AgentResult(
          agentId: metadata.id,
          success: false,
          error: 'Task description is required',
          executionTime: DateTime.now().difference(startTime),
          timestamp: DateTime.now(),
        );
      }

      // Generate base estimate
      final baseEstimate = _generateBaseEstimate(taskDescription, taskComplexity, taskType);
      
      // Apply ADHD-specific adjustments
      final adhdAdjustedEstimate = _applyADHDAdjustments(baseEstimate, taskComplexity, energyLevel);
      
      // Apply historical learning
      final historicalAdjustment = await _getHistoricalAdjustment(taskType, taskComplexity);
      final finalEstimate = _applyHistoricalAdjustment(adhdAdjustedEstimate, historicalAdjustment);
      
      // Calculate confidence level
      final confidence = _calculateConfidence(taskType, taskComplexity, historicalAdjustment);
      
      // Generate breakdown and recommendations
      final breakdown = _generateEstimateBreakdown(baseEstimate, adhdAdjustedEstimate, finalEstimate);
      final recommendations = _generateRecommendations(finalEstimate, confidence, energyLevel);
      
      // Store estimate for learning
      _storeEstimate(taskDescription, taskType, taskComplexity, finalEstimate, confidence, context);
      
      return AgentResult(
        agentId: metadata.id,
        success: true,
        data: {
          'estimate_minutes': finalEstimate,
          'confidence_level': confidence,
          'breakdown': breakdown,
          'recommendations': recommendations,
          'factors_considered': {
            'base_estimate': baseEstimate,
            'adhd_multiplier': metadata.config['adhd_multiplier'],
            'energy_level': energyLevel,
            'historical_data': historicalAdjustment != null,
            'task_complexity': taskComplexity,
          },
        },
        executionTime: DateTime.now().difference(startTime),
        timestamp: DateTime.now(),
      );
    } catch (error) {
      return AgentResult(
        agentId: metadata.id,
        success: false,
        error: error.toString(),
        executionTime: DateTime.now().difference(startTime),
        timestamp: DateTime.now(),
      );
    }
  }

  /// Estimate time for multiple tasks
  Future<AgentResult> _estimateMultipleTasks(ExecutionContext context) async {
    final startTime = DateTime.now();
    
    try {
      final tasks = context.parameters['tasks'] as List<dynamic>? ?? [];
      
      if (tasks.isEmpty) {
        return AgentResult(
          agentId: metadata.id,
          success: false,
          error: 'No tasks provided',
          executionTime: DateTime.now().difference(startTime),
          timestamp: DateTime.now(),
        );
      }

      final estimates = <Map<String, dynamic>>[];
      var totalEstimate = 0;
      var totalConfidence = 0.0;
      
      for (final task in tasks) {
        final taskMap = task as Map<String, dynamic>;
        final taskContext = context.copyWith(parameters: taskMap);
        
        final result = await _estimateTask(taskContext);
        if (result.success) {
          final estimate = result.data['estimate_minutes'] as int;
          final confidence = result.data['confidence_level'] as double;
          
          estimates.add({
            'task': taskMap,
            'estimate_minutes': estimate,
            'confidence_level': confidence,
            'breakdown': result.data['breakdown'],
          });
          
          totalEstimate += estimate;
          totalConfidence += confidence;
        }
      }
      
      // Apply context switching overhead for multiple tasks
      final contextSwitchingOverhead = _calculateContextSwitchingOverhead(estimates.length);
      totalEstimate += contextSwitchingOverhead;
      
      final averageConfidence = estimates.isNotEmpty ? totalConfidence / estimates.length : 0.0;
      
      return AgentResult(
        agentId: metadata.id,
        success: true,
        data: {
          'individual_estimates': estimates,
          'total_estimate_minutes': totalEstimate,
          'average_confidence': averageConfidence,
          'context_switching_overhead': contextSwitchingOverhead,
          'recommendations': _generateMultiTaskRecommendations(estimates, totalEstimate),
        },
        executionTime: DateTime.now().difference(startTime),
        timestamp: DateTime.now(),
      );
    } catch (error) {
      return AgentResult(
        agentId: metadata.id,
        success: false,
        error: error.toString(),
        executionTime: DateTime.now().difference(startTime),
        timestamp: DateTime.now(),
      );
    }
  }

  /// Update actual time taken for a task (for learning)
  Future<AgentResult> _updateActualTime(ExecutionContext context) async {
    final startTime = DateTime.now();
    
    try {
      final estimateId = context.parameters['estimate_id'] as String?;
      final actualMinutes = context.parameters['actual_minutes'] as int?;
      final taskCompleted = context.parameters['completed'] as bool? ?? true;
      final interruptions = context.parameters['interruptions'] as int? ?? 0;
      
      if (estimateId == null || actualMinutes == null) {
        return AgentResult(
          agentId: metadata.id,
          success: false,
          error: 'Estimate ID and actual minutes are required',
          executionTime: DateTime.now().difference(startTime),
          timestamp: DateTime.now(),
        );
      }

      // Find the original estimate
      final estimates = recall<List<Map<String, dynamic>>>('estimates') ?? [];
      final estimateIndex = estimates.indexWhere((e) => e['id'] == estimateId);
      
      if (estimateIndex == -1) {
        return AgentResult(
          agentId: metadata.id,
          success: false,
          error: 'Estimate not found',
          executionTime: DateTime.now().difference(startTime),
          timestamp: DateTime.now(),
        );
      }

      final estimate = estimates[estimateIndex];
      final estimatedMinutes = estimate['estimate_minutes'] as int;
      
      // Calculate accuracy metrics
      final accuracy = _calculateAccuracy(estimatedMinutes, actualMinutes);
      final variance = actualMinutes - estimatedMinutes;
      final variancePercentage = (variance / estimatedMinutes * 100).abs();
      
      // Update estimate with actual data
      estimates[estimateIndex] = {
        ...estimate,
        'actual_minutes': actualMinutes,
        'completed': taskCompleted,
        'interruptions': interruptions,
        'accuracy': accuracy,
        'variance': variance,
        'variance_percentage': variancePercentage,
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      remember('estimates', estimates);
      
      // Learn from this data point
      _learnFromActualTime(estimate, actualMinutes, taskCompleted, interruptions);
      
      return AgentResult(
        agentId: metadata.id,
        success: true,
        data: {
          'estimate_id': estimateId,
          'estimated_minutes': estimatedMinutes,
          'actual_minutes': actualMinutes,
          'accuracy': accuracy,
          'variance': variance,
          'variance_percentage': variancePercentage,
          'learning_applied': true,
        },
        executionTime: DateTime.now().difference(startTime),
        timestamp: DateTime.now(),
      );
    } catch (error) {
      return AgentResult(
        agentId: metadata.id,
        success: false,
        error: error.toString(),
        executionTime: DateTime.now().difference(startTime),
        timestamp: DateTime.now(),
      );
    }
  }

  /// Get estimation accuracy statistics
  Future<AgentResult> _getEstimationAccuracy(ExecutionContext context) async {
    final startTime = DateTime.now();
    
    try {
      final estimates = recall<List<Map<String, dynamic>>>('estimates') ?? [];
      final completedEstimates = estimates.where((e) => 
        e.containsKey('actual_minutes') && e['completed'] == true
      ).toList();
      
      if (completedEstimates.isEmpty) {
        return AgentResult(
          agentId: metadata.id,
          success: true,
          data: {
            'total_estimates': estimates.length,
            'completed_estimates': 0,
            'overall_accuracy': 0.0,
            'average_variance': 0.0,
            'accuracy_trend': 'insufficient_data',
          },
          executionTime: DateTime.now().difference(startTime),
          timestamp: DateTime.now(),
        );
      }

      // Calculate overall statistics
      final totalAccuracy = completedEstimates
          .map((e) => e['accuracy'] as double)
          .reduce((a, b) => a + b);
      final averageAccuracy = totalAccuracy / completedEstimates.length;
      
      final totalVariance = completedEstimates
          .map((e) => (e['variance'] as int).abs())
          .reduce((a, b) => a + b);
      final averageVariance = totalVariance / completedEstimates.length;
      
      // Calculate accuracy by task type
      final accuracyByType = <String, double>{};
      final taskTypes = completedEstimates.map((e) => e['task_type'] as String).toSet();
      
      for (final taskType in taskTypes) {
        final typeEstimates = completedEstimates.where((e) => e['task_type'] == taskType).toList();
        final typeAccuracy = typeEstimates
            .map((e) => e['accuracy'] as double)
            .reduce((a, b) => a + b) / typeEstimates.length;
        accuracyByType[taskType] = typeAccuracy;
      }
      
      // Calculate trend
      final trend = _calculateAccuracyTrend(completedEstimates);
      
      return AgentResult(
        agentId: metadata.id,
        success: true,
        data: {
          'total_estimates': estimates.length,
          'completed_estimates': completedEstimates.length,
          'overall_accuracy': averageAccuracy,
          'average_variance_minutes': averageVariance,
          'accuracy_by_task_type': accuracyByType,
          'accuracy_trend': trend,
          'confidence_correlation': _calculateConfidenceCorrelation(completedEstimates),
        },
        executionTime: DateTime.now().difference(startTime),
        timestamp: DateTime.now(),
      );
    } catch (error) {
      return AgentResult(
        agentId: metadata.id,
        success: false,
        error: error.toString(),
        executionTime: DateTime.now().difference(startTime),
        timestamp: DateTime.now(),
      );
    }
  }

  /// Analyze time estimation patterns
  Future<AgentResult> _analyzeTimePatterns(ExecutionContext context) async {
    final startTime = DateTime.now();
    
    try {
      final estimates = recall<List<Map<String, dynamic>>>('estimates') ?? [];
      final completedEstimates = estimates.where((e) => 
        e.containsKey('actual_minutes')
      ).toList();
      
      if (completedEstimates.length < 5) {
        return AgentResult(
          agentId: metadata.id,
          success: true,
          data: {
            'patterns': [],
            'insights': ['Insufficient data for pattern analysis'],
            'recommendations': ['Complete more tasks to enable pattern analysis'],
          },
          executionTime: DateTime.now().difference(startTime),
          timestamp: DateTime.now(),
        );
      }

      final patterns = <String>[];
      final insights = <String>[];
      final recommendations = <String>[];
      
      // Analyze underestimation/overestimation patterns
      final underestimations = completedEstimates.where((e) => (e['variance'] as int) > 0).length;
      final overestimations = completedEstimates.where((e) => (e['variance'] as int) < 0).length;
      
      if (underestimations > completedEstimates.length * 0.7) {
        patterns.add('chronic_underestimation');
        insights.add('You consistently underestimate task duration');
        recommendations.add('Consider increasing your initial estimates by 25-50%');
      } else if (overestimations > completedEstimates.length * 0.7) {
        patterns.add('chronic_overestimation');
        insights.add('You tend to overestimate task duration');
        recommendations.add('Try to be more optimistic with your time estimates');
      }
      
      // Analyze complexity-based patterns
      final complexityPatterns = _analyzeComplexityPatterns(completedEstimates);
      patterns.addAll(complexityPatterns['patterns'] as List<String>);
      insights.addAll(complexityPatterns['insights'] as List<String>);
      recommendations.addAll(complexityPatterns['recommendations'] as List<String>);
      
      // Analyze time-of-day patterns
      final timePatterns = _analyzeTimeOfDayPatterns(completedEstimates);
      patterns.addAll(timePatterns['patterns'] as List<String>);
      insights.addAll(timePatterns['insights'] as List<String>);
      recommendations.addAll(timePatterns['recommendations'] as List<String>);
      
      return AgentResult(
        agentId: metadata.id,
        success: true,
        data: {
          'patterns': patterns,
          'insights': insights,
          'recommendations': recommendations,
          'analysis_based_on': completedEstimates.length,
        },
        executionTime: DateTime.now().difference(startTime),
        timestamp: DateTime.now(),
      );
    } catch (error) {
      return AgentResult(
        agentId: metadata.id,
        success: false,
        error: error.toString(),
        executionTime: DateTime.now().difference(startTime),
        timestamp: DateTime.now(),
      );
    }
  }

  /// Generate base estimate for a task
  int _generateBaseEstimate(String taskDescription, String complexity, String taskType) {
    // Base estimates by task type (in minutes)
    final baseEstimates = {
      'coding': {'simple': 30, 'medium': 60, 'complex': 120},
      'writing': {'simple': 20, 'medium': 45, 'complex': 90},
      'meeting': {'simple': 15, 'medium': 30, 'complex': 60},
      'research': {'simple': 25, 'medium': 60, 'complex': 180},
      'design': {'simple': 45, 'medium': 90, 'complex': 180},
      'admin': {'simple': 10, 'medium': 20, 'complex': 45},
      'planning': {'simple': 15, 'medium': 30, 'complex': 60},
      'general': {'simple': 20, 'medium': 40, 'complex': 80},
    };
    
    final typeEstimates = baseEstimates[taskType] ?? baseEstimates['general']!;
    var baseEstimate = typeEstimates[complexity] ?? typeEstimates['medium']!;
    
    // Adjust based on task description keywords
    final description = taskDescription.toLowerCase();
    
    // Complexity indicators
    if (description.contains('complex') || description.contains('difficult')) {
      baseEstimate = (baseEstimate * 1.3).round();
    }
    if (description.contains('simple') || description.contains('easy')) {
      baseEstimate = (baseEstimate * 0.8).round();
    }
    
    // Scope indicators
    if (description.contains('large') || description.contains('big') || description.contains('major')) {
      baseEstimate = (baseEstimate * 1.5).round();
    }
    if (description.contains('small') || description.contains('minor') || description.contains('quick')) {
      baseEstimate = (baseEstimate * 0.7).round();
    }
    
    return baseEstimate;
  }

  /// Apply ADHD-specific adjustments to estimate
  int _applyADHDAdjustments(int baseEstimate, String complexity, double energyLevel) {
    var adjustedEstimate = baseEstimate.toDouble();
    
    // Base ADHD multiplier
    final adhdMultiplier = metadata.config['adhd_multiplier'] as double? ?? 1.5;
    adjustedEstimate *= adhdMultiplier;
    
    // Energy level adjustment
    final energyImpact = metadata.config['energy_impact_factor'] as double? ?? 0.3;
    if (energyLevel < 0.3) {
      // Low energy - increase estimate significantly
      adjustedEstimate *= (1 + energyImpact * 1.5);
    } else if (energyLevel > 0.8) {
      // High energy - slight decrease
      adjustedEstimate *= (1 - energyImpact * 0.3);
    }
    
    // Complexity-based ADHD adjustments
    switch (complexity) {
      case 'simple':
        // Simple tasks might take longer due to procrastination
        adjustedEstimate *= 1.2;
        break;
      case 'complex':
        // Complex tasks are especially challenging for ADHD
        adjustedEstimate *= 1.4;
        break;
    }
    
    return adjustedEstimate.round();
  }

  /// Get historical adjustment factor
  Future<Map<String, dynamic>?> _getHistoricalAdjustment(String taskType, String complexity) async {
    final estimates = recall<List<Map<String, dynamic>>>('estimates') ?? [];
    
    // Find similar completed tasks
    final similarTasks = estimates.where((e) => 
      e['task_type'] == taskType && 
      e['complexity'] == complexity &&
      e.containsKey('actual_minutes') &&
      e['completed'] == true
    ).toList();
    
    if (similarTasks.length < 3) return null; // Need at least 3 data points
    
    // Calculate average variance for similar tasks
    final variances = similarTasks.map((e) => e['variance'] as int).toList();
    final averageVariance = variances.reduce((a, b) => a + b) / variances.length;
    
    // Calculate confidence based on consistency
    final varianceStdDev = _calculateStandardDeviation(variances.map((v) => v.toDouble()).toList());
    final confidence = (1 / (1 + varianceStdDev / 30)).clamp(0.0, 1.0); // Normalize by 30 minutes
    
    return {
      'average_variance': averageVariance,
      'confidence': confidence,
      'sample_size': similarTasks.length,
    };
  }

  /// Apply historical adjustment to estimate
  int _applyHistoricalAdjustment(int estimate, Map<String, dynamic>? historicalData) {
    if (historicalData == null) return estimate;
    
    final averageVariance = historicalData['average_variance'] as double;
    final confidence = historicalData['confidence'] as double;
    final historicalWeight = metadata.config['historical_weight'] as double? ?? 0.6;
    
    // Apply weighted adjustment
    final adjustment = averageVariance * confidence * historicalWeight;
    return (estimate + adjustment).round();
  }

  /// Calculate confidence level for estimate
  double _calculateConfidence(String taskType, String complexity, Map<String, dynamic>? historicalData) {
    var confidence = 0.5; // Base confidence
    
    // Adjust based on task type familiarity
    final taskTypeFamiliarity = {
      'coding': 0.8,
      'writing': 0.7,
      'meeting': 0.9,
      'research': 0.6,
      'design': 0.7,
      'admin': 0.8,
      'planning': 0.7,
      'general': 0.5,
    };
    
    confidence = taskTypeFamiliarity[taskType] ?? 0.5;
    
    // Adjust based on complexity
    switch (complexity) {
      case 'simple':
        confidence += 0.2;
        break;
      case 'complex':
        confidence -= 0.2;
        break;
    }
    
    // Adjust based on historical data
    if (historicalData != null) {
      final historicalConfidence = historicalData['confidence'] as double;
      confidence = (confidence + historicalConfidence) / 2;
    } else {
      confidence -= 0.1; // Reduce confidence without historical data
    }
    
    return confidence.clamp(0.0, 1.0);
  }

  /// Generate estimate breakdown
  Map<String, dynamic> _generateEstimateBreakdown(int baseEstimate, int adhdAdjusted, int finalEstimate) {
    return {
      'base_estimate': baseEstimate,
      'adhd_adjusted': adhdAdjusted,
      'final_estimate': finalEstimate,
      'adjustments': {
        'adhd_factor': adhdAdjusted - baseEstimate,
        'historical_factor': finalEstimate - adhdAdjusted,
      },
    };
  }

  /// Generate recommendations based on estimate
  List<String> _generateRecommendations(int estimateMinutes, double confidence, double energyLevel) {
    final recommendations = <String>[];
    
    // Time-based recommendations
    if (estimateMinutes > 120) {
      recommendations.add('Consider breaking this task into smaller chunks');
      recommendations.add('Plan for breaks every 45-60 minutes');
    } else if (estimateMinutes > 60) {
      recommendations.add('Plan for a break halfway through');
    }
    
    // Confidence-based recommendations
    if (confidence < 0.6) {
      recommendations.add('This estimate has low confidence - add buffer time');
      recommendations.add('Consider doing a quick task breakdown first');
    }
    
    // Energy-based recommendations
    if (energyLevel < 0.3) {
      recommendations.add('Your energy is low - this might take longer than estimated');
      recommendations.add('Consider tackling this when your energy is higher');
    } else if (energyLevel > 0.8) {
      recommendations.add('Your energy is high - you might complete this faster');
    }
    
    // ADHD-specific recommendations
    recommendations.add('Set a timer to stay aware of time passing');
    recommendations.add('Prepare your workspace to minimize distractions');
    
    return recommendations;
  }

  /// Calculate context switching overhead for multiple tasks
  int _calculateContextSwitchingOverhead(int taskCount) {
    if (taskCount <= 1) return 0;
    
    // ADHD users have higher context switching costs
    const baseOverheadPerSwitch = 10; // minutes
    const adhdMultiplier = 1.5;
    
    final switches = taskCount - 1;
    return (switches * baseOverheadPerSwitch * adhdMultiplier).round();
  }

  /// Generate recommendations for multiple tasks
  List<String> _generateMultiTaskRecommendations(List<Map<String, dynamic>> estimates, int totalEstimate) {
    final recommendations = <String>[];
    
    if (estimates.length > 3) {
      recommendations.add('Consider grouping similar tasks together');
      recommendations.add('Plan for significant context switching time');
    }
    
    if (totalEstimate > 240) { // 4+ hours
      recommendations.add('This is a full day\'s work - plan accordingly');
      recommendations.add('Schedule longer breaks between task groups');
    }
    
    // Check for low confidence tasks
    final lowConfidenceTasks = estimates.where((e) => 
      (e['confidence_level'] as double) < 0.6
    ).length;
    
    if (lowConfidenceTasks > 0) {
      recommendations.add('$lowConfidenceTasks tasks have low confidence - add extra buffer time');
    }
    
    recommendations.add('Consider tackling high-energy tasks when you\'re most alert');
    recommendations.add('Group similar task types to reduce context switching');
    
    return recommendations;
  }

  /// Store estimate for learning
  void _storeEstimate(String taskDescription, String taskType, String complexity, 
                     int estimate, double confidence, ExecutionContext context) {
    final estimateId = DateTime.now().millisecondsSinceEpoch.toString();
    
    final estimateData = {
      'id': estimateId,
      'task_description': taskDescription,
      'task_type': taskType,
      'complexity': complexity,
      'estimate_minutes': estimate,
      'confidence_level': confidence,
      'context': context.toJson(),
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    final estimates = recall<List<Map<String, dynamic>>>('estimates') ?? [];
    estimates.add(estimateData);
    
    // Keep only last 500 estimates
    if (estimates.length > 500) {
      estimates.removeRange(0, estimates.length - 500);
    }
    
    remember('estimates', estimates);
  }

  /// Learn from actual time data
  void _learnFromActualTime(Map<String, dynamic> estimate, int actualMinutes, 
                           bool completed, int interruptions) {
    if (!metadata.config['learning_enabled'] as bool? ?? true) return;
    
    final learningData = {
      'estimate_data': estimate,
      'actual_minutes': actualMinutes,
      'completed': completed,
      'interruptions': interruptions,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    final learningHistory = recall<List<Map<String, dynamic>>>('learning_history') ?? [];
    learningHistory.add(learningData);
    
    if (learningHistory.length > 200) {
      learningHistory.removeRange(0, learningHistory.length - 200);
    }
    
    remember('learning_history', learningHistory);
    
    // Update task type adjustments
    _updateTaskTypeAdjustments(estimate, actualMinutes, completed);
  }

  /// Update task type adjustments based on learning
  void _updateTaskTypeAdjustments(Map<String, dynamic> estimate, int actualMinutes, bool completed) {
    if (!completed) return; // Only learn from completed tasks
    
    final taskType = estimate['task_type'] as String;
    final complexity = estimate['complexity'] as String;
    final estimatedMinutes = estimate['estimate_minutes'] as int;
    
    final variance = actualMinutes - estimatedMinutes;
    final key = '${taskType}_$complexity';
    
    final adjustments = recall<Map<String, double>>('task_type_adjustments') ?? {};
    final currentAdjustment = adjustments[key] ?? 0.0;
    
    // Use exponential moving average for learning
    const learningRate = 0.1;
    adjustments[key] = currentAdjustment + (variance * learningRate);
    
    remember('task_type_adjustments', adjustments);
  }

  /// Calculate accuracy between estimated and actual time
  double _calculateAccuracy(int estimated, int actual) {
    if (estimated == 0) return 0.0;
    
    final error = (estimated - actual).abs();
    final accuracy = 1.0 - (error / estimated);
    
    return accuracy.clamp(0.0, 1.0);
  }

  /// Calculate accuracy trend over time
  String _calculateAccuracyTrend(List<Map<String, dynamic>> completedEstimates) {
    if (completedEstimates.length < 10) return 'insufficient_data';
    
    // Sort by timestamp
    completedEstimates.sort((a, b) => 
      DateTime.parse(a['timestamp'] as String)
          .compareTo(DateTime.parse(b['timestamp'] as String))
    );
    
    // Compare first half vs second half
    final midpoint = completedEstimates.length ~/ 2;
    final firstHalf = completedEstimates.take(midpoint);
    final secondHalf = completedEstimates.skip(midpoint);
    
    final firstHalfAccuracy = firstHalf
        .map((e) => e['accuracy'] as double)
        .reduce((a, b) => a + b) / firstHalf.length;
    
    final secondHalfAccuracy = secondHalf
        .map((e) => e['accuracy'] as double)
        .reduce((a, b) => a + b) / secondHalf.length;
    
    final improvement = secondHalfAccuracy - firstHalfAccuracy;
    
    if (improvement > 0.1) return 'improving';
    if (improvement < -0.1) return 'declining';
    return 'stable';
  }

  /// Calculate correlation between confidence and accuracy
  double _calculateConfidenceCorrelation(List<Map<String, dynamic>> completedEstimates) {
    if (completedEstimates.length < 5) return 0.0;
    
    final confidences = completedEstimates.map((e) => e['confidence_level'] as double).toList();
    final accuracies = completedEstimates.map((e) => e['accuracy'] as double).toList();
    
    return _calculateCorrelation(confidences, accuracies);
  }

  /// Analyze complexity-based patterns
  Map<String, List<String>> _analyzeComplexityPatterns(List<Map<String, dynamic>> completedEstimates) {
    final patterns = <String>[];
    final insights = <String>[];
    final recommendations = <String>[];
    
    // Group by complexity
    final complexityGroups = <String, List<Map<String, dynamic>>>{};
    for (final estimate in completedEstimates) {
      final complexity = estimate['complexity'] as String;
      complexityGroups[complexity] = (complexityGroups[complexity] ?? [])..add(estimate);
    }
    
    // Analyze each complexity level
    for (final entry in complexityGroups.entries) {
      final complexity = entry.key;
      final estimates = entry.value;
      
      if (estimates.length < 3) continue;
      
      final averageAccuracy = estimates
          .map((e) => e['accuracy'] as double)
          .reduce((a, b) => a + b) / estimates.length;
      
      if (averageAccuracy < 0.6) {
        patterns.add('${complexity}_complexity_issues');
        insights.add('You struggle with time estimation for $complexity tasks');
        recommendations.add('Add extra buffer time for $complexity tasks');
      }
    }
    
    return {
      'patterns': patterns,
      'insights': insights,
      'recommendations': recommendations,
    };
  }

  /// Analyze time-of-day patterns
  Map<String, List<String>> _analyzeTimeOfDayPatterns(List<Map<String, dynamic>> completedEstimates) {
    final patterns = <String>[];
    final insights = <String>[];
    final recommendations = <String>[];
    
    // Group by hour of day
    final hourGroups = <int, List<Map<String, dynamic>>>{};
    for (final estimate in completedEstimates) {
      final timestamp = DateTime.parse(estimate['timestamp'] as String);
      final hour = timestamp.hour;
      hourGroups[hour] = (hourGroups[hour] ?? [])..add(estimate);
    }
    
    // Find patterns
    var bestHour = -1;
    var bestAccuracy = 0.0;
    var worstHour = -1;
    var worstAccuracy = 1.0;
    
    for (final entry in hourGroups.entries) {
      final hour = entry.key;
      final estimates = entry.value;
      
      if (estimates.length < 2) continue;
      
      final averageAccuracy = estimates
          .map((e) => e['accuracy'] as double)
          .reduce((a, b) => a + b) / estimates.length;
      
      if (averageAccuracy > bestAccuracy) {
        bestAccuracy = averageAccuracy;
        bestHour = hour;
      }
      
      if (averageAccuracy < worstAccuracy) {
        worstAccuracy = averageAccuracy;
        worstHour = hour;
      }
    }
    
    if (bestHour != -1 && worstHour != -1) {
      patterns.add('time_of_day_variation');
      insights.add('Your estimation accuracy varies by time of day');
      recommendations.add('Schedule important tasks around $bestHour:00 when you estimate best');
      
      if (worstAccuracy < 0.5) {
        recommendations.add('Be extra careful with estimates around $worstHour:00');
      }
    }
    
    return {
      'patterns': patterns,
      'insights': insights,
      'recommendations': recommendations,
    };
  }

  /// Calculate standard deviation
  double _calculateStandardDeviation(List<double> values) {
    if (values.isEmpty) return 0.0;
    
    final mean = values.reduce((a, b) => a + b) / values.length;
    final squaredDifferences = values.map((v) => pow(v - mean, 2));
    final variance = squaredDifferences.reduce((a, b) => a + b) / values.length;
    
    return sqrt(variance);
  }

  /// Calculate correlation between two lists
  double _calculateCorrelation(List<double> x, List<double> y) {
    if (x.length != y.length || x.isEmpty) return 0.0;
    
    final n = x.length;
    final meanX = x.reduce((a, b) => a + b) / n;
    final meanY = y.reduce((a, b) => a + b) / n;
    
    var numerator = 0.0;
    var sumXSquared = 0.0;
    var sumYSquared = 0.0;
    
    for (int i = 0; i < n; i++) {
      final xDiff = x[i] - meanX;
      final yDiff = y[i] - meanY;
      
      numerator += xDiff * yDiff;
      sumXSquared += xDiff * xDiff;
      sumYSquared += yDiff * yDiff;
    }
    
    final denominator = sqrt(sumXSquared * sumYSquared);
    
    return denominator != 0 ? numerator / denominator : 0.0;
  }

  @override
  Map<String, dynamic> getMetrics() {
    final baseMetrics = super.getMetrics();
    final estimates = recall<List<Map<String, dynamic>>>('estimates') ?? [];
    final completedEstimates = estimates.where((e) => 
      e.containsKey('actual_minutes') && e['completed'] == true
    ).toList();
    
    final totalAccuracy = completedEstimates.isNotEmpty
        ? completedEstimates.map((e) => e['accuracy'] as double).reduce((a, b) => a + b) / completedEstimates.length
        : 0.0;
    
    return {
      ...baseMetrics,
      'total_estimates': estimates.length,
      'completed_estimates': completedEstimates.length,
      'overall_accuracy': totalAccuracy,
      'learning_data_points': recall<List<Map<String, dynamic>>>('learning_history')?.length ?? 0,
      'task_type_adjustments': recall<Map<String, double>>('task_type_adjustments')?.length ?? 0,
    };
  }
}