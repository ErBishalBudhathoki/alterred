
/// Notion authentication state
enum NotionAuthState {
  disconnected,
  connecting,
  connected,
  error,
  expired,
}

/// Notion connection status
class NotionConnection {
  final NotionAuthState state;
  final String? accessToken;
  final String? workspaceName;
  final String? workspaceId;
  final String? botId;
  final DateTime? connectedAt;
  final DateTime? expiresAt;
  final String? errorMessage;
  final Map<String, dynamic> capabilities;

  const NotionConnection({
    required this.state,
    this.accessToken,
    this.workspaceName,
    this.workspaceId,
    this.botId,
    this.connectedAt,
    this.expiresAt,
    this.errorMessage,
    this.capabilities = const {},
  });

  NotionConnection copyWith({
    NotionAuthState? state,
    String? accessToken,
    String? workspaceName,
    String? workspaceId,
    String? botId,
    DateTime? connectedAt,
    DateTime? expiresAt,
    String? errorMessage,
    Map<String, dynamic>? capabilities,
  }) {
    return NotionConnection(
      state: state ?? this.state,
      accessToken: accessToken ?? this.accessToken,
      workspaceName: workspaceName ?? this.workspaceName,
      workspaceId: workspaceId ?? this.workspaceId,
      botId: botId ?? this.botId,
      connectedAt: connectedAt ?? this.connectedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      errorMessage: errorMessage ?? this.errorMessage,
      capabilities: capabilities ?? this.capabilities,
    );
  }

  bool get isConnected => state == NotionAuthState.connected && accessToken != null;
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
  bool get hasError => state == NotionAuthState.error;

  Map<String, dynamic> toJson() {
    return {
      'state': state.name,
      'access_token': accessToken,
      'workspace_name': workspaceName,
      'workspace_id': workspaceId,
      'bot_id': botId,
      'connected_at': connectedAt?.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'error_message': errorMessage,
      'capabilities': capabilities,
    };
  }

  factory NotionConnection.fromJson(Map<String, dynamic> json) {
    return NotionConnection(
      state: NotionAuthState.values.firstWhere(
        (e) => e.name == json['state'],
        orElse: () => NotionAuthState.disconnected,
      ),
      accessToken: json['access_token'],
      workspaceName: json['workspace_name'],
      workspaceId: json['workspace_id'],
      botId: json['bot_id'],
      connectedAt: json['connected_at'] != null 
          ? DateTime.parse(json['connected_at']) 
          : null,
      expiresAt: json['expires_at'] != null 
          ? DateTime.parse(json['expires_at']) 
          : null,
      errorMessage: json['error_message'],
      capabilities: Map<String, dynamic>.from(json['capabilities'] ?? {}),
    );
  }
}

/// Notion page model
class NotionPage {
  final String id;
  final String title;
  final String url;
  final DateTime createdTime;
  final DateTime lastEditedTime;
  final String? parentId;
  final String? parentType;
  final Map<String, dynamic> properties;
  final List<NotionBlock> blocks;
  final bool archived;
  final String type;
  final String excerpt;
  final bool isSynced;

  const NotionPage({
    required this.id,
    required this.title,
    required this.url,
    required this.createdTime,
    required this.lastEditedTime,
    this.parentId,
    this.parentType,
    this.properties = const {},
    this.blocks = const [],
    this.archived = false,
    this.type = 'page',
    this.excerpt = '',
    this.isSynced = false,
  });

  factory NotionPage.fromJson(Map<String, dynamic> json) {
    return NotionPage(
      id: json['id'],
      title: _extractTitle(json['properties']),
      url: json['url'],
      createdTime: DateTime.parse(json['created_time']),
      lastEditedTime: DateTime.parse(json['last_edited_time']),
      parentId: json['parent']?['page_id'] ?? json['parent']?['database_id'],
      parentType: json['parent']?['type'],
      properties: Map<String, dynamic>.from(json['properties'] ?? {}),
      archived: json['archived'] ?? false,
      type: json['object'] ?? 'page',
      excerpt: _extractExcerpt(json['properties']),
      isSynced: json['is_synced'] ?? false,
    );
  }

  static String _extractTitle(Map<String, dynamic>? properties) {
    if (properties == null) return 'Untitled';
    
    for (final prop in properties.values) {
      if (prop['type'] == 'title' && prop['title'] != null) {
        final titleArray = prop['title'] as List;
        if (titleArray.isNotEmpty) {
          return titleArray.first['plain_text'] ?? 'Untitled';
        }
      }
    }
    return 'Untitled';
  }

