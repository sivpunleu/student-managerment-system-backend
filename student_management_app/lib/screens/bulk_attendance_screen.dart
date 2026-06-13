import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/date_utils.dart';
import '../models/attendance.dart';
import '../models/student.dart';
import '../providers/attendance_provider.dart';
import '../widgets/state_views.dart';

class BulkAttendanceScreen extends StatefulWidget {
  const BulkAttendanceScreen({
    super.key,
    required this.date,
    required this.students,
    required this.existingRecords,
  });

  final DateTime date;
  final List<Student> students;
  final List<AttendanceRecord> existingRecords;

  @override
  State<BulkAttendanceScreen> createState() => _BulkAttendanceScreenState();
}

class _BulkAttendanceScreenState extends State<BulkAttendanceScreen> {
  final _searchController = TextEditingController();
  final Map<String, String> _statuses = {};
  final Map<String, String> _notes = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existingByStudent = {
      for (final record in widget.existingRecords) record.studentId: record,
    };
    for (final student in widget.students) {
      final existing = existingByStudent[student.id];
      _statuses[student.id] = existing?.status ?? 'present';
      if (existing?.note.isNotEmpty == true) {
        _notes[student.id] = existing!.note;
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final students = widget.students.where((student) {
      return query.isEmpty ||
          student.fullName.toLowerCase().contains(query) ||
          student.studentId.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Class attendance')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              children: [
                PageBanner(
                  icon: Icons.groups_rounded,
                  title: formatDateOnly(widget.date),
                  subtitle:
                      'Review every student, update a status, then save the class.',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search student name or ID',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _buildSummary()),
                    PopupMenuButton<String>(
                      tooltip: 'Set all statuses',
                      onSelected: _setAll,
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'present',
                          child: Text('Set all present'),
                        ),
                        PopupMenuItem(
                          value: 'absent',
                          child: Text('Set all absent'),
                        ),
                        PopupMenuItem(
                          value: 'late',
                          child: Text('Set all late'),
                        ),
                        PopupMenuItem(
                          value: 'excused',
                          child: Text('Set all excused'),
                        ),
                      ],
                      icon: const Icon(Icons.tune_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: students.isEmpty
                ? const EmptyState(
                    icon: Icons.person_search_outlined,
                    title: 'No students found',
                    message: 'Try a different name or student ID.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 110),
                    itemCount: students.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final student = students[index];
                      return _StudentAttendanceCard(
                        student: student,
                        status: _statuses[student.id]!,
                        hasNote: _notes[student.id]?.isNotEmpty == true,
                        onStatusChanged: (value) {
                          setState(() => _statuses[student.id] = value);
                        },
                        onEditNote: () => _editNote(student),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(
              _saving
                  ? 'Saving attendance...'
                  : 'Save ${_statuses.length} records',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final counts = <String, int>{
      'present': 0,
      'absent': 0,
      'late': 0,
      'excused': 0,
    };
    for (final status in _statuses.values) {
      counts[status] = (counts[status] ?? 0) + 1;
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        StatusPill(
          label: '${counts['present']} present',
          color: AppColors.success,
        ),
        StatusPill(
          label: '${counts['absent']} absent',
          color: AppColors.danger,
        ),
        StatusPill(label: '${counts['late']} late', color: AppColors.warning),
      ],
    );
  }

  void _setAll(String status) {
    setState(() {
      for (final student in widget.students) {
        _statuses[student.id] = status;
      }
    });
  }

  Future<void> _editNote(Student student) async {
    final controller = TextEditingController(text: _notes[student.id]);
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Note for ${student.fullName}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 500,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Optional attendance note',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save note'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (note != null && mounted) {
      setState(() {
        if (note.isEmpty) {
          _notes.remove(student.id);
        } else {
          _notes[student.id] = note;
        }
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final provider = context.read<AttendanceProvider>();
    final success = await provider.markBulkAttendance(
      statuses: _statuses,
      notes: _notes,
    );

    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    if (success) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Could not save attendance')),
      );
    }
  }
}

class _StudentAttendanceCard extends StatelessWidget {
  const _StudentAttendanceCard({
    required this.student,
    required this.status,
    required this.hasNote,
    required this.onStatusChanged,
    required this.onEditNote,
  });

  final Student student;
  final String status;
  final bool hasNote;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onEditNote;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Text(
                student.fullName.isEmpty
                    ? '?'
                    : student.fullName[0].toUpperCase(),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    student.studentId,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Attendance note',
              onPressed: onEditNote,
              icon: Icon(
                hasNote ? Icons.comment_rounded : Icons.comment_outlined,
                color: hasNote ? AppColors.primary : null,
              ),
            ),
            SizedBox(
              width: 112,
              child: DropdownButtonFormField<String>(
                initialValue: status,
                isDense: true,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 11,
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'present', child: Text('Present')),
                  DropdownMenuItem(value: 'absent', child: Text('Absent')),
                  DropdownMenuItem(value: 'late', child: Text('Late')),
                  DropdownMenuItem(value: 'excused', child: Text('Excused')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    onStatusChanged(value);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
