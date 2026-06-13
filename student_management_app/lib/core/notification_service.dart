import 'package:flutter/services.dart';

class NotificationService {
  NotificationService._();

  static const _channel = MethodChannel('student_management/notifications');

  static Future<bool> requestPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestPermission') ?? true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> scheduleTask({
    required String id,
    required String title,
    required DateTime date,
  }) async {
    if (!date.isAfter(DateTime.now())) {
      return;
    }

    try {
      await _channel.invokeMethod<void>('schedule', {
        'id': id,
        'title': title,
        'timestamp': date.millisecondsSinceEpoch,
      });
    } on MissingPluginException {
      // Notifications are an Android enhancement; other platforms continue.
    } on PlatformException {
      // Exact alarms may be restricted by the device, so task saving must win.
    }
  }

  static Future<void> cancel(String id) async {
    try {
      await _channel.invokeMethod<void>('cancel', {'id': id});
    } on MissingPluginException {
      // No native notification implementation on this platform.
    } on PlatformException {
      // A missing alarm does not require user-visible failure.
    }
  }
}
