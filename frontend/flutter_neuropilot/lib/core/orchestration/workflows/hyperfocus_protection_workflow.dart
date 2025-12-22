import '../models/workflow_model.dart';
import '../agents/hyperfocus_detection_agent.dart';
import '../agents/break_enforcement_agent.dart';
import '../agents/energy_assessment_agent.dart';

/// Hyperfocus protection workflow that monitors and interrupts hyperfocus episodes
class HyperfocusProtectionWorkflow {
  static const String workflowId = 'hyperfocus_protection';
  
  /// Create the hyperfocus protection workflow
  static Workflow createWorkflow() {
    return Workflow(
      id: workflowId,
      name: 'Hyperfocus Protection System',
      description: 'Monitors work patterns, detects hyperfocus episodes, and enforces protective breaks',
      steps: _createWorkflowSteps(),
      trigger: const WorkflowTrigger(
        type: TriggerType.condition,
        conditions: [
          WorkflowCondition(
            field: 'hyperfocus_detected',
            operator: ConditionOperator.equals,
            value: true,
          ),
        ],
        cooldown: Duration.zero, // No cooldown for safety
      ),
      createdAt: DateTime.now(),
      config: {
        'max_duration_minutes': 10, // Quick intervention
        'safety_priority': true,
        'interrupt_capability': true,
        'escalation_enabled': true,
        'context_preservation': true,
      },
    );
  }

