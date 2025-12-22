import 'agent_model.dart';

/// Defines a workflow that orchestrates multiple agents
class Workflow {
  final String id;
  final String name;
  final String description;
  final List<WorkflowStep> steps;
  final WorkflowTrigger trigger;
  final Map<String, dynamic> config;
  final WorkflowStatus status;
  final DateTime createdAt;
  final DateTime? lastExecuted;
  final int executionCount;
  final double successRate;

  const Workflow({
    required this.id,
    required this.name,
    required this.description,
    required this.steps,
    required this.trigger,
    this.config = const {},
    this.status = WorkflowStatus.active,
    required this.createdAt,
    this.lastExecuted,
    this.executionCount = 0,
    this.successRate = 0.0,
  });

  Workflow copyWith({
    String? id,
    String? name,
    String? description,
    List<WorkflowStep>? steps,
    WorkflowTrigger? trigger,
    Map<String, dynamic>? config,
    WorkflowStatus? status,
    DateTime? createdAt,
    DateTime? lastExecuted,
    int? executionCount,
    double? successRate,
  }) {
    return Workflow(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      steps: steps ?? this.steps,
      trigger: trigger ?? this.trigger,
      config: config ?? this.config,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      lastExecuted: lastExecuted ?? this.lastExecuted,
      executionCount: executionCount ?? this.executionCount,
      successRate: successRate ?? this.successRate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'steps': steps.map((s) => s.toJson()).toList(),
      'trigger': trigger.toJson(),
      'config': config,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'last_executed': lastExecuted?.toIso8601String(),
      'execution_count': executionCount,
      'success_rate': successRate,
    };
  }

