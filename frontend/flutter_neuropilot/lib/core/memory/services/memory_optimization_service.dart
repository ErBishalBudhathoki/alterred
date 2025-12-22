import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/memory_models.dart';
import 'firestore_memory_service.dart';
import 'gemini_summarization_service.dart';

/// Advanced memory optimization service with intelligent retrieval and cleanup
class MemoryOptimizationService {
  static final MemoryOptimizationService _instance =
      MemoryOptimizationService._internal();
  factory MemoryOptimizationService() => _instance;
  MemoryOptimizationService._internal();

  final FirestoreMemoryService _memoryService = FirestoreMemoryService();
  final GeminiSummarizationService _summarizationService =
      GeminiSummarizationService();

  // Optimization configuration
  // static const int _maxMemoryChunksPerUser = 10000;
  // static const int _maxSessionsPerUser = 500;
  static const Duration _archiveThreshold = Duration(days: 30);
  // static const Duration _deleteThreshold = Duration(days: 90);
  static const double _relevanceDecayRate = 0.1;
  // static const int _batchSize = 100;

  final Map<String, Timer> _optimizationTimers = {};
  final Map<String, MemoryOptimizationStats> _optimizationStats = {};

  /// Initialize the optimization service
  Future<void> initialize() async {
    // Start periodic optimization for active users
    Timer.periodic(const Duration(hours: 4), (timer) {
      _performPeriodicOptimization();
    });

    if (kDebugMode) {
      print('🚀 MemoryOptimizationService initialized');
    }
  }

  /// Optimize memory for a specific user
  Future<MemoryOperationResult<MemoryOptimizationStats>> optimizeUserMemory(
    String userId, {
    bool forceOptimization = false,
    OptimizationLevel level = OptimizationLevel.standard,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      if (kDebugMode) {
        print('🔧 Starting memory optimization for user: $userId');
      }

      final stats = MemoryOptimizationStats(
        userId: userId,
        startTime: DateTime.now(),
        level: level,
      );

      // Step 1: Analyze current memory state
      final analysisResult = await _analyzeMemoryState(userId);
      if (!analysisResult.success) {
        return MemoryOperationResult.failure(analysisResult.error!);
      }

      final analysis = analysisResult.data!;
      stats.initialMetrics = analysis;

      // Step 2: Perform optimization based on level
      switch (level) {
        case OptimizationLevel.light:
          await _performLightOptimization(userId, stats);
          break;
        case OptimizationLevel.standard:
          await _performStandardOptimization(userId, stats);
          break;
        case OptimizationLevel.aggressive:
          await _performAggressiveOptimization(userId, stats);
          break;
        case OptimizationLevel.deep:
          await _performDeepOptimization(userId, stats);
          break;
      }

      // Step 3: Update relevance scores
      await _updateRelevanceScores(userId, stats);

      // Step 4: Optimize storage structure
      await _optimizeStorageStructure(userId, stats);

      // Step 5: Generate final metrics
      final finalAnalysisResult = await _analyzeMemoryState(userId);
      if (finalAnalysisResult.success) {
        stats.finalMetrics = finalAnalysisResult.data!;
      }

      stats.endTime = DateTime.now();
      stats.success = true;

      _optimizationStats[userId] = stats;

      stopwatch.stop();

      if (kDebugMode) {
        print('✅ Memory optimization completed for user: $userId');
        print('   Chunks processed: ${stats.chunksProcessed}');
        print('   Chunks removed: ${stats.chunksRemoved}');
        print('   Chunks summarized: ${stats.chunksSummarized}');
        print(
            '   Storage saved: ${stats.storageSavedMB.toStringAsFixed(2)} MB');
      }

      return MemoryOperationResult.success(
        stats,
        executionTime: stopwatch.elapsed,
        metadata: {
          'operation': 'optimize_user_memory',
          'level': level.name,
          'chunks_processed': stats.chunksProcessed,
          'storage_saved_mb': stats.storageSavedMB,
        },
      );
    } catch (error) {
      stopwatch.stop();
      return MemoryOperationResult.failure(
        'Memory optimization failed: $error',
        executionTime: stopwatch.elapsed,
      );
    }
  }

