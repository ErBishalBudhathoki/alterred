import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/agent_model.dart';
import '../models/workflow_model.dart';
import '../engine/orchestration_engine.dart';
import '../engine/agent_registry.dart';
import '../engine/safety_monitor.dart';
import '../engine/workflow_executor.dart';
import '../workflows/morning_routine_workflow.dart';
import '../workflows/decision_paralysis_workflow.dart';
import '../workflows/hyperfocus_protection_workflow.dart';
import '../agents/base/agent_base.dart';

/// Orchestration state management using Riverpod
class OrchestrationState {
  final bool isInitialized;
  final bool isRunning;
  final Map<String, AgentBase> agents;
  final Map<String, Workflow> workflows;
  final List<WorkflowExecution> activeExecutions;
  final Map<String, dynamic> systemHealth;
  final List<OrchestrationEvent> recentEvents;
  final Map<String, dynamic> statistics;
  final String? error;

  const OrchestrationState({
    this.isInitialized = false,
    this.isRunning = false,
    this.agents = const {},
    this.workflows = const {},
    this.activeExecutions = const [],
    this.systemHealth = const {},
    this.recentEvents = const [],
    this.statistics = const {},
    this.error,
  });

  OrchestrationState copyWith({
    bool? isInitialized,
    bool? isRunning,
    Map<String, AgentBase>? agents,
    Map<String, Workflow>? workflows,
    List<WorkflowExecution>? activeExecutions,
    Map<String, dynamic>? systemHealth,
    List<OrchestrationEvent>? recentEvents,
    Map<String, dynamic>? statistics,
    String? error,
  }) {
    return OrchestrationState(
      isInitialized: isInitialized ?? this.isInitialized,
      isRunning: isRunning ?? this.isRunning,
      agents: agents ?? this.agents,
      workflows: workflows ?? this.workflows,
      activeExecutions: activeExecutions ?? this.activeExecutions,
      systemHealth: systemHealth ?? this.systemHealth,
      recentEvents: recentEvents ?? this.recentEvents,
      statistics: statistics ?? this.statistics,
      error: error,
    );
  }
}

/// Orchestration notifier for state management
class OrchestrationNotifier extends StateNotifier<OrchestrationState> {
  OrchestrationNotifier() : super(const OrchestrationState()) {
    _initialize();
  }

  final OrchestrationEngine _engine = OrchestrationEngine();
  final AgentRegistry _agentRegistry = AgentRegistry();
  final SafetyMonitor _safetyMonitor = SafetyMonitor();
  final WorkflowExecutor _workflowExecutor = WorkflowExecutor();

  /// Initialize the orchestration system
  Future<void> _initialize() async {
    try {
      // Initialize the orchestration engine
      await _engine.initialize();
      
      // Register default workflows
      await _registerDefaultWorkflows();
      
      // Set up event listeners
      _setupEventListeners();
      
      // Start the engine
      await _engine.start();
      
      // Update state
      await _updateState();
      
    } catch (error) {
      state = state.copyWith(error: error.toString());
    }
  }

  /// Register default workflows
  Future<void> _registerDefaultWorkflows() async {
    // Register morning routine workflow
    await _engine.registerWorkflow(MorningRoutineWorkflow.createWorkflow());
    
    // Register decision paralysis workflow
    await _engine.registerWorkflow(DecisionParalysisWorkflow.createWorkflow());
    
    // Register hyperfocus protection workflow
    await _engine.registerWorkflow(HyperfocusProtectionWorkflow.createWorkflow());
    
    // Register workflow variations
    final morningVariations = MorningRoutineWorkflow.getWorkflowVariations();
    for (final workflow in morningVariations.values) {
      await _engine.registerWorkflow(workflow);
    }
    
    final paralysisEscalations = DecisionParalysisWorkflow.getEscalationWorkflows();
    for (final workflow in paralysisEscalations.values) {
      await _engine.registerWorkflow(workflow);
    }
    
    final hyperfocusEscalations = HyperfocusProtectionWorkflow.getEscalationWorkflows();
    for (final workflow in hyperfocusEscalations.values) {
      await _engine.registerWorkflow(workflow);
    }
  }

  /// Set up event listeners
  void _setupEventListeners() {
    // Listen to orchestration events
    _engine.events.listen((event) {
      _handleOrchestrationEvent(event);
    });
    
    // Listen to agent registry events
    _agentRegistry.events.listen((event) {
      _handleAgentRegistryEvent(event);
    });
    
    // Listen to safety monitor events
    _safetyMonitor.events.listen((event) {
      _handleSafetyEvent(event);
    });
    
    // Listen to workflow executor events
    _workflowExecutor.events.listen((event) {
      _handleWorkflowEvent(event);
    });
  }

