import 'dart:async';
import '../models/agent_model.dart';
import '../agents/base/agent_base.dart';
import '../agents/energy_assessment_agent.dart';
import '../agents/decision_helper_agent.dart';
import '../agents/hyperfocus_detection_agent.dart';
import '../agents/time_estimation_agent.dart';
import '../agents/break_enforcement_agent.dart';

/// Central registry for all agents in the orchestration system
class AgentRegistry {
  static final AgentRegistry _instance = AgentRegistry._internal();
  factory AgentRegistry() => _instance;
  AgentRegistry._internal();

  final Map<String, AgentBase> _agents = {};
  final Map<String, AgentFactory> _factories = {};
  StreamController<AgentRegistryEvent> _eventController =
      StreamController<AgentRegistryEvent>.broadcast();

  /// Stream of registry events
  Stream<AgentRegistryEvent> get events => _eventController.stream;

  /// Initialize the registry with default agents
  Future<void> initialize() async {
    if (_eventController.isClosed) {
      _eventController = StreamController<AgentRegistryEvent>.broadcast();
    }

    // Register agent factories
    _registerDefaultFactories();

    // Create and register default agents
    await _createDefaultAgents();

    _eventController.add(AgentRegistryEvent(
      type: AgentRegistryEventType.initialized,
      data: {'total_agents': _agents.length},
      timestamp: DateTime.now(),
    ));
  }

  /// Register agent factories
  void _registerDefaultFactories() {
    _factories[EnergyAssessmentAgent.agentId] = () => EnergyAssessmentAgent();
    _factories[DecisionHelperAgent.agentId] = () => DecisionHelperAgent();
    _factories[HyperfocusDetectionAgent.agentId] =
        () => HyperfocusDetectionAgent();
    _factories[TimeEstimationAgent.agentId] = () => TimeEstimationAgent();
    _factories[BreakEnforcementAgent.agentId] = () => BreakEnforcementAgent();
  }

  /// Create and register default agents
  Future<void> _createDefaultAgents() async {
    for (final factory in _factories.values) {
      final agent = factory();
      await registerAgent(agent);
    }
  }

  /// Register an agent
  Future<void> registerAgent(AgentBase agent) async {
    if (_agents.containsKey(agent.metadata.id)) {
      throw AgentRegistryException(
          'Agent ${agent.metadata.id} is already registered');
    }

    // Initialize the agent
    await agent.initialize();

    // Register the agent
    _agents[agent.metadata.id] = agent;

    // Listen to agent status changes
    agent.statusChanges.listen((status) {
      _eventController.add(AgentRegistryEvent(
        type: AgentRegistryEventType.agentStatusChanged,
        data: {
          'agent_id': agent.metadata.id,
          'status': status.name,
        },
        timestamp: DateTime.now(),
      ));
    });

    // Listen to agent results
    agent.results.listen((result) {
      _eventController.add(AgentRegistryEvent(
        type: AgentRegistryEventType.agentResultReceived,
        data: {
          'agent_id': agent.metadata.id,
          'result': result.toJson(),
        },
        timestamp: DateTime.now(),
      ));
    });

    _eventController.add(AgentRegistryEvent(
      type: AgentRegistryEventType.agentRegistered,
      data: {
        'agent_id': agent.metadata.id,
        'agent_name': agent.metadata.name,
        'agent_type': agent.metadata.type.name,
      },
      timestamp: DateTime.now(),
    ));
  }

  /// Unregister an agent
  Future<void> unregisterAgent(String agentId) async {
    final agent = _agents[agentId];
    if (agent == null) {
      throw AgentRegistryException('Agent $agentId is not registered');
    }

    // Dispose the agent
    await agent.dispose();

    // Remove from registry
    _agents.remove(agentId);

    _eventController.add(AgentRegistryEvent(
      type: AgentRegistryEventType.agentUnregistered,
      data: {'agent_id': agentId},
      timestamp: DateTime.now(),
    ));
  }

  /// Get an agent by ID
  AgentBase? getAgent(String agentId) {
    return _agents[agentId];
  }

  /// Get all agents
  List<AgentBase> getAllAgents() {
    return _agents.values.toList();
  }

  /// Get agents by type
  List<AgentBase> getAgentsByType(AgentType type) {
    return _agents.values
        .where((agent) => agent.metadata.type == type)
        .toList();
  }

