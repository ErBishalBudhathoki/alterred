import 'dart:async';
import '../models/agent_model.dart';
import 'base/proactive_agent.dart';

/// Agent that monitors and assesses user energy levels for ADHD management
class EnergyAssessmentAgent extends ProactiveAgent {
  static const String agentId = 'energy_assessment';

  EnergyAssessmentAgent()
      : super(
          Agent(
            id: agentId,
            name: 'Energy Assessment Agent',
            description:
                'Monitors user energy levels, sleep patterns, and mood for optimal task planning',
            type: AgentType.proactive,
            capabilities: const AgentCapabilities(
              canExecuteParallel: true,
              canBeInterrupted: false,
              canInterruptOthers: false,
              requiresUserInput: false,
              hasMemory: true,
              canLearn: true,
              inputTypes: [
                'sleep_data',
                'mood_input',
                'activity_data',
                'biometric_data'
              ],
              outputTypes: ['energy_level', 'recommendations', 'insights'],
              maxExecutionTime: Duration(seconds: 30),
              maxConcurrentInstances: 1,
            ),
            lastActive: DateTime.now(),
            config: {
              'auto_start_monitoring': true,
              'assessment_frequency': 'hourly',
              'learning_enabled': true,
              'biometric_integration': false,
            },
          ),
          monitoringInterval: const Duration(minutes: 30),
        );

  @override
  Future<List<MonitoringCondition>> checkConditions(
      ExecutionContext context) async {
    final conditions = <MonitoringCondition>[];
    final now = DateTime.now();

    // Check for energy level changes
    final currentEnergy = await _assessCurrentEnergyLevel(context);
    final previousEnergy = recall<double>('last_energy_level') ?? 0.5;

    // Significant energy drop
    if (currentEnergy < previousEnergy - 0.3) {
      conditions.add(MonitoringCondition(
        id: 'energy_drop',
        name: 'Significant Energy Drop',
        description: 'User energy has dropped significantly',
        shouldTrigger: true,
        data: {
          'current_energy': currentEnergy,
          'previous_energy': previousEnergy,
          'drop_amount': previousEnergy - currentEnergy,
        },
        priority: ExecutionPriority.high,
        cooldown: const Duration(hours: 1),
        lastTriggered: recall<DateTime>('last_energy_drop_trigger'),
      ));
    }

    // Low energy warning
    if (currentEnergy < 0.3) {
      conditions.add(MonitoringCondition(
        id: 'low_energy',
        name: 'Low Energy Warning',
        description: 'User energy is critically low',
        shouldTrigger: true,
        data: {
          'energy_level': currentEnergy,
          'recommendations': _getLowEnergyRecommendations(),
        },
        priority: ExecutionPriority.high,
        cooldown: const Duration(hours: 2),
        lastTriggered: recall<DateTime>('last_low_energy_trigger'),
      ));
    }

    // Peak energy opportunity
    if (currentEnergy > 0.8 && previousEnergy < 0.7) {
      conditions.add(MonitoringCondition(
        id: 'peak_energy',
        name: 'Peak Energy Opportunity',
        description: 'User energy is at peak levels',
        shouldTrigger: true,
        data: {
          'energy_level': currentEnergy,
          'recommendations': _getPeakEnergyRecommendations(),
        },
        priority: ExecutionPriority.normal,
        cooldown: const Duration(hours: 3),
        lastTriggered: recall<DateTime>('last_peak_energy_trigger'),
      ));
    }

    // Circadian rhythm check
    final circadianCondition = await _checkCircadianRhythm(context, now);
    if (circadianCondition != null) {
      conditions.add(circadianCondition);
    }

    // Store current energy for next check
    remember('last_energy_level', currentEnergy);
    remember('last_assessment_time', now);

    return conditions;
  }

  @override
  Future<void> onConditionTriggered(
      MonitoringCondition condition, ExecutionContext context) async {
    switch (condition.id) {
      case 'energy_drop':
        await _handleEnergyDrop(condition, context);
        break;
      case 'low_energy':
        await _handleLowEnergy(condition, context);
        break;
      case 'peak_energy':
        await _handlePeakEnergy(condition, context);
        break;
      case 'circadian_mismatch':
        await _handleCircadianMismatch(condition, context);
        break;
    }

    // Update trigger timestamp
    remember('last_${condition.id}_trigger', DateTime.now());
  }

