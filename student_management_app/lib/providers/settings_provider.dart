import 'package:flutter/material.dart';

import '../core/local_store.dart';
import '../core/notification_service.dart';

class SettingsProvider extends ChangeNotifier {
  static const _themeKey = 'settings.theme';
  static const _localeKey = 'settings.locale';
  static const _notificationsKey = 'settings.notifications';

  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale = const Locale('en');
  bool _notificationsEnabled = true;

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;
  bool get notificationsEnabled => _notificationsEnabled;

  Future<void> initialize() async {
    final theme = await LocalStore.getString(_themeKey);
    final locale = await LocalStore.getString(_localeKey);
    final notifications = await LocalStore.getString(_notificationsKey);

    _themeMode = switch (theme) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    };
    _locale = Locale(locale == 'km' ? 'km' : 'en');
    _notificationsEnabled = notifications != 'false';
    notifyListeners();
  }

  Future<void> setDarkMode(bool enabled) async {
    _themeMode = enabled ? ThemeMode.dark : ThemeMode.light;
    await LocalStore.setString(_themeKey, enabled ? 'dark' : 'light');
    notifyListeners();
  }

  Future<void> setLocale(String languageCode) async {
    _locale = Locale(languageCode == 'km' ? 'km' : 'en');
    await LocalStore.setString(_localeKey, _locale.languageCode);
    notifyListeners();
  }

  Future<void> setNotifications(bool enabled) async {
    if (enabled) {
      final allowed = await NotificationService.requestPermission();
      _notificationsEnabled = allowed;
    } else {
      _notificationsEnabled = false;
    }
    await LocalStore.setString(
      _notificationsKey,
      _notificationsEnabled.toString(),
    );
    notifyListeners();
  }
}
