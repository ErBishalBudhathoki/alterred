import 'package:cloud_firestore/cloud_firestore.dart';

/// Core memory chunk representing a piece of contextual information
class MemoryChunk {
  final String id;
  final String userId;
  final String sessionId;
  final MemoryType type;
  final String content;
  final Map<String, dynamic> metadata;
  final List<String> tags;
  final double relevanceScore;
  final double attentionWeight;
  final DateTime timestamp;
  final DateTime? expiresAt;
  final int accessCount;
  final DateTime lastAccessed;
  final String? parentChunkId;
  final List<String> childChunkIds;
  final MemoryPriority priority;
  final Map<String, double> embeddings;

  const MemoryChunk({
    required this.id,
    required this.userId,
    required this.sessionId,
    required this.type,
    required this.content,
    this.metadata = const {},
    this.tags = const [],
    this.relevanceScore = 0.0,
    this.attentionWeight = 1.0,
    required this.timestamp,
    this.expiresAt,
    this.accessCount = 0,
    required this.lastAccessed,
    this.parentChunkId,
    this.childChunkIds = const [],
    this.priority = MemoryPriority.normal,
    this.embeddings = const {},
  });

  /// Create from Firestore document
  factory MemoryChunk.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MemoryChunk(
      id: doc.id,
      userId: data['userId'] as String,
      sessionId: data['sessionId'] as String,
      type: MemoryType.values.firstWhere((e) => e.name == data['type']),
      content: data['content'] as String,
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
      tags: List<String>.from(data['tags'] ?? []),
      relevanceScore: (data['relevanceScore'] as num?)?.toDouble() ?? 0.0,
      attentionWeight: (data['attentionWeight'] as num?)?.toDouble() ?? 1.0,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      expiresAt: data['expiresAt'] != null ? (data['expiresAt'] as Timestamp).toDate() : null,
      accessCount: data['accessCount'] as int? ?? 0,
      lastAccessed: (data['lastAccessed'] as Timestamp).toDate(),
      parentChunkId: data['parentChunkId'] as String?,
      childChunkIds: List<String>.from(data['childChunkIds'] ?? []),
      priority: MemoryPriority.values.firstWhere(
        (e) => e.name == data['priority'],
        orElse: () => MemoryPriority.normal,
      ),
      embeddings: Map<String, double>.from(data['embeddings'] ?? {}),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'sessionId': sessionId,
      'type': type.name,
      'content': content,
      'metadata': metadata,
      'tags': tags,
      'relevanceScore': relevanceScore,
      'attentionWeight': attentionWeight,
      'timestamp': Timestamp.fromDate(timestamp),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'accessCount': accessCount,
      'lastAccessed': Timestamp.fromDate(lastAccessed),
      'parentChunkId': parentChunkId,
      'childChunkIds': childChunkIds,
      'priority': priority.name,
      'embeddings': embeddings,
    };
  }

  /// Create a copy with updated fields
  MemoryChunk copyWith({
    String? id,
    String? userId,
    String? sessionId,
    MemoryType? type,
    String? content,
    Map<String, dynamic>? metadata,
    List<String>? tags,
    double? relevanceScore,
    double? attentionWeight,
    DateTime? timestamp,
    DateTime? expiresAt,
    int? accessCount,
    DateTime? lastAccessed,
    String? parentChunkId,
    List<String>? childChunkIds,
    MemoryPriority? priority,
    Map<String, double>? embeddings,
  }) {
    return MemoryChunk(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      sessionId: sessionId ?? this.sessionId,
      type: type ?? this.type,
      content: content ?? this.content,
      metadata: metadata ?? this.metadata,
      tags: tags ?? this.tags,
      relevanceScore: relevanceScore ?? this.relevanceScore,
      attentionWeight: attentionWeight ?? this.attentionWeight,
      timestamp: timestamp ?? this.timestamp,
      expiresAt: expiresAt ?? this.expiresAt,
      accessCount: accessCount ?? this.accessCount,
      lastAccessed: lastAccessed ?? this.lastAccessed,
      parentChunkId: parentChunkId ?? this.parentChunkId,
      childChunkIds: childChunkIds ?? this.childChunkIds,
      priority: priority ?? this.priority,
      embeddings: embeddings ?? this.embeddings,
    );
  }

  /// Check if memory chunk is expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Calculate memory importance score
  double get importanceScore {
    final recencyFactor = _calculateRecencyFactor();
    final accessFactor = _calculateAccessFactor();
    final priorityFactor = _calculatePriorityFactor();
    
    return (relevanceScore * 0.4) + 
           (attentionWeight * 0.3) + 
           (recencyFactor * 0.15) + 
           (accessFactor * 0.1) + 
           (priorityFactor * 0.05);
  }

  double _calculateRecencyFactor() {
    final hoursSinceCreation = DateTime.now().difference(timestamp).inHours;
    if (hoursSinceCreation < 1) return 1.0;
    if (hoursSinceCreation < 24) return 0.8;
    if (hoursSinceCreation < 168) return 0.6; // 1 week
    if (hoursSinceCreation < 720) return 0.4; // 1 month
    return 0.2;
  }

  double _calculateAccessFactor() {
    if (accessCount == 0) return 0.0;
    if (accessCount < 5) return 0.3;
    if (accessCount < 15) return 0.6;
    if (accessCount < 50) return 0.8;
    return 1.0;
  }

  double _calculatePriorityFactor() {
    switch (priority) {
      case MemoryPriority.critical:
        return 1.0;
      case MemoryPriority.high:
        return 0.8;
      case MemoryPriority.normal:
        return 0.5;
      case MemoryPriority.low:
        return 0.3;
      case MemoryPriority.archive:
        return 0.1;
    }
  }
}

