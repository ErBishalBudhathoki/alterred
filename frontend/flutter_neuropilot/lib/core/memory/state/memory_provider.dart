import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../models/memory_models.dart';
import '../services/firestore_memory_service.dart';
import '../services/context_compaction_service.dart';
import '../services/gemini_summarization_service.dart';
import '../services/memory_optimization_service.dart';
import '../services/session_manager.dart';

/// Memory system state
class MemoryState {
  final bool isInitialized;
  final String? currentUserId;
  final String? currentSessionId;
  final SessionStatus? sessionStatus;
  final ContextWindow? currentContextWindow;
  final MemoryMetrics? metrics;
  final List<MemoryChunk> recentMemories;
  final Map<String, dynamic> optimizationStats;
  final bool isOptimizing;
  final String? error;

  const MemoryState({
    this.isInitialized = false,
    this.currentUserId,
    this.currentSessionId,
    this.sessionStatus,
    this.currentContextWindow,
    this.metrics,
    this.recentMemories = const [],
    this.optimizationStats = const {},
    this.isOptimizing = false,
    this.error,
  });

  MemoryState copyWith({
    bool? isInitialized,
    String? currentUserId,
    String? currentSessionId,
    SessionStatus? sessionStatus,
    ContextWindow? currentContextWindow,
    MemoryMetrics? metrics,
    List<MemoryChunk>? recentMemories,
    Map<String, dynamic>? optimizationStats,
    bool? isOptimizing,
    String? error,
  }) {
    return MemoryState(
      isInitialized: isInitialized ?? this.isInitialized,
      currentUserId: currentUserId ?? this.currentUserId,
      currentSessionId: currentSessionId ?? this.currentSessionId,
      sessionStatus: sessionStatus ?? this.sessionStatus,
      currentContextWindow: currentContextWindow ?? this.currentContextWindow,
      metrics: metrics ?? this.metrics,
      recentMemories: recentMemories ?? this.recentMemories,
      optimizationStats: optimizationStats ?? this.optimizationStats,
      isOptimizing: isOptimizing ?? this.isOptimizing,
      error: error,
    );
  }
}

/// Memory system notifier
class MemoryNotifier extends StateNotifier<MemoryState> {
  MemoryNotifier() : super(const MemoryState()) {
    _initialize();
  }

  final FirestoreMemoryService _memoryService = FirestoreMemoryService();
  final ContextCompactionService _compactionService = ContextCompactionService();
  final GeminiSummarizationService _summarizationService = GeminiSummarizationService();
  final MemoryOptimizationService _optimizationService = MemoryOptimizationService();
  final SessionManager _sessionManager = SessionManager();

  Timer? _metricsTimer;
  Timer? _optimizationTimer;

  /// Initialize the memory system
  Future<void> _initialize() async {
    try {
      // Initialize services
      await _memoryService.initialize();
      await _compactionService.initialize();
      await _summarizationService.initialize();
      await _optimizationService.initialize();

      // Start periodic tasks
      _startPeriodicTasks();

      state = state.copyWith(isInitialized: true);

      if (kDebugMode) {
        print('🧠 Memory system initialized successfully');
      }
    } catch (error) {
      state = state.copyWith(error: error.toString());
      if (kDebugMode) {
        print('❌ Memory system initialization failed: $error');
      }
    }
  }

  /// Set current user
  Future<void> setCurrentUser(String userId) async {
    try {
      await _sessionManager.initialize(userId: userId);
      
      state = state.copyWith(
        currentUserId: userId,
        error: null,
      );

      // Load initial data
      await _loadUserData(userId);
    } catch (error) {
      state = state.copyWith(error: error.toString());
    }
  }

  /// Start a new memory session
  Future<void> startSession({
    required SessionType type,
    String? title,
    Map<String, dynamic>? initialContext,
  }) async {
    if (state.currentUserId == null) {
      state = state.copyWith(error: 'No user set');
      return;
    }

    try {
      final result = await _sessionManager.startSession(
        userId: state.currentUserId!,
        type: type,
        title: title,
        initialContext: initialContext,
      );

      if (result.success) {
        state = state.copyWith(
          currentSessionId: result.data!.id,
          sessionStatus: _sessionManager.getCurrentSessionStatus(state.currentUserId!),
          error: null,
        );

        // Get context window for the new session
        await _updateContextWindow();
      } else {
        state = state.copyWith(error: result.error);
      }
    } catch (error) {
      state = state.copyWith(error: error.toString());
    }
  }

