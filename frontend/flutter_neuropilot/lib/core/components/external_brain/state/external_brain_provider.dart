import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:altered/services/api_client.dart';
import '../models/brain_capture_model.dart';
import '../models/context_snapshot_model.dart';
import '../models/a2a_connection_model.dart';
import '../../../../state/session_state.dart';

// Main External Brain State
final externalBrainProvider = StateNotifierProvider<ExternalBrainNotifier, ExternalBrainState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ExternalBrainNotifier(apiClient);
});

class ExternalBrainState {
  final List<BrainCapture> captures;
  final List<ContextSnapshot> snapshots;
  final List<A2AConnection> connections;
  final List<WorkingMemoryItem> workingMemory;
  final CaptureStats? stats;
  final bool isLoading;
  final String? error;
  final CaptureSession? activeSession;

  const ExternalBrainState({
    this.captures = const [],
    this.snapshots = const [],
    this.connections = const [],
    this.workingMemory = const [],
    this.stats,
    this.isLoading = false,
    this.error,
    this.activeSession,
  });

  ExternalBrainState copyWith({
    List<BrainCapture>? captures,
    List<ContextSnapshot>? snapshots,
    List<A2AConnection>? connections,
    List<WorkingMemoryItem>? workingMemory,
    CaptureStats? stats,
    bool? isLoading,
    String? error,
    CaptureSession? activeSession,
  }) {
    return ExternalBrainState(
      captures: captures ?? this.captures,
      snapshots: snapshots ?? this.snapshots,
      connections: connections ?? this.connections,
      workingMemory: workingMemory ?? this.workingMemory,
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      activeSession: activeSession ?? this.activeSession,
    );
  }
}

class ExternalBrainNotifier extends StateNotifier<ExternalBrainState> {
  final ApiClient _apiClient;

