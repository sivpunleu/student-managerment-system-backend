import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/date_utils.dart';
import '../models/attendance.dart';
import '../providers/attendance_provider.dart';
import '../providers/student_provider.dart';
import '../widgets/state_views.dart';

class AttendanceReportScreen extends StatefulWidget {
  const AttendanceReportScreen({super.key, this.studentId});

  final String? studentId;

  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  late DateTime _from;
  late DateTime _to;
  String? _studentId;

  @override
  void initState() {
    super.initState();
    _to = DateTime.now();
    _from = _to.subtract(const Duration(days: 29));
    _studentId = widget.studentId;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (context.read<StudentProvider>().students.isEmpty) {
        await context.read<StudentProvider>().load();
      }
      if (mounted) {
        await _load();
      }
    });
  }

  Future<void> _load() {
    return context.read<AttendanceProvider>().loadReport(
      from: _from,
      to: _to,
      studentId: _studentId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final attendance = context.watch<AttendanceProvider>();
    final students = context.watch<StudentProvider>().students;
    final report = attendance.report;

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance report')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const PageBanner(
              icon: Icons.insights_rounded,
              title: 'Attendance insights',
              subtitle:
                  'Compare daily performance and identify attendance trends.',
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    DropdownButtonFormField<String?>(
                      initialValue: _studentId,
                      decoration: const InputDecoration(
                        labelText: 'Student',
                        prefixIcon: Icon(Icons.person_search_outlined),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All students'),
                        ),
                        ...students.map(
                          (student) => DropdownMenuItem<String?>(
                            value: student.id,
                            child: Text(student.fullName),
                          ),
                        ),
                      ],
                      onChanged: widget.studentId == null
                          ? (value) => setState(() => _studentId = value)
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _DateButton(
                            label: 'From',
                            date: _from,
                            onTap: () => _pickDate(true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _DateButton(
                            label: 'To',
                            date: _to,
                            onTap: () => _pickDate(false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: attendance.isLoading ? null : _load,
                      icon: const Icon(Icons.analytics_outlined),
                      label: const Text('Generate report'),
                    ),
                  ],
                ),
              ),
            ),
            if (attendance.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(),
              ),
            if (attendance.error != null && report == null)
              SizedBox(
                height: 260,
                child: ErrorPanel(message: attendance.error!, onRetry: _load),
              )
            else if (report != null) ...[
              const SizedBox(height: 12),
              _ReportSummary(report: report),
              const SizedBox(height: 16),
              Text(
                'Daily attendance rate',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _AttendanceChart(days: report.daily),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate(bool isFrom) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected == null) {
      return;
    }
    setState(() {
      if (isFrom) {
        _from = selected;
        if (_from.isAfter(_to)) {
          _to = _from;
        }
      } else {
        _to = selected;
        if (_to.isBefore(_from)) {
          _from = _to;
        }
      }
    });
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.calendar_month_outlined),
      label: Text('$label\n${formatDateOnly(date)}'),
    );
  }
}

class _ReportSummary extends StatelessWidget {
  const _ReportSummary({required this.report});

  final AttendanceReport report;

  @override
  Widget build(BuildContext context) {
    final entries = [
      ('Present', report.present, Colors.green),
      ('Absent', report.absent, Colors.red),
      ('Late', report.late, Colors.orange),
      ('Excused', report.excused, Colors.blueGrey),
    ];
    return Column(
      children: [
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.percent)),
            title: const Text('Overall attendance rate'),
            subtitle: Text('${report.from} to ${report.to}'),
            trailing: Text(
              '${report.attendanceRate.toStringAsFixed(1)}%',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: entries
              .map(
                (entry) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          children: [
                            Text(
                              '${entry.$2}',
                              style: TextStyle(
                                color: entry.$3,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              entry.$1,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _AttendanceChart extends StatelessWidget {
  const _AttendanceChart({required this.days});

  final List<AttendanceReportDay> days;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      return const Text('No report data');
    }
    final visible = days.length > 31 ? days.sublist(days.length - 31) : days;
    return SizedBox(
      height: 210,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: visible.map((day) {
          final height = 8 + 150 * (day.attendanceRate / 100);
          return Expanded(
            child: Tooltip(
              message: '${day.date}: ${day.attendanceRate.toStringAsFixed(0)}%',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Container(
                  height: height,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
