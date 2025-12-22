import 'dart:async';
import '../models/agent_model.dart';
import '../models/workflow_model.dart';
import 'agent_registry.dart';
// import 'safety_monitor.dart'; // Unused

/// Executes workflows by coordinating agent execution
class WorkflowExecutor {
  static final WorkflowExecutor _instance = WorkflowExecutor._internal();
  factory WorkflowExecutor() => _instance;
  WorkflowExecutor._internal();

  final AgentRegistry _agentRegistry = AgentRegistry();
  // final SafetyMonitor _safetyMonitor = SafetyMonitor(); // Unused
  final StreamController<WorkflowExecutionEvent> _eventController =
      StreamController<WorkflowExecutionEvent>.broadcast();

  final Map<String, WorkflowExecution> _activeExecutions = {};
  final Map<String, Timer> _timeoutTimers = {};

  /// Stream of workflow execution events
  Stream<WorkflowExecutionEvent> get events => _eventController.stream;

  /// Execute a workflow
  Future<WorkflowExecution> executeWorkflow(
      Workflow workflow, ExecutionContext context) async {
    final executionId = 'exec_${DateTime.now().millisecondsSinceEpoch}';

    final execution = WorkflowExecution(
      id: executionId,
      workflowId: workflow.id,
      context: context,
      status: WorkflowExecutionStatus.pending,
      startTime: DateTime.now(),
    );

    _activeExecutions[executionId] = execution;

    _eventController.add(WorkflowExecutionEvent(
      type: WorkflowExecutionEventType.started,
      executionId: executionId,
      workflowId: workflow.id,
      data: {'context': context.toJson()},
      timestamp: DateTime.now(),
    ));

    try {
      // Validate workflow
      final validationResult = await _validateWorkflow(workflow, context);
      if (!validationResult.isValid) {
        return await _completeExecution(
          executionId,
          WorkflowExecutionStatus.failed,
          error: validationResult.error,
        );
      }

      // Update execution status
      _activeExecutions[executionId] = execution.copyWith(
        status: WorkflowExecutionStatus.running,
      );

      // Execute workflow steps
      final result = await _executeWorkflowSteps(workflow, execution);

      return result;
    } catch (error) {
      return await _completeExecution(
        executionId,
        WorkflowExecutionStatus.failed,
        error: error.toString(),
      );
    }
  }

  /// Execute workflow steps
  Future<WorkflowExecution> _executeWorkflowSteps(
      Workflow workflow, WorkflowExecution execution) async {
    final stepExecutions = <WorkflowStepExecution>[];
    final executionContext = <String, dynamic>{};

    // Build dependency graph
    final dependencyGraph = _buildDependencyGraph(workflow.steps);

    // Execute steps in dependency order
    final executionOrder = _getExecutionOrder(dependencyGraph);

    for (final stepGroup in executionOrder) {
      // Check if execution should be cancelled
      if (_shouldCancelExecution(execution.id)) {
        return await _completeExecution(
          execution.id,
          WorkflowExecutionStatus.cancelled,
        );
      }

      // Execute step group (parallel or sequential)
      final groupResults = await _executeStepGroup(
          stepGroup, workflow, execution, executionContext);

      stepExecutions.addAll(groupResults);

      // Check for failures
      final failures = groupResults
          .where((r) => r.status == WorkflowStepExecutionStatus.failed)
          .toList();

      if (failures.isNotEmpty) {
        // Handle step failures
        final shouldContinue =
            await _handleStepFailures(failures, workflow, execution);

        if (!shouldContinue) {
          return await _completeExecution(
            execution.id,
            WorkflowExecutionStatus.failed,
            stepExecutions: stepExecutions,
          );
        }
      }
    }

    // Complete successful execution
    return await _completeExecution(
      execution.id,
      WorkflowExecutionStatus.completed,
      stepExecutions: stepExecutions,
      results: executionContext,
    );
  }

  /// Execute a group of steps
  Future<List<WorkflowStepExecution>> _executeStepGroup(
    List<WorkflowStep> steps,
    Workflow workflow,
    WorkflowExecution execution,
    Map<String, dynamic> executionContext,
  ) async {
    final results = <WorkflowStepExecution>[];

    // Determine execution type
    final hasParallelSteps =
        steps.any((s) => s.executionType == ExecutionType.parallel);

    if (hasParallelSteps && steps.length > 1) {
      // Execute parallel steps
      results.addAll(await _executeStepsParallel(
          steps, workflow, execution, executionContext));
    } else {
      // Execute sequential steps
      results.addAll(await _executeStepsSequential(
          steps, workflow, execution, executionContext));
    }

    return results;
  }

