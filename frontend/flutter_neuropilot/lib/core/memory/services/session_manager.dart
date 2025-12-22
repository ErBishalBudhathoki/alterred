import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/memory_models.dart';
import 'firestore_memory_service.dart';
import 'context_compaction_service.dart';
import 'gemini_summarization_service.dart';

/// Session manager for handling memory persistence across app sessions
class SessionManager {
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  final FirestoreMemoryService _memoryService = FirestoreMemoryService();
  final ContextCompactionService _compactionService =
      ContextCompactionService();
  final GeminiSummarizationService _summarizationService =
      GeminiSummarizationService();

  final Map<String, MemorySession> _activeSessions = {};
  final Map<String, Timer> _sessionTimers = {};
  final Map<String, List<MemoryChunk>> _sessionBuffers = {};

  // Configuration
  static const Duration _sessionTimeout = Duration(minutes: 30);
  static const Duration _bufferFlushInterval = Duration(minutes: 5);
  static const int _maxBufferSize = 50;
  static const Duration _sessionSummaryThreshold = Duration(minutes: 15);

  // String? _currentUserId; // Unused
  String? _currentSessionId;

  /// Initialize the session manager
  Future<void> initialize({String? userId}) async {
    // _currentUserId = userId;

    // Start buffer flush timer
    Timer.periodic(_bufferFlushInterval, (timer) {
      _flushAllBuffers();
    });

    if (kDebugMode) {
      print('📝 SessionManager initialized for user: $userId');
    }
  }

  /// Start a new memory session
  Future<MemoryOperationResult<MemorySession>> startSession({
    required String userId,
    required SessionType type,
    String? title,
    Map<String, dynamic>? initialContext,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      // End any existing session for this user
      await endCurrentSession(userId);

      final sessionId =
          'session_${DateTime.now().millisecondsSinceEpoch}_${userId.hashCode}';

      final session = MemorySession(
        id: sessionId,
        userId: userId,
        title: title ?? _generateSessionTitle(type),
        startTime: DateTime.now(),
        type: type,
        context: initialContext ?? {},
        adhdMetrics: _initializeAdhdMetrics(),
      );

      // Store session
      final storeResult = await _memoryService.storeMemorySession(session);
      if (!storeResult.success) {
        return MemoryOperationResult.failure(storeResult.error!);
      }

      // Set as active session
      _activeSessions[userId] = storeResult.data!;
      _currentSessionId = sessionId;
      _sessionBuffers[sessionId] = [];

      // Set session timeout
      _setSessionTimeout(userId, sessionId);

      // Initialize context window
      await _compactionService.getContextWindow(sessionId);

      stopwatch.stop();

      if (kDebugMode) {
        print('🚀 Started new session: $sessionId (${type.name})');
      }

      return MemoryOperationResult.success(
        storeResult.data!,
        executionTime: stopwatch.elapsed,
        metadata: {
          'operation': 'start_session',
          'session_id': sessionId,
          'session_type': type.name,
        },
      );
    } catch (error) {
      stopwatch.stop();
      return MemoryOperationResult.failure(
        'Failed to start session: $error',
        executionTime: stopwatch.elapsed,
      );
    }
  }

  /// Add memory chunk to current session
  Future<MemoryOperationResult<MemoryChunk>> addMemoryToSession(
    String userId,
    MemoryChunk chunk, {
    bool flushImmediately = false,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      final session = _activeSessions[userId];
      if (session == null) {
        // Auto-start session if none exists
        final sessionResult = await startSession(
          userId: userId,
          type: _inferSessionType(chunk),
        );
        if (!sessionResult.success) {
          return MemoryOperationResult.failure(sessionResult.error!);
        }
      }

      final sessionId = _activeSessions[userId]!.id;

      // Ensure chunk has correct session ID
      final sessionChunk = chunk.copyWith(sessionId: sessionId);

      // Add to buffer
      _sessionBuffers[sessionId] ??= [];
      _sessionBuffers[sessionId]!.add(sessionChunk);

      // Update session metrics
      await _updateSessionMetrics(userId, sessionChunk);

      // Add to context window
      await _compactionService.addToContextWindow(sessionId, sessionChunk);

      // Flush if needed
      if (flushImmediately ||
          _sessionBuffers[sessionId]!.length >= _maxBufferSize) {
        await _flushSessionBuffer(sessionId);
      }

      // Reset session timeout
      _setSessionTimeout(userId, sessionId);

      stopwatch.stop();

      return MemoryOperationResult.success(
        sessionChunk,
        executionTime: stopwatch.elapsed,
        metadata: {
          'operation': 'add_memory_to_session',
          'session_id': sessionId,
          'buffer_size': _sessionBuffers[sessionId]!.length,
        },
      );
    } catch (error) {
      stopwatch.stop();
      return MemoryOperationResult.failure(
        'Failed to add memory to session: $error',
        executionTime: stopwatch.elapsed,
      );
    }
  }

