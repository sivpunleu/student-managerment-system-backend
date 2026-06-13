import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_localizations.dart';
import '../providers/settings_provider.dart';
import '../widgets/state_views.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const routeName = '/settings';

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.text('settings'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PageBanner(
            icon: Icons.tune_rounded,
            title: l10n.text('settings'),
            subtitle: 'Personalize appearance, language, and reminders.',
          ),
          const SizedBox(height: 14),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode_outlined),
                  title: Text(l10n.text('darkMode')),
                  subtitle: Text(l10n.text('appearance')),
                  value: settings.themeMode == ThemeMode.dark,
                  onChanged: settings.setDarkMode,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_active_outlined),
                  title: Text(l10n.text('notifications')),
                  value: settings.notificationsEnabled,
                  onChanged: settings.setNotifications,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.language),
              title: Text(l10n.text('language')),
              trailing: DropdownButton<String>(
                value: settings.locale.languageCode,
                underline: const SizedBox.shrink(),
                items: [
                  DropdownMenuItem(
                    value: 'en',
                    child: Text(l10n.text('english')),
                  ),
                  DropdownMenuItem(
                    value: 'km',
                    child: Text(l10n.text('khmer')),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    settings.setLocale(value);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