  /// Create workflow steps
  static List<WorkflowStep> _createWorkflowSteps() {
    return [
      // Step 1: Immediate Hyperfocus Assessment
      const WorkflowStep(
        id: 'assess_hyperfocus_severity',
        name: 'Assess Hyperfocus Severity',
        agentId: HyperfocusDetectionAgent.agentId,
        executionType: ExecutionType.sequential,
        parameters: {
          'action': 'get_hyperfocus_risk',
          'immediate_assessment': true,
          'include_session_data': true,
          'calculate_severity': true,
        },
        conditions: [],
        dependsOn: [],
        timeout: Duration(seconds: 30),
        retryCount: 0,
        onSuccess: WorkflowStepAction.continue_,
        onFailure: WorkflowStepAction.continue_, // Continue with default severity
      ),

      // Step 2: Check Energy and Fatigue Levels (Parallel)
      const WorkflowStep(
        id: 'check_fatigue_levels',
        name: 'Check Energy and Fatigue Levels',
        agentId: EnergyAssessmentAgent.agentId,
        executionType: ExecutionType.parallel,
        parameters: {
          'action': 'assess_energy',
          'hyperfocus_context': true,
          'include_fatigue_indicators': true,
          'quick_assessment': true,
        },
        conditions: [],
        dependsOn: ['assess_hyperfocus_severity'],
        timeout: Duration(seconds: 30),
        retryCount: 1,
        onSuccess: WorkflowStepAction.continue_,
        onFailure: WorkflowStepAction.continue_,
      ),

      // Step 3: Capture Work Context (Parallel - for resumption)
      const WorkflowStep(
        id: 'capture_work_context',
        name: 'Capture Current Work Context',
        agentId: 'external_brain',
        executionType: ExecutionType.parallel,
        parameters: {
          'action': 'capture_context_snapshot',
          'context_type': 'hyperfocus_interruption',
          'include_screen_state': true,
          'include_work_progress': true,
          'include_thought_process': true,
          'urgency': 'high',
        },
        conditions: [],
        dependsOn: ['assess_hyperfocus_severity'],
        timeout: Duration(minutes: 1),
        retryCount: 0,
        onSuccess: WorkflowStepAction.continue_,
        onFailure: WorkflowStepAction.continue_, // Continue even if capture fails
      ),

      // Step 4: Determine Intervention Level
      const WorkflowStep(
        id: 'determine_intervention',
        name: 'Determine Intervention Level',
        agentId: 'intervention_coordinator', // Would be a specialized coordination agent
        executionType: ExecutionType.sequential,
        parameters: {
          'action': 'calculate_intervention_level',
          'hyperfocus_severity': '\${assess_hyperfocus_severity_result.severity}',
          'session_duration': '\${assess_hyperfocus_severity_result.session_duration}',
          'energy_level': '\${check_fatigue_levels_result.energy_level}',
          'fatigue_indicators': '\${check_fatigue_levels_result.fatigue_indicators}',
          'user_compliance_history': 'from_break_agent',
        },
        conditions: [],
        dependsOn: ['assess_hyperfocus_severity', 'check_fatigue_levels'],
        timeout: Duration(seconds: 30),
        retryCount: 0,
        onSuccess: WorkflowStepAction.continue_,
        onFailure: WorkflowStepAction.branch, // Branch to default intervention
      ),

      // Step 5: Execute Intervention (Break Enforcement)
      const WorkflowStep(
        id: 'execute_break_intervention',
        name: 'Execute Break Intervention',
        agentId: BreakEnforcementAgent.agentId,
        executionType: ExecutionType.sequential,
        parameters: {
          'action': 'enforce_break',
          'intervention_level': '\${determine_intervention_result.level}',
          'break_duration': '\${determine_intervention_result.break_duration}',
          'enforcement_type': '\${determine_intervention_result.enforcement_type}',
          'reason': 'hyperfocus_protection',
          'context_snapshot': '\${capture_work_context_result.snapshot_id}',
        },
        conditions: [],
        dependsOn: ['determine_intervention', 'capture_work_context'],
        timeout: Duration(minutes: 1),
        retryCount: 0,
        onSuccess: WorkflowStepAction.continue_,
        onFailure: WorkflowStepAction.branch, // Branch to escalation
      ),

      // Step 6: Monitor Break Compliance
      const WorkflowStep(
        id: 'monitor_break_compliance',
        name: 'Monitor Break Compliance',
        agentId: BreakEnforcementAgent.agentId,
        executionType: ExecutionType.sequential,
        parameters: {
          'action': 'monitor_break_compliance',
          'break_duration': '\${determine_intervention_result.break_duration}',
          'enforcement_level': '\${determine_intervention_result.level}',
          'allow_early_return': false, // Strict for hyperfocus protection
          'escalation_threshold': 0.3, // Low threshold for escalation
        },
        conditions: [
          WorkflowCondition(
            field: 'execute_break_intervention_result.break_started',
            operator: ConditionOperator.equals,
            value: true,
          ),
        ],
        dependsOn: ['execute_break_intervention'],
        timeout: Duration(minutes: 20), // Max break monitoring time
        retryCount: 0,
        onSuccess: WorkflowStepAction.continue_,
        onFailure: WorkflowStepAction.branch, // Branch to escalation
      ),

      // Step 7: Handle Non-Compliance (Conditional Branch)
      const WorkflowStep(
        id: 'handle_non_compliance',
        name: 'Handle Break Non-Compliance',
        agentId: BreakEnforcementAgent.agentId,
        executionType: ExecutionType.conditional,
        parameters: {
          'action': 'escalate_enforcement',
          'compliance_level': '\${monitor_break_compliance_result.compliance_level}',
          'escalation_type': 'hyperfocus_resistance',
          'notify_accountability_partner': true,
          'increase_strictness': true,
        },
        conditions: [
          WorkflowCondition(
            field: 'monitor_break_compliance_result.compliant',
            operator: ConditionOperator.equals,
            value: false,
          ),
        ],
        dependsOn: ['monitor_break_compliance'],
        timeout: Duration(minutes: 2),
        retryCount: 0,
        onSuccess: WorkflowStepAction.continue_,
        onFailure: WorkflowStepAction.continue_,
      ),

      // Step 8: Assess Break Effectiveness
      const WorkflowStep(
        id: 'assess_break_effectiveness',
        name: 'Assess Break Effectiveness',
        agentId: EnergyAssessmentAgent.agentId,
        executionType: ExecutionType.sequential,
        parameters: {
          'action': 'assess_energy',
          'post_break_assessment': true,
          'compare_to_pre_break': true,
          'pre_break_energy': '\${check_fatigue_levels_result.energy_level}',
          'include_recovery_metrics': true,
        },
        conditions: [
          WorkflowCondition(
            field: 'monitor_break_compliance_result.break_completed',
            operator: ConditionOperator.equals,
            value: true,
          ),
        ],
        dependsOn: ['monitor_break_compliance'],
        timeout: Duration(minutes: 1),
        retryCount: 1,
        onSuccess: WorkflowStepAction.continue_,
        onFailure: WorkflowStepAction.continue_,
      ),

      // Step 9: Restore Work Context (Conditional)
      const WorkflowStep(
        id: 'restore_work_context',
        name: 'Restore Work Context',
        agentId: 'external_brain',
        executionType: ExecutionType.conditional,
        parameters: {
          'action': 'restore_context_snapshot',
          'snapshot_id': '\${capture_work_context_result.snapshot_id}',
          'restoration_type': 'guided_resumption',
          'include_break_summary': true,
          'energy_level': '\${assess_break_effectiveness_result.energy_level}',
        },
        conditions: [
          WorkflowCondition(
            field: 'assess_break_effectiveness_result.ready_to_resume',
            operator: ConditionOperator.equals,
            value: true,
          ),
        ],
        dependsOn: ['assess_break_effectiveness'],
        timeout: Duration(minutes: 2),
        retryCount: 1,
        onSuccess: WorkflowStepAction.continue_,
        onFailure: WorkflowStepAction.continue_,
      ),

      // Step 10: Set Up Continued Monitoring
      const WorkflowStep(
        id: 'setup_continued_monitoring',
        name: 'Set Up Enhanced Monitoring',
        agentId: HyperfocusDetectionAgent.agentId,
        executionType: ExecutionType.sequential,
        parameters: {
          'action': 'start_enhanced_monitoring',
          'monitoring_intensity': 'high',
          'session_limit': '\${determine_intervention_result.recommended_session_limit}',
          'break_frequency': '\${determine_intervention_result.recommended_break_frequency}',
          'hyperfocus_history': '\${assess_hyperfocus_severity_result}',
        },
        conditions: [],
        dependsOn: ['restore_work_context'],
        timeout: Duration(seconds: 30),
        retryCount: 0,
        onSuccess: WorkflowStepAction.continue_,
        onFailure: WorkflowStepAction.continue_,
      ),

      // Step 11: Log Protection Event
      const WorkflowStep(
        id: 'log_protection_event',
        name: 'Log Hyperfocus Protection Event',
        agentId: 'logging_agent',
        executionType: ExecutionType.sequential,
        parameters: {
          'action': 'log_hyperfocus_protection',
          'hyperfocus_data': '\${assess_hyperfocus_severity_result}',
          'intervention_data': '\${determine_intervention_result}',
          'compliance_data': '\${monitor_break_compliance_result}',
          'effectiveness_data': '\${assess_break_effectiveness_result}',
          'user_feedback': 'to_be_collected',
        },
        conditions: [],
        dependsOn: ['setup_continued_monitoring'],
        timeout: Duration(seconds: 30),
        retryCount: 0,
        onSuccess: WorkflowStepAction.continue_,
        onFailure: WorkflowStepAction.continue_,
      ),
    ];
  }

