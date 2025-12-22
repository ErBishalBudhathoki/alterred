import 'package:flutter/foundation.dart';

/// Enhanced model for a prioritized task with additional metadata
@immutable
class PrioritizedTaskModel {
  final String id;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final TaskPriority priority;
  final TaskEffort effort;
  final TaskStatus status;
  final double priorityScore;
  final String priorityReasoning;
  final bool isRecommended;
  final int estimatedDurationMinutes;
  final List<String> tags;
  final TaskUrgency urgency;
  final double completionProgress;

  const PrioritizedTaskModel({
    required this.id,
    required this.title,
    this.description,
    this.dueDate,
    required this.priority,
    required this.effort,
    required this.status,
    required this.priorityScore,
    required this.priorityReasoning,
    required this.isRecommended,
    required this.estimatedDurationMinutes,
    this.tags = const [],
    required this.urgency,
    this.completionProgress = 0.0,
  });

  /// Create from the existing PrioritizedTaskItem for backward compatibility
  factory PrioritizedTaskModel.fromLegacy(dynamic legacyTask) {
    return PrioritizedTaskModel(
      id: legacyTask.id ?? '',
      title: legacyTask.title ?? 'Untitled',
      description: legacyTask.description,
      dueDate: legacyTask.dueDate != null 
          ? DateTime.tryParse(legacyTask.dueDate!) 
          : null,
      priority: TaskPriority.fromString(legacyTask.priority ?? 'medium'),
      effort: TaskEffort.fromString(legacyTask.effort ?? 'medium'),
      status: TaskStatus.fromString(legacyTask.status ?? 'pending'),
      priorityScore: (legacyTask.priorityScore ?? 0).toDouble(),
      priorityReasoning: legacyTask.priorityReasoning ?? '',
      isRecommended: legacyTask.isRecommended ?? false,
      estimatedDurationMinutes: legacyTask.estimatedDurationMinutes ?? 30,
      urgency: TaskUrgency.fromDueDate(
        legacyTask.dueDate != null 
            ? DateTime.tryParse(legacyTask.dueDate!) 
            : null
      ),
    );
  }

  /// Create from JSON for API compatibility
  factory PrioritizedTaskModel.fromJson(Map<String, dynamic> json) {
    return PrioritizedTaskModel(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Untitled',
      description: json['description'],
      dueDate: json['due_date'] != null 
          ? DateTime.tryParse(json['due_date']) 
          : null,
      priority: TaskPriority.fromString(json['priority'] ?? 'medium'),
      effort: TaskEffort.fromString(json['effort'] ?? 'medium'),
      status: TaskStatus.fromString(json['status'] ?? 'pending'),
      priorityScore: (json['priority_score'] ?? 0).toDouble(),
      priorityReasoning: json['priority_reasoning'] ?? '',
      isRecommended: json['is_recommended'] ?? false,
      estimatedDurationMinutes: json['estimated_duration_minutes'] ?? 30,
      tags: List<String>.from(json['tags'] ?? []),
      urgency: TaskUrgency.fromDueDate(
        json['due_date'] != null 
            ? DateTime.tryParse(json['due_date']) 
            : null
      ),
      completionProgress: (json['completion_progress'] ?? 0.0).toDouble(),
    );
  }

  /// Convert to JSON for API compatibility
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'due_date': dueDate?.toIso8601String(),
      'priority': priority.name,
      'effort': effort.name,
      'status': status.name,
      'priority_score': priorityScore,
      'priority_reasoning': priorityReasoning,
      'is_recommended': isRecommended,
      'estimated_duration_minutes': estimatedDurationMinutes,
      'tags': tags,
      'completion_progress': completionProgress,
    };
  }

  /// Create a copy with updated fields
  PrioritizedTaskModel copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dueDate,
    TaskPriority? priority,
    TaskEffort? effort,
    TaskStatus? status,
    double? priorityScore,
    String? priorityReasoning,
    bool? isRecommended,
    int? estimatedDurationMinutes,
    List<String>? tags,
    TaskUrgency? urgency,
    double? completionProgress,
  }) {
    return PrioritizedTaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      effort: effort ?? this.effort,
      status: status ?? this.status,
      priorityScore: priorityScore ?? this.priorityScore,
      priorityReasoning: priorityReasoning ?? this.priorityReasoning,
      isRecommended: isRecommended ?? this.isRecommended,
      estimatedDurationMinutes: estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      tags: tags ?? this.tags,
      urgency: urgency ?? this.urgency,
      completionProgress: completionProgress ?? this.completionProgress,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PrioritizedTaskModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'PrioritizedTaskModel(id: $id, title: $title)';
}

