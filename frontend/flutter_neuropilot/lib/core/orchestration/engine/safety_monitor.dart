import 'dart:async';
import '../models/agent_model.dart';
import 'agent_registry.dart';
import '../agents/break_enforcement_agent.dart';

/// Safety monitor that ensures safe operation of the orchestration system
class SafetyMonitor {
  static final SafetyMonitor _instance = SafetyMonitor._internal();
  factory SafetyMonitor() => _instance;
  SafetyMonitor._internal();

  final AgentRegistry _agentRegistry = AgentRegistry();
  final StreamController<SafetyEvent> _eventController =
      StreamController<SafetyEvent>.broadcast();

  Timer? _monitoringTimer;
  bool _isMonitoring = false;
  final Duration _monitoringInterval = const Duration(seconds: 10);

  final Map<String, SafetyRule> _safetyRules = {};
  final List<SafetyViolation> _violations = [];
  final Map<String, DateTime> _lastViolationTime = {};

  /// Stream of safety events
  Stream<SafetyEvent> get events => _eventController.stream;

  /// Whether safety monitoring is active
  bool get isMonitoring => _isMonitoring;

  /// Initialize safety monitor
  Future<void> initialize() async {
    _registerDefaultSafetyRules();
    await startMonitoring();

    _eventController.add(SafetyEvent(
      type: SafetyEventType.monitoringStarted,
      data: {'rules_count': _safetyRules.length},
      timestamp: DateTime.now(),
    ));
  }

  /// Register default safety rules
  void _registerDefaultSafetyRules() {
    // Rule 1: Prevent excessive work sessions
    registerSafetyRule(SafetyRule(
      id: 'max_work_session',
      name: 'Maximum Work Session Duration',
      description: 'Prevents work sessions longer than 3 hours',
      priority: SafetyPriority.high,
      checkFunction: _checkMaxWorkSession,
      violationAction: _handleMaxWorkSessionViolation,
      cooldownPeriod: const Duration(minutes: 30),
    ));

    // Rule 2: Prevent agent overload
    registerSafetyRule(SafetyRule(
      id: 'agent_overload',
      name: 'Agent Overload Prevention',
      description: 'Prevents too many agents running simultaneously',
      priority: SafetyPriority.medium,
      checkFunction: _checkAgentOverload,
      violationAction: _handleAgentOverloadViolation,
      cooldownPeriod: const Duration(minutes: 5),
    ));

    // Rule 3: Prevent infinite loops
    registerSafetyRule(SafetyRule(
      id: 'infinite_loop',
      name: 'Infinite Loop Prevention',
      description: 'Detects and prevents infinite workflow loops',
      priority: SafetyPriority.critical,
      checkFunction: _checkInfiniteLoop,
      violationAction: _handleInfiniteLoopViolation,
      cooldownPeriod: const Duration(minutes: 1),
    ));

    // Rule 4: Resource exhaustion prevention
    registerSafetyRule(SafetyRule(
      id: 'resource_exhaustion',
      name: 'Resource Exhaustion Prevention',
      description: 'Prevents system resource exhaustion',
      priority: SafetyPriority.high,
      checkFunction: _checkResourceExhaustion,
      violationAction: _handleResourceExhaustionViolation,
      cooldownPeriod: const Duration(minutes: 2),
    ));

    // Rule 5: Break enforcement compliance
    registerSafetyRule(SafetyRule(
      id: 'break_compliance',
      name: 'Break Enforcement Compliance',
      description: 'Ensures break enforcement is respected',
      priority: SafetyPriority.critical,
      checkFunction: _checkBreakCompliance,
      violationAction: _handleBreakComplianceViolation,
      cooldownPeriod: Duration.zero, // No cooldown for safety
    ));

    // Rule 6: Agent error cascade prevention
    registerSafetyRule(SafetyRule(
      id: 'error_cascade',
      name: 'Error Cascade Prevention',
      description: 'Prevents cascading agent failures',
      priority: SafetyPriority.high,
      checkFunction: _checkErrorCascade,
      violationAction: _handleErrorCascadeViolation,
      cooldownPeriod: const Duration(minutes: 1),
    ));
  }