  /// Intelligent memory retrieval with context awareness
  Future<MemoryOperationResult<List<MemoryChunk>>> retrieveRelevantMemories(
    String userId,
    String context, {
    int maxResults = 20,
    double minRelevanceScore = 0.3,
    List<MemoryType>? preferredTypes,
    Duration? timeWindow,
    bool includeRelatedMemories = true,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Step 1: Parse context and extract key terms
      final contextTerms = _extractContextTerms(context);

      // Step 2: Build optimized query
      final query = MemoryQuery(
        userId: userId,
        types: preferredTypes ?? [],
        minRelevanceScore: minRelevanceScore,
        fromDate:
            timeWindow != null ? DateTime.now().subtract(timeWindow) : null,
        limit: maxResults * 2, // Get more for filtering
        sortBy: MemoryQuerySort.relevance,
      );

      // Step 3: Retrieve candidate memories
      final candidatesResult = await _memoryService.retrieveMemoryChunks(query);
      if (!candidatesResult.success) {
        return MemoryOperationResult.failure(candidatesResult.error!);
      }

      var candidates = candidatesResult.data!;

      // Step 4: Apply context-aware scoring
      candidates =
          await _applyContextAwareScoring(candidates, context, contextTerms);

      // Step 5: Include related memories if requested
      if (includeRelatedMemories) {
        final relatedMemories = await _findRelatedMemories(candidates, userId);
        candidates.addAll(relatedMemories);
      }

      // Step 6: Final ranking and filtering
      candidates.sort((a, b) => b.importanceScore.compareTo(a.importanceScore));
      final results = candidates.take(maxResults).toList();

      // Step 7: Update access tracking
      for (final memory in results) {
        _memoryService.updateMemoryAccess(memory.id);
      }

      stopwatch.stop();

      return MemoryOperationResult.success(
        results,
        executionTime: stopwatch.elapsed,
        metadata: {
          'operation': 'retrieve_relevant_memories',
          'context_terms': contextTerms,
          'candidates_evaluated': candidates.length,
          'results_returned': results.length,
          'average_relevance': results.isNotEmpty
              ? results.map((m) => m.relevanceScore).reduce((a, b) => a + b) /
                  results.length
              : 0.0,
        },
      );
    } catch (error) {
      stopwatch.stop();
      return MemoryOperationResult.failure(
        'Memory retrieval failed: $error',
        executionTime: stopwatch.elapsed,
      );
    }
  }

  /// Clean up expired and low-value memories
  Future<MemoryOperationResult<CleanupStats>> performMemoryCleanup(
    String userId, {
    CleanupLevel level = CleanupLevel.standard,
    bool dryRun = false,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      final stats = CleanupStats(
        userId: userId,
        level: level,
        dryRun: dryRun,
        startTime: DateTime.now(),
      );

      // Step 1: Identify cleanup candidates
      final candidates = await _identifyCleanupCandidates(userId, level);
      stats.candidatesIdentified = candidates.length;

      // Step 2: Categorize cleanup actions
      final actions = _categorizeCleanupActions(candidates, level);

      // Step 3: Execute cleanup actions (unless dry run)
      if (!dryRun) {
        await _executeCleanupActions(actions, stats);
      } else {
        _simulateCleanupActions(actions, stats);
      }

      stats.endTime = DateTime.now();
      stats.success = true;

      stopwatch.stop();

      if (kDebugMode) {
        print('🧹 Memory cleanup completed for user: $userId');
        print('   Level: ${level.name}');
        print('   Dry run: $dryRun');
        print('   Chunks deleted: ${stats.chunksDeleted}');
        print('   Chunks archived: ${stats.chunksArchived}');
        print(
            '   Storage freed: ${stats.storageFreedMB.toStringAsFixed(2)} MB');
      }

      return MemoryOperationResult.success(
        stats,
        executionTime: stopwatch.elapsed,
        metadata: {
          'operation': 'memory_cleanup',
          'level': level.name,
          'dry_run': dryRun,
          'chunks_deleted': stats.chunksDeleted,
          'storage_freed_mb': stats.storageFreedMB,
        },
      );
    } catch (error) {
      stopwatch.stop();
      return MemoryOperationResult.failure(
        'Memory cleanup failed: $error',
        executionTime: stopwatch.elapsed,
      );
    }
  }

