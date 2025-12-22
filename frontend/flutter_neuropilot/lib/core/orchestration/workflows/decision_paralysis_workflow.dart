import '../models/workflow_model.dart';
import '../agents/decision_helper_agent.dart';
import '../agents/time_estimation_agent.dart';
import '../agents/energy_assessment_agent.dart';

/// Decision paralysis workflow that detects and resolves decision paralysis episodes
class DecisionParalysisWorkflow {
  static const String workflowId = 'decision_paralysis';
  
  /// Create the decision paralysis workflow
  static Workflow createWorkflow() {
    return Workflow(
      id: workflowId,
      name: 'Decision Paralysis Resolution',
      description: 'Detects decision paralysis and guides user through structured decision-making process',
      steps: _createWorkflowSteps(),
      trigger: const WorkflowTrigger(
        type: TriggerType.condition,
        conditions: [
          WorkflowCondition(
            field: 'decision_paralysis_detected',
            operator: ConditionOperator.equals,
            value: true,
          ),
        ],
        cooldown: Duration(minutes: 15), // Prevent rapid re-triggering
      ),
      createdAt: DateTime.now(),
      config: {
        'max_duration_minutes': 15,
        'auto_decide_threshold': 300, // 5 minutes before auto-decision
        'escalation_enabled': true,
        'learning_enabled': true,
      },
    );
  }