  factory Workflow.fromJson(Map<String, dynamic> json) {
    return Workflow(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      steps: (json['steps'] as List<dynamic>)
          .map((s) => WorkflowStep.fromJson(s as Map<String, dynamic>))
          .toList(),
      trigger: WorkflowTrigger.fromJson(json['trigger'] as Map<String, dynamic>),
      config: json['config'] as Map<String, dynamic>? ?? {},
      status: WorkflowStatus.values.firstWhere((e) => e.name == json['status']),
      createdAt: DateTime.parse(json['created_at'] as String),
      lastExecuted: json['last_executed'] != null 
          ? DateTime.parse(json['last_executed'] as String) 
          : null,
      executionCount: json['execution_count'] as int? ?? 0,
      successRate: (json['success_rate'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

enum WorkflowStatus {
  active,
  paused,
  disabled,
  error,
}

/// Individual step in a workflow
class WorkflowStep {
  final String id;
  final String name;
  final String agentId;
  final ExecutionType executionType;
  final Map<String, dynamic> parameters;
  final List<WorkflowCondition> conditions;
  final List<String> dependsOn;
  final Duration? timeout;
  final int retryCount;
  final WorkflowStepAction onSuccess;
  final WorkflowStepAction onFailure;

  const WorkflowStep({
    required this.id,
    required this.name,
    required this.agentId,
    this.executionType = ExecutionType.sequential,
    this.parameters = const {},
    this.conditions = const [],
    this.dependsOn = const [],
    this.timeout,
    this.retryCount = 0,
    this.onSuccess = WorkflowStepAction.continue_,
    this.onFailure = WorkflowStepAction.stop,
  });

  WorkflowStep copyWith({
    String? id,
    String? name,
    String? agentId,
    ExecutionType? executionType,
    Map<String, dynamic>? parameters,
    List<WorkflowCondition>? conditions,
    List<String>? dependsOn,
    Duration? timeout,
    int? retryCount,
    WorkflowStepAction? onSuccess,
    WorkflowStepAction? onFailure,
  }) {
    return WorkflowStep(
      id: id ?? this.id,
      name: name ?? this.name,
      agentId: agentId ?? this.agentId,
      executionType: executionType ?? this.executionType,
      parameters: parameters ?? this.parameters,
      conditions: conditions ?? this.conditions,
      dependsOn: dependsOn ?? this.dependsOn,
      timeout: timeout ?? this.timeout,
      retryCount: retryCount ?? this.retryCount,
      onSuccess: onSuccess ?? this.onSuccess,
      onFailure: onFailure ?? this.onFailure,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'agent_id': agentId,
      'execution_type': executionType.name,
      'parameters': parameters,
      'conditions': conditions.map((c) => c.toJson()).toList(),
      'depends_on': dependsOn,
      'timeout': timeout?.inMilliseconds,
      'retry_count': retryCount,
      'on_success': onSuccess.name,
      'on_failure': onFailure.name,
    };
  }

  factory WorkflowStep.fromJson(Map<String, dynamic> json) {
    return WorkflowStep(
      id: json['id'] as String,
      name: json['name'] as String,
      agentId: json['agent_id'] as String,
      executionType: ExecutionType.values.firstWhere((e) => e.name == json['execution_type']),
      parameters: json['parameters'] as Map<String, dynamic>? ?? {},
      conditions: (json['conditions'] as List<dynamic>?)
          ?.map((c) => WorkflowCondition.fromJson(c as Map<String, dynamic>))
          .toList() ?? [],
      dependsOn: (json['depends_on'] as List<dynamic>?)?.cast<String>() ?? [],
      timeout: json['timeout'] != null ? Duration(milliseconds: json['timeout'] as int) : null,
      retryCount: json['retry_count'] as int? ?? 0,
      onSuccess: WorkflowStepAction.values.firstWhere((e) => e.name == json['on_success']),
      onFailure: WorkflowStepAction.values.firstWhere((e) => e.name == json['on_failure']),
    );
  }
}

enum ExecutionType {
  sequential,  // Execute after previous step completes
  parallel,    // Execute in parallel with other parallel steps
  conditional, // Execute only if conditions are met
  interrupt,   // Can interrupt other steps
}

enum WorkflowStepAction {
  continue_,   // Continue to next step
  stop,        // Stop workflow execution
  retry,       // Retry this step
  skip,        // Skip to next step
  branch,      // Branch to different workflow path
}

/// Condition that must be met for a step to execute
class WorkflowCondition {
  final String field;
  final ConditionOperator operator;
  final dynamic value;
  final String? source; // Where to get the field value from

  const WorkflowCondition({
    required this.field,
    required this.operator,
    required this.value,
    this.source,
  });

  WorkflowCondition copyWith({
    String? field,
    ConditionOperator? operator,
    dynamic value,
    String? source,
  }) {
    return WorkflowCondition(
      field: field ?? this.field,
      operator: operator ?? this.operator,
      value: value ?? this.value,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'field': field,
      'operator': operator.name,
      'value': value,
      'source': source,
    };
  }

  factory WorkflowCondition.fromJson(Map<String, dynamic> json) {
    return WorkflowCondition(
      field: json['field'] as String,
      operator: ConditionOperator.values.firstWhere((e) => e.name == json['operator']),
      value: json['value'],
      source: json['source'] as String?,
    );
  }

  bool evaluate(Map<String, dynamic> context) {
    dynamic actualValue;
    if (source != null) {
      final sourceData = context[source] as Map<String, dynamic>?;
      actualValue = sourceData?[field];
    } else {
      actualValue = context[field];
    }
    
    switch (operator) {
      case ConditionOperator.equals:
        return actualValue == value;
      case ConditionOperator.notEquals:
        return actualValue != value;
      case ConditionOperator.greaterThan:
        return (actualValue as num?) != null && (actualValue as num) > (value as num);
      case ConditionOperator.lessThan:
        return (actualValue as num?) != null && (actualValue as num) < (value as num);
      case ConditionOperator.greaterThanOrEqual:
        return (actualValue as num?) != null && (actualValue as num) >= (value as num);
      case ConditionOperator.lessThanOrEqual:
        return (actualValue as num?) != null && (actualValue as num) <= (value as num);
      case ConditionOperator.contains:
        return actualValue?.toString().contains(value.toString()) ?? false;
      case ConditionOperator.notContains:
        return !(actualValue?.toString().contains(value.toString()) ?? false);
      case ConditionOperator.exists:
        return actualValue != null;
      case ConditionOperator.notExists:
        return actualValue == null;
    }
  }
}

enum ConditionOperator {
  equals,
  notEquals,
  greaterThan,
  lessThan,
  greaterThanOrEqual,
  lessThanOrEqual,
  contains,
  notContains,
  exists,
  notExists,
}

/// Defines what triggers a workflow to execute
class WorkflowTrigger {
  final TriggerType type;
  final Map<String, dynamic> config;
  final List<WorkflowCondition> conditions;
  final Duration? cooldown;

  const WorkflowTrigger({
    required this.type,
    this.config = const {},
    this.conditions = const [],
    this.cooldown,
  });

  WorkflowTrigger copyWith({
    TriggerType? type,
    Map<String, dynamic>? config,
    List<WorkflowCondition>? conditions,
    Duration? cooldown,
  }) {
    return WorkflowTrigger(
      type: type ?? this.type,
      config: config ?? this.config,
      conditions: conditions ?? this.conditions,
      cooldown: cooldown ?? this.cooldown,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'config': config,
      'conditions': conditions.map((c) => c.toJson()).toList(),
      'cooldown': cooldown?.inMilliseconds,
    };
  }

  factory WorkflowTrigger.fromJson(Map<String, dynamic> json) {
    return WorkflowTrigger(
      type: TriggerType.values.firstWhere((e) => e.name == json['type']),
      config: json['config'] as Map<String, dynamic>? ?? {},
      conditions: (json['conditions'] as List<dynamic>?)
          ?.map((c) => WorkflowCondition.fromJson(c as Map<String, dynamic>))
          .toList() ?? [],
      cooldown: json['cooldown'] != null ? Duration(milliseconds: json['cooldown'] as int) : null,
    );
  }
}

enum TriggerType {
  manual,      // User manually triggers
  scheduled,   // Time-based trigger
  event,       // Triggered by system event
  condition,   // Triggered when conditions are met
  agent,       // Triggered by another agent
}

/// Execution state of a workflow
class WorkflowExecution {
  final String id;
  final String workflowId;
  final ExecutionContext context;
  final WorkflowExecutionStatus status;
  final DateTime startTime;
  final DateTime? endTime;
  final List<WorkflowStepExecution> stepExecutions;
  final String? error;
  final Map<String, dynamic> results;

  const WorkflowExecution({
    required this.id,
    required this.workflowId,
    required this.context,
    this.status = WorkflowExecutionStatus.pending,
    required this.startTime,
    this.endTime,
    this.stepExecutions = const [],
    this.error,
    this.results = const {},
  });

  WorkflowExecution copyWith({
    String? id,
    String? workflowId,
    ExecutionContext? context,
    WorkflowExecutionStatus? status,
    DateTime? startTime,
    DateTime? endTime,
    List<WorkflowStepExecution>? stepExecutions,
    String? error,
    Map<String, dynamic>? results,
  }) {
    return WorkflowExecution(
      id: id ?? this.id,
      workflowId: workflowId ?? this.workflowId,
      context: context ?? this.context,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      stepExecutions: stepExecutions ?? this.stepExecutions,
      error: error ?? this.error,
      results: results ?? this.results,
    );
  }

  Duration? get executionTime {
    if (endTime != null) {
      return endTime!.difference(startTime);
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'workflow_id': workflowId,
      'context': context.toJson(),
      'status': status.name,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'step_executions': stepExecutions.map((s) => s.toJson()).toList(),
      'error': error,
      'results': results,
    };
  }

  factory WorkflowExecution.fromJson(Map<String, dynamic> json) {
    return WorkflowExecution(
      id: json['id'] as String,
      workflowId: json['workflow_id'] as String,
      context: ExecutionContext.fromJson(json['context'] as Map<String, dynamic>),
      status: WorkflowExecutionStatus.values.firstWhere((e) => e.name == json['status']),
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null ? DateTime.parse(json['end_time'] as String) : null,
      stepExecutions: (json['step_executions'] as List<dynamic>?)
          ?.map((s) => WorkflowStepExecution.fromJson(s as Map<String, dynamic>))
          .toList() ?? [],
      error: json['error'] as String?,
      results: json['results'] as Map<String, dynamic>? ?? {},
    );
  }
}

enum WorkflowExecutionStatus {
  pending,
  running,
  completed,
  failed,
  cancelled,
  paused,
}

/// Execution state of a workflow step
class WorkflowStepExecution {
  final String stepId;
  final String agentId;
  final WorkflowStepExecutionStatus status;
  final DateTime startTime;
  final DateTime? endTime;
  final AgentResult? result;
  final String? error;
  final int attemptCount;

  const WorkflowStepExecution({
    required this.stepId,
    required this.agentId,
    this.status = WorkflowStepExecutionStatus.pending,
    required this.startTime,
    this.endTime,
    this.result,
    this.error,
    this.attemptCount = 1,
  });

  WorkflowStepExecution copyWith({
    String? stepId,
    String? agentId,
    WorkflowStepExecutionStatus? status,
    DateTime? startTime,
    DateTime? endTime,
    AgentResult? result,
    String? error,
    int? attemptCount,
  }) {
    return WorkflowStepExecution(
      stepId: stepId ?? this.stepId,
      agentId: agentId ?? this.agentId,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      result: result ?? this.result,
      error: error ?? this.error,
      attemptCount: attemptCount ?? this.attemptCount,
    );
  }

  Duration? get executionTime {
    if (endTime != null) {
      return endTime!.difference(startTime);
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'step_id': stepId,
      'agent_id': agentId,
      'status': status.name,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'result': result?.toJson(),
      'error': error,
      'attempt_count': attemptCount,
    };
  }

  factory WorkflowStepExecution.fromJson(Map<String, dynamic> json) {
    return WorkflowStepExecution(
      stepId: json['step_id'] as String,
      agentId: json['agent_id'] as String,
      status: WorkflowStepExecutionStatus.values.firstWhere((e) => e.name == json['status']),
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null ? DateTime.parse(json['end_time'] as String) : null,
      result: json['result'] != null ? AgentResult.fromJson(json['result'] as Map<String, dynamic>) : null,
      error: json['error'] as String?,
      attemptCount: json['attempt_count'] as int? ?? 1,
    );
  }
}

enum WorkflowStepExecutionStatus {
  pending,
  running,
  completed,
  failed,
  skipped,
  cancelled,
}