  /// Handle orchestration events
  void _handleOrchestrationEvent(OrchestrationEvent event) {
    final updatedEvents = [...state.recentEvents, event];
    
    // Keep only last 100 events
    if (updatedEvents.length > 100) {
      updatedEvents.removeRange(0, updatedEvents.length - 100);
    }
    
    state = state.copyWith(recentEvents: updatedEvents);
    
    // Handle specific event types
    switch (event.type) {
      case OrchestrationEventType.initialized:
        state = state.copyWith(isInitialized: true);
        break;
      case OrchestrationEventType.started:
        state = state.copyWith(isRunning: true);
        break;
      case OrchestrationEventType.stopped:
        state = state.copyWith(isRunning: false);
        break;
      default:
        break;
    }
    
    // Update statistics
    _updateStatistics();
  }

  /// Handle agent registry events
  void _handleAgentRegistryEvent(AgentRegistryEvent event) {
    switch (event.type) {
      case AgentRegistryEventType.agentRegistered:
      case AgentRegistryEventType.agentUnregistered:
      case AgentRegistryEventType.agentStatusChanged:
        _updateAgents();
        break;
      default:
        break;
    }
  }

  /// Handle safety events
  void _handleSafetyEvent(SafetyEvent event) {
    if (event.priority == SafetyPriority.critical) {
      // Handle critical safety events immediately
      _handleCriticalSafetyEvent(event);
    }
    
    _updateSystemHealth();
  }

  /// Handle workflow events
  void _handleWorkflowEvent(WorkflowExecutionEvent event) {
    switch (event.type) {
      case WorkflowExecutionEventType.started:
      case WorkflowExecutionEventType.completed:
      case WorkflowExecutionEventType.failed:
      case WorkflowExecutionEventType.cancelled:
        _updateActiveExecutions();
        break;
      default:
        break;
    }
  }

  /// Handle critical safety events
  void _handleCriticalSafetyEvent(SafetyEvent event) {
    // Update state to reflect critical safety situation
    state = state.copyWith(
      error: 'Critical safety event: ${event.data['description'] ?? 'Unknown'}',
    );
  }

  /// Update complete state
  Future<void> _updateState() async {
    await _updateAgents();
    await _updateWorkflows();
    await _updateActiveExecutions();
    await _updateSystemHealth();
    _updateStatistics();
  }

  /// Update agents in state
  Future<void> _updateAgents() async {
    final agents = <String, AgentBase>{};
    for (final agent in _agentRegistry.getAllAgents()) {
      agents[agent.metadata.id] = agent;
    }
    
    state = state.copyWith(agents: agents);
  }

  /// Update workflows in state
  Future<void> _updateWorkflows() async {
    final workflows = <String, Workflow>{};
    for (final workflow in _engine.getAllWorkflows()) {
      workflows[workflow.id] = workflow;
    }
    
    state = state.copyWith(workflows: workflows);
  }

  /// Update active executions
  Future<void> _updateActiveExecutions() async {
    final activeExecutions = _workflowExecutor.getActiveExecutions();
    state = state.copyWith(activeExecutions: activeExecutions);
  }

  /// Update system health
  Future<void> _updateSystemHealth() async {
    final systemHealth = await _engine.getSystemHealth();
    state = state.copyWith(systemHealth: systemHealth);
  }

  /// Update statistics
  void _updateStatistics() {
    final statistics = _engine.getOrchestrationStats();
    state = state.copyWith(statistics: statistics);
  }

  /// Execute a workflow
  Future<WorkflowExecution?> executeWorkflow(String workflowId, {Map<String, dynamic>? parameters}) async {
    try {
      final context = ExecutionContext(
        id: 'manual_${DateTime.now().millisecondsSinceEpoch}',
        userId: 'user', // Would come from user session
        timestamp: DateTime.now(),
        parameters: parameters ?? {},
      );
      
      final execution = await _engine.executeWorkflow(workflowId, context);
      await _updateActiveExecutions();
      
      return execution;
    } catch (error) {
      state = state.copyWith(error: error.toString());
      return null;
    }
  }

  /// Execute an agent
  Future<AgentResult?> executeAgent(String agentId, {Map<String, dynamic>? parameters}) async {
    try {
      final context = ExecutionContext(
        id: 'manual_agent_${DateTime.now().millisecondsSinceEpoch}',
        userId: 'user',
        timestamp: DateTime.now(),
        parameters: parameters ?? {},
      );
      
      final result = await _engine.executeAgent(agentId, context);
      return result;
    } catch (error) {
      state = state.copyWith(error: error.toString());
      return null;
    }
  }