  /// Execute steps in parallel
  Future<List<WorkflowStepExecution>> _executeStepsParallel(
    List<WorkflowStep> steps,
    Workflow workflow,
    WorkflowExecution execution,
    Map<String, dynamic> executionContext,
  ) async {
    final futures = steps.map((step) =>
        _executeSingleStep(step, workflow, execution, executionContext));

    final results = await Future.wait(futures);
    return results;
  }

  /// Execute steps sequentially
  Future<List<WorkflowStepExecution>> _executeStepsSequential(
    List<WorkflowStep> steps,
    Workflow workflow,
    WorkflowExecution execution,
    Map<String, dynamic> executionContext,
  ) async {
    final results = <WorkflowStepExecution>[];

    for (final step in steps) {
      final result =
          await _executeSingleStep(step, workflow, execution, executionContext);

      results.add(result);

      // Handle step result
      if (result.status == WorkflowStepExecutionStatus.failed) {
        final step = workflow.steps.firstWhere((s) => s.id == result.stepId);

        if (step.onFailure == WorkflowStepAction.stop) {
          break;
        } else if (step.onFailure == WorkflowStepAction.retry &&
            result.attemptCount < step.retryCount) {
          // Retry the step
          final retryResult = await _executeSingleStep(
            step,
            workflow,
            execution,
            executionContext,
            attemptCount: result.attemptCount + 1,
          );
          results.add(retryResult);
        }
      }
    }

    return results;
  }

  /// Execute a single workflow step
  Future<WorkflowStepExecution> _executeSingleStep(
    WorkflowStep step,
    Workflow workflow,
    WorkflowExecution execution,
    Map<String, dynamic> executionContext, {
    int attemptCount = 1,
  }) async {
    final stepExecution = WorkflowStepExecution(
      stepId: step.id,
      agentId: step.agentId,
      status: WorkflowStepExecutionStatus.pending,
      startTime: DateTime.now(),
      attemptCount: attemptCount,
    );

    _eventController.add(WorkflowExecutionEvent(
      type: WorkflowExecutionEventType.stepStarted,
      executionId: execution.id,
      workflowId: workflow.id,
      data: {
        'step_id': step.id,
        'agent_id': step.agentId,
        'attempt': attemptCount,
      },
      timestamp: DateTime.now(),
    ));

    try {
      // Check step conditions
      if (!await _checkStepConditions(step, executionContext)) {
        return stepExecution.copyWith(
          status: WorkflowStepExecutionStatus.skipped,
          endTime: DateTime.now(),
        );
      }

      // Get agent
      final agent = _agentRegistry.getAgent(step.agentId);
      if (agent == null) {
        throw WorkflowExecutionException('Agent ${step.agentId} not found');
      }

      // Prepare execution context
      final stepContext = execution.context.copyWith(
        parameters: {
          ...execution.context.parameters,
          ...step.parameters,
          'workflow_id': workflow.id,
          'execution_id': execution.id,
          'step_id': step.id,
          'execution_context': executionContext,
        },
      );

      // Set timeout if specified
      Timer? timeoutTimer;
      if (step.timeout != null) {
        timeoutTimer = Timer(step.timeout!, () {
          // Handle timeout
          _eventController.add(WorkflowExecutionEvent(
            type: WorkflowExecutionEventType.stepTimeout,
            executionId: execution.id,
            workflowId: workflow.id,
            data: {
              'step_id': step.id,
              'timeout_duration': step.timeout!.inMilliseconds,
            },
            timestamp: DateTime.now(),
          ));
        });
      }

      // Execute agent
      final agentResult = await agent.execute(stepContext);

      // Cancel timeout timer
      timeoutTimer?.cancel();

      // Update execution context with results
      if (agentResult.success) {
        executionContext['${step.id}_result'] = agentResult.data;
        executionContext['last_successful_step'] = step.id;
      }

      final finalStepExecution = stepExecution.copyWith(
        status: agentResult.success
            ? WorkflowStepExecutionStatus.completed
            : WorkflowStepExecutionStatus.failed,
        endTime: DateTime.now(),
        result: agentResult,
        error: agentResult.success ? null : agentResult.error,
      );

      _eventController.add(WorkflowExecutionEvent(
        type: agentResult.success
            ? WorkflowExecutionEventType.stepCompleted
            : WorkflowExecutionEventType.stepFailed,
        executionId: execution.id,
        workflowId: workflow.id,
        data: {
          'step_id': step.id,
          'agent_id': step.agentId,
          'result': agentResult.toJson(),
        },
        timestamp: DateTime.now(),
      ));

      return finalStepExecution;
    } catch (error) {
      return stepExecution.copyWith(
        status: WorkflowStepExecutionStatus.failed,
        endTime: DateTime.now(),
        error: error.toString(),
      );
    }
  }

