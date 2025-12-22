import 'dart:async';
import '../models/agent_model.dart';
import 'base/proactive_agent.dart';

/// Agent that detects and manages hyperfocus episodes for ADHD users
class HyperfocusDetectionAgent extends ProactiveAgent {
  static const String agentId = 'hyperfocus_detection';

  HyperfocusDetectionAgent()
      : super(
          Agent(
            id: agentId,
            name: 'Hyperfocus Detection Agent',
            description:
                'Monitors work patterns and detects hyperfocus episodes to prevent burnout',
            type: AgentType.proactive,
            capabilities: const AgentCapabilities(
              canExecuteParallel: true,
              canBeInterrupted: false,
              canInterruptOthers: true, // Can interrupt other agents for safety
              requiresUserInput: false,
              hasMemory: true,
              canLearn: true,
              inputTypes: [
                'activity_data',
                'work_patterns',
                'break_history',
                'focus_metrics'
              ],
              outputTypes: [
                'hyperfocus_alert',
                'break_recommendation',
                'pattern_analysis'
              ],
              maxExecutionTime: Duration(seconds: 15),
              maxConcurrentInstances: 1,
            ),
            lastActive: DateTime.now(),
            config: {
              'hyperfocus_threshold_minutes': 90, // 1.5 hours without break
              'warning_threshold_minutes': 60, // 1 hour warning
              'monitoring_interval_minutes': 5, // Check every 5 minutes
              'break_reminder_interval':
                  15, // Remind every 15 minutes after threshold
              'learning_enabled': true,
              'pattern_detection': true,
            },
          ),
          monitoringInterval: const Duration(minutes: 5),
        );

  @override
  Future<List<MonitoringCondition>> checkConditions(
      ExecutionContext context) async {
    final conditions = <MonitoringCondition>[];
    final now = DateTime.now();

    // Get current work session data
    final workSession = await _getCurrentWorkSession(context);
    final sessionDuration = workSession['duration_minutes'] as int? ?? 0;
    final lastBreak = workSession['last_break'] as DateTime?;

    // Check for hyperfocus threshold
    final hyperfocusThreshold =
        metadata.config['hyperfocus_threshold_minutes'] as int? ?? 90;
    final warningThreshold =
        metadata.config['warning_threshold_minutes'] as int? ?? 60;

    if (sessionDuration >= hyperfocusThreshold) {
      conditions.add(MonitoringCondition(
        id: 'hyperfocus_detected',
        name: 'Hyperfocus Episode Detected',
        description:
            'User has been working for $sessionDuration minutes without a break',
        shouldTrigger: true,
        data: {
          'session_duration': sessionDuration,
          'threshold': hyperfocusThreshold,
          'severity': _calculateHyperfocusSeverity(
              sessionDuration, hyperfocusThreshold),
          'recommendations': _getHyperfocusRecommendations(sessionDuration),
          'last_break': lastBreak?.toIso8601String(),
        },
        priority: ExecutionPriority.urgent,
        cooldown: const Duration(minutes: 15),
        lastTriggered: recall<DateTime>('last_hyperfocus_trigger'),
      ));
    } else if (sessionDuration >= warningThreshold) {
      conditions.add(MonitoringCondition(
        id: 'hyperfocus_warning',
        name: 'Approaching Hyperfocus',
        description: 'User approaching hyperfocus threshold',
        shouldTrigger: true,
        data: {
          'session_duration': sessionDuration,
          'warning_threshold': warningThreshold,
          'time_until_hyperfocus': hyperfocusThreshold - sessionDuration,
          'recommendations': _getWarningRecommendations(),
        },
        priority: ExecutionPriority.high,
        cooldown: const Duration(minutes: 10),
        lastTriggered: recall<DateTime>('last_warning_trigger'),
      ));
    }

    // Check for pattern-based hyperfocus risk
    final patternRisk = await _assessPatternBasedRisk(context, now);
    if (patternRisk != null) {
      conditions.add(patternRisk);
    }

    // Check for break compliance
    final breakCompliance = await _checkBreakCompliance(context, now);
    if (breakCompliance != null) {
      conditions.add(breakCompliance);
    }

    // Update session tracking
    remember('last_session_check', now);
    remember('current_session_duration', sessionDuration);

    return conditions;
  }

