import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/prioritized_task_model.dart';
import 'package:altered/services/api_client.dart';
import '../../../../state/session_state.dart';

/// State for task prioritization
class TaskPrioritizationState {
  final TaskPrioritizationResponse? response;
  final bool isLoading;
  final String? error;
  final bool isCompleted;
  final PrioritizedTaskModel? selectedTask;
  final String? selectionMethod;
  final DateTime? lastUpdated;

  const TaskPrioritizationState({
    this.response,
    this.isLoading = false,
    this.error,
    this.isCompleted = false,
    this.selectedTask,
    this.selectionMethod,
    this.lastUpdated,
  });

  TaskPrioritizationState copyWith({
    TaskPrioritizationResponse? response,
    bool? isLoading,
    String? error,
    bool? isCompleted,
    PrioritizedTaskModel? selectedTask,
    String? selectionMethod,
    DateTime? lastUpdated,
  }) {
    return TaskPrioritizationState(
      response: response ?? this.response,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isCompleted: isCompleted ?? this.isCompleted,
      selectedTask: selectedTask ?? this.selectedTask,
      selectionMethod: selectionMethod ?? this.selectionMethod,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  bool get hasData => response != null && response!.tasks.isNotEmpty;
  bool get hasError => error != null;
  List<PrioritizedTaskModel> get tasks => response?.tasks ?? [];
  String get reasoning => response?.reasoning ?? '';
  int get originalTaskCount => response?.originalTaskCount ?? 0;
}

/// Notifier for task prioritization state management
class TaskPrioritizationNotifier extends StateNotifier<TaskPrioritizationState> {
  final ApiClient _apiClient;

  TaskPrioritizationNotifier(this._apiClient) : super(const TaskPrioritizationState());

  /// Fetch prioritized tasks from the API
  Future<void> fetchPrioritizedTasks({
    int limit = 3,
    bool includeCalendar = true,
    int? energy,
    bool useCacheFallback = true,
  }) async {
    if (state.isLoading) return;

    state = state.copyWith(
      isLoading: true,
      error: null,
    );

    try {
      final response = await _apiClient.getPrioritizedTasks(
        limit: limit,
        includeCalendar: includeCalendar,
        energy: energy,
      );

      final prioritizationResponse = TaskPrioritizationResponse.fromJson(response);
      
      state = state.copyWith(
        response: prioritizationResponse,
        isLoading: false,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      String errorMessage = 'Network error occurred';
      
      if (e.toString().contains('timeout')) {
        errorMessage = 'Connection timeout. Please check your internet connection.';
      } else if (e.toString().contains('connection')) {
        errorMessage = 'Unable to connect to server. Please try again later.';
      } else if (e.toString().contains('401')) {
        errorMessage = 'Authentication required. Please log in again.';
      } else if (e.toString().contains('500')) {
        errorMessage = 'Server error. Please try again later.';
      }

      // Try to load cached data if available and fallback is enabled
      if (useCacheFallback) {
        await _loadCachedData();
      }

      state = state.copyWith(
        isLoading: false,
        error: errorMessage,
      );
    }
  }

  /// Load cached prioritization data
  Future<void> _loadCachedData() async {
    try {
      final response = await _apiClient.get('/tasks/prioritized/cached');
      final prioritizationResponse = TaskPrioritizationResponse.fromJson(response);
      
      state = state.copyWith(
        response: prioritizationResponse,
      );
    } catch (e) {
      // Silently fail - cached data is optional
    }
  }

  /// Select a task and notify the backend
  Future<void> selectTask(
    PrioritizedTaskModel task, 
    String selectionMethod,
  ) async {
    if (state.isCompleted) return;

    // Optimistically update the UI
    state = state.copyWith(
      selectedTask: task,
      selectionMethod: selectionMethod,
      isCompleted: true,
    );

    try {
      await _apiClient.post(
        '/tasks/select',
        {
          'task_id': task.id,
          'selection_method': selectionMethod,
        },
      );
    } catch (e) {
      // Revert optimistic update on failure
      state = state.copyWith(
        selectedTask: null,
        selectionMethod: null,
        isCompleted: false,
        error: 'Network error while selecting task. Selection may not be saved.',
      );
    }
  }

  /// Reset the prioritization state
  void reset() {
    state = const TaskPrioritizationState();
  }

  /// Mark as completed without selecting a task (for manual completion)
  void markCompleted() {
    state = state.copyWith(isCompleted: true);
  }

  /// Clear any error state
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Refresh the prioritization (force fetch)
  Future<void> refresh({
    int limit = 3,
    bool includeCalendar = true,
    int? energy,
  }) async {
    // Clear current state and fetch fresh data
    state = const TaskPrioritizationState();
    await fetchPrioritizedTasks(
      limit: limit,
      includeCalendar: includeCalendar,
      energy: energy,
      useCacheFallback: false,
    );
  }

  /// Invalidate cache on the backend
  Future<void> invalidateCache() async {
    try {
      await _apiClient.post('/tasks/prioritized/invalidate-cache', {});
    } catch (e) {
      // Silently fail - cache invalidation is not critical
    }
  }
}

/// Provider for task prioritization state
final taskPrioritizationProvider = 
    StateNotifierProvider<TaskPrioritizationNotifier, TaskPrioritizationState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return TaskPrioritizationNotifier(apiClient);
});

/// Provider for checking if prioritization is available
final taskPrioritizationAvailableProvider = Provider<bool>((ref) {
  final state = ref.watch(taskPrioritizationProvider);
  return state.hasData && !state.isCompleted;
});

/// Provider for the currently selected task
final selectedTaskProvider = Provider<PrioritizedTaskModel?>((ref) {
  final state = ref.watch(taskPrioritizationProvider);
  return state.selectedTask;
});

/// Provider for prioritization completion status
final prioritizationCompletedProvider = Provider<bool>((ref) {
  final state = ref.watch(taskPrioritizationProvider);
  return state.isCompleted;
});

/// Provider for prioritization error state
final prioritizationErrorProvider = Provider<String?>((ref) {
  final state = ref.watch(taskPrioritizationProvider);
  return state.error;
});

/// Provider for prioritization loading state
final prioritizationLoadingProvider = Provider<bool>((ref) {
  final state = ref.watch(taskPrioritizationProvider);
  return state.isLoading;
});

/// Auto-refresh provider that fetches prioritization when needed
final autoTaskPrioritizationProvider = FutureProvider<TaskPrioritizationResponse?>((ref) async {
  final notifier = ref.read(taskPrioritizationProvider.notifier);
  
  // Check if we already have recent data
  final state = ref.read(taskPrioritizationProvider);
  if (state.hasData && state.lastUpdated != null) {
    final age = DateTime.now().difference(state.lastUpdated!);
    if (age.inMinutes < 5) {
      // Return cached data if less than 5 minutes old
      return state.response;
    }
  }

  // Fetch fresh data
  await notifier.fetchPrioritizedTasks();
  return ref.read(taskPrioritizationProvider).response;
});

/// Countdown timer state for auto-selection
class CountdownState {
  final int totalSeconds;
  final int remainingSeconds;
  final bool isActive;
  final bool isPaused;
  final bool isCompleted;

