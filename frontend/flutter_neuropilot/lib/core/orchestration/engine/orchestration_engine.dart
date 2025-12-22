import 'dart:async';
import '../models/agent_model.dart';
import '../models/workflow_model.dart';
import 'agent_registry.dart';
import 'safety_monitor.dart';
import 'workflow_executor.dart';

/// Main orchestration engine that coordinates all agents and workflows
class OrchestrationEngine {
  static final OrchestrationEngine _instance = OrchestrationEngine._internal();
  factory OrchestrationEngine() => _instance;
  OrchestrationEngine._internal();

  final AgentRegistry _agentRegistry = AgentRegistry();
  final SafetyMonitor _safetyMonitor = SafetyMonitor();
  final WorkflowExecutor _workflowExecutor = WorkflowExecutor();

  final StreamController<OrchestrationEvent> _eventController =
      StreamController<OrchestrationEvent>.broadcast();

  final Map<String, Workflow> _workflows = {};
  // final Map<String, WorkflowTrigger> _triggers = {}; // Unused
  final List<OrchestrationRule> _rules = [];

  bool _isInitialized = false;
  bool _isRunning = false;

  /// Stream of orchestration events
  Stream<OrchestrationEvent> get events => _eventController.stream;

  /// Whether the engine is initialized
  bool get isInitialized => _isInitialized;

  /// Whether the engine is running
  bool get isRunning => _isRunning;

  /// Initialize the orchestration engine
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize components
      await _agentRegistry.initialize();
      await _safetyMonitor.initialize();

      // Register default workflows
      await _registerDefaultWorkflows();

      // Register default orchestration rules
      _registerDefaultOrchestrationRules();

      // Set up event listeners
      _setupEventListeners();

      _isInitialized = true;

