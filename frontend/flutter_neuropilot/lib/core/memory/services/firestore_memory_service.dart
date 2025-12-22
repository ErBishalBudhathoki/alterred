import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/memory_models.dart';

/// Firestore-based memory service with optimized queries and batch operations
class FirestoreMemoryService {
  static final FirestoreMemoryService _instance =
      FirestoreMemoryService._internal();
  factory FirestoreMemoryService() => _instance;
  FirestoreMemoryService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, Timer> _cleanupTimers = {};
  final Map<String, List<MemoryChunk>> _cache = {};
  static const int _cacheSize = 1000;
  // static const Duration _cacheExpiry = Duration(minutes: 15); // Unused

  // Collection references
  CollectionReference get _memoryChunks =>
      _firestore.collection('memory_chunks');
  CollectionReference get _memorySessions =>
      _firestore.collection('memory_sessions');
  // CollectionReference get _contextWindows => _firestore.collection('context_windows'); // Unused

  /// Initialize the memory service
  Future<void> initialize() async {
    try {
      // Set up Firestore settings for optimal performance
      _firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      // Create indexes if they don't exist (in production, these should be created via Firebase Console)
      await _ensureIndexes();

      // Start cleanup timer
      _startCleanupTimer();

      if (kDebugMode) {
        print('🧠 FirestoreMemoryService initialized successfully');
      }
    } catch (error) {
      if (kDebugMode) {
        print('❌ Failed to initialize FirestoreMemoryService: $error');
      }
      rethrow;
    }
  }

  /// Store a memory chunk
  Future<MemoryOperationResult<MemoryChunk>> storeMemoryChunk(
      MemoryChunk chunk) async {
    final stopwatch = Stopwatch()..start();

    try {
      final docRef =
          chunk.id.isEmpty ? _memoryChunks.doc() : _memoryChunks.doc(chunk.id);

      final chunkWithId =
          chunk.id.isEmpty ? chunk.copyWith(id: docRef.id) : chunk;

      await docRef.set(chunkWithId.toFirestore());

      // Update cache
      _updateCache(chunkWithId.userId, chunkWithId);

      stopwatch.stop();

      return MemoryOperationResult.success(
        chunkWithId,
        executionTime: stopwatch.elapsed,
        metadata: {'operation': 'store_chunk', 'chunk_id': chunkWithId.id},
      );
    } catch (error) {
      stopwatch.stop();
      return MemoryOperationResult.failure(
        'Failed to store memory chunk: $error',
        executionTime: stopwatch.elapsed,
      );
    }
  }

  /// Store multiple memory chunks in batch
  Future<MemoryOperationResult<List<MemoryChunk>>> storeMemoryChunksBatch(
      List<MemoryChunk> chunks) async {
    final stopwatch = Stopwatch()..start();

    try {
      final batch = _firestore.batch();
      final chunksWithIds = <MemoryChunk>[];

      for (final chunk in chunks) {
        final docRef = chunk.id.isEmpty
            ? _memoryChunks.doc()
            : _memoryChunks.doc(chunk.id);

        final chunkWithId =
            chunk.id.isEmpty ? chunk.copyWith(id: docRef.id) : chunk;

        batch.set(docRef, chunkWithId.toFirestore());
        chunksWithIds.add(chunkWithId);
      }

      await batch.commit();

      // Update cache for all chunks
      for (final chunk in chunksWithIds) {
        _updateCache(chunk.userId, chunk);
      }

      stopwatch.stop();

      return MemoryOperationResult.success(
        chunksWithIds,
        executionTime: stopwatch.elapsed,
        metadata: {
          'operation': 'batch_store',
          'chunk_count': chunksWithIds.length
        },
      );
    } catch (error) {
      stopwatch.stop();
      return MemoryOperationResult.failure(
        'Failed to store memory chunks batch: $error',
        executionTime: stopwatch.elapsed,
      );
    }
  }

  /// Retrieve memory chunks with optimized query
  Future<MemoryOperationResult<List<MemoryChunk>>> retrieveMemoryChunks(
      MemoryQuery query) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Check cache first
      final cachedResults = _getCachedResults(query);
      if (cachedResults != null) {
        stopwatch.stop();
        return MemoryOperationResult.success(
          cachedResults,
          executionTime: stopwatch.elapsed,
          metadata: {'operation': 'retrieve_cached', 'cache_hit': true},
        );
      }

