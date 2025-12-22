import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import '../state/session_state.dart';
import 'api_client.dart';

final taskServiceProvider = Provider<TaskService>((ref) {
  final api = ref.watch(apiClientProvider);
  return TaskService(api);
});

class TaskService {
  final ApiClient _api;

  TaskService(this._api);

  Future<List<Task>> getTasks() async {
    final response = await _api.get('/tasks/');
    final List<dynamic> tasksJson = response['tasks'] ?? [];
    return tasksJson.map((json) => Task.fromJson(json)).toList();
  }

  Future<Task> createTask(Task task) async {
    final response = await _api.post('/tasks/', task.toJson());
    return Task.fromJson(response);
  }

  Future<Task> updateTask(Task task) async {
    if (task.id == null) throw Exception('Task ID is required for update');
    final response = await _api.put('/tasks/${task.id}', task.toJson());
    return Task.fromJson(response);
  }

  Future<void> deleteTask(String taskId) async {
    await _api.delete('/tasks/$taskId');
  }
}