  /// Create workflow steps
  static List<WorkflowStep> _createWorkflowSteps() {
    return [
      // Step 1: Detect and Assess Paralysis Level
      const WorkflowStep(
        id: 'assess_paralysis',
        name: 'Assess Decision Paralysis Level',
        agentId: DecisionHelperAgent.agentId,
        executionType: ExecutionType.sequential,
        parameters: {
          'type': 'detect_paralysis',
          'include_patterns': true,
          'analyze_triggers': true,
          'assess_urgency': true,
        },
        conditions: [],
        dependsOn: [],
        timeout: Duration(minutes: 1),
        retryCount: 0,
        onSuccess: WorkflowStepAction.continue_,
        onFailure: WorkflowStepAction.stop, // Can't proceed without assessment
      ),

      // Step 2: Check Energy and Context (Parallel)
      const WorkflowStep(
        id: 'check_energy_context',
        name: 'Check Energy and Decision Context',
        agentId: EnergyAssessmentAgent.agentId,
        executionType: ExecutionType.parallel,
        parameters: {
          'action': 'assess_energy',
          'decision_context': true,
          'include_stress_level': true,
          'quick_assessment': true,
        },
        conditions: [],
        dependsOn: ['assess_paralysis'],
        timeout: Duration(seconds: 30),
        retryCount: 1,
        onSuccess: WorkflowStepAction.continue_,
        onFailure: WorkflowStepAction.continue_, // Continue even if energy check fails
      ),

      // Step 3: Capture Decision Context (Parallel)
      const WorkflowStep(
        id: 'capture_decision_context',
        name: 'Capture Decision Context',
        agentId: 'external_brain',
        executionType: ExecutionType.parallel,
        parameters: {
          'action': 'capture_decision_context',
          'paralysis_level': '\${assess_paralysis_result.paralysis_level}',
          'decision_type': '\${assess_paralysis_result.decision_type}',
          'options_count': '\${assess_paralysis_result.options_count}',
        },
        conditions: [],
        dependsOn: ['assess_paralysis'],
        timeout: Duration(minutes: 1),
        retryCount: 0,
        onSuccess: WorkflowStepAction.continue_,
        onFailure: WorkflowStepAction.continue_,
      ),

      // Step 4: Simplify Options (Core Intervention)
      const WorkflowStep(
        id: 'simplify_options',
        name: 'Simplify Decision Options',
        agentId: DecisionHelperAgent.agentId,
        executionType: ExecutionType.sequential,
        parameters: {
          'type': 'simplify_options',
          'paralysis_level': '\${assess_paralysis_result.paralysis_level}',
          'energy_level': '\${check_energy_context_result.energy_level}',
          'max_options': 3, // ADHD-friendly limit
          'use_emergency_simplification': '\${assess_paralysis_result.paralysis_level > 0.7}',
        },
        conditions: [
          WorkflowCondition(
            field: 'assess_paralysis_result.paralysis_level',
            operator: ConditionOperator.greaterThan,
            value: 0.3,
          ),
        ],
        dependsOn: ['assess_paralysis', 'check_energy_context'],
        timeout: Duration(minutes: 2),
        retryCount: 1,
        onSuccess: WorkflowStepAction.continue_,
        onFailure: WorkflowStepAction.branch, // Branch to emergency decision
      ),

      // Step 5: Add Time Pressure (Motivation)
      const WorkflowStep(
        id: 'add_time_pressure',
        name: 'Add Constructive Time Pressure',
        agentId: TimeEstimationAgent.agentId,
        executionType: ExecutionType.sequential,
        parameters: {
          'type': 'estimate_decision_time',
          'decision_complexity': '\${assess_paralysis_result.complexity}',
          'simplified_options': '\${simplify_options_result.simplified_options}',
          'energy_level': '\${check_energy_context_result.energy_level}',
          'add_urgency': true,
          'max_decision_time': 300, // 5 minutes max
        },
        conditions: [
          WorkflowCondition(
            field: 'simplify_options_result.simplified_options',
            operator: ConditionOperator.exists,
            value: null,
          ),
        ],
        dependsOn: ['simplify_options'],
        timeout: Duration(minutes: 1),
        retryCount: 1,
        onSuccess: WorkflowStepAction.continue_,
        onFailure: WorkflowStepAction.continue_,
      ),

      // Step 6: Provide Decision Framework
      const WorkflowStep(
        id: 'provide_framework',
        name: 'Provide Decision Framework',
        agentId: DecisionHelperAgent.agentId,
        executionType: ExecutionType.sequential,
        parameters: {
          'type': 'provide_framework',
          'decision_type': '\${assess_paralysis_result.decision_type}',
          'complexity': '\${assess_paralysis_result.complexity}',
          'simplified_options': '\${simplify_options_result.simplified_options}',
          'time_limit': '\${add_time_pressure_result.recommended_time_limit}',
          'framework_type': 'adhd_optimized',
        },
        conditions: [],
        dependsOn: ['add_time_pressure'],
        timeout: Duration(minutes: 1),
        retryCount: 0,
        onSuccess: WorkflowStepAction.continue_,
        onFailure: WorkflowStepAction.continue_,
      ),

      // Step 7: Monitor Decision Progress
      const WorkflowStep(
        id: 'monitor_decision',
        name: 'Monitor Decision Progress',
        agentId: 'decision_monitor', // Would be a specialized monitoring agent
        executionType: ExecutionType.sequential,
        parameters: {
          'action': 'start_decision_monitoring',
          'time_limit': '\${add_time_pressure_result.recommended_time_limit}',
          'options': '\${simplify_options_result.simplified_options}',
          'framework': '\${provide_framework_result.framework}',
          'escalation_threshold': 0.8, // Escalate if paralysis increases
        },
        conditions: [],
        dependsOn: ['provide_framework'],
        timeout: Duration(minutes: 5), // Max monitoring time
        retryCount: 0,
        onSuccess: WorkflowStepAction.continue_,
        onFailure: WorkflowStepAction.branch, // Branch to auto-decision
      ),

      // Step 8: Auto-Decision (Conditional Branch)
      const WorkflowStep(
        id: 'auto_decision',
        name: 'Make Automatic Decision',
        agentId: DecisionHelperAgent.agentId,
        executionType: ExecutionType.conditional,
        parameters: {
          'type': 'quick_decide',
          'options': '\${simplify_options_result.simplified_options}',
          'criteria': '\${provide_framework_result.criteria}',
          'reason': 'time_limit_exceeded',
          'confidence_note': 'This is an automatic decision to break paralysis. You can adjust later.',
        },
        conditions: [
          WorkflowCondition(
            field: 'monitor_decision_result.decision_made',
            operator: ConditionOperator.equals,
            value: false,
          ),
          WorkflowCondition(
            field: 'monitor_decision_result.time_exceeded',
            operator: ConditionOperator.equals,
            value: true,
          ),
        ],
        dependsOn: ['monitor_decision'],
        timeout: Duration(seconds: 30),
        retryCount: 0,
        onSuccess: WorkflowStepAction.continue_,
        onFailure: WorkflowStepAction.continue_,
      ),

      // Step 9: Capture Decision for Learning
      const WorkflowStep(
        id: 'capture_decision',
        name: 'Capture Decision for Future Learning',
        agentId: 'external_brain',
        executionType: ExecutionType.sequential,
        parameters: {
          'action': 'capture_decision',
          'decision_context': '\${capture_decision_context_result}',
          'paralysis_assessment': '\${assess_paralysis_result}',
          'simplified_options': '\${simplify_options_result.simplified_options}',
          'final_decision': '\${auto_decision_result.chosen_option || monitor_decision_result.user_decision}',
          'decision_method': '\${auto_decision_result ? "automatic" : "user_guided"}',
          'workflow_effectiveness': 'to_be_rated',
        },
        conditions: [],
        dependsOn: ['auto_decision'],
        timeout: Duration(minutes: 1),
        retryCount: 0,
        onSuccess: WorkflowStepAction.continue_,
        onFailure: WorkflowStepAction.continue_,
      ),

      // Step 10: Learn and Adapt
      const WorkflowStep(
        id: 'learn_and_adapt',
        name: 'Learn from Decision Process',
        agentId: DecisionHelperAgent.agentId,
        executionType: ExecutionType.sequential,
        parameters: {
          'type': 'learn_from_decision',
          'paralysis_episode': '\${assess_paralysis_result}',
          'intervention_effectiveness': '\${monitor_decision_result.effectiveness_score}',
          'user_satisfaction': '\${capture_decision_result.user_satisfaction}',
          'decision_outcome': '\${capture_decision_result.final_decision}',
          'update_patterns': true,
        },
        conditions: [],
        dependsOn: ['capture_decision'],
        timeout: Duration(seconds: 30),
        retryCount: 0,
        onSuccess: WorkflowStepAction.continue_,
        onFailure: WorkflowStepAction.continue_,
      ),
    ];
  }