  static String _extractExcerpt(Map<String, dynamic>? properties) {
    if (properties == null) return '';
    
    for (final prop in properties.values) {
      if (prop['type'] == 'rich_text' && prop['rich_text'] != null) {
        final textArray = prop['rich_text'] as List;
        if (textArray.isNotEmpty) {
          final text = textArray.first['plain_text'] ?? '';
          return text.length > 100 ? '${text.substring(0, 100)}...' : text;
        }
      }
    }
    return '';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'url': url,
      'created_time': createdTime.toIso8601String(),
      'last_edited_time': lastEditedTime.toIso8601String(),
      'parent_id': parentId,
      'parent_type': parentType,
      'properties': properties,
      'blocks': blocks.map((b) => b.toJson()).toList(),
      'archived': archived,
      'object': type,
      'excerpt': excerpt,
      'is_synced': isSynced,
    };
  }
}

/// Notion database model
class NotionDatabase {
  final String id;
  final String title;
  final String url;
  final DateTime createdTime;
  final DateTime lastEditedTime;
  final Map<String, NotionProperty> properties;
  final bool archived;

  const NotionDatabase({
    required this.id,
    required this.title,
    required this.url,
    required this.createdTime,
    required this.lastEditedTime,
    this.properties = const {},
    this.archived = false,
  });

  factory NotionDatabase.fromJson(Map<String, dynamic> json) {
    final propertiesMap = <String, NotionProperty>{};
    final props = json['properties'] as Map<String, dynamic>? ?? {};
    
    for (final entry in props.entries) {
      propertiesMap[entry.key] = NotionProperty.fromJson(entry.value);
    }

    return NotionDatabase(
      id: json['id'],
      title: _extractTitle(json['title']),
      url: json['url'],
      createdTime: DateTime.parse(json['created_time']),
      lastEditedTime: DateTime.parse(json['last_edited_time']),
      properties: propertiesMap,
      archived: json['archived'] ?? false,
    );
  }

  static String _extractTitle(List<dynamic>? titleArray) {
    if (titleArray == null || titleArray.isEmpty) return 'Untitled Database';
    return titleArray.first['plain_text'] ?? 'Untitled Database';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'url': url,
      'created_time': createdTime.toIso8601String(),
      'last_edited_time': lastEditedTime.toIso8601String(),
      'properties': properties.map((k, v) => MapEntry(k, v.toJson())),
      'archived': archived,
    };
  }
}

/// Notion property model
class NotionProperty {
  final String id;
  final String name;
  final String type;
  final Map<String, dynamic> config;

  const NotionProperty({
    required this.id,
    required this.name,
    required this.type,
    this.config = const {},
  });

  factory NotionProperty.fromJson(Map<String, dynamic> json) {
    return NotionProperty(
      id: json['id'],
      name: json['name'] ?? '',
      type: json['type'],
      config: Map<String, dynamic>.from(json)..remove('id')..remove('name')..remove('type'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      ...config,
    };
  }
}

/// Notion block model
class NotionBlock {
  final String id;
  final String type;
  final DateTime createdTime;
  final DateTime lastEditedTime;
  final bool hasChildren;
  final Map<String, dynamic> content;
  final List<NotionBlock> children;

  const NotionBlock({
    required this.id,
    required this.type,
    required this.createdTime,
    required this.lastEditedTime,
    this.hasChildren = false,
    this.content = const {},
    this.children = const [],
  });

  factory NotionBlock.fromJson(Map<String, dynamic> json) {
    final childrenList = <NotionBlock>[];
    if (json['children'] != null) {
      for (final child in json['children']) {
        childrenList.add(NotionBlock.fromJson(child));
      }
    }

    return NotionBlock(
      id: json['id'],
      type: json['type'],
      createdTime: DateTime.parse(json['created_time']),
      lastEditedTime: DateTime.parse(json['last_edited_time']),
      hasChildren: json['has_children'] ?? false,
      content: Map<String, dynamic>.from(json[json['type']] ?? {}),
      children: childrenList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'created_time': createdTime.toIso8601String(),
      'last_edited_time': lastEditedTime.toIso8601String(),
      'has_children': hasChildren,
      type: content,
      'children': children.map((c) => c.toJson()).toList(),
    };
  }

  String get plainText {
    if (content['rich_text'] != null) {
      final richText = content['rich_text'] as List;
      return richText.map((rt) => rt['plain_text'] ?? '').join();
    }
    return '';
  }
}

/// Notion sync status
enum NotionSyncStatus {
  idle,
  syncing,
  success,
  error,
  conflict,
}

/// Notion sync operation
class NotionSyncOperation {
  final String id;
  final String type;
  final String operation;
  final NotionSyncStatus status;
  final DateTime timestamp;
  final String? errorMessage;
  final Map<String, dynamic> data;

  const NotionSyncOperation({
    required this.id,
    required this.type,
    required this.operation,
    required this.status,
    required this.timestamp,
    this.errorMessage,
    this.data = const {},
  });

