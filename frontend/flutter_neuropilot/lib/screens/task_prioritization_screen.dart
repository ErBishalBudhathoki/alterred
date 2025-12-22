import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/components/task_prioritization/modes/standalone_task_prioritization.dart';
import '../core/components/task_prioritization/models/prioritized_task_model.dart';
import '../core/components/task_prioritization/state/task_prioritization_provider.dart';
import '../core/routes.dart';

/// Full-screen task prioritization experience
class TaskPrioritizationScreen extends ConsumerWidget {
  const TaskPrioritizationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StandaloneTaskPrioritization(
      onTaskSelected: (task, selectionMethod) {
        _handleTaskSelected(context, ref, task, selectionMethod);
      },
      onScheduleTask: () {
        _handleScheduleTask(context, ref);
      },
      onTakeNote: () {
        _handleTakeNote(context, ref);
      },
      onAtomizeTask: () {
        _handleAtomizeTask(context, ref);
      },
      onBack: () {
        Navigator.of(context).pop();
      },
      enableAutoSelect: true,
      countdownSeconds: 60,
    );
  }

  void _handleTaskSelected(
    BuildContext context,
    WidgetRef ref,
    PrioritizedTaskModel task,
    String selectionMethod,
  ) {
    // Show success feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected: ${task.title}'),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 2),
      ),
    );

    // Navigate to focus mode or task details after a delay
    Future.delayed(const Duration(seconds: 2), () {
      if (context.mounted) {
        // You can navigate to a focus screen, task details, or back to dashboard
        Navigator.of(context).pushReplacementNamed(
          Routes.dashboard,
          arguments: {'selectedTask': task},
        );
      }
    });
  }

  void _handleScheduleTask(BuildContext context, WidgetRef ref) {
    final state = ref.read(taskPrioritizationProvider);
    final selectedTask = state.selectedTask;
    
    if (selectedTask != null) {
      // Navigate to calendar or scheduling interface
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scheduling: ${selectedTask.title}'),
          backgroundColor: const Color(0xFFE2B58D),
        ),
      );
      
      // TODO: Implement calendar integration
      // Navigator.of(context).pushNamed(Routes.calendar, arguments: selectedTask);
    }
  }

  void _handleTakeNote(BuildContext context, WidgetRef ref) {
    final state = ref.read(taskPrioritizationProvider);
    final selectedTask = state.selectedTask;
    
    if (selectedTask != null) {
      // Navigate to note-taking interface
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Taking notes for: ${selectedTask.title}'),
          backgroundColor: const Color(0xFF6C7494),
        ),
      );
      
      // TODO: Implement note-taking interface
      // Navigator.of(context).pushNamed(Routes.notes, arguments: selectedTask);
    }
  }

  void _handleAtomizeTask(BuildContext context, WidgetRef ref) {
    final state = ref.read(taskPrioritizationProvider);
    final selectedTask = state.selectedTask;
    
    if (selectedTask != null) {
      // Navigate to task atomization (breaking down into smaller steps)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Atomizing: ${selectedTask.title}'),
          backgroundColor: const Color(0xFFFBBF24),
        ),
      );
      
      // TODO: Implement task atomization interface
      // Navigator.of(context).pushNamed(Routes.taskAtomize, arguments: selectedTask);
    }
  }
}

/// Route helper for task prioritization screen
class TaskPrioritizationRoute {
  static const String name = '/task-prioritization';
  
  static Route<void> route() {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: name),
      builder: (_) => const TaskPrioritizationScreen(),
    );
  }
}

/// Widget for quick access to task prioritization from other screens
class TaskPrioritizationQuickAccess extends ConsumerWidget {
  final VoidCallback? onTaskSelected;
  final bool showAsCard;

  const TaskPrioritizationQuickAccess({
    super.key,
    this.onTaskSelected,
    this.showAsCard = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(taskPrioritizationProvider);
    
    if (!state.hasData && !state.isLoading) {
      // Auto-fetch if no data
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(taskPrioritizationProvider.notifier).fetchPrioritizedTasks();
      });
    }

    if (showAsCard) {
      return _buildQuickAccessCard(context, ref, state);
    } else {
      return _buildQuickAccessButton(context, ref, state);
    }
  }

  Widget _buildQuickAccessCard(BuildContext context, WidgetRef ref, TaskPrioritizationState state) {
    return Card(
      margin: const EdgeInsets.all(16),
      color: const Color(0xFF0F0505).withValues(alpha: 0.9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: const Color(0xFFE2B58D).withValues(alpha: 0.2),
        ),
      ),
      child: InkWell(
        onTap: () => _navigateToFullScreen(context),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2B58D).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.psychology,
                      color: Color(0xFFE2B58D),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Task Prioritization',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          state.hasData 
                              ? '${state.tasks.length} tasks ready'
                              : state.isLoading 
                                  ? 'Analyzing tasks...'
                                  : 'Tap to prioritize',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Color(0xFFE2B58D),
                    size: 16,
                  ),
                ],
              ),
              
              if (state.hasData) ...[
                const SizedBox(height: 16),
                Text(
                  'Top recommendation: ${state.tasks.first.title}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAccessButton(BuildContext context, WidgetRef ref, TaskPrioritizationState state) {
    return FloatingActionButton.extended(
      onPressed: () => _navigateToFullScreen(context),
      backgroundColor: const Color(0xFFE2B58D),
      foregroundColor: const Color(0xFF0F0505),
      icon: const Icon(Icons.psychology),
      label: Text(
        state.hasData 
            ? 'Prioritize (${state.tasks.length})'
            : 'Prioritize Tasks',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  void _navigateToFullScreen(BuildContext context) {
    Navigator.of(context).push(TaskPrioritizationRoute.route());
  }
}