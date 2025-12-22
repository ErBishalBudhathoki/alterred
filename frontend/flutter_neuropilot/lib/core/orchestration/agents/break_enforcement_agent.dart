import 'dart:async';
import 'dart:math';
import '../models/agent_model.dart';
import 'base/proactive_agent.dart';

/// Agent that enforces breaks and interrupts hyperfocus episodes for ADHD users
class BreakEnforcementAgent extends ProactiveAgent {
  static const String agentId = 'break_enforcement';

  BreakEnforcementAgent()
      : super(
          Agent(
            id: agentId,
            name: 'Break Enforcement Agent',
            description:
                'Enforces breaks and interrupts hyperfocus episodes to prevent burnout and maintain productivity',
            type: AgentType.safety, // Safety agent with interrupt capability
            capabilities: const AgentCapabilities(
              canExecuteParallel: true,
              canBeInterrupted: false, // Safety agents cannot be interrupted
              canInterruptOthers: true, // Can interrupt all other agents
              requiresUserInput: false,
              hasMemory: true,
              canLearn: true,
              inputTypes: [
                'hyperfocus_alert',
                'work_session_data',
                'break_request',
                'user_compliance'
              ],
              outputTypes: [
                'break_enforcement',
                'interruption_signal',
                'compliance_report'
              ],
              maxExecutionTime: Duration(seconds: 10),
              maxConcurrentInstances: 1,
            ),
            lastActive: DateTime.now(),
            priority: 10, // Highest priority for safety
            config: {
              'enforcement_enabled': true,
              'gentle_reminders': true,
              'escalation_enabled': true,
              'max_work_session_minutes': 90,
              'min_break_duration_minutes': 10,
              'escalation_levels': 4,
              'compliance_tracking': true,
            },
          ),
          monitoringInterval: const Duration(minutes: 2), // Frequent monitoring
        );

  @override
  Future<List<MonitoringCondition>> checkConditions(
      ExecutionContext context) async {
    final conditions = <MonitoringCondition>[];
    final now = DateTime.now();

    // Check for hyperfocus detection requests
    final hyperfocusRequest =
        context.userState['hyperfocus_detected'] as bool? ?? false;
    if (hyperfocusRequest) {
      conditions.add(const MonitoringCondition(
        id: 'hyperfocus_break_request',
        name: 'Hyperfocus Break Request',
        description:
            'Hyperfocus Detection Agent has requested a break enforcement',
        shouldTrigger: true,
        data: {
          'source': 'hyperfocus_detection_agent',
          'urgency': 'high',
          'enforcement_type': 'immediate',
        },
        priority: ExecutionPriority.urgent,
        cooldown: Duration.zero, // No cooldown for safety
        lastTriggered: null,
      ));
    }

    // Check for break compliance
    final breakCompliance = await _checkBreakCompliance(context, now);
    if (breakCompliance != null) {
      conditions.add(breakCompliance);
    }

    // Check for work session duration
    final sessionDuration = await _checkWorkSessionDuration(context, now);
    if (sessionDuration != null) {
      conditions.add(sessionDuration);
    }

    // Check for user override attempts
    final overrideAttempt = await _checkUserOverrideAttempts(context, now);
    if (overrideAttempt != null) {
      conditions.add(overrideAttempt);
    }

    // Check for escalation needs
    final escalationNeeded = await _checkEscalationNeeds(context, now);
    if (escalationNeeded != null) {
      conditions.add(escalationNeeded);
    }

    return conditions;
  }

  @override
  Future<void> onConditionTriggered(
      MonitoringCondition condition, ExecutionContext context) async {
    switch (condition.id) {
      case 'hyperfocus_break_request':
        await _enforceHyperfocusBreak(condition, context);
        break;
      case 'break_compliance_violation':
        await _handleBreakComplianceViolation(condition, context);
        break;
      case 'excessive_work_session':
        await _handleExcessiveWorkSession(condition, context);
        break;
      case 'user_override_attempt':
        await _handleUserOverrideAttempt(condition, context);
        break;
      case 'escalation_required':
        await _handleEscalationRequired(condition, context);
        break;
    }

    // Update trigger timestamp and log enforcement action
    remember('last_${condition.id}_trigger', DateTime.now());
    _logEnforcementAction(condition, context);
  }

