import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/app_localizations.dart';
import 'core/app_theme.dart';
import 'providers/attendance_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/note_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/student_provider.dart';
import 'providers/task_provider.dart';
import 'screens/account_screen.dart';
import 'screens/auth_gate.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/register_screen.dart';
import 'screens/settings_screen.dart';

class StudentManagementApp extends StatelessWidget {
  const StudentManagementApp({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: apiClient),
        ChangeNotifierProvider(create: (_) => SettingsProvider()..initialize()),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(apiClient)..initialize(),
        ),
        ChangeNotifierProvider(create: (_) => StudentProvider(apiClient)),
        ChangeNotifierProvider(create: (_) => AttendanceProvider(apiClient)),
        ChangeNotifierProvider(create: (_) => NoteProvider(apiClient)),
        ChangeNotifierProxyProvider<SettingsProvider, TaskProvider>(
          create: (context) => TaskProvider(
            apiClient,
            notificationsEnabled: context
                .read<SettingsProvider>()
                .notificationsEnabled,
          ),
          update: (_, settings, tasks) {
            final provider = tasks ?? TaskProvider(apiClient);
            provider.setNotificationsEnabled(settings.notificationsEnabled);
            return provider;
          },
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) => MaterialApp(
          title: 'Student Management',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: settings.themeMode,
          locale: settings.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const AuthGate(),
          routes: {
            RegisterScreen.routeName: (_) => const RegisterScreen(),
            ForgotPasswordScreen.routeName: (_) => const ForgotPasswordScreen(),
            AccountScreen.routeName: (_) => const AccountScreen(),
            SettingsScreen.routeName: (_) => const SettingsScreen(),
          },
        ),
      ),
    );
  }
}