  ExternalBrainNotifier(this._apiClient) : super(const ExternalBrainState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true);
    try {
      await Future.wait([
        loadCaptures(),
        loadSnapshots(),
        loadConnections(),
        loadWorkingMemory(),
        loadStats(),
      ]);
    } catch (e) {
      if (mounted) state = state.copyWith(error: e.toString());
    } finally {
      if (mounted) state = state.copyWith(isLoading: false);
    }
  }

  Future<void> loadCaptures() async {
    try {
      final response = await _apiClient.externalNotes();
      if (!mounted) return;
      final captures = response.map<BrainCapture>((json) => 
        BrainCapture.fromJson(json as Map<String, dynamic>)
      ).toList();
      state = state.copyWith(captures: captures);
    } catch (e) {
      if (mounted) state = state.copyWith(error: 'Failed to load captures: $e');
    }
  }

  Future<void> loadSnapshots() async {
    try {
      // TODO: Implement API call for context snapshots
      final snapshots = <ContextSnapshot>[];
      if (mounted) state = state.copyWith(snapshots: snapshots);
    } catch (e) {
      if (mounted) state = state.copyWith(error: 'Failed to load snapshots: $e');
    }
  }

  Future<void> loadConnections() async {
    try {
      // TODO: Implement A2A connections API
      final connections = <A2AConnection>[];
      if (mounted) state = state.copyWith(connections: connections);
    } catch (e) {
      if (mounted) state = state.copyWith(error: 'Failed to load connections: $e');
    }
  }

  Future<void> loadWorkingMemory() async {
    try {
      // TODO: Implement working memory API
      final workingMemory = <WorkingMemoryItem>[];
      if (mounted) state = state.copyWith(workingMemory: workingMemory);
    } catch (e) {
      if (mounted) state = state.copyWith(error: 'Failed to load working memory: $e');
    }
  }

  Future<void> loadStats() async {
    try {
      // TODO: Implement stats API
      if (!mounted) return;
      final stats = CaptureStats(
        totalCaptures: state.captures.length,
        todayCaptures: state.captures.where((c) => 
          c.createdAt.isAfter(DateTime.now().subtract(const Duration(days: 1)))
        ).length,
        weekCaptures: state.captures.where((c) => 
          c.createdAt.isAfter(DateTime.now().subtract(const Duration(days: 7)))
        ).length,
        completedTasks: state.captures.where((c) => 
          c.status == BrainCaptureStatus.completed
        ).length,
        completionRate: 0.0,
      );
      state = state.copyWith(stats: stats);
    } catch (e) {
      if (mounted) state = state.copyWith(error: 'Failed to load stats: $e');
    }
  }

  Future<BrainCapture?> captureVoice(String transcript) async {
    try {
      final response = await _apiClient.captureExternal(transcript);
      if (!mounted) return null;
      final capture = BrainCapture(
        id: response['task_id'] as String,
        content: transcript,
        type: BrainCaptureType.voice(transcript: transcript),
        createdAt: DateTime.now(),
        status: BrainCaptureStatus.processing,
      );
      
      state = state.copyWith(
        captures: [capture, ...state.captures],
      );
      
      return capture;
    } catch (e) {
      if (mounted) state = state.copyWith(error: 'Failed to capture voice: $e');
      return null;
    }
  }

  Future<BrainCapture?> captureText(String text) async {
    try {
      final response = await _apiClient.captureExternal(text);
      if (!mounted) return null;
      final capture = BrainCapture(
        id: response['task_id'] as String,
        content: text,
        type: BrainCaptureType.text(text: text),
        createdAt: DateTime.now(),
        status: BrainCaptureStatus.processing,
      );
      
      state = state.copyWith(
        captures: [capture, ...state.captures],
      );
      
      return capture;
    } catch (e) {
      if (mounted) state = state.copyWith(error: 'Failed to capture text: $e');
      return null;
    }
  }

  Future<ContextSnapshot?> createSnapshot(String taskId, Map<String, dynamic> contextData) async {
    try {
      final snapshot = ContextSnapshot(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        taskId: taskId,
        timestamp: DateTime.now(),
        contextData: contextData,
        type: ContextType.work,
      );
      
      if (mounted) {
        state = state.copyWith(
          snapshots: [snapshot, ...state.snapshots],
        );
      }
      
      return snapshot;
    } catch (e) {
      if (mounted) state = state.copyWith(error: 'Failed to create snapshot: $e');
      return null;
    }
  }

  Future<bool> restoreContext(String snapshotId) async {
    try {
      final snapshot = state.snapshots.firstWhere((s) => s.id == snapshotId);
      
      // TODO: Implement context restoration logic
      
      final updatedSnapshot = snapshot.copyWith(
        isRestored: true,
        restoredAt: DateTime.now(),
      );
      
      final updatedSnapshots = state.snapshots.map((s) => 
        s.id == snapshotId ? updatedSnapshot : s
      ).toList();
      
      if (mounted) state = state.copyWith(snapshots: updatedSnapshots);
      
      return true;
    } catch (e) {
      if (mounted) state = state.copyWith(error: 'Failed to restore context: $e');
      return false;
    }
  }

  Future<WorkingMemoryItem?> addToWorkingMemory(String content, WorkingMemoryType type) async {
    try {
      final item = WorkingMemoryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: content,
        type: type,
        createdAt: DateTime.now(),
        priority: 1,
      );
      
      if (mounted) {
        state = state.copyWith(
          workingMemory: [item, ...state.workingMemory],
        );
      }
      
      return item;
    } catch (e) {
      if (mounted) state = state.copyWith(error: 'Failed to add to working memory: $e');
      return null;
    }
  }

  void removeFromWorkingMemory(String itemId) {
    final updatedMemory = state.workingMemory.where((item) => item.id != itemId).toList();
    state = state.copyWith(workingMemory: updatedMemory);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  void startCaptureSession(CaptureSessionType type) {
    final session = CaptureSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: DateTime.now(),
      type: type,
      isActive: true,
    );
    state = state.copyWith(activeSession: session);
  }

  void endCaptureSession() {
    if (state.activeSession != null) {
      final updatedSession = state.activeSession!.copyWith(
        endTime: DateTime.now(),
        isActive: false,
      );
      state = state.copyWith(activeSession: updatedSession);
    }
  }

  Future<bool> saveToNotion(BrainCapture capture) async {
    try {
      // This will be handled by the NotionProvider
      // Just return success for now - the actual implementation
      // will be in the UI layer where we have access to the NotionProvider
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to save to Notion: $e');
      return false;
    }
  }
}

// Specific providers for different aspects
final captureStatsProvider = Provider<CaptureStats?>((ref) {
  return ref.watch(externalBrainProvider).stats;
});

final activeCapturesProvider = Provider<List<BrainCapture>>((ref) {
  return ref.watch(externalBrainProvider).captures
      .where((c) => c.status != BrainCaptureStatus.archived)
      .toList();
});

final workingMemoryProvider = Provider<List<WorkingMemoryItem>>((ref) {
  return ref.watch(externalBrainProvider).workingMemory;
});

final a2aConnectionsProvider = Provider<List<A2AConnection>>((ref) {
  return ref.watch(externalBrainProvider).connections;
});

final contextSnapshotsProvider = Provider<List<ContextSnapshot>>((ref) {
  return ref.watch(externalBrainProvider).snapshots;
});