import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/memory_models.dart';
import 'firestore_memory_service.dart';
import 'gemini_summarization_service.dart';

/// Context compaction service for managing long conversation sessions
class ContextCompactionService {
  static final ContextCompactionService _instance = ContextCompactionService._internal();
  factory ContextCompactionService() => _instance;
  ContextCompactionService._internal();

  final FirestoreMemoryService _memoryService = FirestoreMemoryService();
  final GeminiSummarizationService _summarizationService = GeminiSummarizationService();
  
  // Configuration constants
  static const int _maxContextTokens = 8000;
  static const int _targetContextTokens = 6000;
  static const double _compressionRatio = 0.3;
  static const int _minChunksForCompaction = 10;
  static const Duration _compactionCooldown = Duration(minutes: 5);
  
  final Map<String, DateTime> _lastCompactionTime = {};
  final Map<String, ContextWindow> _activeWindows = {};

  /// Initialize the context compaction service
  Future<void> initialize() async {
    if (kDebugMode) {
      print('🗜️ ContextCompactionService initialized');
    }
  }

  /// Get or create context window for a session
  Future<MemoryOperationResult<ContextWindow>> getContextWindow(String sessionId) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // Check if we have an active window
      if (_activeWindows.containsKey(sessionId)) {
        stopwatch.stop();
        return MemoryOperationResult.success(
          _activeWindows[sessionId]!,
          executionTime: stopwatch.elapsed,
          metadata: {'operation': 'get_cached_window'},
        );
      }

      // Load session chunks
      final chunksResult = await _memoryService.retrieveMemoryChunks(
        MemoryQuery(
          userId: 'current_user', // Would come from session context
          sessionId: sessionId,
          sortBy: MemoryQuerySort.timestamp,
          limit: 200,
        ),
      );

      if (!chunksResult.success) {
        return MemoryOperationResult.failure(
          'Failed to load session chunks: ${chunksResult.error}',
          executionTime: stopwatch.elapsed,
        );
      }

      final chunks = chunksResult.data!;
      final currentTokens = _calculateTokenCount(chunks);

      final contextWindow = ContextWindow(
        id: 'window_$sessionId',
        sessionId: sessionId,
        chunks: chunks,
        maxTokens: _maxContextTokens,
        currentTokens: currentTokens,
        compressionRatio: 1.0,
        lastCompaction: DateTime.now(),
      );

      _activeWindows[sessionId] = contextWindow;
      
      stopwatch.stop();
      
