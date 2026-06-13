import 'package:flutter/services.dart';

class LocalStore {
  LocalStore._();

  static const _channel = MethodChannel('student_management/storage');
  static final Map<String, String> _fallback = {};

  static Future<String?> getString(String key) async {
    try {
      return await _channel.invokeMethod<String>('getString', {'key': key});
    } on MissingPluginException {
      return _fallback[key];
    } on PlatformException {
      return _fallback[key];
    }
  }

  static Future<void> setString(String key, String value) async {
    _fallback[key] = value;
    try {
      await _channel.invokeMethod<void>('setString', {
        'key': key,
        'value': value,
      });
    } on MissingPluginException {
      // Tests and unsupported platforms use the in-memory fallback.
    } on PlatformException {
      // Keep the current process usable if native storage is unavailable.
    }
  }

  static Future<void> remove(String key) async {
    _fallback.remove(key);
    try {
      await _channel.invokeMethod<void>('remove', {'key': key});
    } on MissingPluginException {
      // Tests and unsupported platforms use the in-memory fallback.
    } on PlatformException {
      // Ignore native cleanup failures; the in-memory value is already gone.
    }
  }
}