  /// Get hyperfocus protection triggers
  static List<WorkflowTrigger> getHyperfocusProtectionTriggers() {
    return [
      // Primary hyperfocus detection trigger
      const WorkflowTrigger(
        type: TriggerType.condition,
        conditions: [
          WorkflowCondition(
            field: 'hyperfocus_detected',
            operator: ConditionOperator.equals,
            value: true,
          ),
        ],
        cooldown: Duration.zero, // No cooldown for safety
      ),

      // Session duration trigger
      const WorkflowTrigger(
        type: TriggerType.condition,
        conditions: [
          WorkflowCondition(
            field: 'work_session_duration_minutes',
            operator: ConditionOperator.greaterThan,
            value: 90, // 1.5 hours
          ),
          WorkflowCondition(
            field: 'break_taken_recently',
            operator: ConditionOperator.equals,
            value: false,
          ),
        ],
        cooldown: Duration(minutes: 15),
      ),

      // Agent trigger (from hyperfocus detection agent)
      const WorkflowTrigger(
        type: TriggerType.agent,
        config: {
          'agent_id': HyperfocusDetectionAgent.agentId,
          'trigger_condition': 'hyperfocus_threshold_exceeded',
        },
        cooldown: Duration.zero,
      ),

      // Pattern-based trigger (historical hyperfocus times)
      const WorkflowTrigger(
        type: TriggerType.condition,
        conditions: [
          WorkflowCondition(
            field: 'hyperfocus_risk_level',
            operator: ConditionOperator.greaterThan,
            value: 0.8,
          ),
          WorkflowCondition(
            field: 'current_time_matches_pattern',
            operator: ConditionOperator.equals,
            value: true,
          ),
        ],
        cooldown: Duration(minutes: 30),
      ),

      // Emergency trigger (extreme session duration)
      const WorkflowTrigger(
        type: TriggerType.condition,
        conditions: [
          WorkflowCondition(
            field: 'work_session_duration_minutes',
            operator: ConditionOperator.greaterThan,
            value: 180, // 3 hours - emergency level
          ),
        ],
        cooldown: Duration.zero,
      ),
    ];
  }