  /// Check break compliance
  Future<MonitoringCondition?> _checkBreakCompliance(
      ExecutionContext context, DateTime now) async {
    final lastBreak = recall<DateTime>('last_break_time');
    if (lastBreak == null) return null;

    final timeSinceBreak = now.difference(lastBreak).inMinutes;
    final maxWorkTime =
        metadata.config['max_work_session_minutes'] as int? ?? 90;

    // Check if user is actively working
    final isWorking = context.userState['is_working'] as bool? ?? false;
    if (!isWorking) return null;

    if (timeSinceBreak > maxWorkTime) {
      final severity =
          _calculateComplianceSeverity(timeSinceBreak, maxWorkTime);

      return MonitoringCondition(
        id: 'break_compliance_violation',
        name: 'Break Compliance Violation',
        description:
            'User has been working for $timeSinceBreak minutes without a break',
        shouldTrigger: true,
        data: {
          'time_since_break': timeSinceBreak,
          'max_allowed': maxWorkTime,
          'severity': severity,
          'enforcement_level': _getEnforcementLevel(severity),
        },
        priority:
            severity > 0.8 ? ExecutionPriority.urgent : ExecutionPriority.high,
        cooldown: const Duration(minutes: 5),
        lastTriggered: recall<DateTime>('last_break_compliance_trigger'),
      );
    }

    return null;
  }

  /// Check work session duration
  Future<MonitoringCondition?> _checkWorkSessionDuration(
      ExecutionContext context, DateTime now) async {
    final sessionStart = recall<DateTime>('current_session_start');
    if (sessionStart == null) return null;

    final sessionDuration = now.difference(sessionStart).inMinutes;
    final maxSessionTime =
        metadata.config['max_work_session_minutes'] as int? ?? 90;

    if (sessionDuration > maxSessionTime * 1.5) {
      // 50% over limit
      return MonitoringCondition(
        id: 'excessive_work_session',
        name: 'Excessive Work Session',
        description: 'Work session has exceeded safe duration limits',
        shouldTrigger: true,
        data: {
          'session_duration': sessionDuration,
          'safe_limit': maxSessionTime,
          'excess_time': sessionDuration - maxSessionTime,
          'health_risk': 'high',
        },
        priority: ExecutionPriority.safety,
        cooldown: Duration.zero,
        lastTriggered: null,
      );
    }

    return null;
  }

  /// Check for user override attempts
  Future<MonitoringCondition?> _checkUserOverrideAttempts(
      ExecutionContext context, DateTime now) async {
    final overrideAttempts =
        recall<List<Map<String, dynamic>>>('override_attempts') ?? [];

    // Check for recent override attempts
    final recentAttempts = overrideAttempts.where((attempt) {
      final attemptTime = DateTime.parse(attempt['timestamp'] as String);
      return now.difference(attemptTime).inMinutes < 30;
    }).length;

    if (recentAttempts >= 3) {
      return MonitoringCondition(
        id: 'user_override_attempt',
        name: 'Excessive Override Attempts',
        description: 'User is repeatedly trying to override break enforcement',
        shouldTrigger: true,
        data: {
          'recent_attempts': recentAttempts,
          'pattern': 'resistance',
          'intervention_needed': true,
        },
        priority: ExecutionPriority.high,
        cooldown: const Duration(minutes: 15),
        lastTriggered: recall<DateTime>('last_override_attempt_trigger'),
      );
    }

    return null;
  }

