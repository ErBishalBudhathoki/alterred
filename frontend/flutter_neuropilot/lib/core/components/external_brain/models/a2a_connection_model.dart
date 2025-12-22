class A2AConnection {
  final String partnerId;
  final String partnerName;
  final A2AConnectionStatus status;
  final DateTime connectedAt;
  final String? partnerEmail;
  final String? partnerAvatar;
  final A2AConnectionType? connectionType;
  final Map<String, dynamic>? settings;
  final DateTime? lastActivity;
  final List<String>? sharedGoals;
  final A2AHealthStatus? healthStatus;

  const A2AConnection({
    required this.partnerId,
    required this.partnerName,
    required this.status,
    required this.connectedAt,
    this.partnerEmail,
    this.partnerAvatar,
    this.connectionType,
    this.settings,
    this.lastActivity,
    this.sharedGoals,
    this.healthStatus,
  });

  A2AConnection copyWith({
    String? partnerId,
    String? partnerName,
    A2AConnectionStatus? status,
    DateTime? connectedAt,
    String? partnerEmail,
    String? partnerAvatar,
    A2AConnectionType? connectionType,
    Map<String, dynamic>? settings,
    DateTime? lastActivity,
    List<String>? sharedGoals,
    A2AHealthStatus? healthStatus,
  }) {
    return A2AConnection(
      partnerId: partnerId ?? this.partnerId,
      partnerName: partnerName ?? this.partnerName,
      status: status ?? this.status,
      connectedAt: connectedAt ?? this.connectedAt,
      partnerEmail: partnerEmail ?? this.partnerEmail,
      partnerAvatar: partnerAvatar ?? this.partnerAvatar,
      connectionType: connectionType ?? this.connectionType,
      settings: settings ?? this.settings,
      lastActivity: lastActivity ?? this.lastActivity,
      sharedGoals: sharedGoals ?? this.sharedGoals,
      healthStatus: healthStatus ?? this.healthStatus,
    );
  }

  factory A2AConnection.fromJson(Map<String, dynamic> json) {
    return A2AConnection(
      partnerId: json['partner_id'] as String,
      partnerName: json['partner_name'] as String,
      status: A2AConnectionStatus.values.firstWhere((e) => e.name == json['status']),
      connectedAt: DateTime.parse(json['connected_at'] as String),
      partnerEmail: json['partner_email'] as String?,
      partnerAvatar: json['partner_avatar'] as String?,
      connectionType: json['connection_type'] != null 
          ? A2AConnectionType.values.firstWhere((e) => e.name == json['connection_type'])
          : null,
      settings: json['settings'] as Map<String, dynamic>?,
      lastActivity: json['last_activity'] != null 
          ? DateTime.parse(json['last_activity'] as String) 
          : null,
      sharedGoals: (json['shared_goals'] as List<dynamic>?)?.cast<String>(),
      healthStatus: json['health_status'] != null 
          ? A2AHealthStatus.values.firstWhere((e) => e.name == json['health_status'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'partner_id': partnerId,
      'partner_name': partnerName,
      'status': status.name,
      'connected_at': connectedAt.toIso8601String(),
      'partner_email': partnerEmail,
      'partner_avatar': partnerAvatar,
      'connection_type': connectionType?.name,
      'settings': settings,
      'last_activity': lastActivity?.toIso8601String(),
      'shared_goals': sharedGoals,
      'health_status': healthStatus?.name,
    };
  }
}

enum A2AConnectionStatus {
  pending,
  connected,
  disconnected,
  blocked,
  error,
}

enum A2AConnectionType {
  accountabilityPartner,
  coach,
  friend,
  colleague,
  family,
  therapist,
}

enum A2AHealthStatus {
  healthy,
  degraded,
  offline,
  error,
}

class A2AMessage {
  final String id;
  final String fromPartnerId;
  final String toPartnerId;
  final A2AMessageType type;
  final Map<String, dynamic> content;
  final DateTime timestamp;
  final A2AMessageStatus? status;
  final A2AMessagePriority? priority;
  final String? replyToId;
  final DateTime? expiresAt;

  const A2AMessage({
    required this.id,
    required this.fromPartnerId,
    required this.toPartnerId,
    required this.type,
    required this.content,
    required this.timestamp,
    this.status,
    this.priority,
    this.replyToId,
    this.expiresAt,
  });

  A2AMessage copyWith({
    String? id,
    String? fromPartnerId,
    String? toPartnerId,
    A2AMessageType? type,
    Map<String, dynamic>? content,
    DateTime? timestamp,
    A2AMessageStatus? status,
    A2AMessagePriority? priority,
    String? replyToId,
    DateTime? expiresAt,
  }) {
    return A2AMessage(
      id: id ?? this.id,
      fromPartnerId: fromPartnerId ?? this.fromPartnerId,
      toPartnerId: toPartnerId ?? this.toPartnerId,
      type: type ?? this.type,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      replyToId: replyToId ?? this.replyToId,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  factory A2AMessage.fromJson(Map<String, dynamic> json) {
    return A2AMessage(
      id: json['id'] as String,
      fromPartnerId: json['from_partner_id'] as String,
      toPartnerId: json['to_partner_id'] as String,
      type: A2AMessageType.values.firstWhere((e) => e.name == json['type']),
      content: json['content'] as Map<String, dynamic>,
      timestamp: DateTime.parse(json['timestamp'] as String),
      status: json['status'] != null 
          ? A2AMessageStatus.values.firstWhere((e) => e.name == json['status'])
          : null,
      priority: json['priority'] != null 
          ? A2AMessagePriority.values.firstWhere((e) => e.name == json['priority'])
          : null,
      replyToId: json['reply_to_id'] as String?,
      expiresAt: json['expires_at'] != null 
          ? DateTime.parse(json['expires_at'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'from_partner_id': fromPartnerId,
      'to_partner_id': toPartnerId,
      'type': type.name,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'status': status?.name,
      'priority': priority?.name,
      'reply_to_id': replyToId,
      'expires_at': expiresAt?.toIso8601String(),
    };
  }
}

enum A2AMessageType {
  taskUpdate,
  encouragement,
  checkIn,
  goalProgress,
  reminder,
  celebration,
  support,
  question,
}

enum A2AMessageStatus {
  queued,
  sent,
  delivered,
  read,
  failed,
  retrying,
}

enum A2AMessagePriority {
  low,
  normal,
  high,
  urgent,
}

class A2AUpdate {
  final String id;
  final String partnerId;
  final A2AUpdateType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final String? message;
  final bool? requiresResponse;
  final DateTime? responseDeadline;

  const A2AUpdate({
    required this.id,
    required this.partnerId,
    required this.type,
    required this.data,
    required this.timestamp,
    this.message,
    this.requiresResponse,
    this.responseDeadline,
  });

  A2AUpdate copyWith({
    String? id,
    String? partnerId,
    A2AUpdateType? type,
    Map<String, dynamic>? data,
    DateTime? timestamp,
    String? message,
    bool? requiresResponse,
    DateTime? responseDeadline,
  }) {
    return A2AUpdate(
      id: id ?? this.id,
      partnerId: partnerId ?? this.partnerId,
      type: type ?? this.type,
      data: data ?? this.data,
      timestamp: timestamp ?? this.timestamp,
      message: message ?? this.message,
      requiresResponse: requiresResponse ?? this.requiresResponse,
      responseDeadline: responseDeadline ?? this.responseDeadline,
    );
  }

  factory A2AUpdate.fromJson(Map<String, dynamic> json) {
    return A2AUpdate(
      id: json['id'] as String,
      partnerId: json['partner_id'] as String,
      type: A2AUpdateType.values.firstWhere((e) => e.name == json['type']),
      data: json['data'] as Map<String, dynamic>,
      timestamp: DateTime.parse(json['timestamp'] as String),
      message: json['message'] as String?,
      requiresResponse: json['requires_response'] as bool?,
      responseDeadline: json['response_deadline'] != null 
          ? DateTime.parse(json['response_deadline'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'partner_id': partnerId,
      'type': type.name,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      'message': message,
      'requires_response': requiresResponse,
      'response_deadline': responseDeadline?.toIso8601String(),
    };
  }
}

enum A2AUpdateType {
  taskCompleted,
  goalProgress,
  dailyCheckin,
  weeklyReview,
  milestone,
  struggle,
  breakthrough,
  moodUpdate,
}

class A2AGoal {
  final String id;
  final String title;
  final String description;
  final List<String> partnerIds;
  final DateTime createdAt;
  final DateTime? targetDate;
  final A2AGoalStatus? status;
  final List<A2AMilestone>? milestones;
  final Map<String, dynamic>? progress;
  final A2AGoalType? type;

  const A2AGoal({
    required this.id,
    required this.title,
    required this.description,
    required this.partnerIds,
    required this.createdAt,
    this.targetDate,
    this.status,
    this.milestones,
    this.progress,
    this.type,
  });

  A2AGoal copyWith({
    String? id,
    String? title,
    String? description,
    List<String>? partnerIds,
    DateTime? createdAt,
    DateTime? targetDate,
    A2AGoalStatus? status,
    List<A2AMilestone>? milestones,
    Map<String, dynamic>? progress,
    A2AGoalType? type,
  }) {
    return A2AGoal(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      partnerIds: partnerIds ?? this.partnerIds,
      createdAt: createdAt ?? this.createdAt,
      targetDate: targetDate ?? this.targetDate,
      status: status ?? this.status,
      milestones: milestones ?? this.milestones,
      progress: progress ?? this.progress,
      type: type ?? this.type,
    );
  }

  factory A2AGoal.fromJson(Map<String, dynamic> json) {
    return A2AGoal(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      partnerIds: (json['partner_ids'] as List<dynamic>).cast<String>(),
      createdAt: DateTime.parse(json['created_at'] as String),
      targetDate: json['target_date'] != null 
          ? DateTime.parse(json['target_date'] as String) 
          : null,
      status: json['status'] != null 
          ? A2AGoalStatus.values.firstWhere((e) => e.name == json['status'])
          : null,
      milestones: (json['milestones'] as List<dynamic>?)
          ?.map((e) => A2AMilestone.fromJson(e as Map<String, dynamic>))
          .toList(),
      progress: json['progress'] as Map<String, dynamic>?,
      type: json['type'] != null 
          ? A2AGoalType.values.firstWhere((e) => e.name == json['type'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'partner_ids': partnerIds,
      'created_at': createdAt.toIso8601String(),
      'target_date': targetDate?.toIso8601String(),
      'status': status?.name,
      'milestones': milestones?.map((e) => e.toJson()).toList(),
      'progress': progress,
      'type': type?.name,
    };
  }
}

enum A2AGoalStatus {
  active,
  paused,
  completed,
  abandoned,
}

enum A2AGoalType {
  habit,
  project,
  skill,
  health,
  career,
  personal,
}

class A2AMilestone {
  final String id;
  final String title;
  final DateTime targetDate;
  final A2AMilestoneStatus? status;
  final DateTime? completedAt;
  final String? completedBy;
  final String? notes;

  const A2AMilestone({
    required this.id,
    required this.title,
    required this.targetDate,
    this.status,
    this.completedAt,
    this.completedBy,
    this.notes,
  });

  A2AMilestone copyWith({
    String? id,
    String? title,
    DateTime? targetDate,
    A2AMilestoneStatus? status,
    DateTime? completedAt,
    String? completedBy,
    String? notes,
  }) {
    return A2AMilestone(
      id: id ?? this.id,
      title: title ?? this.title,
      targetDate: targetDate ?? this.targetDate,
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
      completedBy: completedBy ?? this.completedBy,
      notes: notes ?? this.notes,
    );
  }

  factory A2AMilestone.fromJson(Map<String, dynamic> json) {
    return A2AMilestone(
      id: json['id'] as String,
      title: json['title'] as String,
      targetDate: DateTime.parse(json['target_date'] as String),
      status: json['status'] != null 
          ? A2AMilestoneStatus.values.firstWhere((e) => e.name == json['status'])
          : null,
      completedAt: json['completed_at'] != null 
          ? DateTime.parse(json['completed_at'] as String) 
          : null,
      completedBy: json['completed_by'] as String?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'target_date': targetDate.toIso8601String(),
      'status': status?.name,
      'completed_at': completedAt?.toIso8601String(),
      'completed_by': completedBy,
      'notes': notes,
    };
  }
}

enum A2AMilestoneStatus {
  pending,
  inProgress,
  completed,
  overdue,
  skipped,
}

class A2AStats {
  final int totalConnections;
  final int activeConnections;
  final int messagesExchanged;
  final int goalsShared;
  final double responseRate;
  final Map<String, int>? connectionsByType;
  final Map<String, int>? messagesByType;
  final DateTime? lastActivity;

  const A2AStats({
    required this.totalConnections,
    required this.activeConnections,
    required this.messagesExchanged,
    required this.goalsShared,
    required this.responseRate,
    this.connectionsByType,
    this.messagesByType,
    this.lastActivity,
  });

  A2AStats copyWith({
    int? totalConnections,
    int? activeConnections,
    int? messagesExchanged,
    int? goalsShared,
    double? responseRate,
    Map<String, int>? connectionsByType,
    Map<String, int>? messagesByType,
    DateTime? lastActivity,
  }) {
    return A2AStats(
      totalConnections: totalConnections ?? this.totalConnections,
      activeConnections: activeConnections ?? this.activeConnections,
      messagesExchanged: messagesExchanged ?? this.messagesExchanged,
      goalsShared: goalsShared ?? this.goalsShared,
      responseRate: responseRate ?? this.responseRate,
      connectionsByType: connectionsByType ?? this.connectionsByType,
      messagesByType: messagesByType ?? this.messagesByType,
      lastActivity: lastActivity ?? this.lastActivity,
    );
  }

  factory A2AStats.fromJson(Map<String, dynamic> json) {
    return A2AStats(
      totalConnections: json['total_connections'] as int,
      activeConnections: json['active_connections'] as int,
      messagesExchanged: json['messages_exchanged'] as int,
      goalsShared: json['goals_shared'] as int,
      responseRate: (json['response_rate'] as num).toDouble(),
      connectionsByType: (json['connections_by_type'] as Map<String, dynamic>?)?.cast<String, int>(),
      messagesByType: (json['messages_by_type'] as Map<String, dynamic>?)?.cast<String, int>(),
      lastActivity: json['last_activity'] != null 
          ? DateTime.parse(json['last_activity'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_connections': totalConnections,
      'active_connections': activeConnections,
      'messages_exchanged': messagesExchanged,
      'goals_shared': goalsShared,
      'response_rate': responseRate,
      'connections_by_type': connectionsByType,
      'messages_by_type': messagesByType,
      'last_activity': lastActivity?.toIso8601String(),
    };
  }
}