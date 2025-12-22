import 'dart:async';
import '../../models/agent_model.dart';
import 'agent_base.dart';

/// Base class for reactive agents that respond to user requests
abstract class ReactiveAgent extends AgentBase with MemoryCapability {
  ReactiveAgent(super.metadata);

  @override
  Future<AgentResult> executeInternal(ExecutionContext context) async {
    final startTime = DateTime.now();
    
    try {
      // Validate input parameters
      if (!validateInput(context.parameters)) {
        return AgentResult(
          agentId: metadata.id,
          success: false,
          error: 'Invalid input parameters',
          executionTime: DateTime.now().difference(startTime),
          timestamp: DateTime.now(),
        );
      }

      // Execute reactive logic
      final result = await processRequest(context);
      
      // Store result in memory if agent has memory capability
      if (metadata.capabilities.hasMemory) {
        remember('last_execution', {
          'context': context.toJson(),
          'result': result.toJson(),
        });
      }

      return result;
    } catch (error) {
      return AgentResult(
        agentId: metadata.id,
        success: false,
        error: error.toString(),
        executionTime: DateTime.now().difference(startTime),
        timestamp: DateTime.now(),
      );
    }
  }

  /// Process the user request - must be implemented by subclasses
  Future<AgentResult> processRequest(ExecutionContext context);

  /// Get suggested actions based on current context
  Future<List<String>> getSuggestions(ExecutionContext context) async {
    // Override in subclasses to provide context-aware suggestions
    return [];
  }

  /// Check if agent can handle the given request type
  bool canHandleRequest(String requestType) {
    return metadata.capabilities.inputTypes.contains(requestType) ||
           metadata.capabilities.inputTypes.isEmpty;
  }
}

/// Mixin for agents that can provide real-time responses
mixin RealTimeCapability on ReactiveAgent {
  final StreamController<Map<String, dynamic>> _realtimeController = 
      StreamController<Map<String, dynamic>>.broadcast();

  /// Stream of real-time updates
  Stream<Map<String, dynamic>> get realtimeUpdates => _realtimeController.stream;

  /// Send real-time update
  void sendRealtimeUpdate(Map<String, dynamic> update) {
    _realtimeController.add({
      'agent_id': metadata.id,
      'timestamp': DateTime.now().toIso8601String(),
      'data': update,
    });
  }

  @override
  Future<void> dispose() async {
    await _realtimeController.close();
    await super.dispose();
  }
}

/// Mixin for agents that support streaming responses
mixin StreamingCapability on ReactiveAgent {
  /// Process request with streaming response
  Stream<AgentResult> processRequestStream(ExecutionContext context) async* {
    final startTime = DateTime.now();
    
    try {
      await for (final chunk in processRequestInternal(context)) {
        yield AgentResult(
          agentId: metadata.id,
          success: true,
          data: chunk,
          executionTime: DateTime.now().difference(startTime),
          timestamp: DateTime.now(),
          metadata: {'streaming': true, 'partial': true},
        );
      }
      
      // Final result
      yield AgentResult(
        agentId: metadata.id,
        success: true,
        data: {'completed': true},
        executionTime: DateTime.now().difference(startTime),
        timestamp: DateTime.now(),
        metadata: {'streaming': true, 'partial': false},
      );
    } catch (error) {
      yield AgentResult(
        agentId: metadata.id,
        success: false,
        error: error.toString(),
        executionTime: DateTime.now().difference(startTime),
        timestamp: DateTime.now(),
        metadata: {'streaming': true, 'error': true},
      );
    }
  }

  /// Process request with streaming - override in subclasses
  Stream<Map<String, dynamic>> processRequestInternal(ExecutionContext context) async* {
    // Default implementation - override in subclasses
    yield {'message': 'Streaming not implemented'};
  }
}

/// Mixin for agents that can be interrupted gracefully
mixin InterruptibleCapability on ReactiveAgent {
  bool _isInterrupted = false;
  Completer<void>? _interruptCompleter;

  /// Check if agent is interrupted
  bool get isInterrupted => _isInterrupted;

  /// Interrupt the agent
  Future<void> interrupt() async {
    _isInterrupted = true;
    _interruptCompleter = Completer<void>();
    
    // Perform cleanup
    await onInterrupt();
    
    _interruptCompleter?.complete();
  }

  /// Wait for interrupt to complete
  Future<void> waitForInterrupt() async {
    if (_interruptCompleter != null) {
      await _interruptCompleter!.future;
    }
  }

  /// Reset interrupt state
  void resetInterrupt() {
    _isInterrupted = false;
    _interruptCompleter = null;
  }

  /// Called when agent is interrupted - override in subclasses
  Future<void> onInterrupt() async {
    // Default implementation - override in subclasses
  }

  /// Check for interrupt during long operations
  void checkInterrupt() {
    if (_isInterrupted) {
      throw InterruptedException('Agent execution was interrupted');
    }
  }
}

/// Exception thrown when agent is interrupted
class InterruptedException implements Exception {
  final String message;
  InterruptedException(this.message);
  
  @override
  String toString() => 'InterruptedException: $message';
}