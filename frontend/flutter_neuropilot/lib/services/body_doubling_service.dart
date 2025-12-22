import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/session_state.dart';
import 'api_client.dart';

/// Different modes for body doubling to adapt to user needs.
enum BodyDoublingMode {
  /// Frequent check-ins, emphasizes staying on task.
  focusAssistance,

  /// Periodic check-ins, emphasizes progress reporting.
  accountability,

  /// Minimal interruptions, emphasizes presence and tracking.
  productivityTracking,
}

/// Represents the state of the body doubling session.
@immutable
class BodyDoublingState {
  final bool isActive;
  final BodyDoublingMode mode;
  final DateTime? lastCheckIn;
  final DateTime? nextCheckIn;
  final String? currentTask;
  final Duration sessionDuration;
  final String? pendingCheckInMessage;
  final bool isWaitingForResponse;
  final List<String> effectivenessMetrics;

  final DateTime? startTime;
  final String? activeMicroStep;
  final List<String> allMicroSteps;

  const BodyDoublingState({
    this.isActive = false,
    this.mode = BodyDoublingMode.focusAssistance,
    this.lastCheckIn,
    this.nextCheckIn,
    this.currentTask,
    this.sessionDuration = Duration.zero,
    this.pendingCheckInMessage,
    this.isWaitingForResponse = false,
    this.effectivenessMetrics = const [],
    this.startTime,
    this.activeMicroStep,
    this.allMicroSteps = const [],
  });

  BodyDoublingState copyWith({
    bool? isActive,
    BodyDoublingMode? mode,
    DateTime? lastCheckIn,
    DateTime? nextCheckIn,
    String? currentTask,
    Duration? sessionDuration,
    String? pendingCheckInMessage,
    bool? isWaitingForResponse,
    List<String>? effectivenessMetrics,
    DateTime? startTime,
    String? activeMicroStep,
    List<String>? allMicroSteps,
  }) {
    return BodyDoublingState(
      isActive: isActive ?? this.isActive,
      mode: mode ?? this.mode,
      lastCheckIn: lastCheckIn ?? this.lastCheckIn,
      nextCheckIn: nextCheckIn ?? this.nextCheckIn,
      currentTask: currentTask ?? this.currentTask,
      sessionDuration: sessionDuration ?? this.sessionDuration,
      pendingCheckInMessage: pendingCheckInMessage, // Allow null to clear
      isWaitingForResponse: isWaitingForResponse ?? this.isWaitingForResponse,
      effectivenessMetrics: effectivenessMetrics ?? this.effectivenessMetrics,
      startTime: startTime ?? this.startTime,
      activeMicroStep: activeMicroStep ?? this.activeMicroStep,
      allMicroSteps: allMicroSteps ?? this.allMicroSteps,
    );
  }
}

/// Centralized service for intelligent body doubling functionality.
class BodyDoublingService extends StateNotifier<BodyDoublingState> {
  final ApiClient _apiClient;
  Timer? _sessionTimer;
  Timer? _checkInTimer;
  DateTime? _lastUserActivity;

  // Base intervals for different modes (in seconds)
  static const Map<BodyDoublingMode, int> _baseIntervals = {
    BodyDoublingMode.focusAssistance: 300, // 5 mins
    BodyDoublingMode.accountability: 900, // 15 mins
    BodyDoublingMode.productivityTracking: 60, // 30 mins
  };

  BodyDoublingService(this._apiClient) : super(const BodyDoublingState());

  /// Starts a new body doubling session.
  void startSession(BodyDoublingMode mode, {String? task}) {
    if (state.isActive) stopSession();

    final now = DateTime.now();
    state = state.copyWith(
      isActive: true,
      mode: mode,
      currentTask: task,
      sessionDuration: Duration.zero,
      lastCheckIn: now,
      startTime: now,
    );

    _lastUserActivity = now;
    _startTimers();
    _scheduleNextCheckIn();
  }

  /// Update context with micro-steps
  void updateMicroSteps(List<String> steps, String? activeStep) {
    state = state.copyWith(
      allMicroSteps: steps,
      activeMicroStep: activeStep,
    );
  }

  /// Stops the current session.
  void stopSession() {
    _sessionTimer?.cancel();
    _checkInTimer?.cancel();
    state = const BodyDoublingState(isActive: false);
  }

  /// Reports user activity (typing, scrolling) to delay unnecessary check-ins.
  void reportActivity() {
    _lastUserActivity = DateTime.now();
    // If a check-in is pending but user is active, we might want to delay it
    // But for now, we'll just track the time.
  }

  /// Updates the current task context.
  void updateTaskContext(String task) {
    state = state.copyWith(currentTask: task);
  }

  /// Records a user response to a check-in.
  void respondToCheckIn(String response, {bool helpful = true}) {
    final metric =
        "${DateTime.now().toIso8601String()}: $response (Helpful: $helpful)";
    final newMetrics = List<String>.from(state.effectivenessMetrics)
      ..add(metric);

    state = state.copyWith(
      pendingCheckInMessage: null,
      isWaitingForResponse: false,
      effectivenessMetrics: newMetrics,
    );

    _scheduleNextCheckIn();
  }

