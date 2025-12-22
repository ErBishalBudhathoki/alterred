import '../models/workflow_model.dart';
import '../agents/energy_assessment_agent.dart';
import '../agents/time_estimation_agent.dart';

/// Morning routine workflow that orchestrates startup activities
class MorningRoutineWorkflow {
  static const String workflowId = 'morning_routine';
  
  /// Create the morning routine workflow
  static Workflow createWorkflow() {
    return Workflow(
      id: workflowId,
      name: 'Morning Routine Workflow',
      description: 'Orchestrates morning startup routine with energy assessment, calendar review, and task planning',
      steps: _createWorkflowSteps(),
      trigger: const WorkflowTrigger(
        type: TriggerType.scheduled,
        config: {
          'time': '08:00',
          'days': ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'],
          'timezone': 'local',
        },
        conditions: [
          WorkflowCondition(
            field: 'user_awake',
            operator: ConditionOperator.equals,
            value: true,
          ),
        ],
      ),
      createdAt: DateTime.now(),
      config: {
        'max_duration_minutes': 30,
        'allow_skip_steps': true,
        'adaptive_timing': true,
      },
    );
  }

  /// Create workflow steps
  static List<WorkflowStep> _createWorkflowSteps() {
    return [
      // Step 1: Energy Assessment (Foundation)
      const WorkflowStep(
        id: 'energy_assessment',
        name: 'Morning Energy Assessment',
        agentId: EnergyAssessmentAgent.agentId,
        executionType: ExecutionType.sequential,
        parameters: {
          'action': 'assess_energy',
          'include_sleep_quality': true,
          'include_mood': true,
          'morning_assessment': true,
        },
        conditions: [],
        dependsOn: [],
        timeout: Duration(minutes: 2),
        retryCount: 1,
        onSuccess: WorkflowStepAction.continue_,
        onFailure: WorkflowStepAction.continue_, // Continue even if assessment fails
      ),

      // Step 2: Calendar Review (Parallel with Context Capture)
      const WorkflowStep(
        id: 'calendar_review',
        name: 'Review Today\'s Schedule',
        agentId: 'calendar_guardian', // Would be implemented as part of external brain
        executionType: ExecutionType.parallel,
        parameters: {
          'action': 'review_today',
          'include_conflicts': true,
          'include_preparation_time': true,
          'energy_context': '\${energy_assessment_result.energy_level}',
        },
        conditions: [],
        dependsOn: ['energy_assessment'],
        timeout: Duration(minutes: 3),
        retryCount: 2,
        onSuccess: WorkflowStepAction.continue_,
        onFailure: WorkflowStepAction.continue_,
      ),

      // Step 3: Capture Overnight Thoughts (Parallel with Calendar)
      const WorkflowStep(
        id: 'capture_overnight_thoughts',
        name: 'Capture Overnight Thoughts',
        agentId: 'external_brain', // Would integrate with external brain agent
        executionType: ExecutionType.parallel,
        parameters: {
          'action': 'capture_thoughts',
          'context': 'morning_routine',
          'prompt_user': true,
          'timeout_seconds': 120, // 2 minutes max
        },
        conditions: [],
        dependsOn: ['energy_assessment'],
        timeout: Duration(minutes: 2),
        retryCount: 0, // Don't retry thought capture
        onSuccess: WorkflowStepAction.continue_,
        onFailure: WorkflowStepAction.continue_,
      ),

      // Step 4: Task Prioritization (Depends on Energy + Calendar)
      const WorkflowStep(
        id: 'task_prioritization',
        name: 'Prioritize Today\'s Tasks',
        agentId: 'task_prioritization', // Would integrate with task prioritization agent
        executionType: ExecutionType.sequential,
        parameters: {
          'action': 'prioritize_tasks',
          'energy_level': '\${energy_assessment_result.energy_level}',
          'calendar_events': '\${calendar_review_result.events}',
          'available_time_blocks': '\${calendar_review_result.free_blocks}',
          'captured_thoughts': '\${capture_overnight_thoughts_result.thoughts}',
          'mode': 'morning_planning',
        },
        conditions: [
          WorkflowCondition(
            field: 'energy_assessment_result',
            operator: ConditionOperator.exists,
            value: null,
          ),
        ],
        dependsOn: ['energy_assessment', 'calendar_review'],
        timeout: Duration(minutes: 5),
        retryCount: 1,
        onSuccess: WorkflowStepAction.continue_,
        onFailure: WorkflowStepAction.continue_,
      ),

      // Step 5: Time Estimation for Priority Tasks
      const WorkflowStep(
        id: 'time_estimation',
        name: 'Estimate Task Durations',
        agentId: TimeEstimationAgent.agentId,
        executionType: ExecutionType.sequential,
        parameters: {
          'type': 'estimate_multiple',
          'tasks': '\${task_prioritization_result.priority_tasks}',
          'energy_context': '\${energy_assessment_result.energy_level}',
          'available_time': '\${calendar_review_result.total_free_time}',
          'morning_estimation': true,
        },
        conditions: [
          WorkflowCondition(
            field: 'task_prioritization_result.priority_tasks',
            operator: ConditionOperator.exists,
            value: null,
          ),
        ],
        dependsOn: ['task_prioritization'],
        timeout: Duration(minutes: 3),
        retryCount: 1,
        onSuccess: WorkflowStepAction.continue_,
        onFailure: WorkflowStepAction.continue_,
      ),

      // Step 6: Create Daily Plan (Final Integration)
      const WorkflowStep(
        id: 'create_daily_plan',
        name: 'Create Integrated Daily Plan',
        agentId: 'planning_agent', // Would be a new planning coordination agent
        executionType: ExecutionType.sequential,
        parameters: {
          'action': 'create_daily_plan',
          'energy_assessment': '\${energy_assessment_result}',
          'calendar_events': '\${calendar_review_result.events}',
          'priority_tasks': '\${task_prioritization_result.priority_tasks}',
          'time_estimates': '\${time_estimation_result.individual_estimates}',
          'captured_thoughts': '\${capture_overnight_thoughts_result.thoughts}',
          'plan_type': 'adaptive_daily_plan',
        },
        conditions: [],
        dependsOn: ['time_estimation'],
        timeout: Duration(minutes: 4),
        retryCount: 1,
        onSuccess: WorkflowStepAction.continue_,
        onFailure: WorkflowStepAction.continue_,
      ),

      // Step 7: Set Up Monitoring (Proactive Setup)
      const WorkflowStep(
        id: 'setup_monitoring',
        name: 'Set Up Daily Monitoring',
        agentId: 'hyperfocus_detection', // Set up proactive monitoring
        executionType: ExecutionType.sequential,
        parameters: {
          'action': 'start_monitoring',
          'daily_plan': '\${create_daily_plan_result.plan}',
          'energy_baseline': '\${energy_assessment_result.energy_level}',
          'break_schedule': '\${create_daily_plan_result.break_schedule}',
          'monitoring_mode': 'daily_routine',
        },
        conditions: [],
        dependsOn: ['create_daily_plan'],
        timeout: Duration(minutes: 1),
        retryCount: 0,
        onSuccess: WorkflowStepAction.continue_,
        onFailure: WorkflowStepAction.continue_,
      ),

      // Step 8: Morning Summary & Recommendations
      const WorkflowStep(
        id: 'morning_summary',
        name: 'Generate Morning Summary',
        agentId: 'summary_agent', // Would be a new summary/reporting agent
        executionType: ExecutionType.sequential,
        parameters: {
          'action': 'generate_morning_summary',
          'energy_level': '\${energy_assessment_result.energy_level}',
          'daily_plan': '\${create_daily_plan_result.plan}',
          'key_tasks': '\${task_prioritization_result.top_3_tasks}',
          'estimated_workload': '\${time_estimation_result.total_estimate_minutes}',
          'recommendations': '\${energy_assessment_result.recommendations}',
          'include_motivational_message': true,
        },
        conditions: [],
        dependsOn: ['setup_monitoring'],
        timeout: Duration(minutes: 2),
        retryCount: 0,
        onSuccess: WorkflowStepAction.continue_,
        onFailure: WorkflowStepAction.continue_,
      ),
    ];
  }