  /// Get decision paralysis triggers
  static List<WorkflowTrigger> getDecisionParalysisTriggers() {
    return [
      // Primary condition trigger
      const WorkflowTrigger(
        type: TriggerType.condition,
        conditions: [
          WorkflowCondition(
            field: 'decision_paralysis_detected',
            operator: ConditionOperator.equals,
            value: true,
          ),
        ],
        cooldown: Duration(minutes: 15),
      ),

      // Time-based trigger (user stuck on decision too long)
      const WorkflowTrigger(
        type: TriggerType.condition,
        conditions: [
          WorkflowCondition(
            field: 'decision_time_elapsed',
            operator: ConditionOperator.greaterThan,
            value: 600, // 10 minutes
          ),
          WorkflowCondition(
            field: 'decision_in_progress',
            operator: ConditionOperator.equals,
            value: true,
          ),
        ],
        cooldown: Duration(minutes: 5),
      ),

      // Agent trigger (from decision helper agent)
      const WorkflowTrigger(
        type: TriggerType.agent,
        config: {
          'agent_id': DecisionHelperAgent.agentId,
          'trigger_condition': 'paralysis_detected',
        },
        cooldown: Duration(minutes: 10),
      ),

      // Manual trigger (user requests help)
      const WorkflowTrigger(
        type: TriggerType.manual,
        config: {
          'button_text': 'Help Me Decide',
          'description': 'Get help with a difficult decision',
          'icon': 'decision_help',
        },
      ),

      // Event trigger (multiple option views without selection)
      const WorkflowTrigger(
        type: TriggerType.event,
        config: {
          'event_type': 'repeated_option_viewing',
          'threshold': 5, // Viewed options 5+ times
        },
        conditions: [
          WorkflowCondition(
            field: 'time_since_first_view',
            operator: ConditionOperator.greaterThan,
            value: 300, // 5 minutes
          ),
        ],
      ),
    ];
  }