  /// End current session
  Future<MemoryOperationResult<MemorySession>> endCurrentSession(
      String userId) async {
    final stopwatch = Stopwatch()..start();

    try {
      final session = _activeSessions[userId];
      if (session == null) {
        return MemoryOperationResult.failure(
            'No active session found for user');
      }

      // Flush any remaining buffer
      await _flushSessionBuffer(session.id);

      // Create session summary if session was long enough
      SessionSummary? summary;
      if (session.actualDuration >= _sessionSummaryThreshold) {
        final summaryResult = await _createSessionSummary(session);
        if (summaryResult.success) {
          summary = summaryResult.data!;
        }
      }

      // Update session with end time and summary
      final endedSession = MemorySession(
        id: session.id,
        userId: session.userId,
        title: session.title,
        startTime: session.startTime,
        endTime: DateTime.now(),
        type: session.type,
        context: session.context,
        chunkIds: session.chunkIds,
        summary: summary,
        attentionScore: session.attentionScore,
        interruptionCount: session.interruptionCount,
        totalDuration: session.actualDuration,
        adhdMetrics: session.adhdMetrics,
      );

      // Store updated session
      final storeResult = await _memoryService.storeMemorySession(endedSession);
      if (!storeResult.success) {
        return MemoryOperationResult.failure(storeResult.error!);
      }

      // Clean up
      _activeSessions.remove(userId);
      _sessionBuffers.remove(session.id);
      _sessionTimers[userId]?.cancel();
      _sessionTimers.remove(userId);
      _compactionService.clearContextWindow(session.id);

      if (_currentSessionId == session.id) {
        _currentSessionId = null;
      }

      stopwatch.stop();

      if (kDebugMode) {
        print('🏁 Ended session: ${session.id}');
        print('   Duration: ${endedSession.totalDuration.inMinutes} minutes');
        print('   Chunks: ${endedSession.chunkIds.length}');
        print('   Summary: ${summary != null ? 'Created' : 'None'}');
      }

      return MemoryOperationResult.success(
        storeResult.data!,
        executionTime: stopwatch.elapsed,
        metadata: {
          'operation': 'end_session',
          'session_id': session.id,
          'duration_minutes': endedSession.totalDuration.inMinutes,
          'chunk_count': endedSession.chunkIds.length,
          'has_summary': summary != null,
        },
      );
    } catch (error) {
      stopwatch.stop();
      return MemoryOperationResult.failure(
        'Failed to end session: $error',
        executionTime: stopwatch.elapsed,
      );
    }
  }