  /// Get workflow configuration for different energy levels
  static Map<String, dynamic> getAdaptiveConfig(double energyLevel) {
    if (energyLevel < 0.3) {
      // Low energy morning
      return {
        'max_duration_minutes': 20, // Shorter routine
        'skip_optional_steps': true,
        'gentle_mode': true,
        'reduced_task_count': 3,
        'extended_breaks': true,
      };
    } else if (energyLevel > 0.8) {
      // High energy morning
      return {
        'max_duration_minutes': 40, // Longer, more thorough routine
        'include_stretch_goals': true,
        'detailed_planning': true,
        'ambitious_task_count': 8,
        'optimization_focus': true,
      };
    } else {
      // Normal energy morning
      return {
        'max_duration_minutes': 30,
        'balanced_approach': true,
        'standard_task_count': 5,
        'regular_breaks': true,
      };
    }
  }

  /// Get morning routine triggers
  static List<WorkflowTrigger> getMorningTriggers() {
    return [
      // Scheduled trigger (primary)
      const WorkflowTrigger(
        type: TriggerType.scheduled,
        config: {
          'time': '08:00',
          'days': ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'],
          'timezone': 'local',
        },
        conditions: [
          WorkflowCondition(
            field: 'user_awake',
            operator: ConditionOperator.equals,
            value: true,
          ),
        ],
      ),

      // Manual trigger (backup)
      const WorkflowTrigger(
        type: TriggerType.manual,
        config: {
          'button_text': 'Start Morning Routine',
          'description': 'Manually trigger morning routine workflow',
        },
      ),

      // Event trigger (when user opens app in morning)
      WorkflowTrigger(
        type: TriggerType.event,
        config: {
          'event_type': 'app_opened_morning',
          'time_window': {'start': '06:00', 'end': '11:00'},
        },
        conditions: [
          WorkflowCondition(
            field: 'last_morning_routine',
            operator: ConditionOperator.lessThan,
            value: DateTime.now().subtract(const Duration(hours: 20)).millisecondsSinceEpoch,
          ),
        ],
      ),
    ];
  }

