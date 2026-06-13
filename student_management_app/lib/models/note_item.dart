class NoteItem {
  const NoteItem({
    required this.id,
    required this.title,
    required this.content,
    this.studentId,
    this.studentName,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String content;
  final String? studentId;
  final String? studentName;
  final DateTime? updatedAt;

  factory NoteItem.fromJson(Map<String, dynamic> json) {
    final student = json['student'] is Map<String, dynamic>
        ? json['student'] as Map<String, dynamic>
        : null;

    return NoteItem(
      id: json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      studentId: student?['_id']?.toString(),
      studentName: student?['fullName']?.toString(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }
}