  /// Trigger workflows based on conditions
  Future<List<WorkflowExecution>> triggerWorkflows({Map<String, dynamic>? userState}) async {
    try {
      final context = ExecutionContext(
        id: 'trigger_${DateTime.now().millisecondsSinceEpoch}',
        userId: 'user',
        timestamp: DateTime.now(),
        userState: userState ?? {},
      );
      
      final executions = await _engine.triggerWorkflows(context);
      await _updateActiveExecutions();
      
      return executions;
    } catch (error) {
      state = state.copyWith(error: error.toString());
      return [];
    }
  }

  /// Cancel workflow execution
  Future<void> cancelWorkflowExecution(String executionId) async {
    try {
      await _workflowExecutor.cancelExecution(executionId);
      await _updateActiveExecutions();
    } catch (error) {
      state = state.copyWith(error: error.toString());
    }
  }

  /// Pause workflow execution
  Future<void> pauseWorkflowExecution(String executionId) async {
    try {
      await _workflowExecutor.pauseExecution(executionId);
      await _updateActiveExecutions();
    } catch (error) {
      state = state.copyWith(error: error.toString());
    }
  }

  /// Resume workflow execution
  Future<void> resumeWorkflowExecution(String executionId) async {
    try {
      await _workflowExecutor.resumeExecution(executionId);
      await _updateActiveExecutions();
    } catch (error) {
      state = state.copyWith(error: error.toString());
    }
  }

  /// Get agent by ID
  AgentBase? getAgent(String agentId) {
    return state.agents[agentId];
  }

  /// Get workflow by ID
  Workflow? getWorkflow(String workflowId) {
    return state.workflows[workflowId];
  }

  /// Get agents by type
  List<AgentBase> getAgentsByType(AgentType type) {
    return state.agents.values.where((agent) => agent.metadata.type == type).toList();
  }

  /// Get workflows by trigger type
  List<Workflow> getWorkflowsByTriggerType(TriggerType triggerType) {
    return state.workflows.values.where((workflow) => workflow.trigger.type == triggerType).toList();
  }

  /// Get active executions for workflow
  List<WorkflowExecution> getActiveExecutionsForWorkflow(String workflowId) {
    return state.activeExecutions.where((execution) => execution.workflowId == workflowId).toList();
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Refresh state
  Future<void> refresh() async {
    await _updateState();
  }

  /// Dispose resources
  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }
}

/// Provider for orchestration state
final orchestrationProvider = StateNotifierProvider<OrchestrationNotifier, OrchestrationState>((ref) {
  return OrchestrationNotifier();
});

/// Provider for specific agent states
final agentProvider = Provider.family<AgentBase?, String>((ref, agentId) {
  final orchestrationState = ref.watch(orchestrationProvider);
  return orchestrationState.agents[agentId];
});

/// Provider for specific workflow states
final workflowProvider = Provider.family<Workflow?, String>((ref, workflowId) {
  final orchestrationState = ref.watch(orchestrationProvider);
  return orchestrationState.workflows[workflowId];
});

/// Provider for agents by type
final agentsByTypeProvider = Provider.family<List<AgentBase>, AgentType>((ref, type) {
  final orchestrationState = ref.watch(orchestrationProvider);
  return orchestrationState.agents.values.where((agent) => agent.metadata.type == type).toList();
});

/// Provider for workflows by trigger type
final workflowsByTriggerTypeProvider = Provider.family<List<Workflow>, TriggerType>((ref, triggerType) {
  final orchestrationState = ref.watch(orchestrationProvider);
  return orchestrationState.workflows.values.where((workflow) => workflow.trigger.type == triggerType).toList();
});

/// Provider for active executions
final activeExecutionsProvider = Provider<List<WorkflowExecution>>((ref) {
  final orchestrationState = ref.watch(orchestrationProvider);
  return orchestrationState.activeExecutions;
});

/// Provider for system health
final systemHealthProvider = Provider<Map<String, dynamic>>((ref) {
  final orchestrationState = ref.watch(orchestrationProvider);
  return orchestrationState.systemHealth;
});

/// Provider for orchestration statistics
final orchestrationStatsProvider = Provider<Map<String, dynamic>>((ref) {
  final orchestrationState = ref.watch(orchestrationProvider);
  return orchestrationState.statistics;
});