  /// Check step conditions
  Future<bool> _checkStepConditions(
      WorkflowStep step, Map<String, dynamic> executionContext) async {
    for (final condition in step.conditions) {
      if (!condition.evaluate(executionContext)) {
        return false;
      }
    }
    return true;
  }

  /// Build dependency graph for workflow steps
  Map<String, List<String>> _buildDependencyGraph(List<WorkflowStep> steps) {
    final graph = <String, List<String>>{};

    for (final step in steps) {
      graph[step.id] = step.dependsOn;
    }

    return graph;
  }

  /// Get execution order based on dependencies
  List<List<WorkflowStep>> _getExecutionOrder(
      Map<String, List<String>> dependencyGraph) {
    final executionOrder = <List<WorkflowStep>>[];
    final visited = <String>{};
    final inProgress = <String>{};

    // Topological sort with grouping
    void visit(String stepId, List<WorkflowStep> currentGroup) {
      if (visited.contains(stepId)) return;
      if (inProgress.contains(stepId)) {
        throw WorkflowExecutionException(
            'Circular dependency detected involving step $stepId');
      }

      inProgress.add(stepId);

      final dependencies = dependencyGraph[stepId] ?? [];
      for (final dependency in dependencies) {
        visit(dependency, currentGroup);
      }

      inProgress.remove(stepId);
      visited.add(stepId);

      // Add step to current group if no dependencies or all dependencies are satisfied
      final step = _findStepById(stepId);
      if (step != null) {
        currentGroup.add(step);
      }
    }

    // Process all steps
    final allStepIds = dependencyGraph.keys.toList();
    while (visited.length < allStepIds.length) {
      final currentGroup = <WorkflowStep>[];

      for (final stepId in allStepIds) {
        if (!visited.contains(stepId)) {
          visit(stepId, currentGroup);
          break;
        }
      }

      if (currentGroup.isNotEmpty) {
        executionOrder.add(currentGroup);
      }
    }

    return executionOrder;
  }

  /// Find step by ID (helper method)
  WorkflowStep? _findStepById(String stepId) {
    // This would need access to the current workflow
    // For now, return null - this should be refactored
    return null;
  }

  /// Validate workflow before execution
  Future<WorkflowValidationResult> _validateWorkflow(
      Workflow workflow, ExecutionContext context) async {
    // Check if all required agents are available
    for (final step in workflow.steps) {
      final agent = _agentRegistry.getAgent(step.agentId);
      if (agent == null) {
        return WorkflowValidationResult(
          isValid: false,
          error: 'Agent ${step.agentId} not found for step ${step.id}',
        );
      }

      if (!agent.canExecute(context)) {
        return WorkflowValidationResult(
          isValid: false,
          error: 'Agent ${step.agentId} cannot execute in current context',
        );
      }
    }

    // Check for circular dependencies
    try {
      final dependencyGraph = _buildDependencyGraph(workflow.steps);
      _getExecutionOrder(dependencyGraph);
    } catch (error) {
      return WorkflowValidationResult(
        isValid: false,
        error: 'Workflow validation failed: $error',
      );
    }

    return const WorkflowValidationResult(isValid: true);
  }

  /// Handle step failures
  Future<bool> _handleStepFailures(
    List<WorkflowStepExecution> failures,
    Workflow workflow,
    WorkflowExecution execution,
  ) async {
    for (final failure in failures) {
      final step = workflow.steps.firstWhere((s) => s.id == failure.stepId);

      _eventController.add(WorkflowExecutionEvent(
        type: WorkflowExecutionEventType.stepFailed,
        executionId: execution.id,
        workflowId: workflow.id,
        data: {
          'step_id': step.id,
          'error': failure.error,
          'on_failure_action': step.onFailure.name,
        },
        timestamp: DateTime.now(),
      ));

      switch (step.onFailure) {
        case WorkflowStepAction.stop:
          return false;
        case WorkflowStepAction.continue_:
          continue;
        case WorkflowStepAction.retry:
          // Retry logic is handled in step execution
          continue;
        case WorkflowStepAction.skip:
          continue;
        case WorkflowStepAction.branch:
          // Branch logic would be implemented here
          continue;
      }
    }

    return true;
  }

  /// Complete workflow execution
  Future<WorkflowExecution> _completeExecution(
    String executionId,
    WorkflowExecutionStatus status, {
    String? error,
    List<WorkflowStepExecution>? stepExecutions,
    Map<String, dynamic>? results,
  }) async {
    final execution = _activeExecutions[executionId];
    if (execution == null) {
      throw WorkflowExecutionException('Execution $executionId not found');
    }

    final completedExecution = execution.copyWith(
      status: status,
      endTime: DateTime.now(),
      stepExecutions: stepExecutions ?? execution.stepExecutions,
      error: error,
      results: results ?? execution.results,
    );

    _activeExecutions[executionId] = completedExecution;

    // Cancel timeout timer if exists
    _timeoutTimers[executionId]?.cancel();
    _timeoutTimers.remove(executionId);

    _eventController.add(WorkflowExecutionEvent(
      type: WorkflowExecutionEventType.completed,
      executionId: executionId,
      workflowId: execution.workflowId,
      data: {
        'status': status.name,
        'error': error,
        'duration_ms': completedExecution.executionTime?.inMilliseconds,
      },
      timestamp: DateTime.now(),
    ));

    return completedExecution;
  }

