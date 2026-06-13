class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.date,
    required this.status,
    this.note = '',
  });

  final String id;
  final String studentId;
  final String studentName;
  final DateTime date;
  final String status;
  final String note;

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    final student = json['student'] is Map<String, dynamic>
        ? json['student'] as Map<String, dynamic>
        : <String, dynamic>{};

    return AttendanceRecord(
      id: json['_id']?.toString() ?? '',
      studentId: student['_id']?.toString() ?? '',
      studentName: student['fullName']?.toString() ?? 'Unknown student',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      status: json['status']?.toString() ?? 'absent',
      note: json['note']?.toString() ?? '',
    );
  }
}

class AttendanceSummary {
  const AttendanceSummary({
    required this.date,
    required this.totalStudents,
    required this.recorded,
    required this.unmarked,
    required this.present,
    required this.absent,
    required this.late,
    required this.excused,
    required this.attendanceRate,
    required this.completionRate,
  });

  final String date;
  final int totalStudents;
  final int recorded;
  final int unmarked;
  final int present;
  final int absent;
  final int late;
  final int excused;
  final double attendanceRate;
  final double completionRate;

  factory AttendanceSummary.fromJson(Map<String, dynamic> json) {
    final counts = json['counts'] is Map<String, dynamic>
        ? json['counts'] as Map<String, dynamic>
        : <String, dynamic>{};

    return AttendanceSummary(
      date: json['date']?.toString() ?? '',
      totalStudents: (json['totalStudents'] as num?)?.toInt() ?? 0,
      recorded: (json['recorded'] as num?)?.toInt() ?? 0,
      unmarked: (json['unmarked'] as num?)?.toInt() ?? 0,
      present: (counts['present'] as num?)?.toInt() ?? 0,
      absent: (counts['absent'] as num?)?.toInt() ?? 0,
      late: (counts['late'] as num?)?.toInt() ?? 0,
      excused: (counts['excused'] as num?)?.toInt() ?? 0,
      attendanceRate: (json['attendanceRate'] as num?)?.toDouble() ?? 0,
      completionRate: (json['completionRate'] as num?)?.toDouble() ?? 0,
    );
  }
}

class AttendanceReportDay {
  const AttendanceReportDay({
    required this.date,
    required this.present,
    required this.absent,
    required this.late,
    required this.excused,
    required this.recorded,
    required this.attendanceRate,
  });

  final String date;
  final int present;
  final int absent;
  final int late;
  final int excused;
  final int recorded;
  final double attendanceRate;

  factory AttendanceReportDay.fromJson(Map<String, dynamic> json) {
    final counts = json['counts'] is Map<String, dynamic>
        ? json['counts'] as Map<String, dynamic>
        : <String, dynamic>{};
    return AttendanceReportDay(
      date: json['date']?.toString() ?? '',
      present: (counts['present'] as num?)?.toInt() ?? 0,
      absent: (counts['absent'] as num?)?.toInt() ?? 0,
      late: (counts['late'] as num?)?.toInt() ?? 0,
      excused: (counts['excused'] as num?)?.toInt() ?? 0,
      recorded: (json['recorded'] as num?)?.toInt() ?? 0,
      attendanceRate: (json['attendanceRate'] as num?)?.toDouble() ?? 0,
    );
  }
}

class AttendanceReport {
  const AttendanceReport({
    required this.from,
    required this.to,
    required this.present,
    required this.absent,
    required this.late,
    required this.excused,
    required this.totalRecords,
    required this.attendanceRate,
    required this.daily,
  });

  final String from;
  final String to;
  final int present;
  final int absent;
  final int late;
  final int excused;
  final int totalRecords;
  final double attendanceRate;
  final List<AttendanceReportDay> daily;

  factory AttendanceReport.fromJson(Map<String, dynamic> json) {
    final totals = json['totals'] is Map<String, dynamic>
        ? json['totals'] as Map<String, dynamic>
        : <String, dynamic>{};
    return AttendanceReport(
      from: json['from']?.toString() ?? '',
      to: json['to']?.toString() ?? '',
      present: (totals['present'] as num?)?.toInt() ?? 0,
      absent: (totals['absent'] as num?)?.toInt() ?? 0,
      late: (totals['late'] as num?)?.toInt() ?? 0,
      excused: (totals['excused'] as num?)?.toInt() ?? 0,
      totalRecords: (json['totalRecords'] as num?)?.toInt() ?? 0,
      attendanceRate: (json['attendanceRate'] as num?)?.toDouble() ?? 0,
      daily: (json['daily'] as List<dynamic>? ?? [])
          .map(
            (item) => AttendanceReportDay.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}
