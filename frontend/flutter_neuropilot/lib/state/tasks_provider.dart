import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import '../services/task_service.dart';

final tasksProvider =
    StateNotifierProvider<TasksNotifier, AsyncValue<List<Task>>>((ref) {
  final taskService = ref.watch(taskServiceProvider);
  return TasksNotifier(taskService);
});

class TasksNotifier extends StateNotifier<AsyncValue<List<Task>>> {
  final TaskService _taskService;
  bool _mounted = true;

  TasksNotifier(this._taskService) : super(const AsyncValue.loading()) {
    refreshTasks();
  }

  @override
  void dispose() {
    _mounted = false;
    super.dispose();
  }

  Future<void> refreshTasks() async {
    if (!_mounted) return;
    try {
      state = const AsyncValue.loading();
      final tasks = await _taskService.getTasks();
      if (!_mounted) return;
      state = AsyncValue.data(tasks);
    } catch (e, st) {
      if (!_mounted) return;
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createTask(Task task) async {
    try {
      await _taskService.createTask(task);
      if (!_mounted) return;
      // Refresh list to show new task
      await refreshTasks();
    } catch (e) {
      // Handle error (could expose via a separate error state or rethrow)
      rethrow;
    }
  }

  Future<void> updateTask(Task task) async {
    try {
      if (task.id == null) return;
      await _taskService.updateTask(task);
      if (!_mounted) return;
      await refreshTasks();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteTask(String taskId) async {
    try {
      await _taskService.deleteTask(taskId);
      if (!_mounted) return;
      await refreshTasks();
    } catch (e) {
      rethrow;
    }
  }
}