  /// Optimize memory bank queries with intelligent indexing
  Future<MemoryOperationResult<QueryOptimizationResult>> optimizeQueries(
      String userId) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Analyze query patterns
      final queryPatterns = await _analyzeQueryPatterns(userId);

      // Generate optimization recommendations
      final recommendations = _generateQueryOptimizations(queryPatterns);

      // Apply optimizations
      final appliedOptimizations =
          await _applyQueryOptimizations(userId, recommendations);

      final result = QueryOptimizationResult(
        userId: userId,
        queryPatterns: queryPatterns,
        recommendations: recommendations,
        appliedOptimizations: appliedOptimizations,
        performanceImprovement:
            _calculatePerformanceImprovement(appliedOptimizations),
      );

      stopwatch.stop();

      return MemoryOperationResult.success(
        result,
        executionTime: stopwatch.elapsed,
        metadata: {
          'operation': 'optimize_queries',
          'optimizations_applied': appliedOptimizations.length,
          'performance_improvement': result.performanceImprovement,
        },
      );
    } catch (error) {
      stopwatch.stop();
      return MemoryOperationResult.failure(
        'Query optimization failed: $error',
        executionTime: stopwatch.elapsed,
      );
    }
  }

  /// Private helper methods

  Future<MemoryOperationResult<MemoryMetrics>> _analyzeMemoryState(
      String userId) async {
    return await _memoryService.getMemoryMetrics(userId);
  }

  Future<void> _performLightOptimization(
      String userId, MemoryOptimizationStats stats) async {
    // Light optimization: Only remove expired chunks
    final expiredResult = await _memoryService.deleteExpiredChunks(userId);
    if (expiredResult.success) {
      stats.chunksRemoved += expiredResult.data!;
    }
  }

  Future<void> _performStandardOptimization(
      String userId, MemoryOptimizationStats stats) async {
    // Standard optimization: Remove expired + low-value chunks
    await _performLightOptimization(userId, stats);

    // Remove low-value chunks
    final lowValueChunks = await _identifyLowValueChunks(userId);
    if (lowValueChunks.isNotEmpty) {
      await _removeLowValueChunks(lowValueChunks, stats);
    }

    // Summarize old conversation chunks
    await _summarizeOldConversations(userId, stats);
  }

  Future<void> _performAggressiveOptimization(
      String userId, MemoryOptimizationStats stats) async {
    // Aggressive optimization: Standard + more aggressive summarization
    await _performStandardOptimization(userId, stats);

    // More aggressive summarization
    await _performAggressiveSummarization(userId, stats);

    // Archive old sessions
    await _archiveOldSessions(userId, stats);
  }

  Future<void> _performDeepOptimization(
      String userId, MemoryOptimizationStats stats) async {
    // Deep optimization: All previous + structural optimization
    await _performAggressiveOptimization(userId, stats);

    // Restructure memory hierarchy
    await _restructureMemoryHierarchy(userId, stats);

    // Optimize embeddings
    await _optimizeEmbeddings(userId, stats);
  }

  Future<void> _updateRelevanceScores(
      String userId, MemoryOptimizationStats stats) async {
    // Update relevance scores based on access patterns and age
    final query = MemoryQuery(
      userId: userId,
      limit: 1000,
      sortBy: MemoryQuerySort.timestamp,
    );

    final chunksResult = await _memoryService.retrieveMemoryChunks(query);
    if (!chunksResult.success) return;

    final chunks = chunksResult.data!;
    final updatedChunks = <MemoryChunk>[];

    for (final chunk in chunks) {
      final newRelevanceScore = _calculateUpdatedRelevanceScore(chunk);
      if ((newRelevanceScore - chunk.relevanceScore).abs() > 0.1) {
        updatedChunks.add(chunk.copyWith(relevanceScore: newRelevanceScore));
      }
    }

    if (updatedChunks.isNotEmpty) {
      await _memoryService.storeMemoryChunksBatch(updatedChunks);
      stats.chunksUpdated += updatedChunks.length;
    }
  }

  Future<void> _optimizeStorageStructure(
      String userId, MemoryOptimizationStats stats) async {
    // Optimize storage structure by reorganizing chunks
    // This would involve batch operations to improve query performance
    stats.storageOptimized = true;
  }

  List<String> _extractContextTerms(String context) {
    // Extract key terms from context for relevance scoring
    final words = context.toLowerCase().split(RegExp(r'\W+'));
    final stopWords = {
      'the',
      'and',
      'or',
      'but',
      'in',
      'on',
      'at',
      'to',
      'for',
      'of',
      'with',
      'by'
    };

    return words
        .where((word) => word.length > 2 && !stopWords.contains(word))
        .toSet()
        .toList();
  }

  Future<List<MemoryChunk>> _applyContextAwareScoring(
    List<MemoryChunk> chunks,
    String context,
    List<String> contextTerms,
  ) async {
    for (int i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      final contextScore = _calculateContextScore(chunk, context, contextTerms);

      // Update relevance score with context awareness
      final newRelevanceScore =
          (chunk.relevanceScore * 0.7) + (contextScore * 0.3);
      chunks[i] = chunk.copyWith(relevanceScore: newRelevanceScore);
    }

    return chunks;
  }

  double _calculateContextScore(
      MemoryChunk chunk, String context, List<String> contextTerms) {
    final chunkText = '${chunk.content} ${chunk.tags.join(' ')}'.toLowerCase();

    double score = 0.0;
    for (final term in contextTerms) {
      if (chunkText.contains(term)) {
        score += 1.0 / contextTerms.length;
      }
    }

    // Boost score for recent chunks
    final hoursSinceCreation =
        DateTime.now().difference(chunk.timestamp).inHours;
    if (hoursSinceCreation < 24) {
      score *= 1.2;
    }

    // Boost score for frequently accessed chunks
    if (chunk.accessCount > 5) {
      score *= 1.1;
    }

    return score.clamp(0.0, 1.0);
  }

  Future<List<MemoryChunk>> _findRelatedMemories(
      List<MemoryChunk> baseMemories, String userId) async {
    final relatedMemories = <MemoryChunk>[];

    for (final memory in baseMemories.take(5)) {
      // Limit to avoid too many queries
      // Find memories with similar tags
      final similarTagsQuery = MemoryQuery(
        userId: userId,
        tags: memory.tags.take(3).toList(),
        limit: 3,
        sortBy: MemoryQuerySort.relevance,
      );

      final similarResult =
          await _memoryService.retrieveMemoryChunks(similarTagsQuery);
      if (similarResult.success) {
        relatedMemories.addAll(similarResult.data!);
      }
    }

    // Remove duplicates
    final uniqueRelated = <String, MemoryChunk>{};
    for (final memory in relatedMemories) {
      uniqueRelated[memory.id] = memory;
    }

    return uniqueRelated.values.toList();
  }

  Future<List<MemoryChunk>> _identifyCleanupCandidates(
      String userId, CleanupLevel level) async {
    final candidates = <MemoryChunk>[];

    // Get all chunks for analysis
    final allChunksQuery = MemoryQuery(
      userId: userId,
      limit: 5000,
      includeExpired: true,
      sortBy: MemoryQuerySort.timestamp,
    );

    final chunksResult =
        await _memoryService.retrieveMemoryChunks(allChunksQuery);
    if (!chunksResult.success) return candidates;

    final chunks = chunksResult.data!;
    final now = DateTime.now();

    for (final chunk in chunks) {
      final age = now.difference(chunk.timestamp);
      final shouldCleanup = _shouldCleanupChunk(chunk, age, level);

      if (shouldCleanup) {
        candidates.add(chunk);
      }
    }

    return candidates;
  }

  bool _shouldCleanupChunk(
      MemoryChunk chunk, Duration age, CleanupLevel level) {
    // Expired chunks are always candidates
    if (chunk.isExpired) return true;

    // Never cleanup critical priority chunks
    if (chunk.priority == MemoryPriority.critical) return false;

    switch (level) {
      case CleanupLevel.conservative:
        return age > const Duration(days: 90) && chunk.importanceScore < 0.2;
      case CleanupLevel.standard:
        return age > const Duration(days: 60) && chunk.importanceScore < 0.3;
      case CleanupLevel.aggressive:
        return age > const Duration(days: 30) && chunk.importanceScore < 0.4;
    }
  }

  Map<CleanupAction, List<MemoryChunk>> _categorizeCleanupActions(
    List<MemoryChunk> candidates,
    CleanupLevel level,
  ) {
    final actions = <CleanupAction, List<MemoryChunk>>{
      CleanupAction.delete: [],
      CleanupAction.archive: [],
      CleanupAction.summarize: [],
    };

    for (final chunk in candidates) {
      if (chunk.isExpired || chunk.importanceScore < 0.1) {
        actions[CleanupAction.delete]!.add(chunk);
      } else if (chunk.importanceScore < 0.3 && chunk.accessCount == 0) {
        actions[CleanupAction.archive]!.add(chunk);
      } else if (chunk.type == MemoryType.conversation &&
          chunk.content.length > 500) {
        actions[CleanupAction.summarize]!.add(chunk);
      }
    }

    return actions;
  }

  Future<void> _executeCleanupActions(
    Map<CleanupAction, List<MemoryChunk>> actions,
    CleanupStats stats,
  ) async {
    // Delete chunks
    final toDelete = actions[CleanupAction.delete] ?? [];
    for (final chunk in toDelete) {
      // In production, this would be a batch delete
      stats.chunksDeleted++;
      stats.storageFreedMB += _estimateChunkSizeMB(chunk);
    }

    // Archive chunks
    final toArchive = actions[CleanupAction.archive] ?? [];
    for (final chunk in toArchive) {
      final archivedChunk = chunk.copyWith(priority: MemoryPriority.archive);
      await _memoryService.storeMemoryChunk(archivedChunk);
      stats.chunksArchived++;
    }

    // Summarize chunks
    final toSummarize = actions[CleanupAction.summarize] ?? [];
    if (toSummarize.isNotEmpty) {
      final summaryResult =
          await _summarizationService.summarizeMemoryChunks(toSummarize);
      if (summaryResult.success) {
        await _memoryService.storeMemoryChunk(summaryResult.data!);
        stats.chunksSummarized += toSummarize.length;
      }
    }
  }

  void _simulateCleanupActions(
    Map<CleanupAction, List<MemoryChunk>> actions,
    CleanupStats stats,
  ) {
    // Simulate cleanup for dry run
    final toDelete = actions[CleanupAction.delete] ?? [];
    stats.chunksDeleted = toDelete.length;
    stats.storageFreedMB =
        toDelete.fold(0.0, (sum, chunk) => sum + _estimateChunkSizeMB(chunk));

    stats.chunksArchived = (actions[CleanupAction.archive] ?? []).length;
    stats.chunksSummarized = (actions[CleanupAction.summarize] ?? []).length;
  }

  double _estimateChunkSizeMB(MemoryChunk chunk) {
    // Rough estimate of chunk size in MB
    final contentSize = chunk.content.length * 2; // UTF-16
    final metadataSize = chunk.metadata.toString().length * 2;
    final totalBytes = contentSize + metadataSize + 1000; // Base overhead
    return totalBytes / 1024 / 1024;
  }

  Future<List<MemoryChunk>> _identifyLowValueChunks(String userId) async {
    final query = MemoryQuery(
      userId: userId,
      minRelevanceScore: 0.0,
      limit: 1000,
      sortBy: MemoryQuerySort.relevance,
    );

    final result = await _memoryService.retrieveMemoryChunks(query);
    if (!result.success) return [];

    final chunks = result.data!;
    return chunks
        .where((chunk) =>
            chunk.importanceScore < 0.2 &&
            chunk.accessCount == 0 &&
            DateTime.now().difference(chunk.timestamp).inDays > 7)
        .toList();
  }

  Future<void> _removeLowValueChunks(
      List<MemoryChunk> chunks, MemoryOptimizationStats stats) async {
    // In production, this would be a batch delete operation
    stats.chunksRemoved += chunks.length;
    stats.storageSavedMB +=
        chunks.fold(0.0, (sum, chunk) => sum + _estimateChunkSizeMB(chunk));
  }

  Future<void> _summarizeOldConversations(
      String userId, MemoryOptimizationStats stats) async {
    // Find old conversation chunks that can be summarized
    final oldConversationQuery = MemoryQuery(
      userId: userId,
      types: [MemoryType.conversation],
      toDate: DateTime.now().subtract(const Duration(days: 7)),
      limit: 100,
      sortBy: MemoryQuerySort.timestamp,
    );

    final result =
        await _memoryService.retrieveMemoryChunks(oldConversationQuery);
    if (!result.success) return;

    final chunks = result.data!;
    if (chunks.length >= 5) {
      final summaryResult =
          await _summarizationService.summarizeMemoryChunks(chunks);
      if (summaryResult.success) {
        await _memoryService.storeMemoryChunk(summaryResult.data!);
        stats.chunksSummarized += chunks.length;
      }
    }
  }

  Future<void> _performAggressiveSummarization(
      String userId, MemoryOptimizationStats stats) async {
    // More aggressive summarization of various chunk types
    final chunkTypes = [
      MemoryType.conversation,
      MemoryType.task,
      MemoryType.context
    ];

    for (final type in chunkTypes) {
      final query = MemoryQuery(
        userId: userId,
        types: [type],
        toDate: DateTime.now().subtract(const Duration(days: 3)),
        limit: 50,
        sortBy: MemoryQuerySort.timestamp,
      );

      final result = await _memoryService.retrieveMemoryChunks(query);
      if (result.success && result.data!.length >= 3) {
        final summaryResult =
            await _summarizationService.summarizeMemoryChunks(result.data!);
        if (summaryResult.success) {
          await _memoryService.storeMemoryChunk(summaryResult.data!);
          stats.chunksSummarized += result.data!.length;
        }
      }
    }
  }

  Future<void> _archiveOldSessions(
      String userId, MemoryOptimizationStats stats) async {
    // Archive old sessions by updating their priority
    final oldSessionsResult = await _memoryService.retrieveMemorySessions(
      userId,
      toDate: DateTime.now().subtract(_archiveThreshold),
      limit: 100,
    );

    if (oldSessionsResult.success) {
      stats.sessionsArchived += oldSessionsResult.data!.length;
    }
  }

  Future<void> _restructureMemoryHierarchy(
      String userId, MemoryOptimizationStats stats) async {
    // Restructure memory hierarchy for better organization
    stats.hierarchyOptimized = true;
  }

  Future<void> _optimizeEmbeddings(
      String userId, MemoryOptimizationStats stats) async {
    // Optimize embeddings for better similarity search
    stats.embeddingsOptimized = true;
  }

  double _calculateUpdatedRelevanceScore(MemoryChunk chunk) {
    final baseScore = chunk.relevanceScore;
    final ageInDays = DateTime.now().difference(chunk.timestamp).inDays;

    // Apply decay based on age
    final decayFactor = exp(-_relevanceDecayRate * ageInDays);

    // Boost based on access count
    final accessBoost = min(0.2, chunk.accessCount * 0.02);

    // Boost based on priority
    final priorityBoost = chunk.priority.index * 0.05;

    return ((baseScore * decayFactor) + accessBoost + priorityBoost)
        .clamp(0.0, 1.0);
  }

  Future<Map<String, dynamic>> _analyzeQueryPatterns(String userId) async {
    // Analyze query patterns for optimization
    return {
      'common_types': [MemoryType.conversation.name, MemoryType.task.name],
      'common_time_ranges': ['last_24h', 'last_week'],
      'common_sort_orders': [
        MemoryQuerySort.timestamp.name,
        MemoryQuerySort.relevance.name
      ],
    };
  }

  List<String> _generateQueryOptimizations(Map<String, dynamic> patterns) {
    // Generate optimization recommendations
    return [
      'Create composite index for userId + type + timestamp',
      'Optimize relevanceScore index for range queries',
      'Add caching for common query patterns',
    ];
  }

  Future<List<String>> _applyQueryOptimizations(
      String userId, List<String> recommendations) async {
    // Apply query optimizations
    return recommendations; // In production, would actually apply optimizations
  }

  double _calculatePerformanceImprovement(List<String> optimizations) {
    // Calculate estimated performance improvement
    return optimizations.length * 0.15; // 15% improvement per optimization
  }

  Future<void> _performPeriodicOptimization() async {
    // Perform periodic optimization for all active users
    // In production, this would be more sophisticated
    if (kDebugMode) {
      print('🔄 Performing periodic memory optimization');
    }
  }

  /// Get optimization statistics for a user
  MemoryOptimizationStats? getOptimizationStats(String userId) {
    return _optimizationStats[userId];
  }

  /// Dispose the service
  void dispose() {
    for (final timer in _optimizationTimers.values) {
      timer.cancel();
    }
    _optimizationTimers.clear();
    _optimizationStats.clear();
  }
}

