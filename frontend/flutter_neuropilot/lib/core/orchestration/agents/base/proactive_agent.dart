import 'dart:async';
import '../../models/agent_model.dart';
import 'agent_base.dart';

/// Base class for proactive agents that monitor and trigger actions
abstract class ProactiveAgent extends AgentBase with MemoryCapability, LearningCapability {
  Timer? _monitoringTimer;
  bool _isMonitoring = false;
  final Duration _monitoringInterval;
  final StreamController<ProactiveEvent> _eventController = StreamController<ProactiveEvent>.broadcast();

  ProactiveAgent(super.metadata, {Duration monitoringInterval = const Duration(seconds: 30)})
      : _monitoringInterval = monitoringInterval;

  /// Stream of proactive events
  Stream<ProactiveEvent> get events => _eventController.stream;

  /// Whether agent is currently monitoring
  bool get isMonitoring => _isMonitoring;

  @override
  Future<AgentResult> executeInternal(ExecutionContext context) async {
    final startTime = DateTime.now();
    
    try {
      // For proactive agents, execution usually means starting/stopping monitoring
      final action = context.parameters['action'] as String? ?? 'monitor';
      
      switch (action) {
        case 'start_monitoring':
          await startMonitoring(context);
          break;
        case 'stop_monitoring':
          await stopMonitoring();
          break;
        case 'check':
          await performCheck(context);
          break;
        default:
          await performProactiveAction(context);
      }

      return AgentResult(
        agentId: metadata.id,
        success: true,
        data: {'action': action, 'monitoring': _isMonitoring},
        executionTime: DateTime.now().difference(startTime),
        timestamp: DateTime.now(),
      );
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

  /// Start monitoring for conditions
  Future<void> startMonitoring(ExecutionContext context) async {
    if (_isMonitoring) return;

    _isMonitoring = true;
    updateStatus(AgentStatus.monitoring);

    // Store monitoring context
    remember('monitoring_context', context.toJson());

    // Start periodic monitoring
    _monitoringTimer = Timer.periodic(_monitoringInterval, (timer) async {
      try {
        await _performMonitoringCheck(context);
      } catch (error) {
        _eventController.add(ProactiveEvent(
          agentId: metadata.id,
          type: ProactiveEventType.error,
          data: {'error': error.toString()},
          timestamp: DateTime.now(),
        ));
      }
    });

    // Perform initial check
    await _performMonitoringCheck(context);

    _eventController.add(ProactiveEvent(
      agentId: metadata.id,
      type: ProactiveEventType.monitoringStarted,
      data: {'interval': _monitoringInterval.inSeconds},
      timestamp: DateTime.now(),
    ));
  }

  /// Stop monitoring
  Future<void> stopMonitoring() async {
    if (!_isMonitoring) return;

    _isMonitoring = false;
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    updateStatus(AgentStatus.idle);

    _eventController.add(ProactiveEvent(
      agentId: metadata.id,
      type: ProactiveEventType.monitoringStopped,
      data: {},
      timestamp: DateTime.now(),
    ));
  }

  /// Perform a single monitoring check
  Future<void> _performMonitoringCheck(ExecutionContext context) async {
    final conditions = await checkConditions(context);
    
    for (final condition in conditions) {
      if (condition.shouldTrigger) {
        await _handleTriggeredCondition(condition, context);
      }
    }
  }

  /// Handle a triggered condition
  Future<void> _handleTriggeredCondition(MonitoringCondition condition, ExecutionContext context) async {
    // Learn from the trigger
    final result = AgentResult(
      agentId: metadata.id,
      success: true,
      data: condition.toJson(),
      executionTime: Duration.zero,
      timestamp: DateTime.now(),
    );
    learn(context, result);

    // Emit event
    _eventController.add(ProactiveEvent(
      agentId: metadata.id,
      type: ProactiveEventType.conditionTriggered,
      data: condition.toJson(),
      timestamp: DateTime.now(),
      priority: condition.priority,
    ));

    // Execute triggered action
    await onConditionTriggered(condition, context);
  }

  /// Check monitoring conditions - must be implemented by subclasses
  Future<List<MonitoringCondition>> checkConditions(ExecutionContext context);

  /// Called when a condition is triggered - must be implemented by subclasses
  Future<void> onConditionTriggered(MonitoringCondition condition, ExecutionContext context);

  /// Perform a manual check
  Future<void> performCheck(ExecutionContext context) async {
    await _performMonitoringCheck(context);
  }

  /// Perform proactive action - override in subclasses
  Future<void> performProactiveAction(ExecutionContext context) async {
    // Default implementation - override in subclasses
  }

  @override
  Future<void> initialize() async {
    await super.initialize();
    
    // Auto-start monitoring if configured
    if (metadata.config['auto_start_monitoring'] == true) {
      final context = ExecutionContext(
        id: 'auto_start_${DateTime.now().millisecondsSinceEpoch}',
        userId: 'system',
        timestamp: DateTime.now(),
      );
      await startMonitoring(context);
    }
  }

  @override
  Future<void> dispose() async {
    await stopMonitoring();
    await _eventController.close();
    await super.dispose();
  }

  /// Get monitoring statistics
  Map<String, dynamic> getMonitoringStats() {
    return {
      'is_monitoring': _isMonitoring,
      'monitoring_interval': _monitoringInterval.inSeconds,
      'last_check': recall<String>('last_check_time'),
      'total_checks': recall<int>('total_checks') ?? 0,
      'total_triggers': recall<int>('total_triggers') ?? 0,
    };
  }

  /// Update monitoring interval
  Future<void> updateMonitoringInterval(Duration newInterval) async {
    if (_isMonitoring) {
      await stopMonitoring();
      // Update interval and restart
      final context = recall<Map<String, dynamic>>('monitoring_context');
      if (context != null) {
        await startMonitoring(ExecutionContext.fromJson(context));
      }
    }
  }
}

/// Event emitted by proactive agents
class ProactiveEvent {
  final String agentId;
  final ProactiveEventType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final ExecutionPriority priority;

  const ProactiveEvent({
    required this.agentId,
    required this.type,
    required this.data,
    required this.timestamp,
    this.priority = ExecutionPriority.normal,
  });

  Map<String, dynamic> toJson() {
    return {
      'agent_id': agentId,
      'type': type.name,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      'priority': priority.name,
    };
  }

  factory ProactiveEvent.fromJson(Map<String, dynamic> json) {
    return ProactiveEvent(
      agentId: json['agent_id'] as String,
      type: ProactiveEventType.values.firstWhere((e) => e.name == json['type']),
      data: json['data'] as Map<String, dynamic>,
      timestamp: DateTime.parse(json['timestamp'] as String),
      priority: ExecutionPriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => ExecutionPriority.normal,
      ),
    );
  }
}

enum ProactiveEventType {
  monitoringStarted,
  monitoringStopped,
  conditionTriggered,
  actionExecuted,
  error,
  warning,
  info,
}

/// Condition monitored by proactive agents
class MonitoringCondition {
  final String id;
  final String name;
  final String description;
  final bool shouldTrigger;
  final Map<String, dynamic> data;
  final ExecutionPriority priority;
  final Duration? cooldown;
  final DateTime? lastTriggered;

