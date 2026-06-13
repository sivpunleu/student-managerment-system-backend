import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_localizations.dart';
import '../core/app_theme.dart';
import '../providers/attendance_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/note_provider.dart';
import '../providers/student_provider.dart';
import '../providers/task_provider.dart';
import '../widgets/state_views.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await Future.wait([
      context.read<StudentProvider>().load(),
      context.read<AttendanceProvider>().load(),
      context.read<NoteProvider>().load(),
      context.read<TaskProvider>().load(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final students = context.watch<StudentProvider>();
    final attendance = context.watch<AttendanceProvider>();
    final notes = context.watch<NoteProvider>();
    final tasks = context.watch<TaskProvider>();
    final summary = attendance.summary;
    final pendingTasks = tasks.tasks.where((task) => !task.isCompleted).length;
    final completedTasks = tasks.tasks.where((task) => task.isCompleted).length;
    final l10n = context.l10n;
    final firstName = auth.user?.fullName.trim().split(' ').first ?? 'there';

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          if (students.isOffline ||
              attendance.isOffline ||
              notes.isOffline ||
              tasks.isOffline) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.22),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    color: AppColors.warning,
                    size: 20,
                  ),
                  const SizedBox(width: 9),
                  Expanded(child: Text(l10n.text('offlineData'))),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          _WelcomeHero(
            name: firstName,
            subtitle: l10n.text('todayOverview'),
            attendanceRate: summary?.attendanceRate ?? 0,
          ),
          const SizedBox(height: 22),
          AppSectionHeader(
            title: 'Overview',
            subtitle: 'Live campus activity at a glance',
            trailing: IconButton.filledTonal(
              tooltip: 'Refresh',
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 720 ? 4 : 2;
              final spacing = 12.0;
              final width =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  SizedBox(
                    width: width,
                    child: MetricCard(
                      label: l10n.text('students'),
                      value: '${students.students.length}',
                      icon: Icons.groups_2_rounded,
                      color: AppColors.primary,
                      caption: 'Registered',
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: MetricCard(
                      label: l10n.text('attendance'),
                      value:
                          '${summary?.attendanceRate.toStringAsFixed(0) ?? '0'}%',
                      icon: Icons.how_to_reg_rounded,
                      color: AppColors.success,
                      caption: 'Today',
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: MetricCard(
                      label: l10n.text('notes'),
                      value: '${notes.notes.length}',
                      icon: Icons.sticky_note_2_rounded,
                      color: AppColors.warning,
                      caption: 'Saved',
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: MetricCard(
                      label: l10n.text('pendingTasks'),
                      value: '$pendingTasks',
                      icon: Icons.pending_actions_rounded,
                      color: const Color(0xFF8B5CF6),
                      caption: '$completedTasks completed',
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 22),
          AppSectionHeader(
            title: l10n.text('quickAccess'),
            subtitle: 'Jump back into your daily workflow',
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;
              final itemWidth = compact
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _QuickActionCard(
                      icon: Icons.people_alt_rounded,
                      color: AppColors.primary,
                      title: 'Student directory',
                      subtitle: 'View profiles and academic information',
                      onTap: () => widget.onNavigate(1),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _QuickActionCard(
                      icon: Icons.fact_check_rounded,
                      color: AppColors.success,
                      title: 'Mark attendance',
                      subtitle: 'Record and review today\'s attendance',
                      onTap: () => widget.onNavigate(2),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _QuickActionCard(
                      icon: Icons.note_alt_rounded,
                      color: AppColors.warning,
                      title: 'Student notes',
                      subtitle: 'Keep important observations organized',
                      onTap: () => widget.onNavigate(3),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _QuickActionCard(
                      icon: Icons.task_alt_rounded,
                      color: const Color(0xFF8B5CF6),
                      title: 'Tasks & reminders',
                      subtitle: 'Stay ahead of upcoming work',
                      onTap: () => widget.onNavigate(4),
                    ),
                  ),
                ],
              );
            },
          ),
          if (students.isLoading ||
              attendance.isLoading ||
              notes.isLoading ||
              tasks.isLoading)
            Padding(
              padding: const EdgeInsets.only(top: 18),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: const LinearProgressIndicator(minHeight: 5),
              ),
            ),
        ],
      ),
    );
  }
}

class _WelcomeHero extends StatelessWidget {
  const _WelcomeHero({
    required this.name,
    required this.subtitle,
    required this.attendanceRate,
  });

  final String name;
  final String subtitle;
  final double attendanceRate;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned(
              top: -75,
              right: -45,
              child: _HeroCircle(size: 190, opacity: 0.1),
            ),
            Positioned(
              bottom: -95,
              right: 65,
              child: _HeroCircle(size: 170, opacity: 0.06),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Text(
                            'TODAY\'S OVERVIEW',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 13),
                        Text(
                          'Hello, $name',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.7,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.74),
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 92,
                    height: 92,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: attendanceRate.clamp(0, 100) / 100,
                          strokeWidth: 8,
                          strokeCap: StrokeCap.round,
                          backgroundColor: Colors.white.withValues(alpha: 0.14),
                          color: AppColors.cyan,
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${attendanceRate.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'attendance',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.68),
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroCircle extends StatelessWidget {
  const _HeroCircle({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: opacity),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              AppIconBox(icon: icon, color: color, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
