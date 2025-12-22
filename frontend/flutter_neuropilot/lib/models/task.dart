class Task {
  final String? id;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final String priority; // low, medium, high, critical
  final String status; // pending, completed, cancelled
  final String effort; // low, medium, high
  final DateTime? createdAt;

  Task({
    this.id,
    required this.title,
    this.description,
    this.dueDate,
    this.priority = 'medium',
    this.status = 'pending',
    this.effort = 'medium',
    this.createdAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
      priority: json['priority'] ?? 'medium',
      status: json['status'] ?? 'pending',
      effort: json['effort'] ?? 'medium',
      createdAt:
          json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      if (description != null) 'description': description,
      if (dueDate != null) 'dueDate': dueDate!.toIso8601String(),
      'priority': priority,
      'status': status,
      'effort': effort,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }

  Task copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dueDate,
    String? priority,
    String? status,
    String? effort,
    DateTime? createdAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      effort: effort ?? this.effort,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