  /// Restore session context from previous session
  Future<MemoryOperationResult<SessionRestorationResult>> restoreSessionContext(
    String userId, {
    String? specificSessionId,
    Duration? maxAge,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Find session to restore
      MemorySession? sessionToRestore;

      if (specificSessionId != null) {
        final sessionsResult =
            await _memoryService.retrieveMemorySessions(userId, limit: 100);
        if (sessionsResult.success) {
          sessionToRestore = sessionsResult.data!
              .where((s) => s.id == specificSessionId)
              .firstOrNull;
        }
      } else {
        // Find most recent session
        final recentSessionsResult =
            await _memoryService.retrieveMemorySessions(
          userId,
          fromDate: maxAge != null ? DateTime.now().subtract(maxAge) : null,
          limit: 1,
        );

        if (recentSessionsResult.success &&
            recentSessionsResult.data!.isNotEmpty) {
          sessionToRestore = recentSessionsResult.data!.first;
        }
      }

      if (sessionToRestore == null) {
        return MemoryOperationResult.failure('No session found to restore');
      }

      // Get session chunks
      final chunksResult = await _memoryService.retrieveMemoryChunks(
        MemoryQuery(
          userId: userId,
          sessionId: sessionToRestore.id,
          sortBy: MemoryQuerySort.timestamp,
          limit: 200,
        ),
      );

      if (!chunksResult.success) {
        return MemoryOperationResult.failure(chunksResult.error!);
      }

      final chunks = chunksResult.data!;

      // Create restoration result
      final restorationResult = SessionRestorationResult(
        restoredSession: sessionToRestore,
        contextChunks: chunks,
        summary: sessionToRestore.summary,
        carryoverContext: sessionToRestore.summary?.contextCarryover ?? {},
        restorationQuality:
            _calculateRestorationQuality(sessionToRestore, chunks),
      );

      stopwatch.stop();

      if (kDebugMode) {
        print('🔄 Restored session context: ${sessionToRestore.id}');
        print('   Chunks restored: ${chunks.length}');
        print(
            '   Quality: ${restorationResult.restorationQuality.toStringAsFixed(2)}');
      }

      return MemoryOperationResult.success(
        restorationResult,
        executionTime: stopwatch.elapsed,
        metadata: {
          'operation': 'restore_session_context',
          'session_id': sessionToRestore.id,
          'chunks_restored': chunks.length,
          'restoration_quality': restorationResult.restorationQuality,
        },
      );
    } catch (error) {
      stopwatch.stop();
      return MemoryOperationResult.failure(
        'Failed to restore session context: $error',
        executionTime: stopwatch.elapsed,
      );
    }
  }

  /// Handle session interruption (ADHD-specific)
  Future<MemoryOperationResult<InterruptionRecoveryResult>>
      handleSessionInterruption(
    String userId,
    InterruptionType type, {
    String? reason,
    Map<String, dynamic>? context,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      final session = _activeSessions[userId];
      if (session == null) {
        return MemoryOperationResult.failure('No active session to interrupt');
      }

      // Create interruption memory chunk
      final interruptionChunk = MemoryChunk(
        id: '',
        userId: userId,
        sessionId: session.id,
        type: MemoryType.interruption,
        content:
            'Session interrupted: ${type.name}${reason != null ? ' - $reason' : ''}',
        metadata: {
          'interruption_type': type.name,
          'interruption_reason': reason,
          'interruption_context': context ?? {},
          'session_state_before_interruption': _captureSessionState(session),
        },
        tags: ['interruption', type.name, 'adhd'],
        timestamp: DateTime.now(),
        lastAccessed: DateTime.now(),
        priority: MemoryPriority.high,
      );

      // Add interruption to session
      await addMemoryToSession(userId, interruptionChunk,
          flushImmediately: true);

      // Update session metrics
      final updatedSession = session.copyWith(
        interruptionCount: session.interruptionCount + 1,
        adhdMetrics: {
          ...session.adhdMetrics,
          'interruptions':
              (session.adhdMetrics['interruptions'] as int? ?? 0) + 1,
          'last_interruption': DateTime.now().toIso8601String(),
          'interruption_types': [
            ...(session.adhdMetrics['interruption_types'] as List? ?? []),
            type.name,
          ],
        },
      );

      _activeSessions[userId] = updatedSession;

      // Create recovery context
      final recoveryResult = InterruptionRecoveryResult(
        interruptionChunk: interruptionChunk,
        sessionStateSnapshot: _captureSessionState(session),
        recoveryInstructions: _generateRecoveryInstructions(type, session),
        estimatedRecoveryTime: _estimateRecoveryTime(type, session),
      );

      stopwatch.stop();

      if (kDebugMode) {
        print('⚠️ Session interruption handled: ${type.name}');
        print('   Session: ${session.id}');
        print(
            '   Recovery time: ${recoveryResult.estimatedRecoveryTime.inMinutes} minutes');
      }

      return MemoryOperationResult.success(
        recoveryResult,
        executionTime: stopwatch.elapsed,
        metadata: {
          'operation': 'handle_interruption',
          'interruption_type': type.name,
          'session_id': session.id,
          'interruption_count': updatedSession.interruptionCount,
        },
      );
    } catch (error) {
      stopwatch.stop();
      return MemoryOperationResult.failure(
        'Failed to handle interruption: $error',
        executionTime: stopwatch.elapsed,
      );
    }
  }