  /// Get escalation workflows for severe paralysis
  static Map<String, Workflow> getEscalationWorkflows() {
    return {
      'emergency_decision': _createEmergencyDecisionWorkflow(),
      'external_help': _createExternalHelpWorkflow(),
      'postpone_decision': _createPostponeDecisionWorkflow(),
    };
  }

  /// Create emergency decision workflow (for severe paralysis)
  static Workflow _createEmergencyDecisionWorkflow() {
    return Workflow(
      id: 'emergency_decision',
      name: 'Emergency Decision Resolution',
      description: 'Rapid decision-making for severe paralysis episodes',
      steps: [
        const WorkflowStep(
          id: 'emergency_simplification',
          name: 'Emergency Option Simplification',
          agentId: DecisionHelperAgent.agentId,
          parameters: {
            'type': 'emergency_simplification',
            'max_options': 2, // Only 2 options
            'use_heuristics': true,
            'time_limit': 60, // 1 minute
          },
          dependsOn: [],
        ),
        const WorkflowStep(
          id: 'coin_flip_decision',
          name: 'Randomized Decision',
          agentId: DecisionHelperAgent.agentId,
          parameters: {
            'type': 'quick_decide',
            'method': 'randomized',
            'explanation': 'Breaking paralysis with random choice - you can change this later',
          },
          dependsOn: ['emergency_simplification'],
        ),
      ],
      trigger: const WorkflowTrigger(
        type: TriggerType.condition,
        conditions: [
          WorkflowCondition(
            field: 'paralysis_level',
            operator: ConditionOperator.greaterThan,
            value: 0.9,
          ),
        ],
      ),
      createdAt: DateTime.now(),
      config: {'max_duration_minutes': 3},
    );
  }

  /// Create external help workflow
  static Workflow _createExternalHelpWorkflow() {
    return Workflow(
      id: 'external_help_decision',
      name: 'External Help for Decision',
      description: 'Involves accountability partner or external support for decision-making',
      steps: [
        const WorkflowStep(
          id: 'prepare_decision_summary',
          name: 'Prepare Decision Summary',
          agentId: 'summary_agent',
          parameters: {
            'action': 'summarize_decision',
            'include_options': true,
            'include_context': true,
            'format': 'external_sharing',
          },
          dependsOn: [],
        ),
        const WorkflowStep(
          id: 'notify_accountability_partner',
          name: 'Notify Accountability Partner',
          agentId: 'a2a_agent',
          parameters: {
            'action': 'request_decision_help',
            'decision_summary': '\${prepare_decision_summary_result.summary}',
            'urgency': 'medium',
            'expected_response_time': 30, // 30 minutes
          },
          dependsOn: ['prepare_decision_summary'],
        ),
        const WorkflowStep(
          id: 'wait_for_input',
          name: 'Wait for External Input',
          agentId: 'wait_agent',
          parameters: {
            'max_wait_time': 1800, // 30 minutes
            'fallback_action': 'auto_decide',
          },
          dependsOn: ['notify_accountability_partner'],
        ),
      ],
      trigger: const WorkflowTrigger(
        type: TriggerType.manual,
        config: {'button_text': 'Get External Help'},
      ),
      createdAt: DateTime.now(),
      config: {'max_duration_minutes': 45},
    );
  }

