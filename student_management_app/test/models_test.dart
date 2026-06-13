import 'package:flutter_test/flutter_test.dart';
import 'package:student_management_app/models/attendance.dart';
import 'package:student_management_app/models/student_overview.dart';
import 'package:student_management_app/models/task_item.dart';
import 'package:student_management_app/models/user.dart';

void main() {
  test('parses attendance report totals and daily rates', () {
    final report = AttendanceReport.fromJson({
      'from': '2026-06-01',
      'to': '2026-06-02',
      'totals': {'present': 3, 'absent': 1, 'late': 1, 'excused': 0},
      'totalRecords': 5,
      'attendanceRate': 80,
      'daily': [
        {
          'date': '2026-06-01',
          'counts': {'present': 2, 'absent': 1, 'late': 0, 'excused': 0},
          'recorded': 3,
          'attendanceRate': 66.67,
        },
      ],
    });

    expect(report.totalRecords, 5);
    expect(report.attendanceRate, 80);
    expect(report.daily.single.present, 2);
    expect(report.daily.single.attendanceRate, closeTo(66.67, 0.001));
  });

  test('user can round-trip through persisted JSON', () {
    const user = AppUser(
      id: 'user-1',
      fullName: 'Sok Dara',
      email: 'dara@example.com',
      role: 'admin',
    );

    final restored = AppUser.fromJson(user.toJson());

    expect(restored.id, user.id);
    expect(restored.fullName, user.fullName);
    expect(restored.isAdmin, isTrue);
  });

  test('parses a detailed student overview', () {
    final overview = StudentOverview.fromJson({
      'attendance': {
        'counts': {'present': 8, 'absent': 1, 'late': 1, 'excused': 0},
        'totalRecords': 10,
        'attendanceRate': 90,
        'recent': [
          {
            '_id': 'attendance-1',
            'student': {'_id': 'student-1', 'fullName': 'Sok Dara'},
            'date': '2026-06-13T00:00:00.000Z',
            'status': 'present',
          },
        ],
      },
      'notes': {
        'total': 1,
        'recent': [
          {'_id': 'note-1', 'title': 'Progress', 'content': 'Doing well'},
        ],
      },
      'tasks': {
        'total': 3,
        'pending': 1,
        'inProgress': 1,
        'completed': 1,
        'overdue': 1,
        'upcoming': [
          {
            '_id': 'task-1',
            'title': 'Flutter exercise',
            'status': 'pending',
            'priority': 'high',
          },
        ],
      },
    });

    expect(overview.attendance.present, 8);
    expect(overview.attendance.recent.single.studentName, 'Sok Dara');
    expect(overview.notes.recent.single.title, 'Progress');
    expect(overview.tasks.inProgress, 1);
    expect(overview.tasks.upcoming.single.priority, 'high');
  });

  test('identifies overdue and due-today tasks', () {
    final now = DateTime.now();
    final overdue = TaskItem(
      id: 'overdue',
      title: 'Old task',
      description: '',
      priority: 'high',
      status: 'pending',
      dueDate: now.subtract(const Duration(days: 1)),
    );
    final today = TaskItem(
      id: 'today',
      title: 'Today task',
      description: '',
      priority: 'medium',
      status: 'pending',
      dueDate: now,
    );

    expect(overdue.isOverdue, isTrue);
    expect(today.isDueToday, isTrue);
  });
}
