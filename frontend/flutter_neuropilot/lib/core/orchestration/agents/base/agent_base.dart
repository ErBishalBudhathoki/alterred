import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/agent_model.dart';

/// Base class for all agents in the orchestration system
abstract class AgentBase {
  final Agent metadata;
  final StreamController<AgentResult> _resultController = StreamController<AgentResult>.broadcast();
  final StreamController<AgentStatus> _statusController = StreamController<AgentStatus>.broadcast();
  
  AgentStatus _currentStatus = AgentStatus.idle;
  DateTime _lastActive = DateTime.now();

  AgentBase(this.metadata);

  /// Stream of agent results
  Stream<AgentResult> get results => _resultController.stream;

  /// Stream of agent status changes
  Stream<AgentStatus> get statusChanges => _statusController.stream;

  /// Current agent status
  AgentStatus get status => _currentStatus;

  /// Last time agent was active
  DateTime get lastActive => _lastActive;

  /// Execute the agent with given context
  Future<AgentResult> execute(ExecutionContext context) async {
    if (!canExecute(context)) {
      return AgentResult(
        agentId: metadata.id,
        success: false,
        error: 'Agent cannot execute in current context',
        executionTime: Duration.zero,
        timestamp: DateTime.now(),
      );
    }

    updateStatus(AgentStatus.active);
    final startTime = DateTime.now();

    try {
      // Check if agent should be interrupted
      if (metadata.capabilities.canBeInterrupted && _shouldInterrupt(context)) {
        updateStatus(AgentStatus.idle);
        return AgentResult(
          agentId: metadata.id,
          success: false,
          error: 'Agent execution was interrupted',
          executionTime: DateTime.now().difference(startTime),
          timestamp: DateTime.now(),
        );
      }

      // Execute the agent-specific logic
      final result = await executeInternal(context);
      
      updateStatus(AgentStatus.idle);
      _lastActive = DateTime.now();
      
      // Emit result to stream
      _resultController.add(result);
      
      return result;
    } catch (error) {
      updateStatus(AgentStatus.error);
      final errorResult = AgentResult(
        agentId: metadata.id,
        success: false,
        error: error.toString(),
        executionTime: DateTime.now().difference(startTime),
        timestamp: DateTime.now(),
      );
      
      _resultController.add(errorResult);
      return errorResult;
    }
  }

  /// Agent-specific execution logic - must be implemented by subclasses
  Future<AgentResult> executeInternal(ExecutionContext context);

  /// Check if agent can execute in the given context
  bool canExecute(ExecutionContext context) {
    // Check if agent is disabled
    if (metadata.status == AgentStatus.disabled) {
      return false;
    }

    // Check if agent is already busy and doesn't support parallel execution
    if (_currentStatus == AgentStatus.busy && !metadata.capabilities.canExecuteParallel) {
      return false;
    }

    // Check dependencies
    for (final dependency in metadata.dependencies) {
      if (!context.availableAgents.contains(dependency)) {
        return false;
      }
    }

    return true;
  }

  /// Check if agent should be interrupted
  bool _shouldInterrupt(ExecutionContext context) {
    // Check for safety priority interrupts
    if (context.priority == ExecutionPriority.safety) {
      return true;
    }

    // Check for urgent priority interrupts if agent allows it
    if (context.priority == ExecutionPriority.urgent && metadata.capabilities.canBeInterrupted) {
      return true;
    }

    return false;
  }

  /// Update agent status and notify listeners
  @protected
  void updateStatus(AgentStatus newStatus) {
    if (_currentStatus != newStatus) {
      _currentStatus = newStatus;
      _statusController.add(newStatus);
    }
  }

  /// Initialize agent - called when agent is registered
  Future<void> initialize() async {
    // Override in subclasses if needed
  }

  /// Cleanup agent resources
  Future<void> dispose() async {
    await _resultController.close();
    await _statusController.close();
  }

  /// Get agent health status
  Future<Map<String, dynamic>> getHealthStatus() async {
    return {
      'agent_id': metadata.id,
      'status': _currentStatus.name,
      'last_active': _lastActive.toIso8601String(),
      'uptime': DateTime.now().difference(_lastActive).inMilliseconds,
      'healthy': _currentStatus != AgentStatus.error,
    };
  }

  /// Handle configuration updates
  Future<void> updateConfig(Map<String, dynamic> newConfig) async {
    // Override in subclasses if needed
  }

  /// Validate input parameters
  bool validateInput(Map<String, dynamic> parameters) {
    // Override in subclasses for specific validation
    return true;
  }

  /// Get agent metrics
  Map<String, dynamic> getMetrics() {
    return {
      'agent_id': metadata.id,
      'status': _currentStatus.name,
      'last_active': _lastActive.toIso8601String(),
      'execution_count': 0, // Override in subclasses to track
      'success_rate': 0.0,   // Override in subclasses to track
      'average_execution_time': 0, // Override in subclasses to track
    };
  }
}

/// Mixin for agents that can learn and adapt
mixin LearningCapability on AgentBase {
  final Map<String, dynamic> _learningData = {};

  /// Learn from execution result
  void learn(ExecutionContext context, AgentResult result) {
    // Store learning data
    final key = _generateLearningKey(context);
    _learningData[key] = {
      'context': context.toJson(),
      'result': result.toJson(),
      'timestamp': DateTime.now().toIso8601String(),
    };

    // Implement learning logic in subclasses
    processLearning(context, result);
  }

  /// Process learning data - override in subclasses
  void processLearning(ExecutionContext context, AgentResult result) {
    // Default implementation - override in subclasses
  }

  /// Generate a key for learning data
  String _generateLearningKey(ExecutionContext context) {
    return '${context.userId}_${context.triggerSource}_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Get learning insights
  Map<String, dynamic> getLearningInsights() {
    return {
      'total_learning_entries': _learningData.length,
      'learning_data': _learningData,
    };
  }
}

/// Mixin for agents that have memory
mixin MemoryCapability on AgentBase {
  final Map<String, dynamic> _memory = {};

  /// Store data in agent memory
  void remember(String key, dynamic value) {
    _memory[key] = {
      'value': value,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Retrieve data from agent memory
  T? recall<T>(String key) {
    final entry = _memory[key];
    if (entry != null) {
      return entry['value'] as T?;
    }
    return null;
  }

  /// Forget data from agent memory
  void forget(String key) {
    _memory.remove(key);
  }

  /// Clear all memory
  void clearMemory() {
    _memory.clear();
  }

  /// Get memory usage statistics
  Map<String, dynamic> getMemoryStats() {
    return {
      'total_entries': _memory.length,
      'memory_keys': _memory.keys.toList(),
      'oldest_entry': _getOldestEntry(),
      'newest_entry': _getNewestEntry(),
    };
  }

  String? _getOldestEntry() {
    if (_memory.isEmpty) return null;
    
    String? oldestKey;
    DateTime? oldestTime;
    
    for (final entry in _memory.entries) {
      final timestamp = DateTime.parse(entry.value['timestamp'] as String);
      if (oldestTime == null || timestamp.isBefore(oldestTime)) {
        oldestTime = timestamp;
        oldestKey = entry.key;
      }
    }
    
    return oldestKey;
  }

  String? _getNewestEntry() {
    if (_memory.isEmpty) return null;
    
    String? newestKey;
    DateTime? newestTime;
    
    for (final entry in _memory.entries) {
      final timestamp = DateTime.parse(entry.value['timestamp'] as String);
      if (newestTime == null || timestamp.isAfter(newestTime)) {
        newestTime = timestamp;
        newestKey = entry.key;
      }
    }
    
    return newestKey;
  }
}