  /// Get agents by capability
  List<AgentBase> getAgentsByCapability(String capability) {
    return _agents.values.where((agent) {
      switch (capability) {
        case 'parallel':
          return agent.metadata.capabilities.canExecuteParallel;
        case 'interruptible':
          return agent.metadata.capabilities.canBeInterrupted;
        case 'interrupt_others':
          return agent.metadata.capabilities.canInterruptOthers;
        case 'memory':
          return agent.metadata.capabilities.hasMemory;
        case 'learning':
          return agent.metadata.capabilities.canLearn;
        default:
          return false;
      }
    }).toList();
  }

  /// Get available agents for execution context
  List<AgentBase> getAvailableAgents(ExecutionContext context) {
    return _agents.values.where((agent) => agent.canExecute(context)).toList();
  }

  /// Get agents that can handle specific input type
  List<AgentBase> getAgentsForInputType(String inputType) {
    return _agents.values
        .where((agent) =>
            agent.metadata.capabilities.inputTypes.contains(inputType) ||
            agent.metadata.capabilities.inputTypes.isEmpty)
        .toList();
  }

  /// Get agents that produce specific output type
  List<AgentBase> getAgentsForOutputType(String outputType) {
    return _agents.values
        .where((agent) =>
            agent.metadata.capabilities.outputTypes.contains(outputType))
        .toList();
  }

  /// Check if agent exists
  bool hasAgent(String agentId) {
    return _agents.containsKey(agentId);
  }

  /// Get agent count
  int get agentCount => _agents.length;

  /// Get agents by status
  List<AgentBase> getAgentsByStatus(AgentStatus status) {
    return _agents.values.where((agent) => agent.status == status).toList();
  }

  /// Get active agents
  List<AgentBase> getActiveAgents() {
    return getAgentsByStatus(AgentStatus.active);
  }

  /// Get idle agents
  List<AgentBase> getIdleAgents() {
    return getAgentsByStatus(AgentStatus.idle);
  }

  /// Get monitoring agents
  List<AgentBase> getMonitoringAgents() {
    return getAgentsByStatus(AgentStatus.monitoring);
  }

  /// Get error agents
  List<AgentBase> getErrorAgents() {
    return getAgentsByStatus(AgentStatus.error);
  }

  /// Execute agent
  Future<AgentResult> executeAgent(
      String agentId, ExecutionContext context) async {
    final agent = getAgent(agentId);
    if (agent == null) {
      throw AgentRegistryException('Agent $agentId not found');
    }

    return await agent.execute(context);
  }

  /// Execute multiple agents in parallel
  Future<List<AgentResult>> executeAgentsParallel(
      List<String> agentIds, ExecutionContext context) async {
    final agents = agentIds
        .map((id) => getAgent(id))
        .where((agent) => agent != null)
        .cast<AgentBase>();

    // Filter agents that can execute in parallel
    final parallelAgents = agents
        .where((agent) => agent.metadata.capabilities.canExecuteParallel)
        .toList();

    if (parallelAgents.length != agentIds.length) {
      throw AgentRegistryException('Not all agents support parallel execution');
    }

    // Execute all agents in parallel
    final futures = parallelAgents.map((agent) => agent.execute(context));
    return await Future.wait(futures);
  }

  /// Execute agents in sequence
  Future<List<AgentResult>> executeAgentsSequential(
      List<String> agentIds, ExecutionContext context) async {
    final results = <AgentResult>[];

    for (final agentId in agentIds) {
      final agent = getAgent(agentId);
      if (agent == null) {
        throw AgentRegistryException('Agent $agentId not found');
      }

      final result = await agent.execute(context);
      results.add(result);

      // Stop execution if an agent fails (unless configured otherwise)
      if (!result.success) {
        break;
      }
    }

    return results;
  }

  /// Get agent health status
  Future<Map<String, dynamic>> getAgentHealth(String agentId) async {
    final agent = getAgent(agentId);
    if (agent == null) {
      throw AgentRegistryException('Agent $agentId not found');
    }

    return await agent.getHealthStatus();
  }

  /// Get all agents health status
  Future<Map<String, dynamic>> getAllAgentsHealth() async {
    final healthMap = <String, dynamic>{};

    for (final agent in _agents.values) {
      try {
        healthMap[agent.metadata.id] = await agent.getHealthStatus();
      } catch (error) {
        healthMap[agent.metadata.id] = {
          'healthy': false,
          'error': error.toString(),
        };
      }
    }

    return healthMap;
  }

  /// Get registry statistics
  Map<String, dynamic> getRegistryStats() {
    final statusCounts = <String, int>{};
    final typeCounts = <String, int>{};

    for (final agent in _agents.values) {
      final status = agent.status.name;
      final type = agent.metadata.type.name;

      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
      typeCounts[type] = (typeCounts[type] ?? 0) + 1;
    }

    return {
      'total_agents': _agents.length,
      'status_breakdown': statusCounts,
      'type_breakdown': typeCounts,
      'active_agents': getActiveAgents().length,
      'monitoring_agents': getMonitoringAgents().length,
      'error_agents': getErrorAgents().length,
    };
  }