  /// Clears the pending check-in without recording specific feedback (e.g., dismissed).
  void dismissCheckIn() {
    state = state.copyWith(
      pendingCheckInMessage: null,
      isWaitingForResponse: false,
    );
    _scheduleNextCheckIn();
  }

  void _startTimers() {
    _sessionTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      // Sync duration with actual start time to avoid drift
      final duration = state.startTime != null
          ? DateTime.now().difference(state.startTime!)
          : state.sessionDuration + const Duration(minutes: 1);

      state = state.copyWith(sessionDuration: duration);
    });
  }

  void _scheduleNextCheckIn() {
    _checkInTimer?.cancel();

    int interval = _baseIntervals[state.mode]!;
    // Adaptive logic: If user hasn't been active recently, maybe check in sooner?
    // Or if they are very active, delay check in?
    // For "Focus", if inactive > 2 mins, check in.

    // For simplicity, we add some randomness to feel more "human"
    final randomBuffer = Random().nextInt(60);
    final duration = Duration(seconds: interval + randomBuffer);

    final nextTime = DateTime.now().add(duration);
    state = state.copyWith(nextCheckIn: nextTime);

    _checkInTimer = Timer(duration, _performCheckIn);
  }

  Future<void> _performCheckIn() async {
    if (!state.isActive) return;

    // Check inactivity
    final now = DateTime.now();
    final secondsSinceActivity = _lastUserActivity != null
        ? now.difference(_lastUserActivity!).inSeconds
        : 0;

    // Logic to decide whether to interrupt
    if (state.mode == BodyDoublingMode.productivityTracking) {
      // For productivity tracking, we don't interrupt with a dialog,
      // but we do want to give a silent positive reinforcement (toast).
      String message;
      try {
        message = await _generateIntelligentMessage();
      } catch (_) {
        final duration = state.startTime != null
            ? DateTime.now().difference(state.startTime!).inMinutes
            : state.sessionDuration.inMinutes;
        message = "You've been focused for $duration minutes. Great job!";
      }

      state = state.copyWith(
        pendingCheckInMessage: message,
        isWaitingForResponse: false,
      );
      _scheduleNextCheckIn();
      return;
    } else if (state.mode == BodyDoublingMode.focusAssistance) {
      // If active recently, maybe skip this check-in to not break flow
      if (secondsSinceActivity < 60) {
        // Reschedule for shorter time
        _checkInTimer = Timer(const Duration(minutes: 2), _performCheckIn);
        return;
      }
    }

    state = state.copyWith(isWaitingForResponse: true);

    try {
      // Try to get an intelligent message
      String message = await _generateIntelligentMessage();
      state = state.copyWith(pendingCheckInMessage: message);
    } catch (e) {
      // Fallback
      state = state.copyWith(
        pendingCheckInMessage:
            "Checking in! How is '${state.currentTask ?? "your task"}' going?",
      );
    }
  }

  Future<String> _generateIntelligentMessage() async {
    final task = state.currentTask ?? "current task";
    // Calculate precise duration
    final duration = state.startTime != null
        ? DateTime.now().difference(state.startTime!).inMinutes
        : state.sessionDuration.inMinutes;
    final mode = state.mode.name;
    final activeStep = state.activeMicroStep ?? "Not started";
    final stepInfo = state.allMicroSteps.isNotEmpty
        ? "(Step: $activeStep of ${state.allMicroSteps.length})"
        : "";

    // Use the chatRespond endpoint but maybe we should use a specific tool or just prompt
    // We'll use a direct prompt here for simplicity and speed
    String prompt;
    if (state.mode == BodyDoublingMode.productivityTracking) {
      prompt = "System: You are a Body Double. "
          "User is in '$mode' mode (silent tracking). "
          "Main Task: '$task'. "
          "Micro-step context: $stepInfo. "
          "Session duration: $duration minutes. "
          "Generate a short, encouraging, 1-sentence observation/reinforcement. "
          "Do NOT ask a question. Just validate their focus.";
    } else {
      prompt = "System: You are a Body Double. "
          "User is in '$mode' mode. "
          "Main Task: '$task'. "
          "Micro-step context: $stepInfo. "
          "Session duration: $duration minutes. "
          "Generate a short, encouraging, 1-sentence check-in message.";
    }

    try {
      final res = await _apiClient.chatRespond(prompt, timeoutSeconds: 10);
      return res['text'] as String? ?? "You got this! Still focusing on $task?";
    } catch (_) {
      return "Time check! Still on track with $task?";
    }
  }
}

/// Provider for the BodyDoublingService.
final bodyDoublingServiceProvider =
    StateNotifierProvider<BodyDoublingService, BodyDoublingState>((ref) {
  final api = ref.watch(apiClientProvider);
  return BodyDoublingService(api);
});
