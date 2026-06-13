import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/date_utils.dart';
import '../models/attendance.dart';
import '../models/student.dart';
import '../models/student_overview.dart';
import '../models/task_item.dart';
import '../providers/auth_provider.dart';
import '../providers/student_provider.dart';
import '../widgets/state_views.dart';
import 'attendance_report_screen.dart';
import 'student_form_screen.dart';

class StudentDetailsScreen extends StatefulWidget {
  const StudentDetailsScreen({super.key, required this.student});

  final Student student;

  @override
  State<StudentDetailsScreen> createState() => _StudentDetailsScreenState();
}

class _StudentDetailsScreenState extends State<StudentDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<StudentProvider>().loadOverview(widget.student.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StudentProvider>();
    final overview = provider.overviewFor(widget.student.id);
    final isLoading = provider.isOverviewLoading(widget.student.id);
    final error = provider.overviewErrorFor(widget.student.id);
    final isAdmin = context.watch<AuthProvider>().isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student details'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: isLoading
                ? null
                : () => provider.loadOverview(widget.student.id),
            icon: const Icon(Icons.refresh_rounded),
          ),
          if (isAdmin)
            IconButton(
              tooltip: 'Edit',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StudentFormScreen(student: widget.student),
                ),
              ),
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.loadOverview(widget.student.id),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            _StudentHero(student: widget.student),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: LinearProgressIndicator(),
              )
            else
              const SizedBox(height: 18),
            if (error != null && overview == null)
              SizedBox(
                height: 260,
                child: ErrorPanel(
                  message: error,
                  onRetry: () => provider.loadOverview(widget.student.id),
                ),
              ),
            if (overview != null) ...[
              const AppSectionHeader(
                title: 'Performance overview',
                subtitle: 'Attendance, notes, and assigned work',
              ),
              const SizedBox(height: 10),
              _OverviewGrid(overview: overview),
              const SizedBox(height: 20),
              _RecentAttendance(
                records: overview.attendance.recent,
                onOpenReport: _openAttendanceReport,
              ),
              const SizedBox(height: 20),
              _UpcomingTasks(tasks: overview.tasks.upcoming),
              const SizedBox(height: 20),
              _RecentNotes(overview: overview),
              const SizedBox(height: 20),
            ],
            const AppSectionHeader(
              title: 'Personal information',
              subtitle: 'Contact and academic profile',
            ),
            const SizedBox(height: 10),
            _PersonalInformation(student: widget.student),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _openAttendanceReport,
              icon: const Icon(Icons.analytics_outlined),
              label: const Text('View full attendance report'),
            ),
          ],
        ),
      ),
    );
  }

  void _openAttendanceReport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AttendanceReportScreen(studentId: widget.student.id),
      ),
    );
  }
}

class _StudentHero extends StatelessWidget {
  const _StudentHero({required this.student});