/// Task priority levels with enhanced metadata
enum TaskPriority {
  critical('Critical', 4, 0xFFEF4444),
  high('High', 3, 0xFFF97316),
  medium('Medium', 2, 0xFFFBBF24),
  low('Low', 1, 0xFF10B981);

  const TaskPriority(this.label, this.weight, this.colorValue);

  final String label;
  final int weight;
  final int colorValue;

  static TaskPriority fromString(String value) {
    switch (value.toLowerCase()) {
      case 'critical':
        return TaskPriority.critical;
      case 'high':
        return TaskPriority.high;
      case 'medium':
        return TaskPriority.medium;
      case 'low':
        return TaskPriority.low;
      default:
        return TaskPriority.medium;
    }
  }
}

/// Task effort levels with enhanced metadata
enum TaskEffort {
  low('Low', 1, 0xFF10B981),
  medium('Medium', 2, 0xFFFBBF24),
  high('High', 3, 0xFFF97316);

  const TaskEffort(this.label, this.weight, this.colorValue);

  final String label;
  final int weight;
  final int colorValue;

  static TaskEffort fromString(String value) {
    switch (value.toLowerCase()) {
      case 'low':
        return TaskEffort.low;
      case 'medium':
        return TaskEffort.medium;
      case 'high':
        return TaskEffort.high;
      default:
        return TaskEffort.medium;
    }
  }
}

/// Task status with enhanced metadata
enum TaskStatus {
  pending('Pending', 0xFF6B7280),
  inProgress('In Progress', 0xFF3B82F6),
  completed('Completed', 0xFF10B981),
  cancelled('Cancelled', 0xFF6B7280),
  blocked('Blocked', 0xFFEF4444);

  const TaskStatus(this.label, this.colorValue);

  final String label;
  final int colorValue;

  static TaskStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pending':
        return TaskStatus.pending;
      case 'in_progress':
      case 'in progress':
        return TaskStatus.inProgress;
      case 'completed':
        return TaskStatus.completed;
      case 'cancelled':
        return TaskStatus.cancelled;
      case 'blocked':
        return TaskStatus.blocked;
      default:
        return TaskStatus.pending;
    }
  }
}

/// Task urgency based on due date
enum TaskUrgency {
  overdue('Overdue', 0xFFEF4444),
  today('Due Today', 0xFFF97316),
  tomorrow('Due Tomorrow', 0xFFFBBF24),
  thisWeek('This Week', 0xFF3B82F6),
  later('Later', 0xFF6B7280);

  const TaskUrgency(this.label, this.colorValue);

  final String label;
  final int colorValue;

  static TaskUrgency fromDueDate(DateTime? dueDate) {
    if (dueDate == null) return TaskUrgency.later;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final difference = taskDate.difference(today).inDays;

    if (difference < 0) return TaskUrgency.overdue;
    if (difference == 0) return TaskUrgency.today;
    if (difference == 1) return TaskUrgency.tomorrow;
    if (difference <= 7) return TaskUrgency.thisWeek;
    return TaskUrgency.later;
  }
}

/// Response model for task prioritization
@immutable
class TaskPrioritizationResponse {
  final List<PrioritizedTaskModel> tasks;
  final String reasoning;
  final int originalTaskCount;
  final DateTime timestamp;
  final bool fromCache;
  final String? errorMessage;

  const TaskPrioritizationResponse({
    required this.tasks,
    required this.reasoning,
    required this.originalTaskCount,
    required this.timestamp,
    this.fromCache = false,
    this.errorMessage,
  });

  /// Create from API response
  factory TaskPrioritizationResponse.fromJson(Map<String, dynamic> json) {
    final tasksList = json['tasks'] as List? ?? [];
    return TaskPrioritizationResponse(
      tasks: tasksList
          .map((t) => PrioritizedTaskModel.fromJson(t as Map<String, dynamic>))
          .toList(),
      reasoning: json['reasoning'] ?? '',
      originalTaskCount: json['original_task_count'] ?? 0,
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      fromCache: json['cached'] ?? false,
    );
  }

  /// Create error response
  factory TaskPrioritizationResponse.error(String message) {
    return TaskPrioritizationResponse(
      tasks: const [],
      reasoning: '',
      originalTaskCount: 0,
      timestamp: DateTime.now(),
      errorMessage: message,
    );
  }

  /// Check if response has error
  bool get hasError => errorMessage != null;

  /// Check if response is empty
  bool get isEmpty => tasks.isEmpty && !hasError;

  @override
  String toString() => 'TaskPrioritizationResponse(tasks: ${tasks.length})';
}