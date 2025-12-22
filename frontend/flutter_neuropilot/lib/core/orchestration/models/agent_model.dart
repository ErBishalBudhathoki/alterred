
/// Base model for all agents in the orchestration system
class Agent {
  final String id;
  final String name;
  final String description;
  final AgentType type;
  final AgentCapabilities capabilities;
  final AgentStatus status;
  final Map<String, dynamic> config;
  final DateTime lastActive;
  final List<String> dependencies;
  final int priority;

  const Agent({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.capabilities,
    this.status = AgentStatus.idle,
    this.config = const {},
    required this.lastActive,
    this.dependencies = const [],
    this.priority = 0,
  });

  Agent copyWith({
    String? id,
    String? name,
    String? description,
    AgentType? type,
    AgentCapabilities? capabilities,
    AgentStatus? status,
    Map<String, dynamic>? config,
    DateTime? lastActive,
    List<String>? dependencies,
    int? priority,
  }) {
    return Agent(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      capabilities: capabilities ?? this.capabilities,
      status: status ?? this.status,
      config: config ?? this.config,
      lastActive: lastActive ?? this.lastActive,
      dependencies: dependencies ?? this.dependencies,
      priority: priority ?? this.priority,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.name,
      'capabilities': capabilities.toJson(),
      'status': status.name,
      'config': config,
      'last_active': lastActive.toIso8601String(),
      'dependencies': dependencies,
      'priority': priority,
    };
  }

  factory Agent.fromJson(Map<String, dynamic> json) {
    return Agent(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      type: AgentType.values.firstWhere((e) => e.name == json['type']),
      capabilities: AgentCapabilities.fromJson(json['capabilities'] as Map<String, dynamic>),
      status: AgentStatus.values.firstWhere((e) => e.name == json['status']),
      config: json['config'] as Map<String, dynamic>? ?? {},
      lastActive: DateTime.parse(json['last_active'] as String),
      dependencies: (json['dependencies'] as List<dynamic>?)?.cast<String>() ?? [],
      priority: json['priority'] as int? ?? 0,
    );
  }
}

enum AgentType {
  reactive,    // Responds to user requests
  proactive,   // Monitors and triggers actions
  workflow,    // Orchestrates complex processes
  safety,      // Monitors for safety conditions
}

enum AgentStatus {
  idle,
  active,
  busy,
  error,
  disabled,
  monitoring,
}

class AgentCapabilities {
  final bool canExecuteParallel;
  final bool canBeInterrupted;
  final bool canInterruptOthers;
  final bool requiresUserInput;
  final bool hasMemory;
  final bool canLearn;
  final List<String> inputTypes;
  final List<String> outputTypes;
  final Duration maxExecutionTime;
  final int maxConcurrentInstances;

  const AgentCapabilities({
    this.canExecuteParallel = true,
    this.canBeInterrupted = true,
    this.canInterruptOthers = false,
    this.requiresUserInput = false,
    this.hasMemory = false,
    this.canLearn = false,
    this.inputTypes = const [],
    this.outputTypes = const [],
    this.maxExecutionTime = const Duration(minutes: 5),
    this.maxConcurrentInstances = 1,
  });

  AgentCapabilities copyWith({
    bool? canExecuteParallel,
    bool? canBeInterrupted,
    bool? canInterruptOthers,
    bool? requiresUserInput,
    bool? hasMemory,
    bool? canLearn,
    List<String>? inputTypes,
    List<String>? outputTypes,
    Duration? maxExecutionTime,
    int? maxConcurrentInstances,
  }) {
    return AgentCapabilities(
      canExecuteParallel: canExecuteParallel ?? this.canExecuteParallel,
      canBeInterrupted: canBeInterrupted ?? this.canBeInterrupted,
      canInterruptOthers: canInterruptOthers ?? this.canInterruptOthers,
      requiresUserInput: requiresUserInput ?? this.requiresUserInput,
      hasMemory: hasMemory ?? this.hasMemory,
      canLearn: canLearn ?? this.canLearn,
      inputTypes: inputTypes ?? this.inputTypes,
      outputTypes: outputTypes ?? this.outputTypes,
      maxExecutionTime: maxExecutionTime ?? this.maxExecutionTime,
      maxConcurrentInstances: maxConcurrentInstances ?? this.maxConcurrentInstances,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'can_execute_parallel': canExecuteParallel,
      'can_be_interrupted': canBeInterrupted,
      'can_interrupt_others': canInterruptOthers,
      'requires_user_input': requiresUserInput,
      'has_memory': hasMemory,
      'can_learn': canLearn,
      'input_types': inputTypes,
      'output_types': outputTypes,
      'max_execution_time': maxExecutionTime.inMilliseconds,
      'max_concurrent_instances': maxConcurrentInstances,
    };
  }

