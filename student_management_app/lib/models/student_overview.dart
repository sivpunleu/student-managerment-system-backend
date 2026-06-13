import 'attendance.dart';
import 'note_item.dart';
import 'task_item.dart';

class StudentOverview {
  const StudentOverview({
    required this.attendance,
    required this.notes,
    required this.tasks,
  });

  final StudentAttendanceOverview attendance;
  final StudentNoteOverview notes;
  final StudentTaskOverview tasks;

  factory StudentOverview.fromJson(Map<String, dynamic> json) {
    return StudentOverview(
      attendance: StudentAttendanceOverview.fromJson(
        Map<String, dynamic>.from(json['attendance'] as Map? ?? const {}),
      ),
      notes: StudentNoteOverview.fromJson(
        Map<String, dynamic>.from(json['notes'] as Map? ?? const {}),
      ),
      tasks: StudentTaskOverview.fromJson(
        Map<String, dynamic>.from(json['tasks'] as Map? ?? const {}),
      ),
    );
  }
}

class StudentAttendanceOverview {
  const StudentAttendanceOverview({
    required this.present,
    required this.absent,
    required this.late,
    required this.excused,
    required this.totalRecords,
    required this.attendanceRate,
    required this.recent,
  });

  final int present;
  final int absent;
  final int late;
  final int excused;
  final int totalRecords;
  final double attendanceRate;
  final List<AttendanceRecord> recent;

  factory StudentAttendanceOverview.fromJson(Map<String, dynamic> json) {
    final counts = Map<String, dynamic>.from(
      json['counts'] as Map? ?? const {},
    );
    return StudentAttendanceOverview(
      present: (counts['present'] as num?)?.toInt() ?? 0,
      absent: (counts['absent'] as num?)?.toInt() ?? 0,
      late: (counts['late'] as num?)?.toInt() ?? 0,
      excused: (counts['excused'] as num?)?.toInt() ?? 0,
      totalRecords: (json['totalRecords'] as num?)?.toInt() ?? 0,
      attendanceRate: (json['attendanceRate'] as num?)?.toDouble() ?? 0,
      recent: (json['recent'] as List<dynamic>? ?? const [])
          .map(
            (item) => AttendanceRecord.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}

class StudentNoteOverview {
  const StudentNoteOverview({required this.total, required this.recent});

  final int total;
  final List<NoteItem> recent;

  factory StudentNoteOverview.fromJson(Map<String, dynamic> json) {
    return StudentNoteOverview(
      total: (json['total'] as num?)?.toInt() ?? 0,
      recent: (json['recent'] as List<dynamic>? ?? const [])
          .map(
            (item) => NoteItem.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
    );
  }
}

class StudentTaskOverview {
  const StudentTaskOverview({
    required this.total,
    required this.pending,
    required this.inProgress,
    required this.completed,
    required this.overdue,
    required this.upcoming,
  });

  final int total;
  final int pending;
  final int inProgress;
  final int completed;
  final int overdue;
  final List<TaskItem> upcoming;

  factory StudentTaskOverview.fromJson(Map<String, dynamic> json) {
    return StudentTaskOverview(
      total: (json['total'] as num?)?.toInt() ?? 0,
      pending: (json['pending'] as num?)?.toInt() ?? 0,
      inProgress: (json['inProgress'] as num?)?.toInt() ?? 0,
      completed: (json['completed'] as num?)?.toInt() ?? 0,
      overdue: (json['overdue'] as num?)?.toInt() ?? 0,
      upcoming: (json['upcoming'] as List<dynamic>? ?? const [])
          .map(
            (item) => TaskItem.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
    );
  }
}
