class ContextSnapshot {
  final String id;
  final String taskId;
  final DateTime timestamp;
  final Map<String, dynamic> contextData;
  final String? title;
  final String? description;
  final List<String>? screenshots;
  final Map<String, String>? appStates;
  final List<ContextItem>? items;
  final ContextType? type;
  final bool? isRestored;
  final DateTime? restoredAt;

  const ContextSnapshot({
    required this.id,
    required this.taskId,
    required this.timestamp,
    required this.contextData,
    this.title,
    this.description,
    this.screenshots,
    this.appStates,
    this.items,
    this.type,
    this.isRestored,
    this.restoredAt,
  });

  ContextSnapshot copyWith({
    String? id,
    String? taskId,
    DateTime? timestamp,
    Map<String, dynamic>? contextData,
    String? title,
    String? description,
    List<String>? screenshots,
    Map<String, String>? appStates,
    List<ContextItem>? items,
    ContextType? type,
    bool? isRestored,
    DateTime? restoredAt,
  }) {
    return ContextSnapshot(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      timestamp: timestamp ?? this.timestamp,
      contextData: contextData ?? this.contextData,
      title: title ?? this.title,
      description: description ?? this.description,
      screenshots: screenshots ?? this.screenshots,
      appStates: appStates ?? this.appStates,
      items: items ?? this.items,
      type: type ?? this.type,
      isRestored: isRestored ?? this.isRestored,
      restoredAt: restoredAt ?? this.restoredAt,
    );
  }