  /// Start safety monitoring
  Future<void> startMonitoring() async {
    if (_isMonitoring) return;

    _isMonitoring = true;

    _monitoringTimer = Timer.periodic(_monitoringInterval, (timer) async {
      await _performSafetyCheck();
    });

    // Perform initial check
    await _performSafetyCheck();
  }

  /// Stop safety monitoring
  Future<void> stopMonitoring() async {
    if (!_isMonitoring) return;

    _isMonitoring = false;
    _monitoringTimer?.cancel();
    _monitoringTimer = null;

    _eventController.add(SafetyEvent(
      type: SafetyEventType.monitoringStopped,
      data: {},
      timestamp: DateTime.now(),
    ));
  }

  /// Perform safety check
  Future<void> _performSafetyCheck() async {
    final context = ExecutionContext(
      id: 'safety_check_${DateTime.now().millisecondsSinceEpoch}',
      userId: 'safety_monitor',
      timestamp: DateTime.now(),
      priority: ExecutionPriority.safety,
    );

    for (final rule in _safetyRules.values) {
      try {
        // Check if rule is in cooldown
        if (_isRuleInCooldown(rule.id)) continue;

        // Execute safety check
        final violation = await rule.checkFunction(context);

        if (violation != null) {
          await _handleSafetyViolation(rule, violation, context);
        }
      } catch (error) {
        _eventController.add(SafetyEvent(
          type: SafetyEventType.ruleCheckError,
          data: {
            'rule_id': rule.id,
            'error': error.toString(),
          },
          timestamp: DateTime.now(),
          priority: SafetyPriority.medium,
        ));
      }
    }
  }

  /// Handle safety violation
  Future<void> _handleSafetyViolation(SafetyRule rule,
      SafetyViolation violation, ExecutionContext context) async {
    // Record violation
    _violations.add(violation);
    _lastViolationTime[rule.id] = DateTime.now();

    // Emit safety event
    _eventController.add(SafetyEvent(
      type: SafetyEventType.violationDetected,
      data: {
        'rule_id': rule.id,
        'violation': violation.toJson(),
      },
      timestamp: DateTime.now(),
      priority: rule.priority,
    ));

    // Execute violation action
    try {
      await rule.violationAction(violation, context);

      _eventController.add(SafetyEvent(
        type: SafetyEventType.violationHandled,
        data: {
          'rule_id': rule.id,
          'violation_id': violation.id,
        },
        timestamp: DateTime.now(),
        priority: rule.priority,
      ));
    } catch (error) {
      _eventController.add(SafetyEvent(
        type: SafetyEventType.violationHandlingError,
        data: {
          'rule_id': rule.id,
          'violation_id': violation.id,
          'error': error.toString(),
        },
        timestamp: DateTime.now(),
        priority: SafetyPriority.critical,
      ));
    }

    // Keep only last 1000 violations
    if (_violations.length > 1000) {
      _violations.removeRange(0, _violations.length - 1000);
    }
  }

  /// Check if rule is in cooldown
  bool _isRuleInCooldown(String ruleId) {
    final rule = _safetyRules[ruleId];
    final lastViolation = _lastViolationTime[ruleId];

    if (rule == null || lastViolation == null) return false;

    return DateTime.now()
            .difference(lastViolation)
            .compareTo(rule.cooldownPeriod) <
        0;
  }

  /// Register safety rule
  void registerSafetyRule(SafetyRule rule) {
    _safetyRules[rule.id] = rule;

    _eventController.add(SafetyEvent(
      type: SafetyEventType.ruleRegistered,
      data: {
        'rule_id': rule.id,
        'rule_name': rule.name,
        'priority': rule.priority.name,
      },
      timestamp: DateTime.now(),
    ));
  }

  /// Unregister safety rule
  void unregisterSafetyRule(String ruleId) {
    _safetyRules.remove(ruleId);
    _lastViolationTime.remove(ruleId);

    _eventController.add(SafetyEvent(
      type: SafetyEventType.ruleUnregistered,
      data: {'rule_id': ruleId},
      timestamp: DateTime.now(),
    ));
  }

