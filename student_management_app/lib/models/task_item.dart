class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    required this.description,
    required this.priority,
    required this.status,
    this.dueDate,
    this.studentId,
    this.studentName,
  });

  final String id;
  final String title;
  final String description;
  final String priority;
  final String status;
  final DateTime? dueDate;
  final String? studentId;
  final String? studentName;

  bool get isCompleted => status == 'completed';
  bool get isOverdue {
    if (isCompleted || dueDate == null) {
      return false;
    }
    final due = dueDate!.toLocal();
    final dueDay = DateTime(due.year, due.month, due.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return dueDay.isBefore(today);
  }

  bool get isDueToday {
    if (isCompleted || dueDate == null) {
      return false;
    }
    final due = dueDate!.toLocal();
    final now = DateTime.now();
    return due.year == now.year && due.month == now.month && due.day == now.day;
  }

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    final student = json['student'] is Map<String, dynamic>
        ? json['student'] as Map<String, dynamic>
        : null;

    return TaskItem(
      id: json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      priority: json['priority']?.toString() ?? 'medium',
      status: json['status']?.toString() ?? 'pending',
      dueDate: DateTime.tryParse(json['dueDate']?.toString() ?? ''),
      studentId: student?['_id']?.toString(),
      studentName: student?['fullName']?.toString(),
    );
  }
}