  const CountdownState({
    required this.totalSeconds,
    required this.remainingSeconds,
    this.isActive = false,
    this.isPaused = false,
    this.isCompleted = false,
  });

  CountdownState copyWith({
    int? totalSeconds,
    int? remainingSeconds,
    bool? isActive,
    bool? isPaused,
    bool? isCompleted,
  }) {
    return CountdownState(
      totalSeconds: totalSeconds ?? this.totalSeconds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isActive: isActive ?? this.isActive,
      isPaused: isPaused ?? this.isPaused,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  double get progress => remainingSeconds / totalSeconds;
  bool get isUrgent => remainingSeconds <= (totalSeconds * 0.2);
  bool get isWarning => remainingSeconds <= (totalSeconds * 0.5);
}

/// Notifier for countdown timer state
class CountdownNotifier extends StateNotifier<CountdownState> {
  CountdownNotifier(int totalSeconds) 
      : super(CountdownState(
          totalSeconds: totalSeconds,
          remainingSeconds: totalSeconds,
        ));

  void start() {
    if (state.isCompleted || state.isActive) return;
    
    state = state.copyWith(
      isActive: true,
      isPaused: false,
    );
  }

  void pause() {
    if (!state.isActive || state.isPaused) return;
    
    state = state.copyWith(
      isPaused: true,
    );
  }

  void resume() {
    if (!state.isPaused) return;
    
    state = state.copyWith(
      isPaused: false,
    );
  }

  void tick() {
    if (!state.isActive || state.isPaused || state.isCompleted) return;
    
    final newRemaining = state.remainingSeconds - 1;
    
    if (newRemaining <= 0) {
      state = state.copyWith(
        remainingSeconds: 0,
        isActive: false,
        isCompleted: true,
      );
    } else {
      state = state.copyWith(
        remainingSeconds: newRemaining,
      );
    }
  }

  void reset() {
    state = CountdownState(
      totalSeconds: state.totalSeconds,
      remainingSeconds: state.totalSeconds,
    );
  }

  void complete() {
    state = state.copyWith(
      remainingSeconds: 0,
      isActive: false,
      isCompleted: true,
    );
  }
}

/// Provider for countdown timer (60 seconds default)
final countdownProvider = StateNotifierProvider.family<CountdownNotifier, CountdownState, int>(
  (ref, totalSeconds) => CountdownNotifier(totalSeconds),
);

/// Convenience provider for 60-second countdown
final defaultCountdownProvider = Provider<StateNotifierProvider<CountdownNotifier, CountdownState>>((ref) {
  return countdownProvider(60);
});

/// Provider that combines prioritization and countdown state
final taskPrioritizationWithCountdownProvider = Provider<({
  TaskPrioritizationState prioritization,
  CountdownState countdown,
})>((ref) {
  final prioritization = ref.watch(taskPrioritizationProvider);
  final countdown = ref.watch(countdownProvider(60));
  
  return (
    prioritization: prioritization,
    countdown: countdown,
  );
});

/// Provider for task prioritization analytics
final taskPrioritizationAnalyticsProvider = Provider<Map<String, dynamic>>((ref) {
  final state = ref.watch(taskPrioritizationProvider);
  
  return {
    'has_data': state.hasData,
    'task_count': state.tasks.length,
    'is_completed': state.isCompleted,
    'selection_method': state.selectionMethod,
    'last_updated': state.lastUpdated?.toIso8601String(),
    'from_cache': state.response?.fromCache ?? false,
    'has_error': state.hasError,
  };
});