  const MonitoringCondition({
    required this.id,
    required this.name,
    required this.description,
    required this.shouldTrigger,
    this.data = const {},
    this.priority = ExecutionPriority.normal,
    this.cooldown,
    this.lastTriggered,
  });

  MonitoringCondition copyWith({
    String? id,
    String? name,
    String? description,
    bool? shouldTrigger,
    Map<String, dynamic>? data,
    ExecutionPriority? priority,
    Duration? cooldown,
    DateTime? lastTriggered,
  }) {
    return MonitoringCondition(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      shouldTrigger: shouldTrigger ?? this.shouldTrigger,
      data: data ?? this.data,
      priority: priority ?? this.priority,
      cooldown: cooldown ?? this.cooldown,
      lastTriggered: lastTriggered ?? this.lastTriggered,
    );
  }

  /// Check if condition is in cooldown period
  bool get isInCooldown {
    if (cooldown == null || lastTriggered == null) return false;
    return DateTime.now().difference(lastTriggered!).compareTo(cooldown!) < 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'should_trigger': shouldTrigger,
      'data': data,
      'priority': priority.name,
      'cooldown': cooldown?.inMilliseconds,
      'last_triggered': lastTriggered?.toIso8601String(),
    };
  }

  factory MonitoringCondition.fromJson(Map<String, dynamic> json) {
    return MonitoringCondition(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      shouldTrigger: json['should_trigger'] as bool,
      data: json['data'] as Map<String, dynamic>? ?? {},
      priority: ExecutionPriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => ExecutionPriority.normal,
      ),
      cooldown: json['cooldown'] != null ? Duration(milliseconds: json['cooldown'] as int) : null,
      lastTriggered: json['last_triggered'] != null 
          ? DateTime.parse(json['last_triggered'] as String) 
          : null,
    );
  }
}