  /// Get current session status
  SessionStatus getCurrentSessionStatus(String userId) {
    final session = _activeSessions[userId];
    if (session == null) {
      return const SessionStatus(
        hasActiveSession: false,
        sessionId: null,
        sessionType: null,
        duration: Duration.zero,
        chunkCount: 0,
        lastActivity: null,
      );
    }

    final buffer = _sessionBuffers[session.id] ?? [];

    return SessionStatus(
      hasActiveSession: true,
      sessionId: session.id,
      sessionType: session.type,
      duration: session.actualDuration,
      chunkCount: session.chunkIds.length + buffer.length,
      lastActivity: buffer.isNotEmpty ? buffer.last.timestamp : null,
      attentionScore: session.attentionScore,
      interruptionCount: session.interruptionCount,
    );
  }

  /// Get session history for user
  Future<MemoryOperationResult<List<MemorySession>>> getSessionHistory(
    String userId, {
    int limit = 20,
    SessionType? type,
    Duration? maxAge,
  }) async {
    return await _memoryService.retrieveMemorySessions(
      userId,
      type: type,
      fromDate: maxAge != null ? DateTime.now().subtract(maxAge) : null,
      limit: limit,
    );
  }

  /// Private helper methods

  String _generateSessionTitle(SessionType type) {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    switch (type) {
      case SessionType.chat:
        return 'Chat Session - $timeStr';
      case SessionType.voice:
        return 'Voice Session - $timeStr';
      case SessionType.task:
        return 'Task Session - $timeStr';
      case SessionType.planning:
        return 'Planning Session - $timeStr';
      case SessionType.hyperfocus:
        return 'Hyperfocus Session - $timeStr';
      case SessionType.pause:
        return 'Break Session - $timeStr';
      case SessionType.decision:
        return 'Decision Session - $timeStr';
      case SessionType.mixed:
        return 'Mixed Session - $timeStr';
    }
  }

  Map<String, dynamic> _initializeAdhdMetrics() {
    return {
      'interruptions': 0,
      'context_switches': 0,
      'hyperfocus_episodes': 0,
      'attention_score': 0.0,
      'energy_levels': <double>[],
      'break_compliance': 1.0,
    };
  }

  SessionType _inferSessionType(MemoryChunk chunk) {
    switch (chunk.type) {
      case MemoryType.conversation:
        return SessionType.chat;
      case MemoryType.task:
        return SessionType.task;
      case MemoryType.decision:
        return SessionType.decision;
      case MemoryType.hyperfocus:
        return SessionType.hyperfocus;
      default:
        return SessionType.mixed;
    }
  }

  void _setSessionTimeout(String userId, String sessionId) {
    _sessionTimers[userId]?.cancel();
    _sessionTimers[userId] = Timer(_sessionTimeout, () {
      _handleSessionTimeout(userId, sessionId);
    });
  }

  Future<void> _handleSessionTimeout(String userId, String sessionId) async {
    if (kDebugMode) {
      print('⏰ Session timeout for user: $userId');
    }

    await endCurrentSession(userId);
  }

  Future<void> _updateSessionMetrics(String userId, MemoryChunk chunk) async {
    final session = _activeSessions[userId];
    if (session == null) return;

    final updatedMetrics = Map<String, dynamic>.from(session.adhdMetrics);

    // Update attention score based on chunk type and content
    final attentionContribution = _calculateAttentionContribution(chunk);
    final currentAttention = session.attentionScore;
    final newAttentionScore =
        (currentAttention * 0.9) + (attentionContribution * 0.1);

    // Update energy levels if available
    if (chunk.metadata.containsKey('energy_level')) {
      final energyLevels =
          List<double>.from(updatedMetrics['energy_levels'] ?? []);
      energyLevels.add(chunk.metadata['energy_level'] as double);
      if (energyLevels.length > 20) {
        energyLevels.removeAt(0); // Keep only last 20 readings
      }
      updatedMetrics['energy_levels'] = energyLevels;
    }

    // Update context switches
    if (chunk.type != session.type.toMemoryType()) {
      updatedMetrics['context_switches'] =
          (updatedMetrics['context_switches'] as int? ?? 0) + 1;
    }

    // Update hyperfocus episodes
    if (chunk.type == MemoryType.hyperfocus) {
      updatedMetrics['hyperfocus_episodes'] =
          (updatedMetrics['hyperfocus_episodes'] as int? ?? 0) + 1;
    }

    final updatedSession = session.copyWith(
      attentionScore: newAttentionScore,
      adhdMetrics: updatedMetrics,
    );

    _activeSessions[userId] = updatedSession;
  }

