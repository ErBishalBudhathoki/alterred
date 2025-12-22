class BrainCapture {
  final String id;
  final String content;
  final BrainCaptureType type;
  final DateTime createdAt;
  final String? title;
  final String? category;
  final Map<String, dynamic>? metadata;
  final BrainCaptureStatus? status;
  final String? taskId;
  final List<String>? tags;
  final String? contextSnapshotId;
  final int? priority;
  final DateTime? dueDate;
  final String? assignedPartnerId;

  const BrainCapture({
    required this.id,
    required this.content,
    required this.type,
    required this.createdAt,
    this.title,
    this.category,
    this.metadata,
    this.status,
    this.taskId,
    this.tags,
    this.contextSnapshotId,
    this.priority,
    this.dueDate,
    this.assignedPartnerId,
  });

  BrainCapture copyWith({
    String? id,
    String? content,
    BrainCaptureType? type,
    DateTime? createdAt,
    String? title,
    String? category,
    Map<String, dynamic>? metadata,
    BrainCaptureStatus? status,
    String? taskId,
    List<String>? tags,
    String? contextSnapshotId,
    int? priority,
    DateTime? dueDate,
    String? assignedPartnerId,
  }) {
    return BrainCapture(
      id: id ?? this.id,
      content: content ?? this.content,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      title: title ?? this.title,
      category: category ?? this.category,
      metadata: metadata ?? this.metadata,
      status: status ?? this.status,
      taskId: taskId ?? this.taskId,
      tags: tags ?? this.tags,
      contextSnapshotId: contextSnapshotId ?? this.contextSnapshotId,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      assignedPartnerId: assignedPartnerId ?? this.assignedPartnerId,
    );
  }

  factory BrainCapture.fromJson(Map<String, dynamic> json) {
    return BrainCapture(
      id: json['id'] as String,
      content: json['content'] as String,
      type: BrainCaptureType.fromJson(json['type'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['created_at'] as String),
      title: json['title'] as String?,
      category: json['category'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      status: json['status'] != null 
          ? BrainCaptureStatus.values.firstWhere((e) => e.name == json['status'])
          : null,
      taskId: json['task_id'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>(),
      contextSnapshotId: json['context_snapshot_id'] as String?,
      priority: json['priority'] as int?,
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date'] as String) : null,
      assignedPartnerId: json['assigned_partner_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'type': type.toJson(),
      'created_at': createdAt.toIso8601String(),
      'title': title,
      'category': category,
      'metadata': metadata,
      'status': status?.name,
      'task_id': taskId,
      'tags': tags,
      'context_snapshot_id': contextSnapshotId,
      'priority': priority,
      'due_date': dueDate?.toIso8601String(),
      'assigned_partner_id': assignedPartnerId,
    };
  }
}

abstract class BrainCaptureType {
  const BrainCaptureType();

  factory BrainCaptureType.voice({
    required String transcript,
    String? audioPath,
    double? confidence,
  }) = VoiceCapture;

  factory BrainCaptureType.text({
    required String text,
  }) = TextCapture;

  factory BrainCaptureType.image({
    required String imagePath,
    String? description,
  }) = ImageCapture;

  factory BrainCaptureType.task({
    required String description,
    DateTime? dueDate,
    int? priority,
    List<String>? subtasks,
  }) = TaskCapture;

  factory BrainCaptureType.note({
    required String content,
    String? category,
  }) = NoteCapture;

  factory BrainCaptureType.reminder({
    required String message,
    required DateTime reminderTime,
    bool? recurring,
  }) = ReminderCapture;

  T when<T>({
    required T Function(String transcript, String? audioPath, double? confidence) voice,
    required T Function(String text) text,
    required T Function(String imagePath, String? description) image,
    required T Function(String description, DateTime? dueDate, int? priority, List<String>? subtasks) task,
    required T Function(String content, String? category) note,
    required T Function(String message, DateTime reminderTime, bool? recurring) reminder,
  });

  factory BrainCaptureType.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    switch (type) {
      case 'voice':
        return VoiceCapture(
          transcript: json['transcript'] as String,
          audioPath: json['audio_path'] as String?,
          confidence: json['confidence'] as double?,
        );
      case 'text':
        return TextCapture(text: json['text'] as String);
      case 'image':
        return ImageCapture(
          imagePath: json['image_path'] as String,
          description: json['description'] as String?,
        );
      case 'task':
        return TaskCapture(
          description: json['description'] as String,
          dueDate: json['due_date'] != null ? DateTime.parse(json['due_date'] as String) : null,
          priority: json['priority'] as int?,
          subtasks: (json['subtasks'] as List<dynamic>?)?.cast<String>(),
        );
      case 'note':
        return NoteCapture(
          content: json['content'] as String,
          category: json['category'] as String?,
        );
      case 'reminder':
        return ReminderCapture(
          message: json['message'] as String,
          reminderTime: DateTime.parse(json['reminder_time'] as String),
          recurring: json['recurring'] as bool?,
        );
      default:
        throw ArgumentError('Unknown BrainCaptureType: $type');
    }
  }

  Map<String, dynamic> toJson();
}

class VoiceCapture extends BrainCaptureType {
  final String transcript;
  final String? audioPath;
  final double? confidence;

  const VoiceCapture({
    required this.transcript,
    this.audioPath,
    this.confidence,
  });

  @override
  T when<T>({
    required T Function(String transcript, String? audioPath, double? confidence) voice,
    required T Function(String text) text,
    required T Function(String imagePath, String? description) image,
    required T Function(String description, DateTime? dueDate, int? priority, List<String>? subtasks) task,
    required T Function(String content, String? category) note,
    required T Function(String message, DateTime reminderTime, bool? recurring) reminder,
  }) {
    return voice(transcript, audioPath, confidence);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'voice',
      'transcript': transcript,
      'audio_path': audioPath,
      'confidence': confidence,
    };
  }
}

class TextCapture extends BrainCaptureType {
  final String text;

  const TextCapture({required this.text});

  @override
  T when<T>({
    required T Function(String transcript, String? audioPath, double? confidence) voice,
    required T Function(String text) text,
    required T Function(String imagePath, String? description) image,
    required T Function(String description, DateTime? dueDate, int? priority, List<String>? subtasks) task,
    required T Function(String content, String? category) note,
    required T Function(String message, DateTime reminderTime, bool? recurring) reminder,
  }) {
    return text(this.text);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'text',
      'text': text,
    };
  }
}

class ImageCapture extends BrainCaptureType {
  final String imagePath;
  final String? description;

  const ImageCapture({
    required this.imagePath,
    this.description,
  });

  @override
  T when<T>({
    required T Function(String transcript, String? audioPath, double? confidence) voice,
    required T Function(String text) text,
    required T Function(String imagePath, String? description) image,
    required T Function(String description, DateTime? dueDate, int? priority, List<String>? subtasks) task,
    required T Function(String content, String? category) note,
    required T Function(String message, DateTime reminderTime, bool? recurring) reminder,
  }) {
    return image(imagePath, description);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'image',
      'image_path': imagePath,
      'description': description,
    };
  }
}