  /// Create postpone decision workflow
  static Workflow _createPostponeDecisionWorkflow() {
    return Workflow(
      id: 'postpone_decision',
      name: 'Postpone Decision Workflow',
      description: 'Safely postpone decision with proper context capture and scheduling',
      steps: [
        const WorkflowStep(
          id: 'capture_decision_state',
          name: 'Capture Current Decision State',
          agentId: 'external_brain',
          parameters: {
            'action': 'capture_decision_state',
            'include_options': true,
            'include_thought_process': true,
            'include_deadline': true,
          },
          dependsOn: [],
        ),
        const WorkflowStep(
          id: 'schedule_decision_time',
          name: 'Schedule Decision Time',
          agentId: 'calendar_agent',
          parameters: {
            'action': 'schedule_decision_time',
            'decision_context': '\${capture_decision_state_result}',
            'suggested_duration': 30, // 30 minutes
            'optimal_energy_time': true,
          },
          dependsOn: ['capture_decision_state'],
        ),
        const WorkflowStep(
          id: 'set_decision_reminder',
          name: 'Set Decision Reminder',
          agentId: 'reminder_agent',
          parameters: {
            'action': 'set_reminder',
            'reminder_time': '\${schedule_decision_time_result.scheduled_time}',
            'context': '\${capture_decision_state_result}',
            'reminder_type': 'decision_followup',
          },
          dependsOn: ['schedule_decision_time'],
        ),
      ],
      trigger: const WorkflowTrigger(
        type: TriggerType.manual,
        config: {'button_text': 'Postpone Decision'},
      ),
      createdAt: DateTime.now(),
      config: {'max_duration_minutes': 5},
    );
  }

  /// Get decision paralysis patterns for learning
  static Map<String, dynamic> getParalysisPatterns() {
    return {
      'common_triggers': [
        'too_many_options',
        'high_stakes_decision',
        'perfectionism',
        'fear_of_regret',
        'analysis_paralysis',
        'low_energy_state',
        'time_pressure',
        'conflicting_priorities',
      ],
      'intervention_strategies': {
        'option_reduction': {
          'effectiveness': 0.85,
          'best_for': ['too_many_options', 'analysis_paralysis'],
          'time_required': 120, // 2 minutes
        },
        'time_pressure': {
          'effectiveness': 0.75,
          'best_for': ['perfectionism', 'analysis_paralysis'],
          'time_required': 60, // 1 minute
        },
        'framework_guidance': {
          'effectiveness': 0.80,
          'best_for': ['conflicting_priorities', 'high_stakes_decision'],
          'time_required': 180, // 3 minutes
        },
        'randomized_choice': {
          'effectiveness': 0.60,
          'best_for': ['severe_paralysis', 'low_energy_state'],
          'time_required': 30, // 30 seconds
        },
      },
      'success_metrics': {
        'decision_made_within_time_limit': 0.80,
        'user_satisfaction_with_process': 0.75,
        'decision_quality_rating': 0.70,
        'reduced_future_paralysis': 0.65,
      },
    };
  }

  /// Get adaptive configuration based on paralysis level
  static Map<String, dynamic> getAdaptiveConfig(double paralysisLevel) {
    if (paralysisLevel > 0.8) {
      // Severe paralysis - emergency intervention
      return {
        'max_duration_minutes': 5,
        'max_options': 2,
        'use_emergency_simplification': true,
        'auto_decide_threshold': 120, // 2 minutes
        'intervention_intensity': 'high',
      };
    } else if (paralysisLevel > 0.6) {
      // Moderate paralysis - structured intervention
      return {
        'max_duration_minutes': 10,
        'max_options': 3,
        'use_structured_framework': true,
        'auto_decide_threshold': 300, // 5 minutes
        'intervention_intensity': 'medium',
      };
    } else {
      // Mild paralysis - gentle guidance
      return {
        'max_duration_minutes': 15,
        'max_options': 5,
        'use_gentle_guidance': true,
        'auto_decide_threshold': 600, // 10 minutes
        'intervention_intensity': 'low',
      };
    }
  }
}