  @override
  Future<void> onConditionTriggered(
      MonitoringCondition condition, ExecutionContext context) async {
    switch (condition.id) {
      case 'hyperfocus_detected':
        await _handleHyperfocusDetected(condition, context);
        break;
      case 'hyperfocus_warning':
        await _handleHyperfocusWarning(condition, context);
        break;
      case 'pattern_risk':
        await _handlePatternRisk(condition, context);
        break;
      case 'break_non_compliance':
        await _handleBreakNonCompliance(condition, context);
        break;
    }

    // Update trigger timestamp
    remember('last_${condition.id}_trigger', DateTime.now());

    // Learn from this episode
    _learnFromHyperfocusEvent(condition, context);
  }

  /// Get current work session information
  Future<Map<String, dynamic>> _getCurrentWorkSession(
      ExecutionContext context) async {
    final now = DateTime.now();

    // Check for activity indicators
    // final lastActivity = context.userState['last_activity_time'] as DateTime? ?? now; // Unused
    final activityType =
        context.userState['current_activity'] as String? ?? 'unknown';
    final isWorkActivity = _isWorkActivity(activityType);

    // Get session start time
    var sessionStart = recall<DateTime>('current_session_start');

    // If no session or activity changed to non-work, reset session
    if (sessionStart == null || !isWorkActivity) {
      if (isWorkActivity) {
        sessionStart = now;
        remember('current_session_start', sessionStart);
      } else {
        remember('current_session_start', null);
        return {
          'duration_minutes': 0,
          'session_start': null,
          'last_break': recall<DateTime>('last_break_time'),
          'is_active': false,
        };
      }
    }

    // Calculate session duration
    final sessionDuration = now.difference(sessionStart).inMinutes;

    // Check for breaks in session
    final lastBreak = recall<DateTime>('last_break_time');
    final breaksSinceStart = _getBreaksSinceSessionStart(sessionStart);

    return {
      'duration_minutes': sessionDuration,
      'session_start': sessionStart.toIso8601String(),
      'last_break': lastBreak,
      'breaks_count': breaksSinceStart.length,
      'is_active': isWorkActivity,
      'activity_type': activityType,
    };
  }

  /// Check if activity type indicates work
  bool _isWorkActivity(String activityType) {
    const workActivities = [
      'coding',
      'writing',
      'meeting',
      'research',
      'design',
      'analysis',
      'planning',
      'creative_work',
      'focused_work'
    ];
    return workActivities.contains(activityType.toLowerCase());
  }

  /// Calculate hyperfocus severity level
  double _calculateHyperfocusSeverity(int sessionDuration, int threshold) {
    if (sessionDuration < threshold) return 0.0;

    // Severity increases exponentially after threshold
    final overThreshold = sessionDuration - threshold;
    final severityFactor = overThreshold / threshold;

    return (severityFactor * 0.5 + 0.5).clamp(0.0, 1.0);
  }

  /// Get recommendations for hyperfocus episode
  List<String> _getHyperfocusRecommendations(int sessionDuration) {
    final recommendations = <String>[];

    if (sessionDuration >= 180) {
      // 3+ hours
      recommendations.addAll([
        'URGENT: Take a 20-30 minute break immediately',
        'Step away from your workspace completely',
        'Do some physical movement or exercise',
        'Eat something and hydrate',
        'Consider ending work session for today',
      ]);
    } else if (sessionDuration >= 120) {
      // 2+ hours
      recommendations.addAll([
        'Take a 15-20 minute break now',
        'Get some fresh air or natural light',
        'Do some stretching or light exercise',
        'Have a healthy snack and water',
        'Set a timer for your next break',
      ]);
    } else {
      // 90+ minutes
      recommendations.addAll([
        'Take a 10-15 minute break',
        'Stand up and move around',
        'Look away from screens',
        'Do some deep breathing',
        'Hydrate and have a light snack',
      ]);
    }

    return recommendations;
  }

  /// Get warning recommendations
  List<String> _getWarningRecommendations() {
    return [
      'Consider taking a short break soon',
      'Set a timer for 15 minutes to check in',
      'Notice your energy and focus levels',
      'Prepare for a break in the next 10-15 minutes',
      'Save your current work progress',
    ];
  }