      return MemoryOperationResult.success(
        contextWindow,
        executionTime: stopwatch.elapsed,
        metadata: {
          'operation': 'create_window',
          'chunk_count': chunks.length,
          'token_count': currentTokens,
        },
      );
    } catch (error) {
      stopwatch.stop();
      return MemoryOperationResult.failure(
        'Failed to get context window: $error',
        executionTime: stopwatch.elapsed,
      );
    }
  }

  /// Add new memory chunk to context window
  Future<MemoryOperationResult<ContextWindow>> addToContextWindow(
    String sessionId,
    MemoryChunk chunk,
  ) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final windowResult = await getContextWindow(sessionId);
      if (!windowResult.success) {
        return MemoryOperationResult.failure(
          windowResult.error!,
          executionTime: stopwatch.elapsed,
        );
      }

      final window = windowResult.data!;
      final newChunks = [...window.chunks, chunk];
      final newTokenCount = window.currentTokens + _estimateTokenCount(chunk.content);

      var updatedWindow = ContextWindow(
        id: window.id,
        sessionId: window.sessionId,
        chunks: newChunks,
        maxTokens: window.maxTokens,
        currentTokens: newTokenCount,
        compressionRatio: window.compressionRatio,
        lastCompaction: window.lastCompaction,
        compactionMetadata: window.compactionMetadata,
      );

      // Check if compaction is needed
      if (updatedWindow.needsCompaction) {
        final compactionResult = await _performCompaction(updatedWindow);
        if (compactionResult.success) {
          updatedWindow = compactionResult.data!;
        }
      }

      _activeWindows[sessionId] = updatedWindow;
      
      stopwatch.stop();
      
      return MemoryOperationResult.success(
        updatedWindow,
        executionTime: stopwatch.elapsed,
        metadata: {
          'operation': 'add_to_window',
          'new_token_count': updatedWindow.currentTokens,
          'compaction_performed': updatedWindow.lastCompaction.isAfter(window.lastCompaction),
        },
      );
    } catch (error) {
      stopwatch.stop();
      return MemoryOperationResult.failure(
        'Failed to add to context window: $error',
        executionTime: stopwatch.elapsed,
      );
    }
  }

  /// Perform context compaction on a window
  Future<MemoryOperationResult<ContextWindow>> compactContextWindow(String sessionId) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final windowResult = await getContextWindow(sessionId);
      if (!windowResult.success) {
        return MemoryOperationResult.failure(
          windowResult.error!,
          executionTime: stopwatch.elapsed,
        );
      }

      final window = windowResult.data!;
      
      // Check cooldown
      final lastCompaction = _lastCompactionTime[sessionId];
      if (lastCompaction != null && 
          DateTime.now().difference(lastCompaction) < _compactionCooldown) {
        return MemoryOperationResult.failure(
          'Compaction cooldown active',
          executionTime: stopwatch.elapsed,
        );
      }

      final compactionResult = await _performCompaction(window);
      if (!compactionResult.success) {
        return MemoryOperationResult.failure(
          compactionResult.error!,
          executionTime: stopwatch.elapsed,
        );
      }

      final compactedWindow = compactionResult.data!;
      _activeWindows[sessionId] = compactedWindow;
      _lastCompactionTime[sessionId] = DateTime.now();
      
      stopwatch.stop();
      
      return MemoryOperationResult.success(
        compactedWindow,
        executionTime: stopwatch.elapsed,
        metadata: {
          'operation': 'compact_window',
          'original_chunks': window.chunks.length,
          'compacted_chunks': compactedWindow.chunks.length,
          'original_tokens': window.currentTokens,
          'compacted_tokens': compactedWindow.currentTokens,
          'compression_ratio': compactedWindow.compressionRatio,
        },
      );
    } catch (error) {
      stopwatch.stop();
      return MemoryOperationResult.failure(
        'Failed to compact context window: $error',
        executionTime: stopwatch.elapsed,
      );
    }
  }

  /// Perform the actual compaction logic
  Future<MemoryOperationResult<ContextWindow>> _performCompaction(ContextWindow window) async {
    try {
      if (window.chunks.length < _minChunksForCompaction) {
        return MemoryOperationResult.success(window);
      }

      // Strategy 1: Remove low-importance chunks
      final compactionStrategy = _selectCompactionStrategy(window);
      
      switch (compactionStrategy) {
        case CompactionStrategy.removeOldest:
          return await _compactByRemovingOldest(window);
        case CompactionStrategy.removeLowImportance:
          return await _compactByImportance(window);
        case CompactionStrategy.summarizeOldChunks:
          return await _compactBySummarization(window);
        case CompactionStrategy.hierarchicalCompression:
          return await _compactHierarchically(window);
      }
    } catch (error) {
      return MemoryOperationResult.failure('Compaction failed: $error');
    }
  }

  /// Select the best compaction strategy based on context
  CompactionStrategy _selectCompactionStrategy(ContextWindow window) {
    final chunks = window.chunks;
    final avgImportance = chunks.map((c) => c.importanceScore).reduce((a, b) => a + b) / chunks.length;
    final hasLowImportanceChunks = chunks.any((c) => c.importanceScore < avgImportance * 0.5);
    final hasOldChunks = chunks.any((c) => DateTime.now().difference(c.timestamp).inHours > 24);
    
    // Decision tree for strategy selection
    if (hasLowImportanceChunks && chunks.length > 20) {
      return CompactionStrategy.removeLowImportance;
    } else if (hasOldChunks && chunks.length > 15) {
      return CompactionStrategy.summarizeOldChunks;
    } else if (chunks.length > 30) {
      return CompactionStrategy.hierarchicalCompression;
    } else {
      return CompactionStrategy.removeOldest;
    }
  }

  /// Compact by removing oldest chunks
  Future<MemoryOperationResult<ContextWindow>> _compactByRemovingOldest(ContextWindow window) async {
    final chunks = List<MemoryChunk>.from(window.chunks);
    chunks.sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Newest first
    
    final targetChunkCount = (chunks.length * _compressionRatio).round();
    final keptChunks = chunks.take(chunks.length - targetChunkCount).toList();
    
    final newTokenCount = _calculateTokenCount(keptChunks);
    final compressionRatio = newTokenCount / window.currentTokens;
    
    final compactedWindow = ContextWindow(
      id: window.id,
      sessionId: window.sessionId,
      chunks: keptChunks,
      maxTokens: window.maxTokens,
      currentTokens: newTokenCount,
      compressionRatio: compressionRatio,
      lastCompaction: DateTime.now(),
      compactionMetadata: {
        'strategy': 'remove_oldest',
        'removed_chunks': chunks.length - keptChunks.length,
        'compression_ratio': compressionRatio,
      },
    );
    
    return MemoryOperationResult.success(compactedWindow);
  }

  /// Compact by removing low-importance chunks
  Future<MemoryOperationResult<ContextWindow>> _compactByImportance(ContextWindow window) async {
    final chunks = List<MemoryChunk>.from(window.chunks);
    chunks.sort((a, b) => b.importanceScore.compareTo(a.importanceScore)); // Highest importance first
    
    int currentTokens = 0;
    final keptChunks = <MemoryChunk>[];
    
    for (final chunk in chunks) {
      final chunkTokens = _estimateTokenCount(chunk.content);
      if (currentTokens + chunkTokens <= _targetContextTokens) {
        keptChunks.add(chunk);
        currentTokens += chunkTokens;
      }
    }
    
    // Sort back to chronological order
    keptChunks.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    final compressionRatio = currentTokens / window.currentTokens;
    
    final compactedWindow = ContextWindow(
      id: window.id,
      sessionId: window.sessionId,
      chunks: keptChunks,
      maxTokens: window.maxTokens,
      currentTokens: currentTokens,
      compressionRatio: compressionRatio,
      lastCompaction: DateTime.now(),
      compactionMetadata: {
        'strategy': 'remove_low_importance',
        'removed_chunks': chunks.length - keptChunks.length,
        'compression_ratio': compressionRatio,
        'importance_threshold': keptChunks.isNotEmpty ? keptChunks.last.importanceScore : 0.0,
      },
    );
    
    return MemoryOperationResult.success(compactedWindow);
  }

  /// Compact by summarizing old chunks
  Future<MemoryOperationResult<ContextWindow>> _compactBySummarization(ContextWindow window) async {
    final chunks = List<MemoryChunk>.from(window.chunks);
    chunks.sort((a, b) => a.timestamp.compareTo(b.timestamp)); // Oldest first
    
    final cutoffTime = DateTime.now().subtract(const Duration(hours: 12));
    final oldChunks = chunks.where((c) => c.timestamp.isBefore(cutoffTime)).toList();
    final recentChunks = chunks.where((c) => c.timestamp.isAfter(cutoffTime)).toList();
    
    if (oldChunks.isEmpty) {
      return MemoryOperationResult.success(window);
    }

    // Group old chunks by topic/type for better summarization
    final groupedChunks = _groupChunksForSummarization(oldChunks);
    final summaryChunks = <MemoryChunk>[];
    
    for (final group in groupedChunks) {
      final summaryResult = await _summarizationService.summarizeMemoryChunks(
        group,
        maxLength: 200,
        preserveImportantDetails: true,
      );
      
      if (summaryResult.success && summaryResult.data != null) {
        summaryChunks.add(summaryResult.data!);
      } else {
        // If summarization fails, keep the most important chunks from the group
        group.sort((a, b) => b.importanceScore.compareTo(a.importanceScore));
        summaryChunks.addAll(group.take(2));
      }
    }
    
    final finalChunks = [...summaryChunks, ...recentChunks];
    finalChunks.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    final newTokenCount = _calculateTokenCount(finalChunks);
    final compressionRatio = newTokenCount / window.currentTokens;
    
    final compactedWindow = ContextWindow(
      id: window.id,
      sessionId: window.sessionId,
      chunks: finalChunks,
      maxTokens: window.maxTokens,
      currentTokens: newTokenCount,
      compressionRatio: compressionRatio,
      lastCompaction: DateTime.now(),
      compactionMetadata: {
        'strategy': 'summarize_old_chunks',
        'original_chunks': chunks.length,
        'old_chunks_summarized': oldChunks.length,
        'summary_chunks_created': summaryChunks.length,
        'compression_ratio': compressionRatio,
      },
    );
    
    return MemoryOperationResult.success(compactedWindow);
  }

  /// Compact using hierarchical compression
  Future<MemoryOperationResult<ContextWindow>> _compactHierarchically(ContextWindow window) async {
    final chunks = List<MemoryChunk>.from(window.chunks);
    
    // Create hierarchy: Recent (keep all) -> Medium (summarize) -> Old (aggressive compression)
    final now = DateTime.now();
    final recentChunks = chunks.where((c) => now.difference(c.timestamp).inHours < 2).toList();
    final mediumChunks = chunks.where((c) {
      final hours = now.difference(c.timestamp).inHours;
      return hours >= 2 && hours < 12;
    }).toList();
    final oldChunks = chunks.where((c) => now.difference(c.timestamp).inHours >= 12).toList();
    
    final finalChunks = <MemoryChunk>[];
    
    // Keep all recent chunks
    finalChunks.addAll(recentChunks);
    
    // Compress medium chunks by importance
    if (mediumChunks.isNotEmpty) {
      mediumChunks.sort((a, b) => b.importanceScore.compareTo(a.importanceScore));
      final mediumToKeep = (mediumChunks.length * 0.6).round();
      finalChunks.addAll(mediumChunks.take(mediumToKeep));
    }
    
    // Aggressively compress old chunks
    if (oldChunks.isNotEmpty) {
      oldChunks.sort((a, b) => b.importanceScore.compareTo(a.importanceScore));
      final oldToKeep = max(1, (oldChunks.length * 0.2).round());
      finalChunks.addAll(oldChunks.take(oldToKeep));
    }
    
    // Sort back to chronological order
    finalChunks.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    final newTokenCount = _calculateTokenCount(finalChunks);
    final compressionRatio = newTokenCount / window.currentTokens;
    
    final compactedWindow = ContextWindow(
      id: window.id,
      sessionId: window.sessionId,
      chunks: finalChunks,
      maxTokens: window.maxTokens,
      currentTokens: newTokenCount,
      compressionRatio: compressionRatio,
      lastCompaction: DateTime.now(),
      compactionMetadata: {
        'strategy': 'hierarchical_compression',
        'recent_chunks': recentChunks.length,
        'medium_chunks_kept': mediumChunks.isNotEmpty ? (mediumChunks.length * 0.6).round() : 0,
        'old_chunks_kept': oldChunks.isNotEmpty ? max(1, (oldChunks.length * 0.2).round()) : 0,
        'compression_ratio': compressionRatio,
      },
    );
    
    return MemoryOperationResult.success(compactedWindow);
  }

  /// Group chunks for better summarization
  List<List<MemoryChunk>> _groupChunksForSummarization(List<MemoryChunk> chunks) {
    final groups = <String, List<MemoryChunk>>{};
    
    for (final chunk in chunks) {
      // Group by type and similar tags
      final groupKey = '${chunk.type.name}_${chunk.tags.take(2).join('_')}';
      groups[groupKey] ??= [];
      groups[groupKey]!.add(chunk);
    }
    
    // Merge small groups
    final finalGroups = <List<MemoryChunk>>[];
    final smallGroups = <MemoryChunk>[];
    
    for (final group in groups.values) {
      if (group.length >= 3) {
        finalGroups.add(group);
      } else {
        smallGroups.addAll(group);
      }
    }
    
    if (smallGroups.isNotEmpty) {
      finalGroups.add(smallGroups);
    }
    
    return finalGroups;
  }

  /// Calculate token count for a list of chunks
  int _calculateTokenCount(List<MemoryChunk> chunks) {
    return chunks.fold(0, (sum, chunk) => sum + _estimateTokenCount(chunk.content));
  }

  /// Estimate token count for text (rough approximation)
  int _estimateTokenCount(String text) {
    // Rough approximation: 1 token ≈ 4 characters for English text
    return (text.length / 4).ceil();
  }

  /// Get compaction statistics for a session
  Future<MemoryOperationResult<Map<String, dynamic>>> getCompactionStats(String sessionId) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final window = _activeWindows[sessionId];
      if (window == null) {
        return MemoryOperationResult.failure('No active window for session');
      }
      
      final stats = {
        'session_id': sessionId,
        'current_chunks': window.chunks.length,
        'current_tokens': window.currentTokens,
        'max_tokens': window.maxTokens,
        'utilization_ratio': window.utilizationRatio,
        'compression_ratio': window.compressionRatio,
        'last_compaction': window.lastCompaction.toIso8601String(),
        'needs_compaction': window.needsCompaction,
        'is_full': window.isFull,
        'compaction_metadata': window.compactionMetadata,
      };
      
      stopwatch.stop();
      
      return MemoryOperationResult.success(
        stats,
        executionTime: stopwatch.elapsed,
        metadata: {'operation': 'get_compaction_stats'},
      );
    } catch (error) {
      stopwatch.stop();
      return MemoryOperationResult.failure(
        'Failed to get compaction stats: $error',
        executionTime: stopwatch.elapsed,
      );
    }
  }

  /// Clear context window (useful for session end)
  void clearContextWindow(String sessionId) {
    _activeWindows.remove(sessionId);
    _lastCompactionTime.remove(sessionId);
  }

  /// Dispose the service
  void dispose() {
    _activeWindows.clear();
    _lastCompactionTime.clear();
  }
}

/// Compaction strategies
enum CompactionStrategy {
  removeOldest,
  removeLowImportance,
  summarizeOldChunks,
  hierarchicalCompression,
}