  /// Get safety statistics
  Map<String, dynamic> getSafetyStats() {
    final now = DateTime.now();
    final recentViolations = _violations
        .where((v) => now.difference(v.timestamp).inHours < 24)
        .length;

    final violationsByRule = <String, int>{};
    for (final violation in _violations) {
      violationsByRule[violation.ruleId] =
          (violationsByRule[violation.ruleId] ?? 0) + 1;
    }

    return {
      'total_rules': _safetyRules.length,
      'total_violations': _violations.length,
      'recent_violations_24h': recentViolations,
      'violations_by_rule': violationsByRule,
      'is_monitoring': _isMonitoring,
      'monitoring_interval_seconds': _monitoringInterval.inSeconds,
    };
  }

  /// Emergency stop - halt all agent operations
  Future<void> emergencyStop(String reason) async {
    _eventController.add(SafetyEvent(
      type: SafetyEventType.emergencyStop,
      data: {'reason': reason},
      timestamp: DateTime.now(),
      priority: SafetyPriority.critical,
    ));

    // Stop all active agents
    final activeAgents = _agentRegistry.getActiveAgents();
    for (final agent in activeAgents) {
      try {
        // If agent supports interruption, interrupt it
        if (agent.metadata.capabilities.canBeInterrupted) {
          // Note: This would need to be implemented in the agent base class
          // await agent.interrupt();
        }
      } catch (error) {
        // Log error but continue emergency stop
      }
    }

    // Stop monitoring agents
    final monitoringAgents = _agentRegistry.getMonitoringAgents();
    for (final _ /*agent*/ in monitoringAgents) {
      try {
        // Stop monitoring
        // Note: This would need to be implemented in proactive agents
        // await agent.stopMonitoring();
      } catch (error) {
        // Log error but continue emergency stop
      }
    }
  }

  /// Check maximum work session duration
  Future<SafetyViolation?> _checkMaxWorkSession(
      ExecutionContext context) async {
    // This would integrate with session tracking
    // For now, simulate the check
    final sessionDuration =
        context.userState['session_duration_minutes'] as int? ?? 0;
    const maxSessionMinutes = 180; // 3 hours

    if (sessionDuration > maxSessionMinutes) {
      return SafetyViolation(
        id: 'max_work_session_${DateTime.now().millisecondsSinceEpoch}',
        ruleId: 'max_work_session',
        severity: SafetySeverity.high,
        description:
            'Work session duration ($sessionDuration minutes) exceeds maximum ($maxSessionMinutes minutes)',
        data: {
          'session_duration': sessionDuration,
          'max_allowed': maxSessionMinutes,
          'excess_time': sessionDuration - maxSessionMinutes,
        },
        timestamp: DateTime.now(),
      );
    }

    return null;
  }

  /// Handle maximum work session violation
  Future<void> _handleMaxWorkSessionViolation(
      SafetyViolation violation, ExecutionContext context) async {
    // Trigger break enforcement
    final breakAgent = _agentRegistry.getAgent(BreakEnforcementAgent.agentId);
    if (breakAgent != null) {
      await breakAgent.execute(context.copyWith(
        parameters: {
          'action': 'enforce_break',
          'reason': 'max_session_exceeded',
          'urgency': 'high',
        },
      ));
    }
  }

  /// Check agent overload
  Future<SafetyViolation?> _checkAgentOverload(ExecutionContext context) async {
    final activeAgents = _agentRegistry.getActiveAgents();
    const maxConcurrentAgents = 5;

    if (activeAgents.length > maxConcurrentAgents) {
      return SafetyViolation(
        id: 'agent_overload_${DateTime.now().millisecondsSinceEpoch}',
        ruleId: 'agent_overload',
        severity: SafetySeverity.medium,
        description:
            'Too many agents running concurrently (${activeAgents.length}/$maxConcurrentAgents)',
        data: {
          'active_agents': activeAgents.length,
          'max_allowed': maxConcurrentAgents,
          'agent_ids': activeAgents.map((a) => a.metadata.id).toList(),
        },
        timestamp: DateTime.now(),
      );
    }

    return null;
  }