  /// Assess pattern-based hyperfocus risk
  Future<MonitoringCondition?> _assessPatternBasedRisk(
      ExecutionContext context, DateTime now) async {
    final hyperfocusHistory =
        recall<List<Map<String, dynamic>>>('hyperfocus_history') ?? [];
    if (hyperfocusHistory.length < 3) return null; // Need history for patterns

    // Check for time-based patterns
    final currentHour = now.hour;
    final recentEpisodes = hyperfocusHistory.where((episode) {
      final episodeTime = DateTime.parse(episode['timestamp'] as String);
      return episodeTime.hour == currentHour &&
          now.difference(episodeTime).inDays <= 7; // Last week
    }).toList();

    if (recentEpisodes.length >= 2) {
      return MonitoringCondition(
        id: 'pattern_risk',
        name: 'Pattern-Based Hyperfocus Risk',
        description: 'High risk of hyperfocus based on historical patterns',
        shouldTrigger: true,
        data: {
          'risk_level': 'high',
          'pattern_type': 'time_based',
          'current_hour': currentHour,
          'recent_episodes': recentEpisodes.length,
          'recommendations': [
            'Be extra mindful of time during this hour',
            'Set shorter work intervals',
            'Use more frequent check-ins',
          ],
        },
        priority: ExecutionPriority.normal,
        cooldown: const Duration(hours: 1),
        lastTriggered: recall<DateTime>('last_pattern_risk_trigger'),
      );
    }

    return null;
  }

  /// Check break compliance
  Future<MonitoringCondition?> _checkBreakCompliance(
      ExecutionContext context, DateTime now) async {
    final lastBreak = recall<DateTime>('last_break_time');
    if (lastBreak == null) return null;

    final timeSinceBreak = now.difference(lastBreak).inMinutes;
    const maxTimeBetweenBreaks = 60; // 1 hour

    if (timeSinceBreak > maxTimeBetweenBreaks) {
      return MonitoringCondition(
        id: 'break_non_compliance',
        name: 'Break Schedule Non-Compliance',
        description: 'User has not taken a break in $timeSinceBreak minutes',
        shouldTrigger: true,
        data: {
          'time_since_break': timeSinceBreak,
          'max_allowed': maxTimeBetweenBreaks,
          'compliance_score': _calculateBreakCompliance(),
        },
        priority: ExecutionPriority.high,
        cooldown: const Duration(minutes: 20),
        lastTriggered: recall<DateTime>('last_break_compliance_trigger'),
      );
    }

    return null;
  }

  /// Handle hyperfocus detected
  Future<void> _handleHyperfocusDetected(
      MonitoringCondition condition, ExecutionContext context) async {
    final sessionDuration = condition.data['session_duration'] as int;
    final severity = condition.data['severity'] as double;

    // Store hyperfocus episode
    final episode = {
      'duration_minutes': sessionDuration,
      'severity': severity,
      'timestamp': DateTime.now().toIso8601String(),
      'context': context.toJson(),
      'recommendations_given': condition.data['recommendations'],
    };

    final history =
        recall<List<Map<String, dynamic>>>('hyperfocus_history') ?? [];
    history.add(episode);

    // Keep only last 100 episodes
    if (history.length > 100) {
      history.removeRange(0, history.length - 100);
    }

    remember('hyperfocus_history', history);

    // Trigger break enforcement if severity is high
    if (severity > 0.7) {
      remember('force_break_requested', {
        'timestamp': DateTime.now().toIso8601String(),
        'reason': 'hyperfocus_detected',
        'severity': severity,
      });
    }
  }

  /// Handle hyperfocus warning
  Future<void> _handleHyperfocusWarning(
      MonitoringCondition condition, ExecutionContext context) async {
    final sessionDuration = condition.data['session_duration'] as int;

    // Store warning event
    final warning = {
      'session_duration': sessionDuration,
      'timestamp': DateTime.now().toIso8601String(),
      'context': context.toJson(),
    };

    final warnings =
        recall<List<Map<String, dynamic>>>('hyperfocus_warnings') ?? [];
    warnings.add(warning);

    // Keep only last 50 warnings
    if (warnings.length > 50) {
      warnings.removeRange(0, warnings.length - 50);
    }

    remember('hyperfocus_warnings', warnings);
  }

  /// Handle pattern risk
  Future<void> _handlePatternRisk(
      MonitoringCondition condition, ExecutionContext context) async {
    // Store pattern risk event for learning
    final patternEvent = {
      'risk_level': condition.data['risk_level'],
      'pattern_type': condition.data['pattern_type'],
      'timestamp': DateTime.now().toIso8601String(),
      'context': context.toJson(),
    };

    final patternEvents =
        recall<List<Map<String, dynamic>>>('pattern_events') ?? [];
    patternEvents.add(patternEvent);

    if (patternEvents.length > 50) {
      patternEvents.removeRange(0, patternEvents.length - 50);
    }

    remember('pattern_events', patternEvents);
  }