/// Provider for recent events
final recentEventsProvider = Provider<List<OrchestrationEvent>>((ref) {
  final orchestrationState = ref.watch(orchestrationProvider);
  return orchestrationState.recentEvents;
});

/// Provider for orchestration actions
final orchestrationActionsProvider = Provider<OrchestrationActions>((ref) {
  final notifier = ref.read(orchestrationProvider.notifier);
  return OrchestrationActions(notifier);
});

/// Actions class for orchestration operations
class OrchestrationActions {
  final OrchestrationNotifier _notifier;

  OrchestrationActions(this._notifier);

  /// Execute workflow
  Future<WorkflowExecution?> executeWorkflow(String workflowId, {Map<String, dynamic>? parameters}) {
    return _notifier.executeWorkflow(workflowId, parameters: parameters);
  }

  /// Execute agent
  Future<AgentResult?> executeAgent(String agentId, {Map<String, dynamic>? parameters}) {
    return _notifier.executeAgent(agentId, parameters: parameters);
  }

  /// Trigger workflows
  Future<List<WorkflowExecution>> triggerWorkflows({Map<String, dynamic>? userState}) {
    return _notifier.triggerWorkflows(userState: userState);
  }

  /// Cancel execution
  Future<void> cancelExecution(String executionId) {
    return _notifier.cancelWorkflowExecution(executionId);
  }

  /// Pause execution
  Future<void> pauseExecution(String executionId) {
    return _notifier.pauseWorkflowExecution(executionId);
  }

  /// Resume execution
  Future<void> resumeExecution(String executionId) {
    return _notifier.resumeWorkflowExecution(executionId);
  }

  /// Clear error
  void clearError() {
    _notifier.clearError();
  }

  /// Refresh state
  Future<void> refresh() {
    return _notifier.refresh();
  }
}

/// Convenience providers for specific workflows
final morningRoutineWorkflowProvider = Provider<Workflow?>((ref) {
  return ref.watch(workflowProvider(MorningRoutineWorkflow.workflowId));
});

final decisionParalysisWorkflowProvider = Provider<Workflow?>((ref) {
  return ref.watch(workflowProvider(DecisionParalysisWorkflow.workflowId));
});

final hyperfocusProtectionWorkflowProvider = Provider<Workflow?>((ref) {
  return ref.watch(workflowProvider(HyperfocusProtectionWorkflow.workflowId));
});

/// Provider for morning routine execution status
final morningRoutineExecutionProvider = Provider<WorkflowExecution?>((ref) {
  final executions = ref.watch(activeExecutionsProvider);
  return executions
      .where((e) => e.workflowId == MorningRoutineWorkflow.workflowId)
      .isNotEmpty
      ? executions.where((e) => e.workflowId == MorningRoutineWorkflow.workflowId).first
      : null;
});

/// Provider for decision paralysis execution status
final decisionParalysisExecutionProvider = Provider<WorkflowExecution?>((ref) {
  final executions = ref.watch(activeExecutionsProvider);
  return executions
      .where((e) => e.workflowId == DecisionParalysisWorkflow.workflowId)
      .isNotEmpty
      ? executions.where((e) => e.workflowId == DecisionParalysisWorkflow.workflowId).first
      : null;
});

/// Provider for hyperfocus protection execution status
final hyperfocusProtectionExecutionProvider = Provider<WorkflowExecution?>((ref) {
  final executions = ref.watch(activeExecutionsProvider);
  return executions
      .where((e) => e.workflowId == HyperfocusProtectionWorkflow.workflowId)
      .isNotEmpty
      ? executions.where((e) => e.workflowId == HyperfocusProtectionWorkflow.workflowId).first
      : null;
});

/// Provider for orchestration health status
final orchestrationHealthProvider = Provider<String>((ref) {
  final health = ref.watch(systemHealthProvider);
  return health['overall_health'] as String? ?? 'unknown';
});

/// Provider for agent health summary
final agentHealthSummaryProvider = Provider<Map<String, dynamic>>((ref) {
  final health = ref.watch(systemHealthProvider);
  final agents = health['agents'] as Map<String, dynamic>? ?? {};
  
  return {
    'healthy_count': agents['healthy'] ?? 0,
    'total_count': agents['total'] ?? 0,
    'health_percentage': agents['health_percentage'] ?? 0,
  };
});

/// Provider for safety status
final safetyStatusProvider = Provider<Map<String, dynamic>>((ref) {
  final health = ref.watch(systemHealthProvider);
  return health['safety'] as Map<String, dynamic>? ?? {};
});