  /// Update agent configuration
  Future<void> updateAgentConfig(
      String agentId, Map<String, dynamic> config) async {
    final agent = getAgent(agentId);
    if (agent == null) {
      throw AgentRegistryException('Agent $agentId not found');
    }

    await agent.updateConfig(config);

    _eventController.add(AgentRegistryEvent(
      type: AgentRegistryEventType.agentConfigUpdated,
      data: {
        'agent_id': agentId,
        'config': config,
      },
      timestamp: DateTime.now(),
    ));
  }

  /// Get agent metrics
  Map<String, dynamic> getAgentMetrics(String agentId) {
    final agent = getAgent(agentId);
    if (agent == null) {
      throw AgentRegistryException('Agent $agentId not found');
    }

    return agent.getMetrics();
  }

  /// Get all agents metrics
  Map<String, dynamic> getAllAgentsMetrics() {
    final metricsMap = <String, dynamic>{};

    for (final agent in _agents.values) {
      metricsMap[agent.metadata.id] = agent.getMetrics();
    }

    return metricsMap;
  }

  /// Find agents by dependency
  List<AgentBase> findAgentsByDependency(String dependencyAgentId) {
    return _agents.values
        .where(
            (agent) => agent.metadata.dependencies.contains(dependencyAgentId))
        .toList();
  }

  /// Get agent dependency graph
  Map<String, List<String>> getAgentDependencyGraph() {
    final graph = <String, List<String>>{};

    for (final agent in _agents.values) {
      graph[agent.metadata.id] = agent.metadata.dependencies;
    }

    return graph;
  }

  /// Validate agent dependencies
  List<String> validateDependencies() {
    final errors = <String>[];

    for (final agent in _agents.values) {
      for (final dependency in agent.metadata.dependencies) {
        if (!hasAgent(dependency)) {
          errors.add(
              'Agent ${agent.metadata.id} depends on missing agent $dependency');
        }
      }
    }

    return errors;
  }

  /// Get agents in dependency order
  List<AgentBase> getAgentsInDependencyOrder() {
    final visited = <String>{};
    final result = <AgentBase>[];

    void visit(String agentId) {
      if (visited.contains(agentId)) return;

      final agent = getAgent(agentId);
      if (agent == null) return;

      visited.add(agentId);

      // Visit dependencies first
      for (final dependency in agent.metadata.dependencies) {
        visit(dependency);
      }

      result.add(agent);
    }

    // Visit all agents
    for (final agentId in _agents.keys) {
      visit(agentId);
    }

    return result;
  }

  /// Shutdown all agents
  Future<void> shutdown() async {
    for (final agent in _agents.values) {
      try {
        await agent.dispose();
      } catch (error) {
        // Log error but continue shutdown
      }
    }

    _agents.clear();

    if (!_eventController.isClosed) {
      _eventController.add(AgentRegistryEvent(
        type: AgentRegistryEventType.shutdown,
        data: {},
        timestamp: DateTime.now(),
      ));

      await _eventController.close();
    }
  }

  /// Create agent from factory
  AgentBase? createAgent(String agentId) {
    final factory = _factories[agentId];
    if (factory == null) return null;

    return factory();
  }

  /// Register agent factory
  void registerAgentFactory(String agentId, AgentFactory factory) {
    _factories[agentId] = factory;
  }

  /// Get available agent types
  List<String> getAvailableAgentTypes() {
    return _factories.keys.toList();
  }
}

/// Factory function for creating agents
typedef AgentFactory = AgentBase Function();

/// Registry event types
enum AgentRegistryEventType {
  initialized,
  agentRegistered,
  agentUnregistered,
  agentStatusChanged,
  agentResultReceived,
  agentConfigUpdated,
  shutdown,
}

/// Registry event
class AgentRegistryEvent {
  final AgentRegistryEventType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  const AgentRegistryEvent({
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

  factory AgentRegistryEvent.fromJson(Map<String, dynamic> json) {
    return AgentRegistryEvent(
      type: AgentRegistryEventType.values
          .firstWhere((e) => e.name == json['type']),
      data: json['data'] as Map<String, dynamic>,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

/// Registry exception
class AgentRegistryException implements Exception {
  final String message;
  AgentRegistryException(this.message);

  @override
  String toString() => 'AgentRegistryException: $message';
}