  /// Check for escalation needs
  Future<MonitoringCondition?> _checkEscalationNeeds(
      ExecutionContext context, DateTime now) async {
    final enforcementHistory =
        recall<List<Map<String, dynamic>>>('enforcement_history') ?? [];

    // Check for repeated non-compliance
    final recentEnforcements = enforcementHistory.where((enforcement) {
      final enforcementTime =
          DateTime.parse(enforcement['timestamp'] as String);
      return now.difference(enforcementTime).inHours < 2 &&
          enforcement['compliance'] == false;
    }).length;

    if (recentEnforcements >= 2) {
      return MonitoringCondition(
        id: 'escalation_required',
        name: 'Escalation Required',
        description: 'Multiple break enforcement failures require escalation',
        shouldTrigger: true,
        data: {
          'failed_enforcements': recentEnforcements,
          'escalation_level': _getNextEscalationLevel(),
          'intervention_type': 'intensive',
        },
        priority: ExecutionPriority.safety,
        cooldown: const Duration(minutes: 30),
        lastTriggered: recall<DateTime>('last_escalation_trigger'),
      );
    }

    return null;
  }

  /// Enforce hyperfocus break
  Future<void> _enforceHyperfocusBreak(
      MonitoringCondition condition, ExecutionContext context) async {
    final urgency = condition.data['urgency'] as String;
    // final enforcementType = condition.data['enforcement_type'] as String;

    // Immediate enforcement for hyperfocus
    final breakDuration = _calculateRequiredBreakDuration(urgency);

    await _executeBreakEnforcement(
      type: 'hyperfocus_intervention',
      duration: breakDuration,
      urgency: urgency,
      context: context,
    );

    // Save context for resumption
    await _saveWorkContext(context);

    // Notify other agents about the interruption
    remember('active_interruption', {
      'type': 'hyperfocus_break',
      'start_time': DateTime.now().toIso8601String(),
      'duration_minutes': breakDuration,
      'reason': 'hyperfocus_detected',
    });
  }

  /// Handle break compliance violation
  Future<void> _handleBreakComplianceViolation(
      MonitoringCondition condition, ExecutionContext context) async {
    final severity = condition.data['severity'] as double;
    final enforcementLevel = condition.data['enforcement_level'] as int;

    switch (enforcementLevel) {
      case 1: // Gentle reminder
        await _sendGentleReminder(context);
        break;
      case 2: // Firm reminder
        await _sendFirmReminder(context);
        break;
      case 3: // Forced break
        await _executeForcedBreak(context, severity);
        break;
      case 4: // Emergency intervention
        await _executeEmergencyIntervention(context);
        break;
    }
  }

  /// Handle excessive work session
  Future<void> _handleExcessiveWorkSession(
      MonitoringCondition condition, ExecutionContext context) async {
    final sessionDuration = condition.data['session_duration'] as int;
    final excessTime = condition.data['excess_time'] as int;

    // This is a safety issue - immediate intervention required
    await _executeEmergencyIntervention(context);

    // Log health risk event
    _logHealthRiskEvent('excessive_session', {
      'session_duration': sessionDuration,
      'excess_time': excessTime,
      'intervention': 'emergency_break',
    });
  }

  /// Handle user override attempt
  Future<void> _handleUserOverrideAttempt(
      MonitoringCondition condition, ExecutionContext context) async {
    final recentAttempts = condition.data['recent_attempts'] as int;

    // Log the override attempt
    final overrideAttempts =
        recall<List<Map<String, dynamic>>>('override_attempts') ?? [];
    overrideAttempts.add({
      'timestamp': DateTime.now().toIso8601String(),
      'context': context.toJson(),
      'total_recent': recentAttempts,
    });

    if (overrideAttempts.length > 100) {
      overrideAttempts.removeRange(0, overrideAttempts.length - 100);
    }

    remember('override_attempts', overrideAttempts);

    // Increase enforcement strictness
    _increaseEnforcementStrictness();

    // Send educational message about break importance
    await _sendEducationalMessage(context);
  }

  /// Handle escalation required
  Future<void> _handleEscalationRequired(
      MonitoringCondition condition, ExecutionContext context) async {
    final escalationLevel = condition.data['escalation_level'] as int;

    switch (escalationLevel) {
      case 1: // Increase monitoring frequency
        _increaseMonitoringFrequency();
        break;
      case 2: // Reduce work session limits
        _reduceWorkSessionLimits();
        break;
      case 3: // Mandatory breaks with lockout
        await _implementMandatoryBreaks(context);
        break;
      case 4: // External intervention (notify accountability partner)
        await _requestExternalIntervention(context);
        break;
    }
  }