  /// Assess current energy level based on multiple factors
  Future<double> _assessCurrentEnergyLevel(ExecutionContext context) async {
    double energyScore = 0.5; // Base energy level
    // int factorCount = 0; // Unused

    // Time of day factor
    final timeOfDay = DateTime.now().hour;
    final timeEnergy = _getTimeOfDayEnergyFactor(timeOfDay);
    energyScore += timeEnergy * 0.3;
    // factorCount++; // Unused

    // Sleep quality factor (if available)
    final sleepQuality = context.userState['sleep_quality'] as double?;
    if (sleepQuality != null) {
      energyScore += sleepQuality * 0.4;
      // factorCount++; // Unused
    }

    // Recent activity factor
    final recentActivity = context.userState['recent_activity'] as String?;
    if (recentActivity != null) {
      final activityEnergy = _getActivityEnergyImpact(recentActivity);
      energyScore += activityEnergy * 0.2;
      // factorCount++; // Unused
    }

    // Mood factor
    final mood = context.userState['mood'] as double?;
    if (mood != null) {
      energyScore += (mood - 0.5) * 0.3;
      // factorCount++; // Unused
    }

    // Historical pattern learning
    final historicalPattern = await _getHistoricalEnergyPattern();
    if (historicalPattern != null) {
      energyScore += historicalPattern * 0.2;
      // factorCount++; // Unused
    }

    // Normalize score
    energyScore = energyScore.clamp(0.0, 1.0);

    // Store assessment details
    remember('last_energy_assessment', {
      'score': energyScore,
      'factors': {
        'time_of_day': timeEnergy,
        'sleep_quality': sleepQuality,
        'recent_activity': recentActivity,
        'mood': mood,
        'historical_pattern': historicalPattern,
      },
      'timestamp': DateTime.now().toIso8601String(),
    });

    return energyScore;
  }

  /// Get energy factor based on time of day
  double _getTimeOfDayEnergyFactor(int hour) {
    // ADHD-typical energy patterns
    if (hour >= 6 && hour <= 9) return 0.7; // Morning moderate
    if (hour >= 10 && hour <= 12) return 0.9; // Late morning peak
    if (hour >= 13 && hour <= 15) return 0.4; // Afternoon dip
    if (hour >= 16 && hour <= 18) return 0.8; // Evening peak
    if (hour >= 19 && hour <= 21) return 0.6; // Evening moderate
    return 0.3; // Night/early morning low
  }

  /// Get energy impact of recent activity
  double _getActivityEnergyImpact(String activity) {
    switch (activity.toLowerCase()) {
      case 'exercise':
        return 0.3; // Energizing but depleting
      case 'meeting':
        return -0.2; // Draining
      case 'creative_work':
        return 0.1; // Slightly energizing
      case 'admin_tasks':
        return -0.3; // Very draining
      case 'break':
        return 0.2; // Restorative
      case 'social_interaction':
        return -0.1; // Mildly draining
      default:
        return 0.0;
    }
  }

  /// Get historical energy pattern for current time
  Future<double?> _getHistoricalEnergyPattern() async {
    final historicalData =
        recall<List<Map<String, dynamic>>>('energy_history') ?? [];
    if (historicalData.isEmpty) return null;

    final currentHour = DateTime.now().hour;
    final relevantData = historicalData.where((data) {
      final timestamp = DateTime.parse(data['timestamp'] as String);
      return timestamp.hour == currentHour;
    }).toList();

    if (relevantData.isEmpty) return null;

    final averageEnergy = relevantData
            .map((data) => data['energy_level'] as double)
            .reduce((a, b) => a + b) /
        relevantData.length;

    return averageEnergy;
  }

  /// Check circadian rhythm alignment
  Future<MonitoringCondition?> _checkCircadianRhythm(
      ExecutionContext context, DateTime now) async {
    final sleepTime =
        context.userState['typical_sleep_time'] as int? ?? 23; // 11 PM default
    // final wakeTime = context.userState['typical_wake_time'] as int? ?? 7; // Unused   // 7 AM default

    final currentHour = now.hour;

    // Check if user is active during typical sleep hours
    if (currentHour >= sleepTime || currentHour <= 5) {
      final lastActivity = context.userState['last_activity_time'] as DateTime?;
      if (lastActivity != null && now.difference(lastActivity).inMinutes < 30) {
        return MonitoringCondition(
          id: 'circadian_mismatch',
          name: 'Circadian Rhythm Disruption',
          description: 'User is active during typical sleep hours',
          shouldTrigger: true,
          data: {
            'current_hour': currentHour,
            'typical_sleep_time': sleepTime,
            'activity_detected': true,
          },
          priority: ExecutionPriority.high,
          cooldown: const Duration(hours: 6),
          lastTriggered: recall<DateTime>('last_circadian_mismatch_trigger'),
        );
      }
    }

    return null;
  }

  /// Handle energy drop event
  Future<void> _handleEnergyDrop(
      MonitoringCondition condition, ExecutionContext context) async {
    final recommendations = [
      'Take a 10-minute break',
      'Do some light stretching',
      'Have a healthy snack',
      'Switch to easier tasks',
      'Consider a short walk',
    ];

    // Store energy drop event
    _storeEnergyEvent('energy_drop', condition.data, recommendations);
  }

  /// Handle low energy event
  Future<void> _handleLowEnergy(
      MonitoringCondition condition, ExecutionContext context) async {
    final recommendations = _getLowEnergyRecommendations();

    // Store low energy event
    _storeEnergyEvent('low_energy', condition.data, recommendations);
  }