      _eventController.add(OrchestrationEvent(
        type: OrchestrationEventType.initialized,
        data: {
          'agents_count': _agentRegistry.agentCount,
          'workflows_count': _workflows.length,
          'rules_count': _rules.length,
        },
        timestamp: DateTime.now(),
      ));
    } catch (error) {
      _eventController.add(OrchestrationEvent(
        type: OrchestrationEventType.initializationFailed,
        data: {'error': error.toString()},
        timestamp: DateTime.now(),
      ));
      rethrow;
    }
  }

  /// Start the orchestration engine
  Future<void> start() async {
    if (!_isInitialized) {
      throw OrchestrationException('Engine not initialized');
    }

    if (_isRunning) return;

    _isRunning = true;

    _eventController.add(OrchestrationEvent(
      type: OrchestrationEventType.started,
      data: {},
      timestamp: DateTime.now(),
    ));
  }

  /// Stop the orchestration engine
  Future<void> stop() async {
    if (!_isRunning) return;

    _isRunning = false;

    // Cancel all active workflow executions
    final activeExecutions = _workflowExecutor.getActiveExecutions();
    for (final execution in activeExecutions) {
      await _workflowExecutor.cancelExecution(execution.id);
    }

    _eventController.add(OrchestrationEvent(
      type: OrchestrationEventType.stopped,
      data: {},
      timestamp: DateTime.now(),
    ));
  }

  /// Execute a workflow by ID
  Future<WorkflowExecution> executeWorkflow(
      String workflowId, ExecutionContext context) async {
    if (!_isRunning) {
      throw OrchestrationException('Engine not running');
    }

    final workflow = _workflows[workflowId];
    if (workflow == null) {
      throw OrchestrationException('Workflow $workflowId not found');
    }

    _eventController.add(OrchestrationEvent(
      type: OrchestrationEventType.workflowExecutionRequested,
      data: {
        'workflow_id': workflowId,
        'context': context.toJson(),
      },
      timestamp: DateTime.now(),
    ));

    return await _workflowExecutor.executeWorkflow(workflow, context);
  }

  /// Execute an agent directly
  Future<AgentResult> executeAgent(
      String agentId, ExecutionContext context) async {
    if (!_isRunning) {
      throw OrchestrationException('Engine not running');
    }

    _eventController.add(OrchestrationEvent(
      type: OrchestrationEventType.agentExecutionRequested,
      data: {
        'agent_id': agentId,
        'context': context.toJson(),
      },
      timestamp: DateTime.now(),
    ));

    return await _agentRegistry.executeAgent(agentId, context);
  }

  /// Trigger workflows based on conditions
  Future<List<WorkflowExecution>> triggerWorkflows(
      ExecutionContext context) async {
    if (!_isRunning) return [];

    final executions = <WorkflowExecution>[];

    for (final workflow in _workflows.values) {
      if (await _shouldTriggerWorkflow(workflow, context)) {
        try {
          final execution = await executeWorkflow(workflow.id, context);
          executions.add(execution);
        } catch (error) {
          _eventController.add(OrchestrationEvent(
            type: OrchestrationEventType.workflowTriggerFailed,
            data: {
              'workflow_id': workflow.id,
              'error': error.toString(),
            },
            timestamp: DateTime.now(),
          ));
        }
      }
    }

    return executions;
  }

  /// Register a workflow
  Future<void> registerWorkflow(Workflow workflow) async {
    _workflows[workflow.id] = workflow;

    _eventController.add(OrchestrationEvent(
      type: OrchestrationEventType.workflowRegistered,
      data: {
        'workflow_id': workflow.id,
        'workflow_name': workflow.name,
      },
      timestamp: DateTime.now(),
    ));
  }

  /// Unregister a workflow
  Future<void> unregisterWorkflow(String workflowId) async {
    _workflows.remove(workflowId);

    _eventController.add(OrchestrationEvent(
      type: OrchestrationEventType.workflowUnregistered,
      data: {'workflow_id': workflowId},
      timestamp: DateTime.now(),
    ));
  }

  /// Get workflow by ID
  Workflow? getWorkflow(String workflowId) {
    return _workflows[workflowId];
  }

  /// Get all workflows
  List<Workflow> getAllWorkflows() {
    return _workflows.values.toList();
  }

  /// Get workflows by trigger type
  List<Workflow> getWorkflowsByTriggerType(TriggerType triggerType) {
    return _workflows.values
        .where((w) => w.trigger.type == triggerType)
        .toList();
  }

  /// Register default workflows
  Future<void> _registerDefaultWorkflows() async {
    // Note: The actual workflow implementations will be created in the next phase
    // For now, we'll register placeholder workflows

    // Morning Routine Workflow
    await registerWorkflow(Workflow(
      id: 'morning_routine',
      name: 'Morning Routine Workflow',
      description:
          'Orchestrates morning startup routine with energy assessment and task planning',
      steps: [], // Will be populated by specific workflow implementations
      trigger: const WorkflowTrigger(
        type: TriggerType.scheduled,
        config: {
          'time': '08:00',
          'days': ['monday', 'tuesday', 'wednesday', 'thursday', 'friday']
        },
      ),
      createdAt: DateTime.now(),
    ));

    // Decision Paralysis Workflow
    await registerWorkflow(Workflow(
      id: 'decision_paralysis',
      name: 'Decision Paralysis Resolution',
      description: 'Detects and resolves decision paralysis episodes',
      steps: [], // Will be populated by specific workflow implementations
      trigger: const WorkflowTrigger(
        type: TriggerType.condition,
        conditions: [
          WorkflowCondition(
            field: 'decision_paralysis_detected',
            operator: ConditionOperator.equals,
            value: true,
          ),
        ],
      ),
      createdAt: DateTime.now(),
    ));

    // Hyperfocus Protection Workflow
    await registerWorkflow(Workflow(
      id: 'hyperfocus_protection',
      name: 'Hyperfocus Protection System',
      description:
          'Monitors and interrupts hyperfocus episodes to prevent burnout',
      steps: [], // Will be populated by specific workflow implementations
      trigger: const WorkflowTrigger(
        type: TriggerType.condition,
        conditions: [
          WorkflowCondition(
            field: 'hyperfocus_detected',
            operator: ConditionOperator.equals,
            value: true,
          ),
        ],
      ),
      createdAt: DateTime.now(),
    ));
  }

  /// Register default orchestration rules
  void _registerDefaultOrchestrationRules() {
    // Rule 1: Energy-based agent selection
    _rules.add(OrchestrationRule(
      id: 'energy_based_selection',
      name: 'Energy-Based Agent Selection',
      description: 'Select agents based on user energy levels',
      priority: 1,
      condition: (context) => context.userState.containsKey('energy_level'),
      action: _applyEnergyBasedSelection,
    ));

    // Rule 2: Workload balancing
    _rules.add(OrchestrationRule(
      id: 'workload_balancing',
      name: 'Agent Workload Balancing',
      description: 'Balance workload across available agents',
      priority: 2,
      condition: (context) => _agentRegistry.getActiveAgents().length > 3,
      action: _applyWorkloadBalancing,
    ));

    // Rule 3: Priority escalation
    _rules.add(OrchestrationRule(
      id: 'priority_escalation',
      name: 'Priority-Based Escalation',
      description: 'Escalate high-priority tasks to appropriate agents',
      priority: 3,
      condition: (context) =>
          context.priority == ExecutionPriority.urgent ||
          context.priority == ExecutionPriority.safety,
      action: _applyPriorityEscalation,
    ));
  }

  /// Set up event listeners
  void _setupEventListeners() {
    // Listen to agent registry events
    _agentRegistry.events.listen((event) {
      _eventController.add(OrchestrationEvent(
        type: OrchestrationEventType.agentEvent,
        data: {
          'agent_event': event.toJson(),
        },
        timestamp: DateTime.now(),
      ));
    });

    // Listen to safety monitor events
    _safetyMonitor.events.listen((event) {
      _eventController.add(OrchestrationEvent(
        type: OrchestrationEventType.safetyEvent,
        data: {
          'safety_event': event.toJson(),
        },
        timestamp: DateTime.now(),
      ));

      // Handle critical safety events
      if (event.priority == SafetyPriority.critical) {
        _handleCriticalSafetyEvent(event);
      }
    });

    // Listen to workflow executor events
    _workflowExecutor.events.listen((event) {
      _eventController.add(OrchestrationEvent(
        type: OrchestrationEventType.workflowEvent,
        data: {
          'workflow_event': event.toJson(),
        },
        timestamp: DateTime.now(),
      ));
    });
  }

  /// Check if workflow should be triggered
  Future<bool> _shouldTriggerWorkflow(
      Workflow workflow, ExecutionContext context) async {
    final trigger = workflow.trigger;

    switch (trigger.type) {
      case TriggerType.manual:
        return false; // Manual triggers are not automatic

      case TriggerType.scheduled:
        return _checkScheduledTrigger(trigger, context);

      case TriggerType.event:
        return _checkEventTrigger(trigger, context);

      case TriggerType.condition:
        return _checkConditionTrigger(trigger, context);

      case TriggerType.agent:
        return _checkAgentTrigger(trigger, context);
    }
  }

  /// Check scheduled trigger
  bool _checkScheduledTrigger(
      WorkflowTrigger trigger, ExecutionContext context) {
    // Implementation would check current time against schedule
    // For now, return false
    return false;
  }

  /// Check event trigger
  bool _checkEventTrigger(WorkflowTrigger trigger, ExecutionContext context) {
    final eventType = trigger.config['event_type'] as String?;
    final contextEvent = context.parameters['event_type'] as String?;

    return eventType == contextEvent;
  }

  /// Check condition trigger
  bool _checkConditionTrigger(
      WorkflowTrigger trigger, ExecutionContext context) {
    for (final condition in trigger.conditions) {
      if (!condition.evaluate(context.userState)) {
        return false;
      }
    }
    return true;
  }

  /// Check agent trigger
  bool _checkAgentTrigger(WorkflowTrigger trigger, ExecutionContext context) {
    final triggerAgentId = trigger.config['agent_id'] as String?;
    final contextAgentId = context.parameters['triggering_agent'] as String?;

    return triggerAgentId == contextAgentId;
  }

  /// Apply energy-based agent selection
  Future<void> _applyEnergyBasedSelection(ExecutionContext context) async {
    final energyLevel = context.userState['energy_level'] as double? ?? 0.5;

    // Modify context to prefer certain agents based on energy
    if (energyLevel < 0.3) {
      // Low energy - prefer simpler agents
      context.parameters['preferred_agents'] = [
        'decision_helper',
        'time_estimation'
      ];
    } else if (energyLevel > 0.8) {
      // High energy - can handle complex agents
      context.parameters['preferred_agents'] = [
        'energy_assessment',
        'hyperfocus_detection'
      ];
    }
  }

  /// Apply workload balancing
  Future<void> _applyWorkloadBalancing(ExecutionContext context) async {
    // final activeAgents = _agentRegistry.getActiveAgents(); // Unused
    final idleAgents = _agentRegistry.getIdleAgents();

    // Prefer idle agents for new tasks
    if (idleAgents.isNotEmpty) {
      context.parameters['preferred_agents'] =
          idleAgents.map((a) => a.metadata.id).toList();
    }
  }

  /// Apply priority escalation
  Future<void> _applyPriorityEscalation(ExecutionContext context) async {
    // For high-priority tasks, prefer agents that can interrupt others
    final interruptCapableAgents =
        _agentRegistry.getAgentsByCapability('interrupt_others');

    if (interruptCapableAgents.isNotEmpty) {
      context.parameters['preferred_agents'] =
          interruptCapableAgents.map((a) => a.metadata.id).toList();
      context.parameters['allow_interruption'] = true;
    }
  }

  /// Handle critical safety events
  Future<void> _handleCriticalSafetyEvent(SafetyEvent event) async {
    switch (event.type) {
      case SafetyEventType.emergencyStop:
        await stop();
        break;
      case SafetyEventType.violationDetected:
        // Handle specific violations
        final violationData = event.data['violation'] as Map<String, dynamic>?;
        if (violationData != null) {
          await _handleSafetyViolation(violationData);
        }
        break;
      default:
        // Log other critical events
        break;
    }
  }

  /// Handle safety violation
  Future<void> _handleSafetyViolation(
      Map<String, dynamic> violationData) async {
    final ruleId = violationData['rule_id'] as String?;

    switch (ruleId) {
      case 'break_compliance':
        // Trigger break enforcement workflow
        await triggerWorkflows(ExecutionContext(
          id: 'safety_break_${DateTime.now().millisecondsSinceEpoch}',
          userId: 'safety_system',
          timestamp: DateTime.now(),
          priority: ExecutionPriority.safety,
          parameters: {'event_type': 'break_enforcement_required'},
        ));
        break;
      case 'infinite_loop':
        // Emergency stop
        await stop();
        break;
      default:
        // Log unknown violation
        break;
    }
  }

  /// Get orchestration statistics
  Map<String, dynamic> getOrchestrationStats() {
    return {
      'is_initialized': _isInitialized,
      'is_running': _isRunning,
      'agents': _agentRegistry.getRegistryStats(),
      'workflows': {
        'total': _workflows.length,
        'by_trigger_type': _getWorkflowsByTriggerTypeStats(),
      },
      'executions': _workflowExecutor.getExecutionStats(),
      'safety': _safetyMonitor.getSafetyStats(),
      'rules': _rules.length,
    };
  }

  /// Get workflows by trigger type statistics
  Map<String, int> _getWorkflowsByTriggerTypeStats() {
    final stats = <String, int>{};

    for (final workflow in _workflows.values) {
      final triggerType = workflow.trigger.type.name;
      stats[triggerType] = (stats[triggerType] ?? 0) + 1;
    }

    return stats;
  }

  /// Get system health
  Future<Map<String, dynamic>> getSystemHealth() async {
    final agentHealth = await _agentRegistry.getAllAgentsHealth();
    final safetyStats = _safetyMonitor.getSafetyStats();

    final healthyAgents =
        agentHealth.values.where((h) => h['healthy'] == true).length;
    final totalAgents = agentHealth.length;

    return {
      'overall_health': _calculateOverallHealth(agentHealth, safetyStats),
      'agents': {
        'healthy': healthyAgents,
        'total': totalAgents,
        'health_percentage':
            totalAgents > 0 ? (healthyAgents / totalAgents * 100).round() : 0,
      },
      'safety': {
        'violations_24h': safetyStats['recent_violations_24h'],
        'monitoring_active': safetyStats['is_monitoring'],
      },
      'orchestration': {
        'initialized': _isInitialized,
        'running': _isRunning,
      },
    };
  }

  /// Calculate overall system health
  String _calculateOverallHealth(
      Map<String, dynamic> agentHealth, Map<String, dynamic> safetyStats) {
    final healthyAgents =
        agentHealth.values.where((h) => h['healthy'] == true).length;
    final totalAgents = agentHealth.length;
    final recentViolations = safetyStats['recent_violations_24h'] as int? ?? 0;

    if (!_isInitialized || !_isRunning) return 'critical';
    if (totalAgents == 0) return 'unknown';

    final healthPercentage = healthyAgents / totalAgents;

    if (healthPercentage >= 0.9 && recentViolations == 0) return 'excellent';
    if (healthPercentage >= 0.8 && recentViolations <= 2) return 'good';
    if (healthPercentage >= 0.6 && recentViolations <= 5) return 'fair';
    if (healthPercentage >= 0.4) return 'poor';

    return 'critical';
  }

  /// Dispose orchestration engine
  Future<void> dispose() async {
    await stop();

    await _agentRegistry.shutdown();
    await _safetyMonitor.dispose();
    await _workflowExecutor.dispose();

    await _eventController.close();

    _isInitialized = false;
  }
}