  /// Handle agent overload violation
  Future<void> _handleAgentOverloadViolation(
      SafetyViolation violation, ExecutionContext context) async {
    // Pause lowest priority agents
    final activeAgents = _agentRegistry.getActiveAgents();
    activeAgents
        .sort((a, b) => a.metadata.priority.compareTo(b.metadata.priority));

    // Pause the lowest priority agents
    final agentsToPause = activeAgents.take(activeAgents.length - 3).toList();
    for (final _ /*agent*/ in agentsToPause) {
      // Note: This would need pause functionality in agents
      // await agent.pause();
    }
  }

  /// Check for infinite loops
  Future<SafetyViolation?> _checkInfiniteLoop(ExecutionContext context) async {
    // This would analyze workflow execution patterns
    // For now, simulate based on execution count
    final executionCount =
        context.sessionData['workflow_execution_count'] as int? ?? 0;
    const maxExecutions = 100;

    if (executionCount > maxExecutions) {
      return SafetyViolation(
        id: 'infinite_loop_${DateTime.now().millisecondsSinceEpoch}',
        ruleId: 'infinite_loop',
        severity: SafetySeverity.critical,
        description:
            'Potential infinite loop detected (execution count: $executionCount)',
        data: {
          'execution_count': executionCount,
          'max_allowed': maxExecutions,
        },
        timestamp: DateTime.now(),
      );
    }

    return null;
  }

  /// Handle infinite loop violation
  Future<void> _handleInfiniteLoopViolation(
      SafetyViolation violation, ExecutionContext context) async {
    // Emergency stop all workflows
    await emergencyStop('Infinite loop detected');
  }

  /// Check resource exhaustion
  Future<SafetyViolation?> _checkResourceExhaustion(
      ExecutionContext context) async {
    // This would check system resources (memory, CPU, etc.)
    // For now, simulate based on agent count and execution time
    final totalAgents = _agentRegistry.agentCount;
    final activeAgents = _agentRegistry.getActiveAgents().length;

    if (activeAgents > totalAgents * 0.8) {
      return SafetyViolation(
        id: 'resource_exhaustion_${DateTime.now().millisecondsSinceEpoch}',
        ruleId: 'resource_exhaustion',
        severity: SafetySeverity.high,
        description: 'High resource usage detected',
        data: {
          'active_agents': activeAgents,
          'total_agents': totalAgents,
          'usage_percentage': (activeAgents / totalAgents * 100).round(),
        },
        timestamp: DateTime.now(),
      );
    }

    return null;
  }

  /// Handle resource exhaustion violation
  Future<void> _handleResourceExhaustionViolation(
      SafetyViolation violation, ExecutionContext context) async {
    // Throttle agent execution
    // This would implement resource throttling
  }

  /// Check break compliance
  Future<SafetyViolation?> _checkBreakCompliance(
      ExecutionContext context) async {
    final breakEnforcementActive =
        context.userState['break_enforcement_active'] as bool? ?? false;
    final userOverrideAttempts =
        context.userState['break_override_attempts'] as int? ?? 0;

    if (breakEnforcementActive && userOverrideAttempts > 3) {
      return SafetyViolation(
        id: 'break_compliance_${DateTime.now().millisecondsSinceEpoch}',
        ruleId: 'break_compliance',
        severity: SafetySeverity.critical,
        description: 'User repeatedly attempting to override break enforcement',
        data: {
          'override_attempts': userOverrideAttempts,
          'enforcement_active': breakEnforcementActive,
        },
        timestamp: DateTime.now(),
      );
    }

    return null;
  }