  /// Add memory to current session
  Future<void> addMemory(MemoryChunk chunk) async {
    if (state.currentUserId == null) {
      state = state.copyWith(error: 'No user set');
      return;
    }

    try {
      final result = await _sessionManager.addMemoryToSession(
        state.currentUserId!,
        chunk,
      );

      if (result.success) {
        // Update recent memories
        final updatedRecent = [result.data!, ...state.recentMemories];
        if (updatedRecent.length > 50) {
          updatedRecent.removeRange(50, updatedRecent.length);
        }

        state = state.copyWith(
          recentMemories: updatedRecent,
          sessionStatus: _sessionManager.getCurrentSessionStatus(state.currentUserId!),
          error: null,
        );

        // Update context window
        await _updateContextWindow();
      } else {
        state = state.copyWith(error: result.error);
      }
    } catch (error) {
      state = state.copyWith(error: error.toString());
    }
  }

  /// End current session
  Future<void> endSession() async {
    if (state.currentUserId == null) return;

    try {
      final result = await _sessionManager.endCurrentSession(state.currentUserId!);

      if (result.success) {
        state = state.copyWith(
          currentSessionId: null,
          sessionStatus: null,
          currentContextWindow: null,
          error: null,
        );
      } else {
        state = state.copyWith(error: result.error);
      }
    } catch (error) {
      state = state.copyWith(error: error.toString());
    }
  }

  /// Search memories
  Future<List<MemoryChunk>> searchMemories(
    String query, {
    List<MemoryType>? types,
    int limit = 20,
  }) async {
    if (state.currentUserId == null) return [];

    try {
      final result = await _memoryService.searchMemoryChunks(
        state.currentUserId!,
        query,
        types: types,
        limit: limit,
      );

      if (result.success) {
        return result.data!;
      } else {
        state = state.copyWith(error: result.error);
        return [];
      }
    } catch (error) {
      state = state.copyWith(error: error.toString());
      return [];
    }
  }

  /// Get relevant memories for context
  Future<List<MemoryChunk>> getRelevantMemories(
    String context, {
    int maxResults = 20,
    double minRelevanceScore = 0.3,
  }) async {
    if (state.currentUserId == null) return [];

    try {
      final result = await _optimizationService.retrieveRelevantMemories(
        state.currentUserId!,
        context,
        maxResults: maxResults,
        minRelevanceScore: minRelevanceScore,
      );

      if (result.success) {
        return result.data!;
      } else {
        state = state.copyWith(error: result.error);
        return [];
      }
    } catch (error) {
      state = state.copyWith(error: error.toString());
      return [];
    }
  }

  /// Optimize user memory
  Future<void> optimizeMemory({
    OptimizationLevel level = OptimizationLevel.standard,
  }) async {
    if (state.currentUserId == null) return;

    state = state.copyWith(isOptimizing: true);

    try {
      final result = await _optimizationService.optimizeUserMemory(
        state.currentUserId!,
        level: level,
      );

      if (result.success) {
        state = state.copyWith(
          optimizationStats: {
            'last_optimization': DateTime.now().toIso8601String(),
            'level': level.name,
            'chunks_processed': result.data!.chunksProcessed,
            'chunks_removed': result.data!.chunksRemoved,
            'storage_saved_mb': result.data!.storageSavedMB,
          },
          isOptimizing: false,
          error: null,
        );

        // Refresh metrics
        await _updateMetrics();
      } else {
        state = state.copyWith(
          isOptimizing: false,
          error: result.error,
        );
      }
    } catch (error) {
      state = state.copyWith(
        isOptimizing: false,
        error: error.toString(),
      );
    }
  }

  /// Handle session interruption
  Future<InterruptionRecoveryResult?> handleInterruption(
    InterruptionType type, {
    String? reason,
    Map<String, dynamic>? context,
  }) async {
    if (state.currentUserId == null) return null;

    try {
      final result = await _sessionManager.handleSessionInterruption(
        state.currentUserId!,
        type,
        reason: reason,
        context: context,
      );

      if (result.success) {
        state = state.copyWith(
          sessionStatus: _sessionManager.getCurrentSessionStatus(state.currentUserId!),
          error: null,
        );
        return result.data!;
      } else {
        state = state.copyWith(error: result.error);
        return null;
      }
    } catch (error) {
      state = state.copyWith(error: error.toString());
      return null;
    }
  }

  /// Restore session context
  Future<SessionRestorationResult?> restoreSessionContext({
    String? sessionId,
    Duration? maxAge,
  }) async {
    if (state.currentUserId == null) return null;

    try {
      final result = await _sessionManager.restoreSessionContext(
        state.currentUserId!,
        specificSessionId: sessionId,
        maxAge: maxAge,
      );

      if (result.success) {
        return result.data!;
      } else {
        state = state.copyWith(error: result.error);
        return null;
      }
    } catch (error) {
      state = state.copyWith(error: error.toString());
      return null;
    }
  }

