import 'dart:async';
import 'dart:math';
import '../models/agent_model.dart';
import 'base/reactive_agent.dart';

/// Agent that helps reduce decision paralysis for ADHD users
class DecisionHelperAgent extends ReactiveAgent {
  static const String agentId = 'decision_helper';

  DecisionHelperAgent()
      : super(
          Agent(
            id: agentId,
            name: 'Decision Helper Agent',
            description:
                'Reduces decision paralysis by simplifying choices and providing structured decision-making',
            type: AgentType.reactive,
            capabilities: const AgentCapabilities(
              canExecuteParallel: true,
              canBeInterrupted: true,
              canInterruptOthers: false,
              requiresUserInput: true,
              hasMemory: true,
              canLearn: true,
              inputTypes: [
                'decision_request',
                'options_list',
                'criteria',
                'preferences'
              ],
              outputTypes: [
                'simplified_options',
                'recommendation',
                'decision_framework'
              ],
              maxExecutionTime: Duration(minutes: 2),
              maxConcurrentInstances: 3,
            ),
            lastActive: DateTime.now(),
            config: {
              'max_options': 3,
              'decision_timeout': 300, // 5 minutes
              'learning_enabled': true,
              'auto_simplify': true,
            },
          ),
        );

  @override
  Future<AgentResult> processRequest(ExecutionContext context) async {
    final requestType = context.parameters['type'] as String? ?? 'help_decide';

    switch (requestType) {
      case 'help_decide':
        return await _helpMakeDecision(context);
      case 'simplify_options':
        return await _simplifyOptions(context);
      case 'detect_paralysis':
        return await _detectDecisionParalysis(context);
      case 'provide_framework':
        return await _provideDecisionFramework(context);
      case 'quick_decide':
        return await _makeQuickDecision(context);
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

  /// Help user make a decision
  Future<AgentResult> _helpMakeDecision(ExecutionContext context) async {
    final startTime = DateTime.now();

    try {
      final options = context.parameters['options'] as List<dynamic>? ?? [];
      final criteria = context.parameters['criteria'] as List<dynamic>? ?? [];
      final decisionType =
          context.parameters['decision_type'] as String? ?? 'general';

      if (options.isEmpty) {
        return AgentResult(
          agentId: metadata.id,
          success: false,
          error: 'No options provided for decision',
          executionTime: DateTime.now().difference(startTime),
          timestamp: DateTime.now(),
        );
      }

      // Detect if user is experiencing decision paralysis
      final paralysisLevel =
          await _assessDecisionParalysis(context, options.length);

      Map<String, dynamic> result;

      if (paralysisLevel > 0.7) {
        // High paralysis - use emergency simplification
        result =
            await _emergencySimplification(options, criteria, decisionType);
      } else if (paralysisLevel > 0.4) {
        // Moderate paralysis - use structured approach
        result =
            await _structuredDecisionMaking(options, criteria, decisionType);
      } else {
        // Low paralysis - provide gentle guidance
        result = await _gentleDecisionGuidance(options, criteria, decisionType);
      }

      // Learn from this decision process
      _learnFromDecision(context, result, paralysisLevel);

      return AgentResult(
        agentId: metadata.id,
        success: true,
        data: result,
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

  /// Simplify a list of options
  Future<AgentResult> _simplifyOptions(ExecutionContext context) async {
    final startTime = DateTime.now();

    try {
      final options = context.parameters['options'] as List<dynamic>? ?? [];
      final maxOptions = context.parameters['max_options'] as int? ??
          (metadata.config['max_options'] as int? ?? 3);

      final simplifiedOptions =
          await _performOptionSimplification(options, maxOptions);

      return AgentResult(
        agentId: metadata.id,
        success: true,
        data: {
          'original_count': options.length,
          'simplified_count': simplifiedOptions.length,
          'simplified_options': simplifiedOptions,
          'simplification_method': 'priority_based',
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

  /// Detect decision paralysis patterns
  Future<AgentResult> _detectDecisionParalysis(ExecutionContext context) async {
    final startTime = DateTime.now();

    try {
      final decisionHistory =
          recall<List<Map<String, dynamic>>>('decision_history') ?? [];
      final currentOptions =
          context.parameters['options'] as List<dynamic>? ?? [];

      final paralysisLevel =
          await _assessDecisionParalysis(context, currentOptions.length);
      final patterns = _analyzeParalysisPatterns(decisionHistory);

      return AgentResult(
        agentId: metadata.id,
        success: true,
        data: {
          'paralysis_level': paralysisLevel,
          'patterns': patterns,
          'recommendations':
              _getParalysisRecommendations(paralysisLevel, patterns),
          'triggers': _identifyParalysisTriggers(context, patterns),
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

  /// Provide decision-making framework
  Future<AgentResult> _provideDecisionFramework(
      ExecutionContext context) async {
    final startTime = DateTime.now();

    try {
      final decisionType =
          context.parameters['decision_type'] as String? ?? 'general';
      final complexity =
          context.parameters['complexity'] as String? ?? 'medium';

      final framework = _getDecisionFramework(decisionType, complexity);

      return AgentResult(
        agentId: metadata.id,
        success: true,
        data: framework,
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

  /// Make a quick decision for the user
  Future<AgentResult> _makeQuickDecision(ExecutionContext context) async {
    final startTime = DateTime.now();

    try {
      final options = context.parameters['options'] as List<dynamic>? ?? [];
      final criteria = context.parameters['criteria'] as List<dynamic>? ?? [];

      if (options.isEmpty) {
        return AgentResult(
          agentId: metadata.id,
          success: false,
          error: 'No options provided for quick decision',
          executionTime: DateTime.now().difference(startTime),
          timestamp: DateTime.now(),
        );
      }

      final decision = await _performQuickDecision(options, criteria, context);

      return AgentResult(
        agentId: metadata.id,
        success: true,
        data: decision,
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

  /// Assess level of decision paralysis
  Future<double> _assessDecisionParalysis(
      ExecutionContext context, int optionCount) async {
    double paralysisScore = 0.0;

    // Factor 1: Number of options (more options = higher paralysis)
    if (optionCount > 10) {
      paralysisScore += 0.4;
    } else if (optionCount > 5) {
      paralysisScore += 0.2;
    } else if (optionCount > 3) {
      paralysisScore += 0.1;
    }

    // Factor 2: Time spent on decision
    final decisionStartTime =
        context.parameters['decision_start_time'] as DateTime?;
    if (decisionStartTime != null) {
      final timeSpent = DateTime.now().difference(decisionStartTime);
      if (timeSpent.inMinutes > 30) {
        paralysisScore += 0.3;
      } else if (timeSpent.inMinutes > 10) {
        paralysisScore += 0.2;
      } else if (timeSpent.inMinutes > 5) {
        paralysisScore += 0.1;
      }
    }

    // Factor 3: User's historical paralysis patterns
    final history =
        recall<List<Map<String, dynamic>>>('decision_history') ?? [];
    if (history.isNotEmpty) {
      final recentParalysis = history
          .take(10)
          .where((d) => (d['paralysis_level'] as double? ?? 0.0) > 0.5)
          .length;
      paralysisScore += (recentParalysis / 10) * 0.2;
    }

    // Factor 4: Current stress/energy level
    final energyLevel = context.userState['energy_level'] as double? ?? 0.5;
    if (energyLevel < 0.3) paralysisScore += 0.2;

    // Factor 5: Decision importance
    final importance = context.parameters['importance'] as String? ?? 'medium';
    if (importance == 'high') paralysisScore += 0.1;

    return paralysisScore.clamp(0.0, 1.0);
  }

  /// Emergency simplification for high paralysis
  Future<Map<String, dynamic>> _emergencySimplification(List<dynamic> options,
      List<dynamic> criteria, String decisionType) async {
    // Reduce to maximum 2 options using simple heuristics
    final simplified = options.take(2).toList();

    return {
      'method': 'emergency_simplification',
      'simplified_options': simplified,
      'recommendation': simplified.first,
      'reasoning': 'Reduced to top 2 options to break decision paralysis',
      'next_steps': [
        'Choose between these 2 options only',
        'Set a 5-minute timer to decide',
        'Remember: any decision is better than no decision',
      ],
      'confidence': 0.7,
    };
  }

  /// Structured decision making for moderate paralysis
  Future<Map<String, dynamic>> _structuredDecisionMaking(List<dynamic> options,
      List<dynamic> criteria, String decisionType) async {
    final maxOptions = metadata.config['max_options'] as int? ?? 3;
    final simplified = await _performOptionSimplification(options, maxOptions);

    // Score options based on criteria
    final scoredOptions = <Map<String, dynamic>>[];
    for (final option in simplified) {
      final score = _scoreOption(option, criteria);
      scoredOptions.add({
        'option': option,
        'score': score,
        'pros': _getOptionPros(option, criteria),
        'cons': _getOptionCons(option, criteria),
      });
    }

    // Sort by score
    scoredOptions
        .sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));

    return {
      'method': 'structured_decision',
      'simplified_options': scoredOptions,
      'recommendation': scoredOptions.first['option'],
      'reasoning': 'Top-scored option based on your criteria',
      'decision_matrix': scoredOptions,
      'next_steps': [
        'Review the top option',
        'Consider the pros and cons',
        'Make a decision within 10 minutes',
      ],
      'confidence': 0.8,
    };
  }

  /// Gentle decision guidance for low paralysis
  Future<Map<String, dynamic>> _gentleDecisionGuidance(List<dynamic> options,
      List<dynamic> criteria, String decisionType) async {
    return {
      'method': 'gentle_guidance',
      'options': options,
      'suggestions': [
        'Take your time to consider each option',
        'Think about your long-term goals',
        'Consider which option aligns with your values',
        'Trust your instincts',
      ],
      'framework': _getDecisionFramework(decisionType, 'medium'),
      'confidence': 0.6,
    };
  }

  /// Perform option simplification
  Future<List<dynamic>> _performOptionSimplification(
      List<dynamic> options, int maxOptions) async {
    if (options.length <= maxOptions) return options;

    // Simple heuristic: take first maxOptions (could be enhanced with ML)
    // In a real implementation, this would use more sophisticated ranking
    return options.take(maxOptions).toList();
  }

  /// Score an option based on criteria
  double _scoreOption(dynamic option, List<dynamic> criteria) {
    // Simple scoring - in real implementation would be more sophisticated
    return Random().nextDouble(); // Placeholder
  }

  /// Get pros for an option
  List<String> _getOptionPros(dynamic option, List<dynamic> criteria) {
    // Placeholder - would analyze option against criteria
    return ['Quick to implement', 'Low risk', 'Aligns with goals'];
  }

  /// Get cons for an option
  List<String> _getOptionCons(dynamic option, List<dynamic> criteria) {
    // Placeholder - would analyze option against criteria
    return ['Requires more time', 'Higher cost'];
  }

  /// Perform quick decision
  Future<Map<String, dynamic>> _performQuickDecision(List<dynamic> options,
      List<dynamic> criteria, ExecutionContext context) async {
    // For ADHD users, sometimes any decision is better than no decision
    final randomChoice = options[Random().nextInt(options.length)];

    return {
      'method': 'quick_decision',
      'chosen_option': randomChoice,
      'reasoning': 'Quick decision to break analysis paralysis',
      'confidence': 0.5,
      'note':
          'This is a quick decision to help you move forward. You can always adjust later.',
    };
  }

  /// Analyze paralysis patterns
  Map<String, dynamic> _analyzeParalysisPatterns(
      List<Map<String, dynamic>> history) {
    if (history.isEmpty) return {'patterns': [], 'insights': []};

    final patterns = <String>[];
    final insights = <String>[];

    // Analyze common triggers
    final highParalysisDecisions = history
        .where((d) => (d['paralysis_level'] as double? ?? 0.0) > 0.7)
        .toList();

    if (highParalysisDecisions.length > history.length * 0.3) {
      patterns.add('frequent_paralysis');
      insights.add('You experience decision paralysis frequently');
    }

    // Analyze decision types that cause paralysis
    final paralysisTypes = <String, int>{};
    for (final decision in highParalysisDecisions) {
      final type = decision['decision_type'] as String? ?? 'general';
      paralysisTypes[type] = (paralysisTypes[type] ?? 0) + 1;
    }

    if (paralysisTypes.isNotEmpty) {
      final mostProblematic =
          paralysisTypes.entries.reduce((a, b) => a.value > b.value ? a : b);
      patterns.add('type_specific_paralysis');
      insights.add('${mostProblematic.key} decisions often cause paralysis');
    }

    return {
      'patterns': patterns,
      'insights': insights,
      'paralysis_frequency': highParalysisDecisions.length / history.length,
    };
  }

  /// Get recommendations for paralysis level
  List<String> _getParalysisRecommendations(
      double paralysisLevel, Map<String, dynamic> patterns) {
    final recommendations = <String>[];

    if (paralysisLevel > 0.7) {
      recommendations.addAll([
        'Use the 2-option rule: narrow down to just 2 choices',
        'Set a strict time limit (5-10 minutes)',
        'Remember: done is better than perfect',
        'Consider the "good enough" option',
      ]);
    } else if (paralysisLevel > 0.4) {
      recommendations.addAll([
        'Use a decision matrix to compare options',
        'List pros and cons for each option',
        'Consider your long-term goals',
        'Ask: "What would I regret not trying?"',
      ]);
    } else {
      recommendations.addAll([
        'Take time to reflect on your values',
        'Consider seeking input from trusted friends',
        'Think about potential outcomes',
        'Trust your intuition',
      ]);
    }

    return recommendations;
  }

  /// Identify paralysis triggers
  List<String> _identifyParalysisTriggers(
      ExecutionContext context, Map<String, dynamic> patterns) {
    final triggers = <String>[];

    // Check for common ADHD paralysis triggers
    final optionCount = context.parameters['options']?.length ?? 0;
    if (optionCount > 5) triggers.add('too_many_options');

    final importance = context.parameters['importance'] as String? ?? 'medium';
    if (importance == 'high') triggers.add('high_stakes');

    final energyLevel = context.userState['energy_level'] as double? ?? 0.5;
    if (energyLevel < 0.3) triggers.add('low_energy');

    if (patterns['patterns']?.contains('frequent_paralysis') == true) {
      triggers.add('chronic_pattern');
    }

    return triggers;
  }

  /// Get decision framework based on type and complexity
  Map<String, dynamic> _getDecisionFramework(
      String decisionType, String complexity) {
    final frameworks = {
      'general': {
        'simple': {
          'steps': [
            'List your options',
            'Identify what matters most',
            'Choose the best fit',
            'Act on your decision',
          ],
          'time_limit': '10 minutes',
        },
        'medium': {
          'steps': [
            'Define the decision clearly',
            'List all viable options',
            'Identify decision criteria',
            'Evaluate each option',
            'Make your choice',
            'Plan implementation',
          ],
          'time_limit': '30 minutes',
        },
        'complex': {
          'steps': [
            'Break down the decision',
            'Research thoroughly',
            'Consult stakeholders',
            'Use decision tools',
            'Consider long-term impact',
            'Make informed choice',
            'Create action plan',
          ],
          'time_limit': '2 hours',
        },
      },
    };

    return frameworks[decisionType]?[complexity] ??
        frameworks['general']!['medium']!;
  }

  /// Learn from decision process
  void _learnFromDecision(ExecutionContext context, Map<String, dynamic> result,
      double paralysisLevel) {
    final history =
        recall<List<Map<String, dynamic>>>('decision_history') ?? [];

    history.add({
      'context': context.toJson(),
      'result': result,
      'paralysis_level': paralysisLevel,
      'timestamp': DateTime.now().toIso8601String(),
      'decision_type': context.parameters['decision_type'] ?? 'general',
      'option_count': context.parameters['options']?.length ?? 0,
    });

    // Keep only last 100 decisions
    if (history.length > 100) {
      history.removeRange(0, history.length - 100);
    }

    remember('decision_history', history);
  }

  @override
  Map<String, dynamic> getMetrics() {
    final baseMetrics = super.getMetrics();
    final history =
        recall<List<Map<String, dynamic>>>('decision_history') ?? [];

    final avgParalysis = history.isNotEmpty
        ? history
                .map((d) => d['paralysis_level'] as double? ?? 0.0)
                .reduce((a, b) => a + b) /
            history.length
        : 0.0;

    return {
      ...baseMetrics,
      'total_decisions_helped': history.length,
      'average_paralysis_level': avgParalysis,
      'high_paralysis_decisions': history
          .where((d) => (d['paralysis_level'] as double? ?? 0.0) > 0.7)
          .length,
      'decision_types': _getDecisionTypeBreakdown(history),
    };
  }

  Map<String, int> _getDecisionTypeBreakdown(
      List<Map<String, dynamic>> history) {
    final breakdown = <String, int>{};
    for (final decision in history) {
      final type = decision['decision_type'] as String? ?? 'general';
      breakdown[type] = (breakdown[type] ?? 0) + 1;
    }
    return breakdown;
  }
}