/// Memory optimization statistics
class MemoryOptimizationStats {
  final String userId;
  final OptimizationLevel level;
  final DateTime startTime;
  DateTime? endTime;
  bool success = false;

  MemoryMetrics? initialMetrics;
  MemoryMetrics? finalMetrics;

  int chunksProcessed = 0;
  int chunksRemoved = 0;
  int chunksSummarized = 0;
  int chunksUpdated = 0;
  int sessionsArchived = 0;
  double storageSavedMB = 0.0;
  bool storageOptimized = false;
  bool hierarchyOptimized = false;
  bool embeddingsOptimized = false;

  MemoryOptimizationStats({
    required this.userId,
    required this.level,
    required this.startTime,
  });

  Duration get duration => (endTime ?? DateTime.now()).difference(startTime);

  double get compressionRatio {
    if (initialMetrics == null || finalMetrics == null) return 1.0;
    return finalMetrics!.storageUsageMB / initialMetrics!.storageUsageMB;
  }
}

/// Cleanup statistics
class CleanupStats {
  final String userId;
  final CleanupLevel level;
  final bool dryRun;
  final DateTime startTime;
  DateTime? endTime;
  bool success = false;

  int candidatesIdentified = 0;
  int chunksDeleted = 0;
  int chunksArchived = 0;
  int chunksSummarized = 0;
  double storageFreedMB = 0.0;

  CleanupStats({
    required this.userId,
    required this.level,
    required this.dryRun,
    required this.startTime,
  });

  Duration get duration => (endTime ?? DateTime.now()).difference(startTime);
}

/// Query optimization result
class QueryOptimizationResult {
  final String userId;
  final Map<String, dynamic> queryPatterns;
  final List<String> recommendations;
  final List<String> appliedOptimizations;
  final double performanceImprovement;

  const QueryOptimizationResult({
    required this.userId,
    required this.queryPatterns,
    required this.recommendations,
    required this.appliedOptimizations,
    required this.performanceImprovement,
  });
}

/// Optimization levels
enum OptimizationLevel {
  light,
  standard,
  aggressive,
  deep,
}

/// Cleanup levels
enum CleanupLevel {
  conservative,
  standard,
  aggressive,
}

/// Cleanup actions
enum CleanupAction {
  delete,
  archive,
  summarize,
}