  final Student student;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 11),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Center(
              child: Text(
                student.fullName.isEmpty
                    ? '?'
                    : student.fullName[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 31,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  student.studentId,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    StatusPill(
                      label: student.department.name,
                      color: AppColors.cyan,
                      icon: Icons.apartment_rounded,
                    ),
                    if (student.year != null)
                      StatusPill(
                        label: 'Year ${student.year}',
                        color: Colors.white,
                        icon: Icons.school_rounded,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewGrid extends StatelessWidget {
  const _OverviewGrid({required this.overview});

  final StudentOverview overview;

  @override
  Widget build(BuildContext context) {
    final openTasks = overview.tasks.pending + overview.tasks.inProgress;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth > 700
            ? (constraints.maxWidth - 36) / 4
            : (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: width,
              child: MetricCard(
                label: 'Attendance',
                value:
                    '${overview.attendance.attendanceRate.toStringAsFixed(0)}%',
                icon: Icons.analytics_outlined,
                color: AppColors.primary,
                caption: '${overview.attendance.totalRecords} records',
              ),
            ),
            SizedBox(
              width: width,
              child: MetricCard(
                label: 'Present',
                value: '${overview.attendance.present}',
                icon: Icons.check_circle_outline_rounded,
                color: AppColors.success,
                caption: '${overview.attendance.late} late',
              ),
            ),
            SizedBox(
              width: width,
              child: MetricCard(
                label: 'Notes',
                value: '${overview.notes.total}',
                icon: Icons.sticky_note_2_outlined,
                color: const Color(0xFF8B5CF6),
                caption: 'Linked notes',
              ),
            ),
            SizedBox(
              width: width,
              child: MetricCard(
                label: 'Open tasks',
                value: '$openTasks',
                icon: Icons.task_alt_rounded,
                color: overview.tasks.overdue > 0
                    ? AppColors.danger
                    : AppColors.warning,
                caption: '${overview.tasks.overdue} overdue',
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RecentAttendance extends StatelessWidget {
  const _RecentAttendance({required this.records, required this.onOpenReport});

  final List<AttendanceRecord> records;
  final VoidCallback onOpenReport;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppSectionHeader(
          title: 'Recent attendance',
          subtitle: 'Latest five attendance records',
          trailing: TextButton(
            onPressed: onOpenReport,
            child: const Text('View all'),
          ),
        ),
        const SizedBox(height: 10),
        if (records.isEmpty)
          const Card(
            child: ListTile(
              leading: AppIconBox(
                icon: Icons.event_busy_outlined,
                color: AppColors.muted,
              ),
              title: Text('No attendance history'),
              subtitle: Text('Attendance records will appear here.'),
            ),
          )
        else
          Card(
            child: Column(
              children: records.map((record) {
                final color = _attendanceColor(record.status);
                return ListTile(
                  leading: AppIconBox(
                    icon: Icons.calendar_today_outlined,
                    color: color,
                    size: 42,
                  ),
                  title: Text(formatDisplayDate(record.date)),
                  subtitle: record.note.isEmpty ? null : Text(record.note),
                  trailing: StatusPill(
                    label: record.status.toUpperCase(),
                    color: color,
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

class _UpcomingTasks extends StatelessWidget {
  const _UpcomingTasks({required this.tasks});

  final List<TaskItem> tasks;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(
          title: 'Upcoming tasks',
          subtitle: 'Incomplete work linked to this student',
        ),
        const SizedBox(height: 10),
        if (tasks.isEmpty)
          const Card(
            child: ListTile(
              leading: AppIconBox(
                icon: Icons.task_alt_rounded,
                color: AppColors.success,
              ),
              title: Text('No open tasks'),
              subtitle: Text('This student has no scheduled work.'),
            ),
          )
        else
          ...tasks.map(
            (task) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  leading: AppIconBox(
                    icon: task.isOverdue
                        ? Icons.warning_amber_rounded
                        : Icons.task_alt_rounded,
                    color: task.isOverdue
                        ? AppColors.danger
                        : AppColors.primary,
                  ),
                  title: Text(task.title),
                  subtitle: Text(
                    task.isOverdue
                        ? 'Overdue - ${formatDisplayDate(task.dueDate)}'
                        : 'Due ${formatDisplayDate(task.dueDate)}',
                  ),
                  trailing: StatusPill(
                    label: task.priority.toUpperCase(),
                    color: _priorityColor(task.priority),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RecentNotes extends StatelessWidget {
  const _RecentNotes({required this.overview});

  final StudentOverview overview;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(
          title: 'Recent notes',
          subtitle: 'Latest observations and progress notes',
        ),
        const SizedBox(height: 10),
        if (overview.notes.recent.isEmpty)
          const Card(
            child: ListTile(
              leading: AppIconBox(
                icon: Icons.note_alt_outlined,
                color: Color(0xFF8B5CF6),
              ),
              title: Text('No notes yet'),
              subtitle: Text('Linked student notes will appear here.'),
            ),
          )
        else
          Card(
            child: Column(
              children: overview.notes.recent
                  .map(
                    (note) => ListTile(
                      leading: const AppIconBox(
                        icon: Icons.note_alt_outlined,
                        color: Color(0xFF8B5CF6),
                        size: 42,
                      ),
                      title: Text(note.title),
                      subtitle: Text(
                        note.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}

class _PersonalInformation extends StatelessWidget {
  const _PersonalInformation({required this.student});

  final Student student;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          _DetailTile(
            icon: Icons.email_outlined,
            label: 'Email',
            value: student.email,
          ),
          _DetailTile(
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: student.phone?.isNotEmpty == true
                ? student.phone!
                : 'Not provided',
          ),
          _DetailTile(
            icon: Icons.apartment_outlined,
            label: 'Department',
            value: student.department.name,
          ),
          _DetailTile(
            icon: Icons.school_outlined,
            label: 'Study year',
            value: student.year == null
                ? 'Not provided'
                : 'Year ${student.year}',
          ),
          _DetailTile(
            icon: Icons.person_outline,
            label: 'Gender',
            value: student.gender ?? 'Not provided',
          ),
        ],
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      leading: AppIconBox(icon: icon, color: AppColors.primary, size: 42),
      title: Text(label),
      subtitle: Text(value),
    );
  }
}

Color _attendanceColor(String status) {
  return switch (status) {
    'present' => AppColors.success,
    'absent' => AppColors.danger,
    'late' => AppColors.warning,
    _ => Colors.blueGrey,
  };
}

Color _priorityColor(String priority) {
  return switch (priority) {
    'high' => AppColors.danger,
    'low' => AppColors.success,
    _ => AppColors.warning,
  };
}