/// Memory session representing a continuous interaction period
class MemorySession {
  final String id;
  final String userId;
  final String title;
  final DateTime startTime;
  final DateTime? endTime;
  final SessionType type;
  final Map<String, dynamic> context;
  final List<String> chunkIds;
  final SessionSummary? summary;
  final double attentionScore;
  final int interruptionCount;
  final Duration totalDuration;
  final Map<String, dynamic> adhdMetrics;

  const MemorySession({
    required this.id,
    required this.userId,
    required this.title,
    required this.startTime,
    this.endTime,
    required this.type,
    this.context = const {},
    this.chunkIds = const [],
    this.summary,
    this.attentionScore = 0.0,
    this.interruptionCount = 0,
    this.totalDuration = Duration.zero,
    this.adhdMetrics = const {},
  });

  factory MemorySession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MemorySession(
      id: doc.id,
      userId: data['userId'] as String,
      title: data['title'] as String,
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: data['endTime'] != null ? (data['endTime'] as Timestamp).toDate() : null,
      type: SessionType.values.firstWhere((e) => e.name == data['type']),
      context: Map<String, dynamic>.from(data['context'] ?? {}),
      chunkIds: List<String>.from(data['chunkIds'] ?? []),
      summary: data['summary'] != null ? SessionSummary.fromMap(data['summary']) : null,
      attentionScore: (data['attentionScore'] as num?)?.toDouble() ?? 0.0,
      interruptionCount: data['interruptionCount'] as int? ?? 0,
      totalDuration: Duration(milliseconds: data['totalDurationMs'] as int? ?? 0),
      adhdMetrics: Map<String, dynamic>.from(data['adhdMetrics'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'type': type.name,
      'context': context,
      'chunkIds': chunkIds,
      'summary': summary?.toMap(),
      'attentionScore': attentionScore,
      'interruptionCount': interruptionCount,
      'totalDurationMs': totalDuration.inMilliseconds,
      'adhdMetrics': adhdMetrics,
    };
  }

  MemorySession copyWith({
    String? id,
    String? userId,
    String? title,
    DateTime? startTime,
    DateTime? endTime,
    SessionType? type,
    Map<String, dynamic>? context,
    List<String>? chunkIds,
    SessionSummary? summary,
    double? attentionScore,
    int? interruptionCount,
    Duration? totalDuration,
    Map<String, dynamic>? adhdMetrics,
  }) {
    return MemorySession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      type: type ?? this.type,
      context: context ?? this.context,
      chunkIds: chunkIds ?? this.chunkIds,
      summary: summary ?? this.summary,
      attentionScore: attentionScore ?? this.attentionScore,
      interruptionCount: interruptionCount ?? this.interruptionCount,
      totalDuration: totalDuration ?? this.totalDuration,
      adhdMetrics: adhdMetrics ?? this.adhdMetrics,
    );
  }

  bool get isActive => endTime == null;
  
  Duration get actualDuration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }
}

/// Session summary for efficient context retrieval
class SessionSummary {
  final String keyPoints;
  final List<String> mainTopics;
  final Map<String, dynamic> outcomes;
  final double completionScore;
  final List<String> importantDecisions;
  final Map<String, dynamic> contextCarryover;

  const SessionSummary({
    required this.keyPoints,
    this.mainTopics = const [],
    this.outcomes = const {},
    this.completionScore = 0.0,
    this.importantDecisions = const [],
    this.contextCarryover = const {},
  });