  factory AgentCapabilities.fromJson(Map<String, dynamic> json) {
    return AgentCapabilities(
      canExecuteParallel: json['can_execute_parallel'] as bool? ?? true,
      canBeInterrupted: json['can_be_interrupted'] as bool? ?? true,
      canInterruptOthers: json['can_interrupt_others'] as bool? ?? false,
      requiresUserInput: json['requires_user_input'] as bool? ?? false,
      hasMemory: json['has_memory'] as bool? ?? false,
      canLearn: json['can_learn'] as bool? ?? false,
      inputTypes: (json['input_types'] as List<dynamic>?)?.cast<String>() ?? [],
      outputTypes: (json['output_types'] as List<dynamic>?)?.cast<String>() ?? [],
      maxExecutionTime: Duration(milliseconds: json['max_execution_time'] as int? ?? 300000),
      maxConcurrentInstances: json['max_concurrent_instances'] as int? ?? 1,
    );
  }
}

/// Execution context for agent operations
class ExecutionContext {
  final String id;
  final String userId;
  final Map<String, dynamic> userState;
  final Map<String, dynamic> sessionData;
  final DateTime timestamp;
  final String? triggerSource;
  final Map<String, dynamic> parameters;
  final List<String> availableAgents;
  final ExecutionPriority priority;

  const ExecutionContext({
    required this.id,
    required this.userId,
    this.userState = const {},
    this.sessionData = const {},
    required this.timestamp,
    this.triggerSource,
    this.parameters = const {},
    this.availableAgents = const [],
    this.priority = ExecutionPriority.normal,
  });

  ExecutionContext copyWith({
    String? id,
    String? userId,
    Map<String, dynamic>? userState,
    Map<String, dynamic>? sessionData,
    DateTime? timestamp,
    String? triggerSource,
    Map<String, dynamic>? parameters,
    List<String>? availableAgents,
    ExecutionPriority? priority,
  }) {
    return ExecutionContext(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userState: userState ?? this.userState,
      sessionData: sessionData ?? this.sessionData,
      timestamp: timestamp ?? this.timestamp,
      triggerSource: triggerSource ?? this.triggerSource,
      parameters: parameters ?? this.parameters,
      availableAgents: availableAgents ?? this.availableAgents,
      priority: priority ?? this.priority,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_state': userState,
      'session_data': sessionData,
      'timestamp': timestamp.toIso8601String(),
      'trigger_source': triggerSource,
      'parameters': parameters,
      'available_agents': availableAgents,
      'priority': priority.name,
    };
  }

  factory ExecutionContext.fromJson(Map<String, dynamic> json) {
    return ExecutionContext(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      userState: json['user_state'] as Map<String, dynamic>? ?? {},
      sessionData: json['session_data'] as Map<String, dynamic>? ?? {},
      timestamp: DateTime.parse(json['timestamp'] as String),
      triggerSource: json['trigger_source'] as String?,
      parameters: json['parameters'] as Map<String, dynamic>? ?? {},
      availableAgents: (json['available_agents'] as List<dynamic>?)?.cast<String>() ?? [],
      priority: ExecutionPriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => ExecutionPriority.normal,
      ),
    );
  }
}

enum ExecutionPriority {
  low,
  normal,
  high,
  urgent,
  safety,
}

/// Result of agent execution
class AgentResult {
  final String agentId;
  final bool success;
  final Map<String, dynamic> data;
  final String? error;
  final Duration executionTime;
  final DateTime timestamp;
  final List<String> triggeredAgents;
  final Map<String, dynamic> metadata;

  const AgentResult({
    required this.agentId,
    required this.success,
    this.data = const {},
    this.error,
    required this.executionTime,
    required this.timestamp,
    this.triggeredAgents = const [],
    this.metadata = const {},
  });

  AgentResult copyWith({
    String? agentId,
    bool? success,
    Map<String, dynamic>? data,
    String? error,
    Duration? executionTime,
    DateTime? timestamp,
    List<String>? triggeredAgents,
    Map<String, dynamic>? metadata,
  }) {
    return AgentResult(
      agentId: agentId ?? this.agentId,
      success: success ?? this.success,
      data: data ?? this.data,
      error: error ?? this.error,
      executionTime: executionTime ?? this.executionTime,
      timestamp: timestamp ?? this.timestamp,
      triggeredAgents: triggeredAgents ?? this.triggeredAgents,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'agent_id': agentId,
      'success': success,
      'data': data,
      'error': error,
      'execution_time': executionTime.inMilliseconds,
      'timestamp': timestamp.toIso8601String(),
      'triggered_agents': triggeredAgents,
      'metadata': metadata,
    };
  }

  factory AgentResult.fromJson(Map<String, dynamic> json) {
    return AgentResult(
      agentId: json['agent_id'] as String,
      success: json['success'] as bool,
      data: json['data'] as Map<String, dynamic>? ?? {},
      error: json['error'] as String?,
      executionTime: Duration(milliseconds: json['execution_time'] as int),
      timestamp: DateTime.parse(json['timestamp'] as String),
      triggeredAgents: (json['triggered_agents'] as List<dynamic>?)?.cast<String>() ?? [],
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }
}