  /// Handle break non-compliance
  Future<void> _handleBreakNonCompliance(
      MonitoringCondition condition, ExecutionContext context) async {
    final timeSinceBreak = condition.data['time_since_break'] as int;

    // Escalate break reminders
    remember('break_reminder_escalation', {
      'level': _getEscalationLevel(timeSinceBreak),
      'time_since_break': timeSinceBreak,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Get breaks since session start
  List<Map<String, dynamic>> _getBreaksSinceSessionStart(
      DateTime sessionStart) {
    final breakHistory =
        recall<List<Map<String, dynamic>>>('break_history') ?? [];

    return breakHistory.where((breakEvent) {
      final breakTime = DateTime.parse(breakEvent['timestamp'] as String);
      return breakTime.isAfter(sessionStart);
    }).toList();
  }

  /// Calculate break compliance score
  double _calculateBreakCompliance() {
    final breakHistory =
        recall<List<Map<String, dynamic>>>('break_history') ?? [];
    if (breakHistory.isEmpty) return 0.0;

    final recentBreaks = breakHistory.where((breakEvent) {
      final breakTime = DateTime.parse(breakEvent['timestamp'] as String);
      return DateTime.now().difference(breakTime).inDays <= 7;
    }).toList();

    // Calculate compliance based on frequency and regularity
    const expectedBreaksPerDay = 8; // Every hour during 8-hour workday
    final actualBreaksPerDay = recentBreaks.length / 7;

    return (actualBreaksPerDay / expectedBreaksPerDay).clamp(0.0, 1.0);
  }

  /// Get escalation level for break reminders
  int _getEscalationLevel(int timeSinceBreak) {
    if (timeSinceBreak >= 180) return 4; // 3+ hours - critical
    if (timeSinceBreak >= 120) return 3; // 2+ hours - urgent
    if (timeSinceBreak >= 90) return 2; // 1.5+ hours - high
    if (timeSinceBreak >= 60) return 1; // 1+ hour - normal
    return 0;
  }

  /// Learn from hyperfocus event
  void _learnFromHyperfocusEvent(
      MonitoringCondition condition, ExecutionContext context) {
    if (!metadata.config['learning_enabled'] as bool? ?? true) return;

    final learningData = {
      'condition_id': condition.id,
      'condition_data': condition.data,
      'context': context.toJson(),
      'timestamp': DateTime.now().toIso8601String(),
      'user_response': null, // Will be updated when user responds
    };

    final learningHistory =
        recall<List<Map<String, dynamic>>>('learning_history') ?? [];
    learningHistory.add(learningData);

    if (learningHistory.length > 200) {
      learningHistory.removeRange(0, learningHistory.length - 200);
    }

    remember('learning_history', learningHistory);
  }

  @override
  Future<void> performProactiveAction(ExecutionContext context) async {
    final action = context.parameters['action'] as String?;

    switch (action) {
      case 'log_break':
        await _logBreakTaken(context);
        break;
      case 'start_work_session':
        await _startWorkSession(context);
        break;
      case 'end_work_session':
        await _endWorkSession(context);
        break;
      case 'get_hyperfocus_risk':
        await _assessCurrentHyperfocusRisk(context);
        break;
      case 'update_activity':
        await _updateCurrentActivity(context);
        break;
    }
  }

  /// Log a break taken by the user
  Future<void> _logBreakTaken(ExecutionContext context) async {
    final breakDuration = context.parameters['duration_minutes'] as int? ?? 10;
    final breakType = context.parameters['break_type'] as String? ?? 'general';

    final breakEvent = {
      'duration_minutes': breakDuration,
      'break_type': breakType,
      'timestamp': DateTime.now().toIso8601String(),
      'context': context.toJson(),
    };

    final breakHistory =
        recall<List<Map<String, dynamic>>>('break_history') ?? [];
    breakHistory.add(breakEvent);

    if (breakHistory.length > 500) {
      breakHistory.removeRange(0, breakHistory.length - 500);
    }

    remember('break_history', breakHistory);
    remember('last_break_time', DateTime.now());

    // Reset session if it was a significant break
    if (breakDuration >= 15) {
      remember('current_session_start', null);
    }
  }

  /// Start a new work session
  Future<void> _startWorkSession(ExecutionContext context) async {
    final activityType =
        context.parameters['activity_type'] as String? ?? 'focused_work';

    remember('current_session_start', DateTime.now());
    remember('current_activity_type', activityType);

    final sessionEvent = {
      'activity_type': activityType,
      'start_time': DateTime.now().toIso8601String(),
      'context': context.toJson(),
    };

    final sessionHistory =
        recall<List<Map<String, dynamic>>>('session_history') ?? [];
    sessionHistory.add(sessionEvent);

    if (sessionHistory.length > 200) {
      sessionHistory.removeRange(0, sessionHistory.length - 200);
    }

    remember('session_history', sessionHistory);
  }

  /// End current work session
  Future<void> _endWorkSession(ExecutionContext context) async {
    final sessionStart = recall<DateTime>('current_session_start');
    if (sessionStart == null) return;

    final sessionDuration = DateTime.now().difference(sessionStart).inMinutes;

    final sessionEnd = {
      'duration_minutes': sessionDuration,
      'end_time': DateTime.now().toIso8601String(),
      'reason': context.parameters['reason'] as String? ?? 'manual',
      'context': context.toJson(),
    };

    remember('last_session_end', sessionEnd);
    remember('current_session_start', null);
    remember('current_activity_type', null);
  }

  /// Assess current hyperfocus risk
  Future<void> _assessCurrentHyperfocusRisk(ExecutionContext context) async {
    final workSession = await _getCurrentWorkSession(context);
    final sessionDuration = workSession['duration_minutes'] as int? ?? 0;
    final hyperfocusThreshold =
        metadata.config['hyperfocus_threshold_minutes'] as int? ?? 90;

    final riskLevel = sessionDuration / hyperfocusThreshold;
    final riskCategory = _getRiskCategory(riskLevel);

    remember('current_hyperfocus_risk', {
      'risk_level': riskLevel.clamp(0.0, 1.0),
      'risk_category': riskCategory,
      'session_duration': sessionDuration,
      'threshold': hyperfocusThreshold,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Update current activity
  Future<void> _updateCurrentActivity(ExecutionContext context) async {
    final activityType = context.parameters['activity_type'] as String?;
    if (activityType != null) {
      remember('current_activity_type', activityType);

      // If switching to non-work activity, end session
      if (!_isWorkActivity(activityType)) {
        await _endWorkSession(context.copyWith(
          parameters: {'reason': 'activity_change'},
        ));
      }
    }
  }

  /// Get risk category from risk level
  String _getRiskCategory(double riskLevel) {
    if (riskLevel >= 1.0) return 'critical';
    if (riskLevel >= 0.8) return 'high';
    if (riskLevel >= 0.6) return 'moderate';
    if (riskLevel >= 0.3) return 'low';
    return 'minimal';
  }

  @override
  Map<String, dynamic> getMetrics() {
    final baseMetrics = super.getMetrics();
    final hyperfocusHistory =
        recall<List<Map<String, dynamic>>>('hyperfocus_history') ?? [];
    final breakHistory =
        recall<List<Map<String, dynamic>>>('break_history') ?? [];
    final sessionHistory =
        recall<List<Map<String, dynamic>>>('session_history') ?? [];

    return {
      ...baseMetrics,
      'total_hyperfocus_episodes': hyperfocusHistory.length,
      'total_breaks_logged': breakHistory.length,
      'total_sessions': sessionHistory.length,
      'break_compliance_score': _calculateBreakCompliance(),
      'average_session_duration':
          _calculateAverageSessionDuration(sessionHistory),
      'hyperfocus_frequency': _calculateHyperfocusFrequency(hyperfocusHistory),
      'current_risk_level': recall<Map<String, dynamic>>(
              'current_hyperfocus_risk')?['risk_level'] ??
          0.0,
      'monitoring_stats': getMonitoringStats(),
    };
  }

  /// Calculate average session duration
  double _calculateAverageSessionDuration(
      List<Map<String, dynamic>> sessionHistory) {
    if (sessionHistory.isEmpty) return 0.0;

    final completedSessions = sessionHistory
        .where((session) => session.containsKey('duration_minutes'))
        .toList();

    if (completedSessions.isEmpty) return 0.0;

    final totalDuration = completedSessions
        .map((session) => session['duration_minutes'] as int? ?? 0)
        .reduce((a, b) => a + b);

    return totalDuration / completedSessions.length;
  }

  /// Calculate hyperfocus frequency (episodes per week)
  double _calculateHyperfocusFrequency(
      List<Map<String, dynamic>> hyperfocusHistory) {
    if (hyperfocusHistory.isEmpty) return 0.0;

    final now = DateTime.now();
    final recentEpisodes = hyperfocusHistory.where((episode) {
      final episodeTime = DateTime.parse(episode['timestamp'] as String);
      return now.difference(episodeTime).inDays <= 7;
    }).length;

    return recentEpisodes.toDouble();
  }
}