  factory SessionSummary.fromMap(Map<String, dynamic> map) {
    return SessionSummary(
      keyPoints: map['keyPoints'] as String,
      mainTopics: List<String>.from(map['mainTopics'] ?? []),
      outcomes: Map<String, dynamic>.from(map['outcomes'] ?? {}),
      completionScore: (map['completionScore'] as num?)?.toDouble() ?? 0.0,
      importantDecisions: List<String>.from(map['importantDecisions'] ?? []),
      contextCarryover: Map<String, dynamic>.from(map['contextCarryover'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'keyPoints': keyPoints,
      'mainTopics': mainTopics,
      'outcomes': outcomes,
      'completionScore': completionScore,
      'importantDecisions': importantDecisions,
      'contextCarryover': contextCarryover,
    };
  }
}

/// Context window for managing conversation context
class ContextWindow {
  final String id;
  final String sessionId;
  final List<MemoryChunk> chunks;
  final int maxTokens;
  final int currentTokens;
  final double compressionRatio;
  final DateTime lastCompaction;
  final Map<String, dynamic> compactionMetadata;

  const ContextWindow({
    required this.id,
    required this.sessionId,
    this.chunks = const [],
    this.maxTokens = 8000,
    this.currentTokens = 0,
    this.compressionRatio = 1.0,
    required this.lastCompaction,
    this.compactionMetadata = const {},
  });

  bool get needsCompaction => currentTokens > (maxTokens * 0.8);
  bool get isFull => currentTokens >= maxTokens;
  double get utilizationRatio => currentTokens / maxTokens;
}

/// Memory retrieval query
class MemoryQuery {
  final String userId;
  final String? sessionId;
  final List<MemoryType> types;
  final List<String> tags;
  final String? searchText;
  final DateTime? fromDate;
  final DateTime? toDate;
  final MemoryPriority? minPriority;
  final double? minRelevanceScore;
  final int limit;
  final MemoryQuerySort sortBy;
  final bool includeExpired;
  final Map<String, dynamic> contextFilters;

  const MemoryQuery({
    required this.userId,
    this.sessionId,
    this.types = const [],
    this.tags = const [],
    this.searchText,
    this.fromDate,
    this.toDate,
    this.minPriority,
    this.minRelevanceScore,
    this.limit = 50,
    this.sortBy = MemoryQuerySort.relevance,
    this.includeExpired = false,
    this.contextFilters = const {},
  });
}

/// Memory optimization metrics
class MemoryMetrics {
  final int totalChunks;
  final int activeChunks;
  final int expiredChunks;
  final double averageRelevanceScore;
  final double storageUsageMB;
  final int totalSessions;
  final int activeSessions;
  final double compressionRatio;
  final Duration averageRetrievalTime;
  final Map<MemoryType, int> chunksByType;
  final Map<MemoryPriority, int> chunksByPriority;

  const MemoryMetrics({
    this.totalChunks = 0,
    this.activeChunks = 0,
    this.expiredChunks = 0,
    this.averageRelevanceScore = 0.0,
    this.storageUsageMB = 0.0,
    this.totalSessions = 0,
    this.activeSessions = 0,
    this.compressionRatio = 1.0,
    this.averageRetrievalTime = Duration.zero,
    this.chunksByType = const {},
    this.chunksByPriority = const {},
  });
}

/// Enums for memory system
enum MemoryType {
  conversation,
  task,
  decision,
  context,
  summary,
  insight,
  reminder,
  hyperfocus,
  interruption,
  energy,
  calendar,
  external,
}

enum MemoryPriority {
  critical,
  high,
  normal,
  low,
  archive,
}

enum SessionType {
  chat,
  voice,
  task,
  planning,
  hyperfocus,
  pause,
  decision,
  mixed,
}

enum MemoryQuerySort {
  relevance,
  timestamp,
  importance,
  accessCount,
  priority,
}

/// Memory operation result
class MemoryOperationResult<T> {
  final bool success;
  final T? data;
  final String? error;
  final Duration executionTime;
  final Map<String, dynamic> metadata;

  const MemoryOperationResult({
    required this.success,
    this.data,
    this.error,
    this.executionTime = Duration.zero,
    this.metadata = const {},
  });

  factory MemoryOperationResult.success(T data, {Duration? executionTime, Map<String, dynamic>? metadata}) {
    return MemoryOperationResult(
      success: true,
      data: data,
      executionTime: executionTime ?? Duration.zero,
      metadata: metadata ?? {},
    );
  }

  factory MemoryOperationResult.failure(String error, {Duration? executionTime, Map<String, dynamic>? metadata}) {
    return MemoryOperationResult(
      success: false,
      error: error,
      executionTime: executionTime ?? Duration.zero,
      metadata: metadata ?? {},
    );
  }
}