class TaskCapture extends BrainCaptureType {
  final String description;
  final DateTime? dueDate;
  final int? priority;
  final List<String>? subtasks;

  const TaskCapture({
    required this.description,
    this.dueDate,
    this.priority,
    this.subtasks,
  });

  @override
  T when<T>({
    required T Function(String transcript, String? audioPath, double? confidence) voice,
    required T Function(String text) text,
    required T Function(String imagePath, String? description) image,
    required T Function(String description, DateTime? dueDate, int? priority, List<String>? subtasks) task,
    required T Function(String content, String? category) note,
    required T Function(String message, DateTime reminderTime, bool? recurring) reminder,
  }) {
    return task(description, dueDate, priority, subtasks);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'task',
      'description': description,
      'due_date': dueDate?.toIso8601String(),
      'priority': priority,
      'subtasks': subtasks,
    };
  }
}

class NoteCapture extends BrainCaptureType {
  final String content;
  final String? category;

  const NoteCapture({
    required this.content,
    this.category,
  });

  @override
  T when<T>({
    required T Function(String transcript, String? audioPath, double? confidence) voice,
    required T Function(String text) text,
    required T Function(String imagePath, String? description) image,
    required T Function(String description, DateTime? dueDate, int? priority, List<String>? subtasks) task,
    required T Function(String content, String? category) note,
    required T Function(String message, DateTime reminderTime, bool? recurring) reminder,
  }) {
    return note(content, category);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'note',
      'content': content,
      'category': category,
    };
  }
}

class ReminderCapture extends BrainCaptureType {
  final String message;
  final DateTime reminderTime;
  final bool? recurring;

  const ReminderCapture({
    required this.message,
    required this.reminderTime,
    this.recurring,
  });

