import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('en'), Locale('km')];

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        const AppLocalizations(Locale('en'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const Map<String, Map<String, String>> _values = {
    'en': {
      'appName': 'Student Management',
      'welcomeBack': 'Welcome back',
      'loginSubtitle': 'Sign in to manage students and attendance',
      'email': 'Email',
      'password': 'Password',
      'signIn': 'Sign in',
      'createAccount': 'Create a new account',
      'forgotPassword': 'Forgot password?',
      'dashboard': 'Dashboard',
      'home': 'Home',
      'students': 'Students',
      'attendance': 'Attendance',
      'notes': 'Notes',
      'tasks': 'Tasks',
      'reports': 'Reports',
      'account': 'Account',
      'settings': 'Settings',
      'signOut': 'Sign out',
      'appearance': 'Appearance',
      'darkMode': 'Dark mode',
      'language': 'Language',
      'english': 'English',
      'khmer': 'Khmer',
      'notifications': 'Task reminders',
      'profile': 'Profile',
      'changePassword': 'Change password',
      'fullName': 'Full name',
      'save': 'Save',
      'cancel': 'Cancel',
      'currentPassword': 'Current password',
      'newPassword': 'New password',
      'confirmPassword': 'Confirm password',
      'hello': 'Hello',
      'todayOverview': "Here is today's student management overview.",
      'quickAccess': 'Quick access',
      'pendingTasks': 'Pending tasks',
      'offlineData': 'Showing saved offline data',
    },
    'km': {
      'appName': 'ប្រព័ន្ធគ្រប់គ្រងនិស្សិត',
      'welcomeBack': 'សូមស្វាគមន៍មកវិញ',
      'loginSubtitle': 'ចូលប្រើដើម្បីគ្រប់គ្រងនិស្សិត និងវត្តមាន',
      'email': 'អ៊ីមែល',
      'password': 'ពាក្យសម្ងាត់',
      'signIn': 'ចូលប្រើ',
      'createAccount': 'បង្កើតគណនីថ្មី',
      'forgotPassword': 'ភ្លេចពាក្យសម្ងាត់?',
      'dashboard': 'ផ្ទាំងគ្រប់គ្រង',
      'home': 'ទំព័រដើម',
      'students': 'និស្សិត',
      'attendance': 'វត្តមាន',
      'notes': 'កំណត់ត្រា',
      'tasks': 'កិច្ចការ',
      'reports': 'របាយការណ៍',
      'account': 'គណនី',
      'settings': 'ការកំណត់',
      'signOut': 'ចាកចេញ',
      'appearance': 'រូបរាង',
      'darkMode': 'ផ្ទៃងងឹត',
      'language': 'ភាសា',
      'english': 'អង់គ្លេស',
      'khmer': 'ខ្មែរ',
      'notifications': 'ការរំលឹកកិច្ចការ',
      'profile': 'ព័ត៌មានផ្ទាល់ខ្លួន',
      'changePassword': 'ប្តូរពាក្យសម្ងាត់',
      'fullName': 'ឈ្មោះពេញ',
      'save': 'រក្សាទុក',
      'cancel': 'បោះបង់',
      'currentPassword': 'ពាក្យសម្ងាត់បច្ចុប្បន្ន',
      'newPassword': 'ពាក្យសម្ងាត់ថ្មី',
      'confirmPassword': 'បញ្ជាក់ពាក្យសម្ងាត់',
      'hello': 'សួស្តី',
      'todayOverview': 'នេះជាសេចក្តីសង្ខេបការគ្រប់គ្រងនិស្សិតថ្ងៃនេះ។',
      'quickAccess': 'ចូលប្រើរហ័ស',
      'pendingTasks': 'កិច្ចការមិនទាន់រួច',
      'offlineData': 'កំពុងបង្ហាញទិន្នន័យដែលបានរក្សាទុក',
    },
  };

  String text(String key) {
    return _values[locale.languageCode]?[key] ?? _values['en']![key] ?? key;
  }
}

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
    (item) => item.languageCode == locale.languageCode,
  );

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