  /// Execute break enforcement
  Future<void> _executeBreakEnforcement({
    required String type,
    required int duration,
    required String urgency,
    required ExecutionContext context,
  }) async {
    final enforcement = {
      'type': type,
      'duration_minutes': duration,
      'urgency': urgency,
      'start_time': DateTime.now().toIso8601String(),
      'context': context.toJson(),
    };

    // Store active enforcement
    remember('active_enforcement', enforcement);

    // Set break timer
    remember('break_end_time', DateTime.now().add(Duration(minutes: duration)));

    // Update user state
    remember('enforced_break_active', true);

    // Log enforcement action
    final enforcementHistory =
        recall<List<Map<String, dynamic>>>('enforcement_history') ?? [];
    enforcementHistory.add(enforcement);

    if (enforcementHistory.length > 200) {
      enforcementHistory.removeRange(0, enforcementHistory.length - 200);
    }

    remember('enforcement_history', enforcementHistory);
  }

  /// Calculate required break duration based on urgency
  int _calculateRequiredBreakDuration(String urgency) {
    switch (urgency) {
      case 'low':
        return 5;
      case 'medium':
        return 10;
      case 'high':
        return 15;
      case 'critical':
        return 20;
      default:
        return 10;
    }
  }

  /// Calculate compliance severity
  double _calculateComplianceSeverity(int timeSinceBreak, int maxWorkTime) {
    if (timeSinceBreak <= maxWorkTime) return 0.0;

    final excessTime = timeSinceBreak - maxWorkTime;
    final severity = (excessTime / maxWorkTime).clamp(0.0, 1.0);

    return severity;
  }

  /// Get enforcement level based on severity
  int _getEnforcementLevel(double severity) {
    if (severity >= 0.8) return 4; // Emergency
    if (severity >= 0.6) return 3; // Forced
    if (severity >= 0.3) return 2; // Firm
    return 1; // Gentle
  }

  /// Send gentle reminder
  Future<void> _sendGentleReminder(ExecutionContext context) async {
    remember('last_reminder', {
      'type': 'gentle',
      'timestamp': DateTime.now().toIso8601String(),
      'message':
          'Consider taking a short break soon to maintain your productivity.',
    });
  }

  /// Send firm reminder
  Future<void> _sendFirmReminder(ExecutionContext context) async {
    remember('last_reminder', {
      'type': 'firm',
      'timestamp': DateTime.now().toIso8601String(),
      'message':
          'You\'ve been working for a while. Please take a break within the next 10 minutes.',
    });
  }

  /// Execute forced break
  Future<void> _executeForcedBreak(
      ExecutionContext context, double severity) async {
    final breakDuration = severity > 0.7 ? 15 : 10;

    await _executeBreakEnforcement(
      type: 'forced_break',
      duration: breakDuration,
      urgency: 'high',
      context: context,
    );

    await _saveWorkContext(context);
  }

  /// Execute emergency intervention
  Future<void> _executeEmergencyIntervention(ExecutionContext context) async {
    await _executeBreakEnforcement(
      type: 'emergency_intervention',
      duration: 20,
      urgency: 'critical',
      context: context,
    );

    await _saveWorkContext(context);

    // Notify accountability partner if available
    await _notifyAccountabilityPartner(context);
  }

  /// Save work context for resumption
  Future<void> _saveWorkContext(ExecutionContext context) async {
    final workContext = {
      'timestamp': DateTime.now().toIso8601String(),
      'context': context.toJson(),
      'current_task': context.userState['current_task'],
      'work_progress': context.userState['work_progress'],
      'open_applications': context.userState['open_applications'],
      'notes': 'Context saved during break enforcement',
    };

    remember('saved_work_context', workContext);
  }