  /// Compact context window
  Future<void> compactContextWindow() async {
    if (state.currentSessionId == null) return;

    try {
      final result = await _compactionService.compactContextWindow(state.currentSessionId!);

      if (result.success) {
        state = state.copyWith(
          currentContextWindow: result.data!,
          error: null,
        );
      } else {
        state = state.copyWith(error: result.error);
      }
    } catch (error) {
      state = state.copyWith(error: error.toString());
    }
  }

  /// Summarize memory chunks
  Future<MemoryChunk?> summarizeChunks(
    List<MemoryChunk> chunks, {
    int maxLength = 300,
    SummarizationStyle style = SummarizationStyle.concise,
  }) async {
    try {
      final result = await _summarizationService.summarizeMemoryChunks(
        chunks,
        maxLength: maxLength,
        style: style,
      );

      if (result.success) {
        return result.data!;
      } else {
        state = state.copyWith(error: result.error);
        return null;
      }
    } catch (error) {
      state = state.copyWith(error: error.toString());
      return null;
    }
  }

  /// Get session history
  Future<List<MemorySession>> getSessionHistory({
    int limit = 20,
    SessionType? type,
    Duration? maxAge,
  }) async {
    if (state.currentUserId == null) return [];

    try {
      final result = await _sessionManager.getSessionHistory(
        state.currentUserId!,
        limit: limit,
        type: type,
        maxAge: maxAge,
      );

      if (result.success) {
        return result.data!;
      } else {
        state = state.copyWith(error: result.error);
        return [];
      }
    } catch (error) {
      state = state.copyWith(error: error.toString());
      return [];
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Private helper methods

  void _startPeriodicTasks() {
    // Update metrics every 30 seconds
    _metricsTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (state.currentUserId != null) {
        _updateMetrics();
        _updateSessionStatus();
      }
    });

    // Run optimization every 6 hours
    _optimizationTimer = Timer.periodic(const Duration(hours: 6), (timer) {
      if (state.currentUserId != null && !state.isOptimizing) {
        optimizeMemory(level: OptimizationLevel.light);
      }
    });
  }

  Future<void> _loadUserData(String userId) async {
    await _updateMetrics();
    _updateSessionStatus();
    await _loadRecentMemories();
  }

  Future<void> _updateMetrics() async {
    if (state.currentUserId == null) return;

    try {
      final result = await _memoryService.getMemoryMetrics(state.currentUserId!);
      if (result.success) {
        state = state.copyWith(metrics: result.data!);
      }
    } catch (error) {
      // Don't update error state for background tasks
      if (kDebugMode) {
        print('Failed to update metrics: $error');
      }
    }
  }

  void _updateSessionStatus() {
    if (state.currentUserId == null) return;

    final status = _sessionManager.getCurrentSessionStatus(state.currentUserId!);
    state = state.copyWith(sessionStatus: status);
  }

  Future<void> _loadRecentMemories() async {
    if (state.currentUserId == null) return;

    try {
      final result = await _memoryService.retrieveMemoryChunks(
        MemoryQuery(
          userId: state.currentUserId!,
          limit: 50,
          sortBy: MemoryQuerySort.timestamp,
        ),
      );

      if (result.success) {
        state = state.copyWith(recentMemories: result.data!);
      }
    } catch (error) {
      if (kDebugMode) {
        print('Failed to load recent memories: $error');
      }
    }
  }

  Future<void> _updateContextWindow() async {
    if (state.currentSessionId == null) return;

    try {
      final result = await _compactionService.getContextWindow(state.currentSessionId!);
      if (result.success) {
        state = state.copyWith(currentContextWindow: result.data!);
      }
    } catch (error) {
      if (kDebugMode) {
        print('Failed to update context window: $error');
      }
    }
  }

  @override
  void dispose() {
    _metricsTimer?.cancel();
    _optimizationTimer?.cancel();
    _memoryService.dispose();
    _compactionService.dispose();
    _summarizationService.dispose();
    _optimizationService.dispose();
    _sessionManager.dispose();
    super.dispose();
  }
}

/// Memory system provider
final memoryProvider = StateNotifierProvider<MemoryNotifier, MemoryState>((ref) {
  return MemoryNotifier();
});

/// Memory actions provider
final memoryActionsProvider = Provider<MemoryActions>((ref) {
  final notifier = ref.read(memoryProvider.notifier);
  return MemoryActions(notifier);
});

/// Memory actions class
class MemoryActions {
  final MemoryNotifier _notifier;

  MemoryActions(this._notifier);