  double _calculateAttentionContribution(MemoryChunk chunk) {
    double score = 0.5; // Base score

    // Boost for high-importance chunks
    score += chunk.importanceScore * 0.3;

    // Boost for certain types
    switch (chunk.type) {
      case MemoryType.task:
      case MemoryType.decision:
        score += 0.2;
        break;
      case MemoryType.hyperfocus:
        score += 0.4;
        break;
      case MemoryType.interruption:
        score -= 0.3;
        break;
      default:
        break;
    }

    return score.clamp(0.0, 1.0);
  }

  Future<void> _flushSessionBuffer(String sessionId) async {
    final buffer = _sessionBuffers[sessionId];
    if (buffer == null || buffer.isEmpty) return;

    try {
      // Store all chunks in batch
      final storeResult = await _memoryService.storeMemoryChunksBatch(buffer);

      if (storeResult.success) {
        // Update session with chunk IDs
        final session =
            _activeSessions.values.where((s) => s.id == sessionId).firstOrNull;

        if (session != null) {
          final updatedChunkIds = [
            ...session.chunkIds,
            ...storeResult.data!.map((c) => c.id),
          ];

          final updatedSession = session.copyWith(chunkIds: updatedChunkIds);
          _activeSessions[session.userId] = updatedSession;
        }

        // Clear buffer
        _sessionBuffers[sessionId] = [];

        if (kDebugMode) {
          print('💾 Flushed ${buffer.length} chunks for session: $sessionId');
        }
      }
    } catch (error) {
      if (kDebugMode) {
        print('❌ Failed to flush session buffer: $error');
      }
    }
  }

  Future<void> _flushAllBuffers() async {
    for (final sessionId in _sessionBuffers.keys.toList()) {
      await _flushSessionBuffer(sessionId);
    }
  }

  Future<MemoryOperationResult<SessionSummary>> _createSessionSummary(
      MemorySession session) async {
    try {
      // Get all chunks for the session
      final chunksResult = await _memoryService.retrieveMemoryChunks(
        MemoryQuery(
          userId: session.userId,
          sessionId: session.id,
          sortBy: MemoryQuerySort.timestamp,
          limit: 500,
        ),
      );

      if (!chunksResult.success || chunksResult.data!.isEmpty) {
        return MemoryOperationResult.failure(
            'No chunks found for session summary');
      }

      return await _summarizationService.createSessionSummary(
        chunksResult.data!,
        includeOutcomes: true,
        includeDecisions: true,
        includeContextCarryover: true,
      );
    } catch (error) {
      return MemoryOperationResult.failure(
          'Failed to create session summary: $error');
    }
  }

  double _calculateRestorationQuality(
      MemorySession session, List<MemoryChunk> chunks) {
    double quality = 0.5; // Base quality

    // Boost for recent sessions
    final age = DateTime.now().difference(session.startTime);
    if (age.inHours < 24) {
      quality += 0.3;
    } else if (age.inDays < 7) {
      quality += 0.2;
    } else if (age.inDays < 30) {
      quality += 0.1;
    }

    // Boost for sessions with summaries
    if (session.summary != null) quality += 0.2;

    // Boost for sessions with more chunks
    if (chunks.length > 10) quality += 0.1;
    if (chunks.length > 50) quality += 0.1;

    // Boost for high attention score
    quality += session.attentionScore * 0.2;

    return quality.clamp(0.0, 1.0);
  }