  NotionSyncOperation copyWith({
    NotionSyncStatus? status,
    String? errorMessage,
    Map<String, dynamic>? data,
  }) {
    return NotionSyncOperation(
      id: id,
      type: type,
      operation: operation,
      status: status ?? this.status,
      timestamp: timestamp,
      errorMessage: errorMessage ?? this.errorMessage,
      data: data ?? this.data,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'operation': operation,
      'status': status.name,
      'timestamp': timestamp.toIso8601String(),
      'error_message': errorMessage,
      'data': data,
    };
  }

  factory NotionSyncOperation.fromJson(Map<String, dynamic> json) {
    return NotionSyncOperation(
      id: json['id'],
      type: json['type'],
      operation: json['operation'],
      status: NotionSyncStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => NotionSyncStatus.idle,
      ),
      timestamp: DateTime.parse(json['timestamp']),
      errorMessage: json['error_message'],
      data: Map<String, dynamic>.from(json['data'] ?? {}),
    );
  }
}

/// ADHD-specific Notion templates
enum NotionTemplate {
  dailyReflection,
  weeklyReview,
  hyperfocusSession,
  energyTracking,
  goalSetting,
  decisionLog,
  resourceLibrary,
  moodTracker,
  medicationLog,
  appointmentNotes,
  contextSnapshot,
  achievementLog,
  strategyNotes,
  sensoryEnvironment,
  transitionRitual,
}

extension NotionTemplateExtension on NotionTemplate {
  String get displayName {
    switch (this) {
      case NotionTemplate.dailyReflection:
        return 'Daily Reflection';
      case NotionTemplate.weeklyReview:
        return 'Weekly Review';
      case NotionTemplate.hyperfocusSession:
        return 'Hyperfocus Session';
      case NotionTemplate.energyTracking:
        return 'Energy Tracking';
      case NotionTemplate.goalSetting:
        return 'Goal Setting';
      case NotionTemplate.decisionLog:
        return 'Decision Log';
      case NotionTemplate.resourceLibrary:
        return 'Resource Library';
      case NotionTemplate.moodTracker:
        return 'Mood Tracker';
      case NotionTemplate.medicationLog:
        return 'Medication Log';
      case NotionTemplate.appointmentNotes:
        return 'Appointment Notes';
      case NotionTemplate.contextSnapshot:
        return 'Context Snapshot';
      case NotionTemplate.achievementLog:
        return 'Achievement Log';
      case NotionTemplate.strategyNotes:
        return 'Strategy Notes';
      case NotionTemplate.sensoryEnvironment:
        return 'Sensory Environment';
      case NotionTemplate.transitionRitual:
        return 'Transition Ritual';
    }
  }

  String get description {
    switch (this) {
      case NotionTemplate.dailyReflection:
        return 'Daily reflection and planning template';
      case NotionTemplate.weeklyReview:
        return 'Weekly review and goal adjustment';
      case NotionTemplate.hyperfocusSession:
        return 'Document hyperfocus sessions and outcomes';
      case NotionTemplate.energyTracking:
        return 'Track energy levels throughout the day';
      case NotionTemplate.goalSetting:
        return 'Set and track long-term goals';
      case NotionTemplate.decisionLog:
        return 'Log important decisions and outcomes';
      case NotionTemplate.resourceLibrary:
        return 'Collect helpful resources and strategies';
      case NotionTemplate.moodTracker:
        return 'Track mood and emotional patterns';
      case NotionTemplate.medicationLog:
        return 'Track medication and effects';
      case NotionTemplate.appointmentNotes:
        return 'Notes from appointments and meetings';
      case NotionTemplate.contextSnapshot:
        return 'Save current work context for later';
      case NotionTemplate.achievementLog:
        return 'Celebrate achievements and wins';
      case NotionTemplate.strategyNotes:
        return 'Document what works and what doesn\'t';
      case NotionTemplate.sensoryEnvironment:
        return 'Track optimal environments for focus';
      case NotionTemplate.transitionRitual:
        return 'Document transition routines';
    }
  }

  String get icon {
    switch (this) {
      case NotionTemplate.dailyReflection:
        return '📝';
      case NotionTemplate.weeklyReview:
        return '📊';
      case NotionTemplate.hyperfocusSession:
        return '🎯';
      case NotionTemplate.energyTracking:
        return '⚡';
      case NotionTemplate.goalSetting:
        return '🎯';
      case NotionTemplate.decisionLog:
        return '🤔';
      case NotionTemplate.resourceLibrary:
        return '📚';
      case NotionTemplate.moodTracker:
        return '😊';
      case NotionTemplate.medicationLog:
        return '💊';
      case NotionTemplate.appointmentNotes:
        return '📅';
      case NotionTemplate.contextSnapshot:
        return '📸';
      case NotionTemplate.achievementLog:
        return '🏆';
      case NotionTemplate.strategyNotes:
        return '💡';
      case NotionTemplate.sensoryEnvironment:
        return '🌟';
      case NotionTemplate.transitionRitual:
        return '🔄';
    }
  }
}