      Query firestoreQuery =
          _memoryChunks.where('userId', isEqualTo: query.userId);

      // Apply filters
      if (query.sessionId != null) {
        firestoreQuery =
            firestoreQuery.where('sessionId', isEqualTo: query.sessionId);
      }

      if (query.types.isNotEmpty) {
        firestoreQuery = firestoreQuery.where('type',
            whereIn: query.types.map((t) => t.name).toList());
      }

      if (query.minPriority != null) {
        final priorityValues = MemoryPriority.values
            .where((p) => p.index >= query.minPriority!.index)
            .map((p) => p.name)
            .toList();
        firestoreQuery =
            firestoreQuery.where('priority', whereIn: priorityValues);
      }

      if (query.minRelevanceScore != null) {
        firestoreQuery = firestoreQuery.where('relevanceScore',
            isGreaterThanOrEqualTo: query.minRelevanceScore);
      }

      if (query.fromDate != null) {
        firestoreQuery = firestoreQuery.where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(query.fromDate!));
      }

      if (query.toDate != null) {
        firestoreQuery = firestoreQuery.where('timestamp',
            isLessThanOrEqualTo: Timestamp.fromDate(query.toDate!));
      }

      if (!query.includeExpired) {
        firestoreQuery = firestoreQuery
            .where('expiresAt', isNull: true)
            .where('expiresAt', isGreaterThan: Timestamp.now());
      }

      // Apply sorting
      switch (query.sortBy) {
        case MemoryQuerySort.timestamp:
          firestoreQuery =
              firestoreQuery.orderBy('timestamp', descending: true);
          break;
        case MemoryQuerySort.relevance:
          firestoreQuery =
              firestoreQuery.orderBy('relevanceScore', descending: true);
          break;
        case MemoryQuerySort.importance:
          // Note: importance is calculated, so we'll sort by relevance and calculate later
          firestoreQuery =
              firestoreQuery.orderBy('relevanceScore', descending: true);
          break;
        case MemoryQuerySort.accessCount:
          firestoreQuery =
              firestoreQuery.orderBy('accessCount', descending: true);
          break;
        case MemoryQuerySort.priority:
          firestoreQuery =
              firestoreQuery.orderBy('priority', descending: false);
          break;
      }

      firestoreQuery = firestoreQuery.limit(query.limit);

      final querySnapshot = await firestoreQuery.get();
      final chunks = querySnapshot.docs
          .map((doc) => MemoryChunk.fromFirestore(doc))
          .toList();

      // Apply additional filtering that couldn't be done in Firestore
      final filteredChunks = _applyAdditionalFilters(chunks, query);

      // Sort by importance if requested (requires calculation)
      if (query.sortBy == MemoryQuerySort.importance) {
        filteredChunks
            .sort((a, b) => b.importanceScore.compareTo(a.importanceScore));
      }

      // Update cache
      _cacheResults(query, filteredChunks);

      stopwatch.stop();

      return MemoryOperationResult.success(
        filteredChunks,
        executionTime: stopwatch.elapsed,
        metadata: {
          'operation': 'retrieve_query',
          'cache_hit': false,
          'result_count': filteredChunks.length,
          'query_filters': _getQueryFiltersMetadata(query),
        },
      );
    } catch (error) {
      stopwatch.stop();
      return MemoryOperationResult.failure(
        'Failed to retrieve memory chunks: $error',
        executionTime: stopwatch.elapsed,
      );
    }
  }

  /// Update memory chunk access tracking
  Future<MemoryOperationResult<MemoryChunk>> updateMemoryAccess(
      String chunkId) async {
    final stopwatch = Stopwatch()..start();

    try {
      final docRef = _memoryChunks.doc(chunkId);

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        if (!doc.exists) {
          throw Exception('Memory chunk not found');
        }

        final chunk = MemoryChunk.fromFirestore(doc);
        final updatedChunk = chunk.copyWith(
          accessCount: chunk.accessCount + 1,
          lastAccessed: DateTime.now(),
        );

        transaction.update(docRef, {
          'accessCount': updatedChunk.accessCount,
          'lastAccessed': Timestamp.fromDate(updatedChunk.lastAccessed),
        });

        return updatedChunk;
      });

      stopwatch.stop();

      // Get updated chunk
      final updatedDoc = await docRef.get();
      final updatedChunk = MemoryChunk.fromFirestore(updatedDoc);

      // Update cache
      _updateCache(updatedChunk.userId, updatedChunk);

      return MemoryOperationResult.success(
        updatedChunk,
        executionTime: stopwatch.elapsed,
        metadata: {'operation': 'update_access', 'chunk_id': chunkId},
      );
    } catch (error) {
      stopwatch.stop();
      return MemoryOperationResult.failure(
        'Failed to update memory access: $error',
        executionTime: stopwatch.elapsed,
      );
    }
  }

  /// Store memory session
  Future<MemoryOperationResult<MemorySession>> storeMemorySession(
      MemorySession session) async {
    final stopwatch = Stopwatch()..start();

    try {
      final docRef = session.id.isEmpty
          ? _memorySessions.doc()
          : _memorySessions.doc(session.id);

      final sessionWithId = session.id.isEmpty
          ? MemorySession(
              id: docRef.id,
              userId: session.userId,
              title: session.title,
              startTime: session.startTime,
              endTime: session.endTime,
              type: session.type,
              context: session.context,
              chunkIds: session.chunkIds,
              summary: session.summary,
              attentionScore: session.attentionScore,
              interruptionCount: session.interruptionCount,
              totalDuration: session.totalDuration,
              adhdMetrics: session.adhdMetrics,
            )
          : session;

      await docRef.set(sessionWithId.toFirestore());

      stopwatch.stop();

      return MemoryOperationResult.success(
        sessionWithId,
        executionTime: stopwatch.elapsed,
        metadata: {
          'operation': 'store_session',
          'session_id': sessionWithId.id
        },
      );
    } catch (error) {
      stopwatch.stop();
      return MemoryOperationResult.failure(
        'Failed to store memory session: $error',
        executionTime: stopwatch.elapsed,
      );
    }
  }

  /// Retrieve memory sessions
  Future<MemoryOperationResult<List<MemorySession>>> retrieveMemorySessions(
    String userId, {
    SessionType? type,
    DateTime? fromDate,
    DateTime? toDate,
    bool activeOnly = false,
    int limit = 50,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      Query query = _memorySessions.where('userId', isEqualTo: userId);

      if (type != null) {
        query = query.where('type', isEqualTo: type.name);
      }

      if (activeOnly) {
        query = query.where('endTime', isNull: true);
      }

      if (fromDate != null) {
        query = query.where('startTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(fromDate));
      }

      if (toDate != null) {
        query = query.where('startTime',
            isLessThanOrEqualTo: Timestamp.fromDate(toDate));
      }

      query = query.orderBy('startTime', descending: true).limit(limit);

      final querySnapshot = await query.get();
      final sessions = querySnapshot.docs
          .map((doc) => MemorySession.fromFirestore(doc))
          .toList();

      stopwatch.stop();

      return MemoryOperationResult.success(
        sessions,
        executionTime: stopwatch.elapsed,
        metadata: {
          'operation': 'retrieve_sessions',
          'result_count': sessions.length,
          'active_only': activeOnly,
        },
      );
    } catch (error) {
      stopwatch.stop();
      return MemoryOperationResult.failure(
        'Failed to retrieve memory sessions: $error',
        executionTime: stopwatch.elapsed,
      );
    }
  }

  /// Delete expired memory chunks
  Future<MemoryOperationResult<int>> deleteExpiredChunks(String userId) async {
    final stopwatch = Stopwatch()..start();

    try {
      final now = Timestamp.now();
      final query = _memoryChunks
          .where('userId', isEqualTo: userId)
          .where('expiresAt', isLessThan: now);

      final querySnapshot = await query.get();
      final batch = _firestore.batch();

      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      // Clear cache for this user
      _cache.remove(userId);

      stopwatch.stop();

      return MemoryOperationResult.success(
        querySnapshot.docs.length,
        executionTime: stopwatch.elapsed,
        metadata: {
          'operation': 'delete_expired',
          'deleted_count': querySnapshot.docs.length
        },
      );
    } catch (error) {
      stopwatch.stop();
      return MemoryOperationResult.failure(
        'Failed to delete expired chunks: $error',
        executionTime: stopwatch.elapsed,
      );
    }
  }

  /// Get memory metrics for a user
  Future<MemoryOperationResult<MemoryMetrics>> getMemoryMetrics(
      String userId) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Get chunk statistics
      final chunksQuery = _memoryChunks.where('userId', isEqualTo: userId);
      final chunksSnapshot = await chunksQuery.get();

      final chunks = chunksSnapshot.docs
          .map((doc) => MemoryChunk.fromFirestore(doc))
          .toList();
      final activeChunks = chunks.where((c) => !c.isExpired).toList();
      final expiredChunks = chunks.where((c) => c.isExpired).toList();

      // Get session statistics
      final sessionsQuery = _memorySessions.where('userId', isEqualTo: userId);
      final sessionsSnapshot = await sessionsQuery.get();

      final sessions = sessionsSnapshot.docs
          .map((doc) => MemorySession.fromFirestore(doc))
          .toList();
      final activeSessions = sessions.where((s) => s.isActive).toList();

      // Calculate metrics
      final averageRelevanceScore = chunks.isNotEmpty
          ? chunks.map((c) => c.relevanceScore).reduce((a, b) => a + b) /
              chunks.length
          : 0.0;

      final chunksByType = <MemoryType, int>{};
      final chunksByPriority = <MemoryPriority, int>{};

      for (final chunk in chunks) {
        chunksByType[chunk.type] = (chunksByType[chunk.type] ?? 0) + 1;
        chunksByPriority[chunk.priority] =
            (chunksByPriority[chunk.priority] ?? 0) + 1;
      }

      // Estimate storage usage (rough calculation)
      final storageUsageMB = chunks.fold<double>(0.0, (previousValue, chunk) {
        return previousValue +
            (chunk.content.length * 2 / 1024 / 1024); // Rough UTF-16 estimate
      });

      stopwatch.stop();

      final metrics = MemoryMetrics(
        totalChunks: chunks.length,
        activeChunks: activeChunks.length,
        expiredChunks: expiredChunks.length,
        averageRelevanceScore: averageRelevanceScore,
        storageUsageMB: storageUsageMB,
        totalSessions: sessions.length,
        activeSessions: activeSessions.length,
        compressionRatio: 1.0, // Will be calculated by compression service
        averageRetrievalTime: stopwatch.elapsed,
        chunksByType: chunksByType,
        chunksByPriority: chunksByPriority,
      );

      return MemoryOperationResult.success(
        metrics,
        executionTime: stopwatch.elapsed,
        metadata: {'operation': 'get_metrics'},
      );
    } catch (error) {
      stopwatch.stop();
      return MemoryOperationResult.failure(
        'Failed to get memory metrics: $error',
        executionTime: stopwatch.elapsed,
      );
    }
  }

  /// Search memory chunks with text similarity
  Future<MemoryOperationResult<List<MemoryChunk>>> searchMemoryChunks(
    String userId,
    String searchText, {
    List<MemoryType>? types,
    int limit = 20,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      // For now, use simple text search. In production, this would use vector embeddings
      Query query = _memoryChunks.where('userId', isEqualTo: userId);

      if (types != null && types.isNotEmpty) {
        query = query.where('type', whereIn: types.map((t) => t.name).toList());
      }

      final querySnapshot = await query.get();
      final allChunks = querySnapshot.docs
          .map((doc) => MemoryChunk.fromFirestore(doc))
          .toList();

      // Simple text matching (in production, use vector similarity)
      final searchTerms = searchText.toLowerCase().split(' ');
      final matchingChunks = allChunks.where((chunk) {
        final content = chunk.content.toLowerCase();
        final tags = chunk.tags.map((t) => t.toLowerCase()).join(' ');
        final searchableText = '$content $tags';

        return searchTerms.any((term) => searchableText.contains(term));
      }).toList();

      // Sort by relevance (simple term frequency for now)
      matchingChunks.sort((a, b) {
        final aScore = _calculateTextRelevance(
            '${a.content} ${a.tags.join(' ')}', searchText);
        final bScore = _calculateTextRelevance(
            '${b.content} ${b.tags.join(' ')}', searchText);
        return bScore.compareTo(aScore);
      });

      final results = matchingChunks.take(limit).toList();

      stopwatch.stop();

      return MemoryOperationResult.success(
        results,
        executionTime: stopwatch.elapsed,
        metadata: {
          'operation': 'search_chunks',
          'search_text': searchText,
          'result_count': results.length,
        },
      );
    } catch (error) {
      stopwatch.stop();
      return MemoryOperationResult.failure(
        'Failed to search memory chunks: $error',
        executionTime: stopwatch.elapsed,
      );
    }
  }

  /// Private helper methods

  Future<void> _ensureIndexes() async {
    // In production, these indexes should be created via Firebase Console
    // This is just for documentation of required indexes
    if (kDebugMode) {
      print('📋 Required Firestore indexes:');
      print('  - memory_chunks: userId, type, timestamp');
      print('  - memory_chunks: userId, sessionId, timestamp');
      print('  - memory_chunks: userId, priority, relevanceScore');
      print('  - memory_chunks: userId, expiresAt');
      print('  - memory_sessions: userId, type, startTime');
      print('  - memory_sessions: userId, endTime');
    }
  }

  void _startCleanupTimer() {
    Timer.periodic(const Duration(hours: 6), (timer) {
      _performAutomaticCleanup();
    });
  }

  Future<void> _performAutomaticCleanup() async {
    try {
      // Clean up expired chunks for all users (in production, this should be a Cloud Function)
      final expiredQuery = _memoryChunks
          .where('expiresAt', isLessThan: Timestamp.now())
          .limit(100);

      final expiredSnapshot = await expiredQuery.get();

      if (expiredSnapshot.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in expiredSnapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        if (kDebugMode) {
          print(
              '🧹 Cleaned up ${expiredSnapshot.docs.length} expired memory chunks');
        }
      }

      // Clear old cache entries
      _cache.clear();
    } catch (error) {
      if (kDebugMode) {
        print('❌ Automatic cleanup failed: $error');
      }
    }
  }

  void _updateCache(String userId, MemoryChunk chunk) {
    final userCache = _cache[userId] ?? [];

    // Remove existing chunk with same ID
    userCache.removeWhere((c) => c.id == chunk.id);

    // Add new chunk
    userCache.add(chunk);

    // Limit cache size
    if (userCache.length > _cacheSize) {
      userCache.removeRange(0, userCache.length - _cacheSize);
    }

    _cache[userId] = userCache;
  }

  List<MemoryChunk>? _getCachedResults(MemoryQuery query) {
    final userCache = _cache[query.userId];
    if (userCache == null) return null;

    // Simple cache hit for basic queries (in production, implement more sophisticated caching)
    if (query.sessionId != null || query.searchText != null) return null;

    return userCache
        .where((chunk) {
          if (query.types.isNotEmpty && !query.types.contains(chunk.type)) {
            return false;
          }
          if (query.minPriority != null &&
              chunk.priority.index < query.minPriority!.index) {
            return false;
          }
          if (query.minRelevanceScore != null &&
              chunk.relevanceScore < query.minRelevanceScore!) {
            return false;
          }
          if (!query.includeExpired && chunk.isExpired) return false;
          return true;
        })
        .take(query.limit)
        .toList();
  }

  void _cacheResults(MemoryQuery query, List<MemoryChunk> results) {
    // Simple caching strategy - cache results for basic queries
    if (query.sessionId == null && query.searchText == null) {
      for (final chunk in results) {
        _updateCache(query.userId, chunk);
      }
    }
  }

  List<MemoryChunk> _applyAdditionalFilters(
      List<MemoryChunk> chunks, MemoryQuery query) {
    return chunks.where((chunk) {
      // Apply tag filtering
      if (query.tags.isNotEmpty) {
        final hasMatchingTag =
            query.tags.any((tag) => chunk.tags.contains(tag));
        if (!hasMatchingTag) return false;
      }

      // Apply context filters
      for (final entry in query.contextFilters.entries) {
        final contextValue = chunk.metadata[entry.key];
        if (contextValue != entry.value) return false;
      }

      return true;
    }).toList();
  }

  Map<String, dynamic> _getQueryFiltersMetadata(MemoryQuery query) {
    return {
      'session_id': query.sessionId,
      'types': query.types.map((t) => t.name).toList(),
      'tags': query.tags,
      'search_text': query.searchText,
      'min_priority': query.minPriority?.name,
      'min_relevance_score': query.minRelevanceScore,
      'limit': query.limit,
      'sort_by': query.sortBy.name,
      'include_expired': query.includeExpired,
    };
  }

  double _calculateTextRelevance(String text, String searchText) {
    final textLower = text.toLowerCase();
    final searchLower = searchText.toLowerCase();
    final searchTerms = searchLower.split(' ');

    double score = 0.0;
    for (final term in searchTerms) {
      final occurrences = term.allMatches(textLower).length;
      score += occurrences * (term.length / searchText.length);
    }

    return score;
  }

  /// Dispose the service
  void dispose() {
    for (final timer in _cleanupTimers.values) {
      timer.cancel();
    }
    _cleanupTimers.clear();
    _cache.clear();
  }
}
