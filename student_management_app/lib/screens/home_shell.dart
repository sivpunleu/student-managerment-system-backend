import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_localizations.dart';
import '../core/app_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/state_views.dart';
import 'account_screen.dart';
import 'attendance_screen.dart';
import 'dashboard_screen.dart';
import 'notes_screen.dart';
import 'settings_screen.dart';
import 'students_screen.dart';
import 'tasks_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final l10n = context.l10n;
    final titles = [
      l10n.text('dashboard'),
      l10n.text('students'),
      l10n.text('attendance'),
      l10n.text('notes'),
      l10n.text('tasks'),
    ];
    final pages = [
      DashboardScreen(onNavigate: _navigate),
      const StudentsScreen(),
      const AttendanceScreen(),
      const NotesScreen(),
      const TasksScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        titleSpacing: 16,
        title: Row(
          children: [
            const ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(11)),
              child: Image(
                image: AssetImage('assets/app_icon.png'),
                width: 38,
                height: 38,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titles[_selectedIndex],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Student Management',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (MediaQuery.sizeOf(context).width > 410)
            StatusPill(
              label: auth.user?.role.toUpperCase() ?? 'USER',
              color: auth.isAdmin ? AppColors.primary : AppColors.success,
              icon: auth.isAdmin
                  ? Icons.verified_user_rounded
                  : Icons.person_rounded,
            ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            tooltip: 'Account',
            offset: const Offset(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            onSelected: (value) {
              if (value == 'logout') {
                context.read<AuthProvider>().logout();
              } else if (value == 'account') {
                Navigator.pushNamed(context, AccountScreen.routeName);
              } else if (value == 'settings') {
                Navigator.pushNamed(context, SettingsScreen.routeName);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: SizedBox(
                  width: 230,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.12),
                        child: Text(
                          _initials(auth.user?.fullName ?? ''),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              auth.user?.fullName ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              auth.user?.email ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'account',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const AppIconBox(
                    icon: Icons.manage_accounts_outlined,
                    color: AppColors.primary,
                    size: 38,
                  ),
                  title: Text(l10n.text('account')),
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const AppIconBox(
                    icon: Icons.settings_outlined,
                    color: AppColors.warning,
                    size: 38,
                  ),
                  title: Text(l10n.text('settings')),
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const AppIconBox(
                    icon: Icons.logout_rounded,
                    color: AppColors.danger,
                    size: 38,
                  ),
                  title: Text(
                    l10n.text('signOut'),
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: CircleAvatar(
                radius: 19,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.12),
                child: Text(
                  _initials(auth.user?.fullName ?? ''),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _navigate,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.dashboard_outlined),
              selectedIcon: const Icon(Icons.dashboard_rounded),
              label: l10n.text('home'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.people_outline_rounded),
              selectedIcon: const Icon(Icons.people_rounded),
              label: l10n.text('students'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.fact_check_outlined),
              selectedIcon: const Icon(Icons.fact_check_rounded),
              label: l10n.text('attendance'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.note_alt_outlined),
              selectedIcon: const Icon(Icons.note_alt_rounded),
              label: l10n.text('notes'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.task_alt_outlined),
              selectedIcon: const Icon(Icons.task_alt_rounded),
              label: l10n.text('tasks'),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      return '?';
    }
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }

  void _navigate(int index) {
    setState(() => _selectedIndex = index);
  }
}