  /// Handle peak energy event
  Future<void> _handlePeakEnergy(
      MonitoringCondition condition, ExecutionContext context) async {
    final recommendations = _getPeakEnergyRecommendations();

    // Store peak energy event
    _storeEnergyEvent('peak_energy', condition.data, recommendations);
  }

  /// Handle circadian rhythm mismatch
  Future<void> _handleCircadianMismatch(
      MonitoringCondition condition, ExecutionContext context) async {
    final recommendations = [
      'Consider winding down for sleep',
      'Dim the lights',
      'Avoid screens if possible',
      'Try relaxation techniques',
      'Set a sleep reminder',
    ];

    _storeEnergyEvent('circadian_mismatch', condition.data, recommendations);
  }

  /// Get recommendations for low energy
  List<String> _getLowEnergyRecommendations() {
    return [
      'Take a longer break (15-20 minutes)',
      'Have a protein-rich snack',
      'Do some light exercise',
      'Switch to routine/easy tasks',
      'Consider a power nap (10-20 minutes)',
      'Hydrate with water',
      'Get some natural light',
    ];
  }

  /// Get recommendations for peak energy
  List<String> _getPeakEnergyRecommendations() {
    return [
      'Tackle your most challenging tasks',
      'Work on creative projects',
      'Handle complex problem-solving',
      'Make important decisions',
      'Do focused deep work',
      'Learn something new',
    ];
  }

  /// Store energy event for learning
  void _storeEnergyEvent(String eventType, Map<String, dynamic> data,
      List<String> recommendations) {
    final events = recall<List<Map<String, dynamic>>>('energy_events') ?? [];
    events.add({
      'type': eventType,
      'data': data,
      'recommendations': recommendations,
      'timestamp': DateTime.now().toIso8601String(),
    });

    // Keep only last 100 events
    if (events.length > 100) {
      events.removeRange(0, events.length - 100);
    }

    remember('energy_events', events);
  }

  /// Get current energy assessment
  Future<Map<String, dynamic>> getCurrentEnergyAssessment(
      ExecutionContext context) async {
    final energyLevel = await _assessCurrentEnergyLevel(context);
    final assessment =
        recall<Map<String, dynamic>>('last_energy_assessment') ?? {};

    return {
      'energy_level': energyLevel,
      'assessment_details': assessment,
      'recommendations': _getRecommendationsForEnergyLevel(energyLevel),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Get recommendations based on energy level
  List<String> _getRecommendationsForEnergyLevel(double energyLevel) {
    if (energyLevel < 0.3) {
      return _getLowEnergyRecommendations();
    } else if (energyLevel > 0.8) {
      return _getPeakEnergyRecommendations();
    } else {
      return [
        'Continue with current tasks',
        'Take regular breaks',
        'Stay hydrated',
        'Monitor your energy levels',
      ];
    }
  }

  @override
  Future<void> performProactiveAction(ExecutionContext context) async {
    final action = context.parameters['action'] as String?;

    switch (action) {
      case 'assess_energy':
        final assessment = await getCurrentEnergyAssessment(context);
        remember('manual_assessment', assessment);
        break;
      case 'log_energy':
        final userEnergy = context.parameters['energy_level'] as double?;
        if (userEnergy != null) {
          _logUserEnergyInput(userEnergy, context);
        }
        break;
      case 'get_recommendations':
        final energyLevel = await _assessCurrentEnergyLevel(context);
        remember('current_recommendations',
            _getRecommendationsForEnergyLevel(energyLevel));
        break;
    }
  }

  /// Log user energy input for learning
  void _logUserEnergyInput(double userEnergy, ExecutionContext context) {
    final history = recall<List<Map<String, dynamic>>>('energy_history') ?? [];
    history.add({
      'energy_level': userEnergy,
      'timestamp': DateTime.now().toIso8601String(),
      'context': context.toJson(),
    });

    // Keep only last 1000 entries
    if (history.length > 1000) {
      history.removeRange(0, history.length - 1000);
    }

    remember('energy_history', history);
  }

  @override
  Map<String, dynamic> getMetrics() {
    final baseMetrics = super.getMetrics();
    final energyHistory =
        recall<List<Map<String, dynamic>>>('energy_history') ?? [];
    final energyEvents =
        recall<List<Map<String, dynamic>>>('energy_events') ?? [];

    return {
      ...baseMetrics,
      'total_assessments': energyHistory.length,
      'total_events': energyEvents.length,
      'average_energy': energyHistory.isNotEmpty
          ? energyHistory
                  .map((e) => e['energy_level'] as double)
                  .reduce((a, b) => a + b) /
              energyHistory.length
          : 0.0,
      'last_energy_level': recall<double>('last_energy_level'),
      'monitoring_stats': getMonitoringStats(),
    };
  }
}