  /// Send educational message
  Future<void> _sendEducationalMessage(ExecutionContext context) async {
    final messages = [
      'Regular breaks are essential for ADHD brain health and sustained focus.',
      'Taking breaks actually improves your productivity and prevents burnout.',
      'Your brain needs rest to process information and maintain attention.',
      'Breaks help prevent hyperfocus episodes that can lead to exhaustion.',
    ];

    final message = messages[Random().nextInt(messages.length)];

    remember('last_educational_message', {
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Increase enforcement strictness
  void _increaseEnforcementStrictness() {
    final currentStrictness = recall<int>('enforcement_strictness') ?? 1;
    final newStrictness = (currentStrictness + 1).clamp(1, 5);

    remember('enforcement_strictness', newStrictness);

    // Adjust monitoring interval based on strictness
    // final newInterval = Duration(minutes: max(1, 5 - newStrictness));
    // Note: In a real implementation, this would update the monitoring interval
  }

  /// Get next escalation level
  int _getNextEscalationLevel() {
    final currentLevel = recall<int>('current_escalation_level') ?? 0;
    final maxLevels = metadata.config['escalation_levels'] as int? ?? 4;

    final nextLevel = (currentLevel + 1).clamp(1, maxLevels);
    remember('current_escalation_level', nextLevel);

    return nextLevel;
  }

  /// Increase monitoring frequency
  void _increaseMonitoringFrequency() {
    remember('monitoring_frequency_increased', {
      'timestamp': DateTime.now().toIso8601String(),
      'new_interval_minutes': 1,
      'reason': 'escalation_level_1',
    });
  }

  /// Reduce work session limits
  void _reduceWorkSessionLimits() {
    final currentLimit =
        metadata.config['max_work_session_minutes'] as int? ?? 90;
    final newLimit = (currentLimit * 0.75).round(); // Reduce by 25%

    remember('reduced_session_limit', {
      'original_limit': currentLimit,
      'new_limit': newLimit,
      'timestamp': DateTime.now().toIso8601String(),
      'reason': 'escalation_level_2',
    });
  }

  /// Implement mandatory breaks
  Future<void> _implementMandatoryBreaks(ExecutionContext context) async {
    remember('mandatory_breaks_active', {
      'enabled': true,
      'break_interval_minutes': 45, // Shorter intervals
      'break_duration_minutes': 15, // Longer breaks
      'timestamp': DateTime.now().toIso8601String(),
      'reason': 'escalation_level_3',
    });
  }

  /// Request external intervention
  Future<void> _requestExternalIntervention(ExecutionContext context) async {
    // This would integrate with A2A service to notify accountability partner
    remember('external_intervention_requested', {
      'timestamp': DateTime.now().toIso8601String(),
      'reason': 'repeated_non_compliance',
      'escalation_level': 4,
    });

    await _notifyAccountabilityPartner(context);
  }

  /// Notify accountability partner
  Future<void> _notifyAccountabilityPartner(ExecutionContext context) async {
    // Integration point with A2A service
    remember('accountability_notification', {
      'timestamp': DateTime.now().toIso8601String(),
      'message': 'User needs break enforcement support',
      'context': context.toJson(),
    });
  }

  /// Log enforcement action
  void _logEnforcementAction(
      MonitoringCondition condition, ExecutionContext context) {
    final enforcementLog = {
      'condition_id': condition.id,
      'condition_data': condition.data,
      'context': context.toJson(),
      'timestamp': DateTime.now().toIso8601String(),
      'agent_id': metadata.id,
    };

    final logs = recall<List<Map<String, dynamic>>>('enforcement_logs') ?? [];
    logs.add(enforcementLog);

    if (logs.length > 500) {
      logs.removeRange(0, logs.length - 500);
    }

    remember('enforcement_logs', logs);
  }

  /// Log health risk event
  void _logHealthRiskEvent(String eventType, Map<String, dynamic> eventData) {
    final healthRiskLog = {
      'event_type': eventType,
      'event_data': eventData,
      'timestamp': DateTime.now().toIso8601String(),
      'severity': 'high',
    };

    final healthLogs =
        recall<List<Map<String, dynamic>>>('health_risk_logs') ?? [];
    healthLogs.add(healthRiskLog);

    if (healthLogs.length > 100) {
      healthLogs.removeRange(0, healthLogs.length - 100);
    }

    remember('health_risk_logs', healthLogs);
  }

  @override
  Future<void> performProactiveAction(ExecutionContext context) async {
    final action = context.parameters['action'] as String?;

    switch (action) {
      case 'log_break_taken':
        await _logBreakTaken(context);
        break;
      case 'check_compliance':
        await _checkCurrentCompliance(context);
        break;
      case 'override_enforcement':
        await _handleOverrideRequest(context);
        break;
      case 'end_break':
        await _endEnforcedBreak(context);
        break;
      case 'get_enforcement_status':
        await _getEnforcementStatus(context);
        break;
    }
  }

  /// Log break taken by user
  Future<void> _logBreakTaken(ExecutionContext context) async {
    final breakDuration = context.parameters['duration_minutes'] as int? ?? 10;
    final breakType =
        context.parameters['break_type'] as String? ?? 'voluntary';

    remember('last_break_time', DateTime.now());

    // Check if this was compliance with enforcement
    final activeEnforcement =
        recall<Map<String, dynamic>>('active_enforcement');
    var compliance = false;

    if (activeEnforcement != null) {
      compliance = true;
      remember('active_enforcement', null); // Clear active enforcement
      remember('enforced_break_active', false);
    }

    // Update compliance statistics
    _updateComplianceStats(compliance);

    // Log the break
    final breakLog = {
      'duration_minutes': breakDuration,
      'break_type': breakType,
      'compliance': compliance,
      'timestamp': DateTime.now().toIso8601String(),
    };

    final breakHistory =
        recall<List<Map<String, dynamic>>>('break_history') ?? [];
    breakHistory.add(breakLog);

    if (breakHistory.length > 500) {
      breakHistory.removeRange(0, breakHistory.length - 500);
    }

    remember('break_history', breakHistory);
  }

  /// Check current compliance
  Future<void> _checkCurrentCompliance(ExecutionContext context) async {
    final complianceStats = _calculateComplianceStats();

    remember('current_compliance_status', {
      'compliance_rate': complianceStats['compliance_rate'],
      'recent_violations': complianceStats['recent_violations'],
      'enforcement_effectiveness': complianceStats['enforcement_effectiveness'],
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Handle override request
  Future<void> _handleOverrideRequest(ExecutionContext context) async {
    final reason = context.parameters['reason'] as String? ?? 'user_request';
    final duration = context.parameters['duration_minutes'] as int? ?? 30;

    // Log override attempt
    final overrideAttempts =
        recall<List<Map<String, dynamic>>>('override_attempts') ?? [];
    overrideAttempts.add({
      'reason': reason,
      'requested_duration': duration,
      'timestamp': DateTime.now().toIso8601String(),
      'granted': false, // Default to not granted
    });

    remember('override_attempts', overrideAttempts);

    // Evaluate if override should be granted
    final shouldGrant = _evaluateOverrideRequest(reason, duration, context);

    if (shouldGrant) {
      remember('override_granted', {
        'reason': reason,
        'duration_minutes': duration,
        'expires_at':
            DateTime.now().add(Duration(minutes: duration)).toIso8601String(),
      });

      // Update the last override attempt to granted
      overrideAttempts.last['granted'] = true;
      remember('override_attempts', overrideAttempts);
    }
  }

  /// End enforced break
  Future<void> _endEnforcedBreak(ExecutionContext context) async {
    remember('enforced_break_active', false);
    remember('active_enforcement', null);

    // Restore work context if available
    final savedContext = recall<Map<String, dynamic>>('saved_work_context');
    if (savedContext != null) {
      remember('restored_work_context', {
        'original_context': savedContext,
        'restored_at': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Get enforcement status
  Future<void> _getEnforcementStatus(ExecutionContext context) async {
    final status = {
      'enforcement_active': recall<bool>('enforced_break_active') ?? false,
      'active_enforcement': recall<Map<String, dynamic>>('active_enforcement'),
      'compliance_rate': _calculateComplianceStats()['compliance_rate'],
      'escalation_level': recall<int>('current_escalation_level') ?? 0,
      'strictness_level': recall<int>('enforcement_strictness') ?? 1,
      'override_active':
          recall<Map<String, dynamic>>('override_granted') != null,
    };

    remember('current_enforcement_status', status);
  }

  /// Evaluate override request
  bool _evaluateOverrideRequest(
      String reason, int duration, ExecutionContext context) {
    // Check recent override history
    final recentOverrides =
        recall<List<Map<String, dynamic>>>('override_attempts') ?? [];
    final recentCount = recentOverrides.where((attempt) {
      final attemptTime = DateTime.parse(attempt['timestamp'] as String);
      return DateTime.now().difference(attemptTime).inHours < 24 &&
          attempt['granted'] == true;
    }).length;

    // Limit overrides per day
    if (recentCount >= 2) return false;

    // Evaluate reason
    const validReasons = ['urgent_deadline', 'emergency', 'important_meeting'];
    if (!validReasons.contains(reason)) return false;

    // Limit duration
    if (duration > 60) return false; // Max 1 hour override

    return true;
  }

  /// Update compliance statistics
  void _updateComplianceStats(bool compliance) {
    final stats = recall<Map<String, dynamic>>('compliance_stats') ??
        {
          'total_enforcements': 0,
          'compliant_breaks': 0,
          'non_compliant_breaks': 0,
        };

    stats['total_enforcements'] = (stats['total_enforcements'] as int) + 1;

    if (compliance) {
      stats['compliant_breaks'] = (stats['compliant_breaks'] as int) + 1;
    } else {
      stats['non_compliant_breaks'] =
          (stats['non_compliant_breaks'] as int) + 1;
    }

    remember('compliance_stats', stats);
  }

  /// Calculate compliance statistics
  Map<String, dynamic> _calculateComplianceStats() {
    final stats = recall<Map<String, dynamic>>('compliance_stats') ??
        {
          'total_enforcements': 0,
          'compliant_breaks': 0,
          'non_compliant_breaks': 0,
        };

    final totalEnforcements = stats['total_enforcements'] as int;
    final compliantBreaks = stats['compliant_breaks'] as int;

    final complianceRate =
        totalEnforcements > 0 ? compliantBreaks / totalEnforcements : 0.0;

    // Calculate recent violations
    final enforcementHistory =
        recall<List<Map<String, dynamic>>>('enforcement_history') ?? [];
    final recentViolations = enforcementHistory.where((enforcement) {
      final enforcementTime =
          DateTime.parse(enforcement['timestamp'] as String);
      return DateTime.now().difference(enforcementTime).inDays <= 7 &&
          enforcement['compliance'] == false;
    }).length;

    return {
      'compliance_rate': complianceRate,
      'recent_violations': recentViolations,
      'total_enforcements': totalEnforcements,
      'enforcement_effectiveness': complianceRate > 0.7
          ? 'high'
          : complianceRate > 0.4
              ? 'medium'
              : 'low',
    };
  }

  @override
  Map<String, dynamic> getMetrics() {
    final baseMetrics = super.getMetrics();
    final complianceStats = _calculateComplianceStats();
    final enforcementHistory =
        recall<List<Map<String, dynamic>>>('enforcement_history') ?? [];
    final breakHistory =
        recall<List<Map<String, dynamic>>>('break_history') ?? [];

    return {
      ...baseMetrics,
      'total_enforcements': enforcementHistory.length,
      'total_breaks_logged': breakHistory.length,
      'compliance_rate': complianceStats['compliance_rate'],
      'recent_violations': complianceStats['recent_violations'],
      'enforcement_effectiveness': complianceStats['enforcement_effectiveness'],
      'current_escalation_level': recall<int>('current_escalation_level') ?? 0,
      'current_strictness': recall<int>('enforcement_strictness') ?? 1,
      'health_risk_events':
          recall<List<Map<String, dynamic>>>('health_risk_logs')?.length ?? 0,
      'monitoring_stats': getMonitoringStats(),
    };
  }
}
