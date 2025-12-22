import 'package:flutter/material.dart';
import 'task_prioritization/models/prioritized_task_model.dart';
import 'task_prioritization/modes/chat_task_prioritization.dart';

/// Legacy model for backward compatibility - use PrioritizedTaskModel instead
class PrioritizedTaskItem {
  final String id;
  final String title;
  final String? description;
  final String? dueDate;
  final String priority;
  final String effort;
  final double priorityScore;
  final String priorityReasoning;
  final bool isRecommended;
  final int estimatedDurationMinutes;

  PrioritizedTaskItem({
    required this.id,
    required this.title,
    this.description,
    this.dueDate,
    required this.priority,
    required this.effort,
    required this.priorityScore,
    required this.priorityReasoning,
    required this.isRecommended,
    required this.estimatedDurationMinutes,
  });

  factory PrioritizedTaskItem.fromJson(Map<String, dynamic> json) {
    return PrioritizedTaskItem(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Untitled',
      description: json['description'],
      dueDate: json['due_date'],
      priority: json['priority'] ?? 'medium',
      effort: json['effort'] ?? 'medium',
      priorityScore: (json['priority_score'] ?? 0).toDouble(),
      priorityReasoning: json['priority_reasoning'] ?? '',
      isRecommended: json['is_recommended'] ?? false,
      estimatedDurationMinutes: json['estimated_duration_minutes'] ?? 30,
    );
  }

  /// Convert to new model format
  PrioritizedTaskModel toModel() {
    return PrioritizedTaskModel.fromJson({
      'id': id,
      'title': title,
      'description': description,
      'due_date': dueDate,
      'priority': priority,
      'effort': effort,
      'priority_score': priorityScore,
      'priority_reasoning': priorityReasoning,
      'is_recommended': isRecommended,
      'estimated_duration_minutes': estimatedDurationMinutes,
    });
  }
}

/// Enhanced task prioritization widget with backward compatibility
///
/// This widget now uses the new modular architecture while maintaining
/// compatibility with existing code. For new implementations, consider
/// using ChatTaskPrioritization, VoiceTaskPrioritization, or 
/// StandaloneTaskPrioritization directly.
class TaskPrioritizationWidget extends StatefulWidget {
  final List<PrioritizedTaskItem> tasks;
  final String reasoning;
  final int originalTaskCount;
  final Function(PrioritizedTaskItem, String selectionMethod) onTaskSelected;
  final VoidCallback? onScheduleTask;
  final VoidCallback? onTakeNote;
  final VoidCallback? onRefresh;
  final int countdownSeconds;
  final bool isCompleted;
  final VoidCallback? onCompleted;
  final bool enableAutoSelect;
  final Function(PrioritizedTaskItem task)? onAtomizeTask;

  const TaskPrioritizationWidget({
    super.key,
    required this.tasks,
    required this.reasoning,
    required this.originalTaskCount,
    required this.onTaskSelected,
    this.onScheduleTask,
    this.onTakeNote,
    this.onRefresh,
    this.countdownSeconds = 60,
    this.isCompleted = false,
    this.onCompleted,
    this.enableAutoSelect = false,
    this.onAtomizeTask,
  });

  @override
  State<TaskPrioritizationWidget> createState() => _TaskPrioritizationWidgetState();
}

class _TaskPrioritizationWidgetState extends State<TaskPrioritizationWidget> {
  @override
  Widget build(BuildContext context) {
    // Convert legacy tasks to new model format
    final tasks = widget.tasks.map((task) => task.toModel()).toList();
    
    return ChatTaskPrioritization(
      onTaskSelected: (task, selectionMethod) {
        // Convert back to legacy format for callback
        final legacyTask = PrioritizedTaskItem(
          id: task.id,
          title: task.title,
          description: task.description,
          dueDate: task.dueDate?.toIso8601String(),
          priority: task.priority.name,
          effort: task.effort.name,
          priorityScore: task.priorityScore,
          priorityReasoning: task.priorityReasoning,
          isRecommended: task.isRecommended,
          estimatedDurationMinutes: task.estimatedDurationMinutes,
        );
        widget.onTaskSelected(legacyTask, selectionMethod);
      },
      onScheduleTask: widget.onScheduleTask,
      onTakeNote: widget.onTakeNote,
      onRefresh: widget.onRefresh,
      onAtomizeTask: widget.onAtomizeTask != null 
          ? () {
              if (tasks.isNotEmpty) {
                final legacyTask = PrioritizedTaskItem(
                  id: tasks.first.id,
                  title: tasks.first.title,
                  description: tasks.first.description,
                  dueDate: tasks.first.dueDate?.toIso8601String(),
                  priority: tasks.first.priority.name,
                  effort: tasks.first.effort.name,
                  priorityScore: tasks.first.priorityScore,
                  priorityReasoning: tasks.first.priorityReasoning,
                  isRecommended: tasks.first.isRecommended,
                  estimatedDurationMinutes: tasks.first.estimatedDurationMinutes,
                );
                widget.onAtomizeTask!(legacyTask);
              }
            }
          : null,
      enableAutoSelect: widget.enableAutoSelect,
      countdownSeconds: widget.countdownSeconds,
      showQuickActions: true,
    );
  }
}
