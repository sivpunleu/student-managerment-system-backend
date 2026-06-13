import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/date_utils.dart';
import '../models/attendance.dart';
import '../models/student.dart';
import '../providers/attendance_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/student_provider.dart';
import '../widgets/state_views.dart';
import 'attendance_report_screen.dart';
import 'bulk_attendance_screen.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final students = context.read<StudentProvider>();
      if (students.students.isEmpty) {
        await students.load();
      }
      if (mounted) {
        await context.read<AttendanceProvider>().load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    final isAdmin = context.watch<AuthProvider>().isAdmin;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: _showMarkOptions,
              icon: const Icon(Icons.add_task),
              label: const Text('Mark'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: provider.load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            AppSectionHeader(
              title: 'Daily attendance',
              subtitle: 'Track presence and punctuality',
              trailing: FilledButton.tonalIcon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AttendanceReportScreen(),
                  ),
                ),
                icon: const Icon(Icons.analytics_outlined),
                label: const Text('Reports'),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 7,
                ),
                leading: const AppIconBox(
                  icon: Icons.calendar_month_rounded,
                  color: AppColors.primary,
                ),
                title: const Text('Attendance date'),
                subtitle: Text(formatDateOnly(provider.selectedDate)),
                trailing: const Icon(Icons.edit_calendar_rounded),
                onTap: _pickDate,
              ),
            ),
            const SizedBox(height: 12),
            if (provider.summary != null)
              _SummaryGrid(summary: provider.summary!),
            if (provider.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: LinearProgressIndicator(),
              ),
            if (provider.error != null && provider.records.isEmpty)
              SizedBox(
                height: 300,
                child: ErrorPanel(
                  message: provider.error!,
                  onRetry: provider.load,
                ),
              )
            else ...[
              const SizedBox(height: 18),
              const AppSectionHeader(
                title: 'Attendance records',
                subtitle: 'Students marked for the selected day',
              ),
              const SizedBox(height: 10),
              if (provider.records.isEmpty)
                const SizedBox(
                  height: 260,
                  child: EmptyState(
                    icon: Icons.fact_check_outlined,
                    title: 'No attendance recorded',
                    message: 'Mark attendance for the selected date.',
                  ),
                )
              else
                ...provider.records.map(
                  (record) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _AttendanceTile(
                      record: record,
                      canDelete: isAdmin,
                      onDelete: () => _deleteAttendance(record),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final provider = context.read<AttendanceProvider>();
    final selected = await showDatePicker(
      context: context,
      initialDate: provider.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (selected != null && mounted) {
      await provider.load(date: selected);
    }
  }

  Future<void> _markAttendance() async {
    final students = context.read<StudentProvider>().students;
    final attendance = context.read<AttendanceProvider>();
    final recordedIds = attendance.records
        .map((record) => record.studentId)
        .toSet();
    final availableStudents = students
        .where((student) => !recordedIds.contains(student.id))
        .toList();

    if (availableStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Every student is already marked for this date'),
        ),
      );
      return;
    }

    final result = await showDialog<_AttendanceInput>(
      context: context,
      builder: (_) => _AttendanceDialog(students: availableStudents),
    );

    if (result == null || !mounted) {
      return;
    }

    final success = await attendance.markAttendance(
      studentId: result.studentId,
      status: result.status,
      note: result.note,
    );

    if (mounted && !success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(attendance.error ?? 'Could not mark attendance'),
        ),
      );
    }
  }

  Future<void> _showMarkOptions() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mark attendance',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: const AppIconBox(
                  icon: Icons.person_add_alt_1_rounded,
                  color: AppColors.primary,
                ),
                title: const Text('One student'),
                subtitle: const Text('Add one attendance record'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(context, 'single'),
              ),
              const SizedBox(height: 6),
              ListTile(
                leading: const AppIconBox(
                  icon: Icons.groups_rounded,
                  color: AppColors.success,
                ),
                title: const Text('Entire class'),
                subtitle: const Text('Review and save all students at once'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(context, 'bulk'),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted) {
      return;
    }
    if (action == 'single') {
      await _markAttendance();
    } else if (action == 'bulk') {
      await _openBulkAttendance();
    }
  }

  Future<void> _openBulkAttendance() async {
    final students = context.read<StudentProvider>().students;
    if (students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add students before marking attendance')),
      );
      return;
    }

    final attendance = context.read<AttendanceProvider>();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BulkAttendanceScreen(
          date: attendance.selectedDate,
          students: students,
          existingRecords: attendance.records,
        ),
      ),
    );
  }

  Future<void> _deleteAttendance(AttendanceRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete attendance?'),
        content: Text('Delete attendance for ${record.studentName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<AttendanceProvider>().deleteAttendance(record.id);
    }
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});

  final AttendanceSummary summary;

  @override
  Widget build(BuildContext context) {
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
                label: 'Present',
                value: '${summary.present}',
                icon: Icons.check_circle_outline,
                color: Colors.green,
              ),
            ),
            SizedBox(
              width: width,
              child: MetricCard(
                label: 'Absent',
                value: '${summary.absent}',
                icon: Icons.cancel_outlined,
                color: Colors.red,
              ),
            ),
            SizedBox(
              width: width,
              child: MetricCard(
                label: 'Late',
                value: '${summary.late}',
                icon: Icons.schedule,
                color: Colors.orange,
              ),
            ),
            SizedBox(
              width: width,
              child: MetricCard(
                label: 'Rate',
                value: '${summary.attendanceRate.toStringAsFixed(0)}%',
                icon: Icons.analytics_outlined,
                color: Colors.blue,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AttendanceTile extends StatelessWidget {
  const _AttendanceTile({
    required this.record,
    required this.canDelete,
    required this.onDelete,
  });

  final AttendanceRecord record;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = switch (record.status) {
      'present' => Colors.green,
      'absent' => Colors.red,
      'late' => Colors.orange,
      _ => Colors.blueGrey,
    };

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(Icons.person_outline, color: color),
        ),
        title: Text(
          record.studentName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: record.note.isEmpty ? null : Text(record.note),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatusPill(label: record.status.toUpperCase(), color: color),
            if (canDelete)
              IconButton(
                tooltip: 'Delete',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceInput {
  const _AttendanceInput({
    required this.studentId,
    required this.status,
    required this.note,
  });

  final String studentId;
  final String status;
  final String note;
}

class _AttendanceDialog extends StatefulWidget {
  const _AttendanceDialog({required this.students});

  final List<Student> students;

  @override
  State<_AttendanceDialog> createState() => _AttendanceDialogState();
}

class _AttendanceDialogState extends State<_AttendanceDialog> {
  String? _studentId;
  String _status = 'present';
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mark attendance'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _studentId,
              decoration: const InputDecoration(labelText: 'Student'),
              items: widget.students
                  .map(
                    (student) => DropdownMenuItem(
                      value: student.id,
                      child: Text(student.fullName),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _studentId = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(value: 'present', child: Text('Present')),
                DropdownMenuItem(value: 'absent', child: Text('Absent')),
                DropdownMenuItem(value: 'late', child: Text('Late')),
                DropdownMenuItem(value: 'excused', child: Text('Excused')),
              ],
              onChanged: (value) =>
                  setState(() => _status = value ?? 'present'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: 'Note'),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _studentId == null
              ? null
              : () => Navigator.pop(
                  context,
                  _AttendanceInput(
                    studentId: _studentId!,
                    status: _status,
                    note: _noteController.text,
                  ),
                ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