  /// Get success criteria for morning routine
  static Map<String, dynamic> getSuccessCriteria() {
    return {
      'minimum_steps_completed': 5, // At least 5 out of 8 steps
      'energy_assessment_required': true,
      'task_prioritization_required': true,
      'max_duration_minutes': 45,
      'user_satisfaction_threshold': 0.7,
    };
  }

  /// Get morning routine variations
  static Map<String, Workflow> getWorkflowVariations() {
    return {
      'quick_morning': _createQuickMorningWorkflow(),
      'detailed_morning': _createDetailedMorningWorkflow(),
      'weekend_morning': _createWeekendMorningWorkflow(),
    };
  }

  /// Create quick morning workflow (5-10 minutes)
  static Workflow _createQuickMorningWorkflow() {
    return Workflow(
      id: 'quick_morning_routine',
      name: 'Quick Morning Routine',
      description: 'Streamlined 5-10 minute morning routine for busy days',
      steps: [
        const WorkflowStep(
          id: 'quick_energy_check',
          name: 'Quick Energy Check',
          agentId: EnergyAssessmentAgent.agentId,
          parameters: {'action': 'quick_assessment'},
          dependsOn: [],
        ),
        const WorkflowStep(
          id: 'top_3_tasks',
          name: 'Identify Top 3 Tasks',
          agentId: 'task_prioritization',
          parameters: {'action': 'quick_prioritize', 'max_tasks': 3},
          dependsOn: ['quick_energy_check'],
        ),
        const WorkflowStep(
          id: 'quick_time_estimate',
          name: 'Quick Time Estimates',
          agentId: TimeEstimationAgent.agentId,
          parameters: {'type': 'estimate_multiple', 'quick_mode': true},
          dependsOn: ['top_3_tasks'],
        ),
      ],
      trigger: const WorkflowTrigger(
        type: TriggerType.manual,
        config: {'button_text': 'Quick Morning Start'},
      ),
      createdAt: DateTime.now(),
      config: {'max_duration_minutes': 10},
    );
  }

  /// Create detailed morning workflow (45-60 minutes)
  static Workflow _createDetailedMorningWorkflow() {
    return Workflow(
      id: 'detailed_morning_routine',
      name: 'Detailed Morning Routine',
      description: 'Comprehensive morning routine with deep planning and reflection',
      steps: [
        // All standard steps plus additional ones
        ...createWorkflow().steps,
        const WorkflowStep(
          id: 'weekly_review',
          name: 'Weekly Progress Review',
          agentId: 'review_agent',
          parameters: {'action': 'weekly_review', 'include_goals': true},
          dependsOn: ['morning_summary'],
        ),
        const WorkflowStep(
          id: 'goal_alignment',
          name: 'Align Tasks with Goals',
          agentId: 'goal_agent',
          parameters: {'action': 'align_daily_tasks'},
          dependsOn: ['weekly_review'],
        ),
      ],
      trigger: const WorkflowTrigger(
        type: TriggerType.scheduled,
        config: {'time': '07:30', 'days': ['monday']}, // Monday deep planning
      ),
      createdAt: DateTime.now(),
      config: {'max_duration_minutes': 60},
    );
  }

  /// Create weekend morning workflow
  static Workflow _createWeekendMorningWorkflow() {
    return Workflow(
      id: 'weekend_morning_routine',
      name: 'Weekend Morning Routine',
      description: 'Relaxed weekend morning routine focused on personal projects and well-being',
      steps: [
        const WorkflowStep(
          id: 'weekend_energy_assessment',
          name: 'Weekend Energy & Mood Check',
          agentId: EnergyAssessmentAgent.agentId,
          parameters: {
            'action': 'assess_energy',
            'weekend_mode': true,
            'include_wellbeing': true,
          },
          dependsOn: [],
        ),
        const WorkflowStep(
          id: 'personal_project_review',
          name: 'Review Personal Projects',
          agentId: 'project_agent',
          parameters: {'action': 'review_personal_projects'},
          dependsOn: ['weekend_energy_assessment'],
        ),
        const WorkflowStep(
          id: 'weekend_planning',
          name: 'Plan Weekend Activities',
          agentId: 'task_prioritization',
          parameters: {
            'action': 'weekend_planning',
            'include_fun_activities': true,
            'balance_work_rest': true,
          },
          dependsOn: ['personal_project_review'],
        ),
      ],
      trigger: const WorkflowTrigger(
        type: TriggerType.scheduled,
        config: {'time': '09:00', 'days': ['saturday', 'sunday']},
      ),
      createdAt: DateTime.now(),
      config: {'max_duration_minutes': 25, 'relaxed_mode': true},
    );
  }
}