  /// Check if execution should be cancelled
  bool _shouldCancelExecution(String executionId) {
    final execution = _activeExecutions[executionId];
    return execution?.status == WorkflowExecutionStatus.cancelled;
  }

  /// Cancel workflow execution
  Future<void> cancelExecution(String executionId) async {
    final execution = _activeExecutions[executionId];
    if (execution == null) return;

    _activeExecutions[executionId] = execution.copyWith(
      status: WorkflowExecutionStatus.cancelled,
      endTime: DateTime.now(),
    );

    _eventController.add(WorkflowExecutionEvent(
      type: WorkflowExecutionEventType.cancelled,
      executionId: executionId,
      workflowId: execution.workflowId,
      data: {},
      timestamp: DateTime.now(),
    ));
  }

  /// Pause workflow execution
  Future<void> pauseExecution(String executionId) async {
    final execution = _activeExecutions[executionId];
    if (execution == null) return;

    _activeExecutions[executionId] = execution.copyWith(
      status: WorkflowExecutionStatus.paused,
    );

    _eventController.add(WorkflowExecutionEvent(
      type: WorkflowExecutionEventType.paused,
      executionId: executionId,
      workflowId: execution.workflowId,
      data: {},
      timestamp: DateTime.now(),
    ));
  }

  /// Resume workflow execution
  Future<void> resumeExecution(String executionId) async {
    final execution = _activeExecutions[executionId];
    if (execution == null ||
        execution.status != WorkflowExecutionStatus.paused) {
      return;
    }

    _activeExecutions[executionId] = execution.copyWith(
      status: WorkflowExecutionStatus.running,
    );

    _eventController.add(WorkflowExecutionEvent(
      type: WorkflowExecutionEventType.resumed,
      executionId: executionId,
      workflowId: execution.workflowId,
      data: {},
      timestamp: DateTime.now(),
    ));
  }

  /// Get active executions
  List<WorkflowExecution> getActiveExecutions() {
    return _activeExecutions.values.toList();
  }

  /// Get execution by ID
  WorkflowExecution? getExecution(String executionId) {
    return _activeExecutions[executionId];
  }

  /// Get execution statistics
  Map<String, dynamic> getExecutionStats() {
    final executions = _activeExecutions.values;
    final statusCounts = <String, int>{};

    for (final execution in executions) {
      final status = execution.status.name;
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }

    return {
      'total_executions': executions.length,
      'status_breakdown': statusCounts,
      'running_executions': executions
          .where((e) => e.status == WorkflowExecutionStatus.running)
          .length,
    };
  }

  /// Dispose workflow executor
  Future<void> dispose() async {
    // Cancel all active executions
    for (final executionId in _activeExecutions.keys.toList()) {
      await cancelExecution(executionId);
    }

    // Cancel all timers
    for (final timer in _timeoutTimers.values) {
      timer.cancel();
    }
    _timeoutTimers.clear();

    await _eventController.close();
  }
}

/// Workflow validation result
class WorkflowValidationResult {
  final bool isValid;
  final String? error;

  const WorkflowValidationResult({
    required this.isValid,
    this.error,
  });
}

/// Workflow execution event
class WorkflowExecutionEvent {
  final WorkflowExecutionEventType type;
  final String executionId;
  final String workflowId;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  const WorkflowExecutionEvent({
    required this.type,
    required this.executionId,
    required this.workflowId,
    required this.data,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'execution_id': executionId,
      'workflow_id': workflowId,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory WorkflowExecutionEvent.fromJson(Map<String, dynamic> json) {
    return WorkflowExecutionEvent(
      type: WorkflowExecutionEventType.values
          .firstWhere((e) => e.name == json['type']),
      executionId: json['execution_id'] as String,
      workflowId: json['workflow_id'] as String,
      data: json['data'] as Map<String, dynamic>,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

/// Workflow execution event types
enum WorkflowExecutionEventType {
  started,
  completed,
  failed,
  cancelled,
  paused,
  resumed,
  stepStarted,
  stepCompleted,
  stepFailed,
  stepTimeout,
}

/// Workflow execution exception
class WorkflowExecutionException implements Exception {
  final String message;
  WorkflowExecutionException(this.message);

  @override
  String toString() => 'WorkflowExecutionException: $message';
}