  /// Set current user
  Future<void> setUser(String userId) => _notifier.setCurrentUser(userId);

  /// Start session
  Future<void> startSession({
    required SessionType type,
    String? title,
    Map<String, dynamic>? initialContext,
  }) => _notifier.startSession(
        type: type,
        title: title,
        initialContext: initialContext,
      );

  /// Add memory
  Future<void> addMemory(MemoryChunk chunk) => _notifier.addMemory(chunk);

  /// End session
  Future<void> endSession() => _notifier.endSession();

  /// Search memories
  Future<List<MemoryChunk>> searchMemories(
    String query, {
    List<MemoryType>? types,
    int limit = 20,
  }) => _notifier.searchMemories(query, types: types, limit: limit);

  /// Get relevant memories
  Future<List<MemoryChunk>> getRelevantMemories(
    String context, {
    int maxResults = 20,
    double minRelevanceScore = 0.3,
  }) => _notifier.getRelevantMemories(
        context,
        maxResults: maxResults,
        minRelevanceScore: minRelevanceScore,
      );

  /// Optimize memory
  Future<void> optimizeMemory({
    OptimizationLevel level = OptimizationLevel.standard,
  }) => _notifier.optimizeMemory(level: level);

  /// Handle interruption
  Future<InterruptionRecoveryResult?> handleInterruption(
    InterruptionType type, {
    String? reason,
    Map<String, dynamic>? context,
  }) => _notifier.handleInterruption(type, reason: reason, context: context);

  /// Restore session context
  Future<SessionRestorationResult?> restoreSessionContext({
    String? sessionId,
    Duration? maxAge,
  }) => _notifier.restoreSessionContext(sessionId: sessionId, maxAge: maxAge);

  /// Compact context window
  Future<void> compactContextWindow() => _notifier.compactContextWindow();

  /// Summarize chunks
  Future<MemoryChunk?> summarizeChunks(
    List<MemoryChunk> chunks, {
    int maxLength = 300,
    SummarizationStyle style = SummarizationStyle.concise,
  }) => _notifier.summarizeChunks(chunks, maxLength: maxLength, style: style);

  /// Get session history
  Future<List<MemorySession>> getSessionHistory({
    int limit = 20,
    SessionType? type,
    Duration? maxAge,
  }) => _notifier.getSessionHistory(limit: limit, type: type, maxAge: maxAge);

  /// Clear error
  void clearError() => _notifier.clearError();
}

/// Specific providers for UI components

/// Current session provider
final currentSessionProvider = Provider<SessionStatus?>((ref) {
  final memoryState = ref.watch(memoryProvider);
  return memoryState.sessionStatus;
});

/// Memory metrics provider
final memoryMetricsProvider = Provider<MemoryMetrics?>((ref) {
  final memoryState = ref.watch(memoryProvider);
  return memoryState.metrics;
});

/// Recent memories provider
final recentMemoriesProvider = Provider<List<MemoryChunk>>((ref) {
  final memoryState = ref.watch(memoryProvider);
  return memoryState.recentMemories;
});

/// Context window provider
final contextWindowProvider = Provider<ContextWindow?>((ref) {
  final memoryState = ref.watch(memoryProvider);
  return memoryState.currentContextWindow;
});

/// Memory optimization status provider
final memoryOptimizationStatusProvider = Provider<Map<String, dynamic>>((ref) {
  final memoryState = ref.watch(memoryProvider);
  return {
    'is_optimizing': memoryState.isOptimizing,
    'stats': memoryState.optimizationStats,
  };
});

/// Memory system health provider
final memorySystemHealthProvider = Provider<Map<String, dynamic>>((ref) {
  final memoryState = ref.watch(memoryProvider);
  
  return {
    'is_initialized': memoryState.isInitialized,
    'has_user': memoryState.currentUserId != null,
    'has_active_session': memoryState.sessionStatus?.hasActiveSession ?? false,
    'has_error': memoryState.error != null,
    'error': memoryState.error,
    'memory_count': memoryState.metrics?.totalChunks ?? 0,
    'session_count': memoryState.metrics?.totalSessions ?? 0,
    'storage_usage_mb': memoryState.metrics?.storageUsageMB ?? 0.0,
  };
});

/// Search memories provider (family)
final searchMemoriesProvider = FutureProvider.family<List<MemoryChunk>, String>((ref, query) async {
  final actions = ref.read(memoryActionsProvider);
  return await actions.searchMemories(query);
});

/// Session history provider
final sessionHistoryProvider = FutureProvider<List<MemorySession>>((ref) async {
  final actions = ref.read(memoryActionsProvider);
  return await actions.getSessionHistory();
});