  factory ContextSnapshot.fromJson(Map<String, dynamic> json) {
    return ContextSnapshot(
      id: json['id'] as String,
      taskId: json['task_id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      contextData: json['context_data'] as Map<String, dynamic>,
      title: json['title'] as String?,
      description: json['description'] as String?,
      screenshots: (json['screenshots'] as List<dynamic>?)?.cast<String>(),
      appStates: (json['app_states'] as Map<String, dynamic>?)?.cast<String, String>(),
      items: (json['items'] as List<dynamic>?)
          ?.map((e) => ContextItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      type: json['type'] != null 
          ? ContextType.values.firstWhere((e) => e.name == json['type'])
          : null,
      isRestored: json['is_restored'] as bool?,
      restoredAt: json['restored_at'] != null 
          ? DateTime.parse(json['restored_at'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'task_id': taskId,
      'timestamp': timestamp.toIso8601String(),
      'context_data': contextData,
      'title': title,
      'description': description,
      'screenshots': screenshots,
      'app_states': appStates,
      'items': items?.map((e) => e.toJson()).toList(),
      'type': type?.name,
      'is_restored': isRestored,
      'restored_at': restoredAt?.toIso8601String(),
    };
  }
}

class ContextItem {
  final String id;
  final String type;
  final String title;
  final String? content;
  final String? url;
  final String? appName;
  final Map<String, dynamic>? metadata;
  final int? order;
  final bool? isActive;

  const ContextItem({
    required this.id,
    required this.type,
    required this.title,
    this.content,
    this.url,
    this.appName,
    this.metadata,
    this.order,
    this.isActive,
  });

  ContextItem copyWith({
    String? id,
    String? type,
    String? title,
    String? content,
    String? url,
    String? appName,
    Map<String, dynamic>? metadata,
    int? order,
    bool? isActive,
  }) {
    return ContextItem(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      content: content ?? this.content,
      url: url ?? this.url,
      appName: appName ?? this.appName,
      metadata: metadata ?? this.metadata,
      order: order ?? this.order,
      isActive: isActive ?? this.isActive,
    );
  }

  factory ContextItem.fromJson(Map<String, dynamic> json) {
    return ContextItem(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      content: json['content'] as String?,
      url: json['url'] as String?,
      appName: json['app_name'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      order: json['order'] as int?,
      isActive: json['is_active'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'content': content,
      'url': url,
      'app_name': appName,
      'metadata': metadata,
      'order': order,
      'is_active': isActive,
    };
  }
}

enum ContextType {
  work,
  personal,
  creative,
  learning,
  meeting,
  breakTime,
  pause,
  transition,
}

class ContextRestoration {
  final String snapshotId;
  final DateTime startTime;
  final DateTime? endTime;
  final RestorationStatus status;
  final List<String>? restoredItems;
  final List<String>? failedItems;
  final String? errorMessage;
  final Map<String, dynamic>? restorationData;

  const ContextRestoration({
    required this.snapshotId,
    required this.startTime,
    this.endTime,
    required this.status,
    this.restoredItems,
    this.failedItems,
    this.errorMessage,
    this.restorationData,
  });

  ContextRestoration copyWith({
    String? snapshotId,
    DateTime? startTime,
    DateTime? endTime,
    RestorationStatus? status,
    List<String>? restoredItems,
    List<String>? failedItems,
    String? errorMessage,
    Map<String, dynamic>? restorationData,
  }) {
    return ContextRestoration(
      snapshotId: snapshotId ?? this.snapshotId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      restoredItems: restoredItems ?? this.restoredItems,
      failedItems: failedItems ?? this.failedItems,
      errorMessage: errorMessage ?? this.errorMessage,
      restorationData: restorationData ?? this.restorationData,
    );
  }

  factory ContextRestoration.fromJson(Map<String, dynamic> json) {
    return ContextRestoration(
      snapshotId: json['snapshot_id'] as String,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null ? DateTime.parse(json['end_time'] as String) : null,
      status: RestorationStatus.values.firstWhere((e) => e.name == json['status']),
      restoredItems: (json['restored_items'] as List<dynamic>?)?.cast<String>(),
      failedItems: (json['failed_items'] as List<dynamic>?)?.cast<String>(),
      errorMessage: json['error_message'] as String?,
      restorationData: json['restoration_data'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'snapshot_id': snapshotId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'status': status.name,
      'restored_items': restoredItems,
      'failed_items': failedItems,
      'error_message': errorMessage,
      'restoration_data': restorationData,
    };
  }
}

enum RestorationStatus {
  pending,
  inProgress,
  completed,
  partiallyCompleted,
  failed,
}

class WorkingMemoryItem {
  final String id;
  final String content;
  final WorkingMemoryType type;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final int? priority;
  final bool? isPinned;
  final String? category;
  final Map<String, dynamic>? metadata;

  const WorkingMemoryItem({
    required this.id,
    required this.content,
    required this.type,
    required this.createdAt,
    this.expiresAt,
    this.priority,
    this.isPinned,
    this.category,
    this.metadata,
  });

  WorkingMemoryItem copyWith({
    String? id,
    String? content,
    WorkingMemoryType? type,
    DateTime? createdAt,
    DateTime? expiresAt,
    int? priority,
    bool? isPinned,
    String? category,
    Map<String, dynamic>? metadata,
  }) {
    return WorkingMemoryItem(
      id: id ?? this.id,
      content: content ?? this.content,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      priority: priority ?? this.priority,
      isPinned: isPinned ?? this.isPinned,
      category: category ?? this.category,
      metadata: metadata ?? this.metadata,
    );
  }

  factory WorkingMemoryItem.fromJson(Map<String, dynamic> json) {
    return WorkingMemoryItem(
      id: json['id'] as String,
      content: json['content'] as String,
      type: WorkingMemoryType.values.firstWhere((e) => e.name == json['type']),
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: json['expires_at'] != null ? DateTime.parse(json['expires_at'] as String) : null,
      priority: json['priority'] as int?,
      isPinned: json['is_pinned'] as bool?,
      category: json['category'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'type': type.name,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'priority': priority,
      'is_pinned': isPinned,
      'category': category,
      'metadata': metadata,
    };
  }
}

enum WorkingMemoryType {
  quickNote,
  temporaryReminder,
  activeTask,
  reference,
  calculation,
  phoneNumber,
  address,
  code,
}

class ContextTimeline {
  final String id;
  final DateTime date;
  final List<ContextTimelineEntry> entries;
  final Map<String, int>? stats;

  const ContextTimeline({
    required this.id,
    required this.date,
    required this.entries,
    this.stats,
  });

  ContextTimeline copyWith({
    String? id,
    DateTime? date,
    List<ContextTimelineEntry>? entries,
    Map<String, int>? stats,
  }) {
    return ContextTimeline(
      id: id ?? this.id,
      date: date ?? this.date,
      entries: entries ?? this.entries,
      stats: stats ?? this.stats,
    );
  }

  factory ContextTimeline.fromJson(Map<String, dynamic> json) {
    return ContextTimeline(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      entries: (json['entries'] as List<dynamic>)
          .map((e) => ContextTimelineEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      stats: (json['stats'] as Map<String, dynamic>?)?.cast<String, int>(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'entries': entries.map((e) => e.toJson()).toList(),
      'stats': stats,
    };
  }
}

class ContextTimelineEntry {
  final String id;
  final DateTime timestamp;
  final TimelineEntryType type;
  final String title;
  final String? description;
  final String? snapshotId;
  final String? taskId;
  final Map<String, dynamic>? data;

  const ContextTimelineEntry({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.title,
    this.description,
    this.snapshotId,
    this.taskId,
    this.data,
  });

  ContextTimelineEntry copyWith({
    String? id,
    DateTime? timestamp,
    TimelineEntryType? type,
    String? title,
    String? description,
    String? snapshotId,
    String? taskId,
    Map<String, dynamic>? data,
  }) {
    return ContextTimelineEntry(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      snapshotId: snapshotId ?? this.snapshotId,
      taskId: taskId ?? this.taskId,
      data: data ?? this.data,
    );
  }

  factory ContextTimelineEntry.fromJson(Map<String, dynamic> json) {
    return ContextTimelineEntry(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      type: TimelineEntryType.values.firstWhere((e) => e.name == json['type']),
      title: json['title'] as String,
      description: json['description'] as String?,
      snapshotId: json['snapshot_id'] as String?,
      taskId: json['task_id'] as String?,
      data: json['data'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'type': type.name,
      'title': title,
      'description': description,
      'snapshot_id': snapshotId,
      'task_id': taskId,
      'data': data,
    };
  }
}

enum TimelineEntryType {
  contextSnapshot,
  taskStart,
  taskComplete,
  interruption,
  restoration,
  breakTime,
  transition,
}