  @override
  T when<T>({
    required T Function(String transcript, String? audioPath, double? confidence) voice,
    required T Function(String text) text,
    required T Function(String imagePath, String? description) image,
    required T Function(String description, DateTime? dueDate, int? priority, List<String>? subtasks) task,
    required T Function(String content, String? category) note,
    required T Function(String message, DateTime reminderTime, bool? recurring) reminder,
  }) {
    return reminder(message, reminderTime, recurring);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'reminder',
      'message': message,
      'reminder_time': reminderTime.toIso8601String(),
      'recurring': recurring,
    };
  }
}

enum BrainCaptureStatus {
  pending,
  processing,
  structured,
  completed,
  archived,
  failed,
}

class CaptureSession {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final CaptureSessionType type;
  final List<BrainCapture>? captures;
  final Map<String, dynamic>? context;
  final bool? isActive;

  const CaptureSession({
    required this.id,
    required this.startTime,
    this.endTime,
    required this.type,
    this.captures,
    this.context,
    this.isActive,
  });

  CaptureSession copyWith({
    String? id,
    DateTime? startTime,
    DateTime? endTime,
    CaptureSessionType? type,
    List<BrainCapture>? captures,
    Map<String, dynamic>? context,
    bool? isActive,
  }) {
    return CaptureSession(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      type: type ?? this.type,
      captures: captures ?? this.captures,
      context: context ?? this.context,
      isActive: isActive ?? this.isActive,
    );
  }

  factory CaptureSession.fromJson(Map<String, dynamic> json) {
    return CaptureSession(
      id: json['id'] as String,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null ? DateTime.parse(json['end_time'] as String) : null,
      type: CaptureSessionType.values.firstWhere((e) => e.name == json['type']),
      captures: (json['captures'] as List<dynamic>?)
          ?.map((e) => BrainCapture.fromJson(e as Map<String, dynamic>))
          .toList(),
      context: json['context'] as Map<String, dynamic>?,
      isActive: json['is_active'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'type': type.name,
      'captures': captures?.map((e) => e.toJson()).toList(),
      'context': context,
      'is_active': isActive,
    };
  }
}

enum CaptureSessionType {
  voice,
  manual,
  batch,
  contextual,
}

class CaptureStats {
  final int totalCaptures;
  final int todayCaptures;
  final int weekCaptures;
  final int completedTasks;
  final double completionRate;
  final Map<String, int>? capturesByType;
  final Map<String, int>? capturesByCategory;
  final DateTime? lastCaptureTime;

  const CaptureStats({
    required this.totalCaptures,
    required this.todayCaptures,
    required this.weekCaptures,
    required this.completedTasks,
    required this.completionRate,
    this.capturesByType,
    this.capturesByCategory,
    this.lastCaptureTime,
  });

  CaptureStats copyWith({
    int? totalCaptures,
    int? todayCaptures,
    int? weekCaptures,
    int? completedTasks,
    double? completionRate,
    Map<String, int>? capturesByType,
    Map<String, int>? capturesByCategory,
    DateTime? lastCaptureTime,
  }) {
    return CaptureStats(
      totalCaptures: totalCaptures ?? this.totalCaptures,
      todayCaptures: todayCaptures ?? this.todayCaptures,
      weekCaptures: weekCaptures ?? this.weekCaptures,
      completedTasks: completedTasks ?? this.completedTasks,
      completionRate: completionRate ?? this.completionRate,
      capturesByType: capturesByType ?? this.capturesByType,
      capturesByCategory: capturesByCategory ?? this.capturesByCategory,
      lastCaptureTime: lastCaptureTime ?? this.lastCaptureTime,
    );
  }

  factory CaptureStats.fromJson(Map<String, dynamic> json) {
    return CaptureStats(
      totalCaptures: json['total_captures'] as int,
      todayCaptures: json['today_captures'] as int,
      weekCaptures: json['week_captures'] as int,
      completedTasks: json['completed_tasks'] as int,
      completionRate: (json['completion_rate'] as num).toDouble(),
      capturesByType: (json['captures_by_type'] as Map<String, dynamic>?)?.cast<String, int>(),
      capturesByCategory: (json['captures_by_category'] as Map<String, dynamic>?)?.cast<String, int>(),
      lastCaptureTime: json['last_capture_time'] != null 
          ? DateTime.parse(json['last_capture_time'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_captures': totalCaptures,
      'today_captures': todayCaptures,
      'week_captures': weekCaptures,
      'completed_tasks': completedTasks,
      'completion_rate': completionRate,
      'captures_by_type': capturesByType,
      'captures_by_category': capturesByCategory,
      'last_capture_time': lastCaptureTime?.toIso8601String(),
    };
  }
}