  /// Handle break compliance violation
  Future<void> _handleBreakComplianceViolation(
      SafetyViolation violation, ExecutionContext context) async {
    // Escalate break enforcement
    final breakAgent = _agentRegistry.getAgent(BreakEnforcementAgent.agentId);
    if (breakAgent != null) {
      await breakAgent.execute(context.copyWith(
        parameters: {
          'action': 'escalate_enforcement',
          'reason': 'compliance_violation',
          'urgency': 'critical',
        },
      ));
    }
  }

  /// Check error cascade
  Future<SafetyViolation?> _checkErrorCascade(ExecutionContext context) async {
    final errorAgents = _agentRegistry.getErrorAgents();
    const maxErrorAgents = 2;

    if (errorAgents.length > maxErrorAgents) {
      return SafetyViolation(
        id: 'error_cascade_${DateTime.now().millisecondsSinceEpoch}',
        ruleId: 'error_cascade',
        severity: SafetySeverity.high,
        description:
            'Multiple agents in error state - potential cascade failure',
        data: {
          'error_agents': errorAgents.length,
          'max_allowed': maxErrorAgents,
          'error_agent_ids': errorAgents.map((a) => a.metadata.id).toList(),
        },
        timestamp: DateTime.now(),
      );
    }

    return null;
  }

  /// Handle error cascade violation
  Future<void> _handleErrorCascadeViolation(
      SafetyViolation violation, ExecutionContext context) async {
    // Reset error agents
    final errorAgents = _agentRegistry.getErrorAgents();
    for (final _ /*agent*/ in errorAgents) {
      try {
        // This would restart the agent
        // await agent.restart();
      } catch (error) {
        // Log error but continue
      }
    }
  }

  /// Dispose safety monitor
  Future<void> dispose() async {
    await stopMonitoring();
    await _eventController.close();
  }
}

/// Safety rule definition
class SafetyRule {
  final String id;
  final String name;
  final String description;
  final SafetyPriority priority;
  final Future<SafetyViolation?> Function(ExecutionContext) checkFunction;
  final Future<void> Function(SafetyViolation, ExecutionContext)
      violationAction;
  final Duration cooldownPeriod;

  const SafetyRule({
    required this.id,
    required this.name,
    required this.description,
    required this.priority,
    required this.checkFunction,
    required this.violationAction,
    this.cooldownPeriod = const Duration(minutes: 5),
  });
}

/// Safety violation
class SafetyViolation {
  final String id;
  final String ruleId;
  final SafetySeverity severity;
  final String description;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  const SafetyViolation({
    required this.id,
    required this.ruleId,
    required this.severity,
    required this.description,
    this.data = const {},
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rule_id': ruleId,
      'severity': severity.name,
      'description': description,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory SafetyViolation.fromJson(Map<String, dynamic> json) {
    return SafetyViolation(
      id: json['id'] as String,
      ruleId: json['rule_id'] as String,
      severity:
          SafetySeverity.values.firstWhere((e) => e.name == json['severity']),
      description: json['description'] as String,
      data: json['data'] as Map<String, dynamic>? ?? {},
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

/// Safety event
class SafetyEvent {
  final SafetyEventType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final SafetyPriority priority;

  const SafetyEvent({
    required this.type,
    required this.data,
    required this.timestamp,
    this.priority = SafetyPriority.medium,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      'priority': priority.name,
    };
  }

  factory SafetyEvent.fromJson(Map<String, dynamic> json) {
    return SafetyEvent(
      type: SafetyEventType.values.firstWhere((e) => e.name == json['type']),
      data: json['data'] as Map<String, dynamic>,
      timestamp: DateTime.parse(json['timestamp'] as String),
      priority: SafetyPriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => SafetyPriority.medium,
      ),
    );
  }
}

/// Safety priority levels
enum SafetyPriority {
  low,
  medium,
  high,
  critical,
}

/// Safety severity levels
enum SafetySeverity {
  low,
  medium,
  high,
  critical,
}

/// Safety event types
enum SafetyEventType {
  monitoringStarted,
  monitoringStopped,
  ruleRegistered,
  ruleUnregistered,
  ruleCheckError,
  violationDetected,
  violationHandled,
  violationHandlingError,
  emergencyStop,
}