  /// Get intervention level configurations
  static Map<String, Map<String, dynamic>> getInterventionLevels() {
    return {
      'gentle': {
        'break_duration_minutes': 5,
        'enforcement_type': 'reminder',
        'allow_postpone': true,
        'escalation_threshold': 2, // 2 ignored reminders
        'description': 'Gentle reminder to take a break',
      },
      'firm': {
        'break_duration_minutes': 10,
        'enforcement_type': 'strong_reminder',
        'allow_postpone': false,
        'escalation_threshold': 1, // 1 ignored reminder
        'description': 'Firm break recommendation',
      },
      'mandatory': {
        'break_duration_minutes': 15,
        'enforcement_type': 'forced_break',
        'allow_postpone': false,
        'escalation_threshold': 0, // No tolerance
        'description': 'Mandatory break for health protection',
      },
      'emergency': {
        'break_duration_minutes': 20,
        'enforcement_type': 'emergency_intervention',
        'allow_postpone': false,
        'escalation_threshold': 0,
        'notify_accountability_partner': true,
        'description': 'Emergency intervention to prevent burnout',
      },
    };
  }

  /// Get escalation workflows
  static Map<String, Workflow> getEscalationWorkflows() {
    return {
      'accountability_notification': _createAccountabilityNotificationWorkflow(),
      'system_lockdown': _createSystemLockdownWorkflow(),
      'extended_break_enforcement': _createExtendedBreakWorkflow(),
    };
  }

  /// Create accountability notification workflow
  static Workflow _createAccountabilityNotificationWorkflow() {
    return Workflow(
      id: 'accountability_notification',
      name: 'Accountability Partner Notification',
      description: 'Notifies accountability partner when user resists break enforcement',
      steps: [
        const WorkflowStep(
          id: 'prepare_notification',
          name: 'Prepare Accountability Notification',
          agentId: 'notification_agent',
          parameters: {
            'action': 'prepare_hyperfocus_alert',
            'session_duration': 'from_context',
            'compliance_level': 'from_context',
            'urgency': 'high',
          },
          dependsOn: [],
        ),
        const WorkflowStep(
          id: 'send_notification',
          name: 'Send Notification to Partner',
          agentId: 'a2a_agent',
          parameters: {
            'action': 'send_hyperfocus_alert',
            'message': '\${prepare_notification_result.message}',
            'priority': 'urgent',
            'request_intervention': true,
          },
          dependsOn: ['prepare_notification'],
        ),
        const WorkflowStep(
          id: 'wait_for_response',
          name: 'Wait for Partner Response',
          agentId: 'wait_agent',
          parameters: {
            'max_wait_time': 900, // 15 minutes
            'fallback_action': 'escalate_further',
          },
          dependsOn: ['send_notification'],
        ),
      ],
      trigger: const WorkflowTrigger(
        type: TriggerType.condition,
        conditions: [
          WorkflowCondition(
            field: 'break_compliance_violations',
            operator: ConditionOperator.greaterThan,
            value: 2,
          ),
        ],
      ),
      createdAt: DateTime.now(),
      config: {'max_duration_minutes': 20},
    );
  }

  /// Create system lockdown workflow
  static Workflow _createSystemLockdownWorkflow() {
    return Workflow(
      id: 'system_lockdown',
      name: 'System Lockdown for Break Enforcement',
      description: 'Locks system access to enforce mandatory break',
      steps: [
        const WorkflowStep(
          id: 'save_all_work',
          name: 'Auto-Save All Work',
          agentId: 'system_agent',
          parameters: {
            'action': 'auto_save_all',
            'create_backup': true,
            'save_session_state': true,
          },
          dependsOn: [],
        ),
        const WorkflowStep(
          id: 'initiate_lockdown',
          name: 'Initiate System Lockdown',
          agentId: 'system_agent',
          parameters: {
            'action': 'lockdown_system',
            'lockdown_duration': 'from_break_duration',
            'allow_emergency_override': true,
            'display_break_timer': true,
          },
          dependsOn: ['save_all_work'],
        ),
        const WorkflowStep(
          id: 'monitor_lockdown',
          name: 'Monitor Lockdown Period',
          agentId: 'system_agent',
          parameters: {
            'action': 'monitor_lockdown',
            'check_interval': 30, // 30 seconds
            'allow_early_unlock': false,
          },
          dependsOn: ['initiate_lockdown'],
        ),
      ],
      trigger: const WorkflowTrigger(
        type: TriggerType.condition,
        conditions: [
          WorkflowCondition(
            field: 'intervention_level',
            operator: ConditionOperator.equals,
            value: 'emergency',
          ),
          WorkflowCondition(
            field: 'compliance_violations',
            operator: ConditionOperator.greaterThan,
            value: 3,
          ),
        ],
      ),
      createdAt: DateTime.now(),
      config: {'max_duration_minutes': 30},
    );
  }