/// Orchestration rule
class OrchestrationRule {
  final String id;
  final String name;
  final String description;
  final int priority;
  final bool Function(ExecutionContext) condition;
  final Future<void> Function(ExecutionContext) action;

  const OrchestrationRule({
    required this.id,
    required this.name,
    required this.description,
    required this.priority,
    required this.condition,
    required this.action,
  });
}

/// Orchestration event
class OrchestrationEvent {
  final OrchestrationEventType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  const OrchestrationEvent({
    required this.type,
    required this.data,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory OrchestrationEvent.fromJson(Map<String, dynamic> json) {
    return OrchestrationEvent(
      type: OrchestrationEventType.values
          .firstWhere((e) => e.name == json['type']),
      data: json['data'] as Map<String, dynamic>,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

/// Orchestration event types
enum OrchestrationEventType {
  initialized,
  initializationFailed,
  started,
  stopped,
  workflowRegistered,
  workflowUnregistered,
  workflowExecutionRequested,
  workflowTriggerFailed,
  agentExecutionRequested,
  agentEvent,
  safetyEvent,
  workflowEvent,
}

/// Orchestration exception
class OrchestrationException implements Exception {
  final String message;
  OrchestrationException(this.message);

  @override
  String toString() => 'OrchestrationException: $message';
}