  Map<String, dynamic> _captureSessionState(MemorySession session) {
    return {
      'session_id': session.id,
      'session_type': session.type.name,
      'duration_minutes': session.actualDuration.inMinutes,
      'chunk_count': session.chunkIds.length,
      'attention_score': session.attentionScore,
      'interruption_count': session.interruptionCount,
      'adhd_metrics': session.adhdMetrics,
      'context': session.context,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  List<String> _generateRecoveryInstructions(
      InterruptionType type, MemorySession session) {
    final instructions = <String>[];

    switch (type) {
      case InterruptionType.external:
        instructions.addAll([
          'Take a moment to refocus',
          'Review what you were working on before the interruption',
          'Set a timer to stay on track',
        ]);
        break;
      case InterruptionType.internal:
        instructions.addAll([
          'Acknowledge the distraction without judgment',
          'Write down the distracting thought if needed',
          'Use a grounding technique (5-4-3-2-1)',
          'Return to your previous task',
        ]);
        break;
      case InterruptionType.hyperfocus:
        instructions.addAll([
          'Take a mandatory break',
          'Do some light physical activity',
          'Hydrate and have a snack if needed',
          'Review your progress before continuing',
        ]);
        break;
      case InterruptionType.fatigue:
        instructions.addAll([
          'Consider taking a longer break',
          'Do some energizing activities',
          'Check if you need food or water',
          'Adjust your task difficulty if needed',
        ]);
        break;
      case InterruptionType.emergency:
        instructions.addAll([
          'Handle the emergency first',
          'When ready, review your session context',
          'Decide if you can continue or need to reschedule',
        ]);
        break;
    }

    return instructions;
  }

  Duration _estimateRecoveryTime(InterruptionType type, MemorySession session) {
    switch (type) {
      case InterruptionType.external:
        return const Duration(minutes: 2);
      case InterruptionType.internal:
        return const Duration(minutes: 1);
      case InterruptionType.hyperfocus:
        return const Duration(minutes: 10);
      case InterruptionType.fatigue:
        return const Duration(minutes: 15);
      case InterruptionType.emergency:
        return const Duration(minutes: 30);
    }
  }

  /// Dispose the service
  void dispose() {
    for (final timer in _sessionTimers.values) {
      timer.cancel();
    }
    _sessionTimers.clear();
    _activeSessions.clear();
    _sessionBuffers.clear();
  }
}

/// Session restoration result
class SessionRestorationResult {
  final MemorySession restoredSession;
  final List<MemoryChunk> contextChunks;
  final SessionSummary? summary;
  final Map<String, dynamic> carryoverContext;
  final double restorationQuality;

  const SessionRestorationResult({
    required this.restoredSession,
    required this.contextChunks,
    this.summary,
    this.carryoverContext = const {},
    required this.restorationQuality,
  });
}

/// Interruption recovery result
class InterruptionRecoveryResult {
  final MemoryChunk interruptionChunk;
  final Map<String, dynamic> sessionStateSnapshot;
  final List<String> recoveryInstructions;
  final Duration estimatedRecoveryTime;

  const InterruptionRecoveryResult({
    required this.interruptionChunk,
    required this.sessionStateSnapshot,
    required this.recoveryInstructions,
    required this.estimatedRecoveryTime,
  });
}

/// Session status
class SessionStatus {
  final bool hasActiveSession;
  final String? sessionId;
  final SessionType? sessionType;
  final Duration duration;
  final int chunkCount;
  final DateTime? lastActivity;
  final double? attentionScore;
  final int? interruptionCount;

  const SessionStatus({
    required this.hasActiveSession,
    this.sessionId,
    this.sessionType,
    required this.duration,
    required this.chunkCount,
    this.lastActivity,
    this.attentionScore,
    this.interruptionCount,
  });
}

/// Interruption types
enum InterruptionType {
  external, // External distraction
  internal, // Internal distraction/mind wandering
  hyperfocus, // Hyperfocus break
  fatigue, // Mental fatigue
  emergency, // Emergency interruption
}

/// Extension to convert SessionType to MemoryType
extension SessionTypeExtension on SessionType {
  MemoryType toMemoryType() {
    switch (this) {
      case SessionType.chat:
        return MemoryType.conversation;
      case SessionType.voice:
        return MemoryType.conversation;
      case SessionType.task:
        return MemoryType.task;
      case SessionType.planning:
        return MemoryType.task;
      case SessionType.hyperfocus:
        return MemoryType.hyperfocus;
      case SessionType.pause:
        return MemoryType.context;
      case SessionType.decision:
        return MemoryType.decision;
      case SessionType.mixed:
        return MemoryType.context;
    }
  }
}