  /// Create extended break workflow
  static Workflow _createExtendedBreakWorkflow() {
    return Workflow(
      id: 'extended_break_enforcement',
      name: 'Extended Break Enforcement',
      description: 'Enforces longer break periods for severe hyperfocus episodes',
      steps: [
        const WorkflowStep(
          id: 'assess_burnout_risk',
          name: 'Assess Burnout Risk',
          agentId: EnergyAssessmentAgent.agentId,
          parameters: {
            'action': 'assess_burnout_risk',
            'session_duration': 'from_context',
            'recent_break_history': 'from_context',
            'energy_depletion': 'from_context',
          },
          dependsOn: [],
        ),
        const WorkflowStep(
          id: 'calculate_recovery_time',
          name: 'Calculate Required Recovery Time',
          agentId: 'recovery_agent',
          parameters: {
            'action': 'calculate_recovery_time',
            'burnout_risk': '\${assess_burnout_risk_result.risk_level}',
            'session_intensity': 'from_context',
            'user_recovery_patterns': 'from_history',
          },
          dependsOn: ['assess_burnout_risk'],
        ),
        const WorkflowStep(
          id: 'enforce_extended_break',
          name: 'Enforce Extended Break',
          agentId: BreakEnforcementAgent.agentId,
          parameters: {
            'action': 'enforce_extended_break',
            'break_duration': '\${calculate_recovery_time_result.recommended_duration}',
            'break_activities': '\${calculate_recovery_time_result.recommended_activities}',
            'strict_enforcement': true,
          },
          dependsOn: ['calculate_recovery_time'],
        ),
      ],
      trigger: const WorkflowTrigger(
        type: TriggerType.condition,
        conditions: [
          WorkflowCondition(
            field: 'hyperfocus_severity',
            operator: ConditionOperator.greaterThan,
            value: 0.9,
          ),
          WorkflowCondition(
            field: 'session_duration_hours',
            operator: ConditionOperator.greaterThan,
            value: 4,
          ),
        ],
      ),
      createdAt: DateTime.now(),
      config: {'max_duration_minutes': 60},
    );
  }

  /// Get adaptive monitoring configurations
  static Map<String, dynamic> getAdaptiveMonitoringConfig(Map<String, dynamic> userProfile) {
    final hyperfocusFrequency = userProfile['hyperfocus_frequency'] as double? ?? 0.5;
    final complianceRate = userProfile['break_compliance_rate'] as double? ?? 0.7;
    final severityHistory = userProfile['average_hyperfocus_severity'] as double? ?? 0.6;

    return {
      'monitoring_interval_minutes': _calculateMonitoringInterval(hyperfocusFrequency),
      'detection_sensitivity': _calculateDetectionSensitivity(severityHistory),
      'intervention_threshold': _calculateInterventionThreshold(complianceRate),
      'escalation_speed': _calculateEscalationSpeed(complianceRate),
      'context_capture_frequency': _calculateContextCaptureFrequency(hyperfocusFrequency),
    };
  }

  /// Calculate monitoring interval based on hyperfocus frequency
  static int _calculateMonitoringInterval(double frequency) {
    if (frequency > 0.8) return 2; // Every 2 minutes for high frequency
    if (frequency > 0.5) return 5; // Every 5 minutes for medium frequency
    return 10; // Every 10 minutes for low frequency
  }

  /// Calculate detection sensitivity
  static double _calculateDetectionSensitivity(double severityHistory) {
    if (severityHistory > 0.8) return 0.6; // High sensitivity for severe episodes
    if (severityHistory > 0.5) return 0.7; // Medium sensitivity
    return 0.8; // Lower sensitivity for mild episodes
  }

  /// Calculate intervention threshold
  static double _calculateInterventionThreshold(double complianceRate) {
    if (complianceRate < 0.3) return 0.5; // Lower threshold for non-compliant users
    if (complianceRate < 0.7) return 0.7; // Medium threshold
    return 0.8; // Higher threshold for compliant users
  }

  /// Calculate escalation speed
  static String _calculateEscalationSpeed(double complianceRate) {
    if (complianceRate < 0.3) return 'fast'; // Quick escalation for resistant users
    if (complianceRate < 0.7) return 'medium';
    return 'slow'; // Gentle escalation for compliant users
  }

  /// Calculate context capture frequency
  static int _calculateContextCaptureFrequency(double frequency) {
    if (frequency > 0.8) return 15; // Every 15 minutes for frequent hyperfocus
    if (frequency > 0.5) return 30; // Every 30 minutes
    return 60; // Every hour for infrequent hyperfocus
  }
}