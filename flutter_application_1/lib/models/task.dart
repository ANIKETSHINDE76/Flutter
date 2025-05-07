enum TaskPriority { low, medium, high }

class Task {
  final String id;
  final String name;
  final String? description;
  final TaskPriority priority;
  final DateTime dueDate;
  final Duration estimatedDuration;
  final bool isCompleted;
  final DateTime createdAt;

  Task({
    required this.id,
    required this.name,
    this.description,
    required this.priority,
    required this.dueDate,
    required this.estimatedDuration,
    this.isCompleted = false,
    required this.createdAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      priority: TaskPriority.values.firstWhere(
        (e) => e.toString() == 'TaskPriority.${json['priority']}',
      ),
      dueDate: DateTime.parse(json['due_date'] as String),
      estimatedDuration: Duration(minutes: json['estimated_duration'] as int),
      isCompleted: json['is_completed'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'priority': priority.toString().split('.').last,
      'due_date': dueDate.toIso8601String(),
      'estimated_duration': estimatedDuration.inMinutes,
      'is_completed': isCompleted,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Task copyWith({
    String? id,
    String? name,
    String? description,
    TaskPriority? priority,
    DateTime? dueDate,
    Duration? estimatedDuration,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return Task(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }
} 