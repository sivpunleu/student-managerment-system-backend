import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/cache_store.dart';
import '../core/notification_service.dart';
import '../models/task_item.dart';

class TaskProvider extends ChangeNotifier {
  TaskProvider(this._apiClient, {bool notificationsEnabled = true})
    : _notificationsEnabled = notificationsEnabled;

  final ApiClient _apiClient;
  final List<TaskItem> _tasks = [];
  bool _isLoading = false;
  bool _isOffline = false;
  bool _notificationsEnabled;
  String? _error;

  List<TaskItem> get tasks => List.unmodifiable(_tasks);
  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;
  String? get error => _error;

  Future<void> load() async {
    _setLoading(true);

    try {
      final response = await _apiClient.get(
        '/api/tasks',
        query: {'limit': 100},
      );
      _tasks
        ..clear()
        ..addAll(
          (response['tasks'] as List<dynamic>? ?? []).map(
            (item) => TaskItem.fromJson(Map<String, dynamic>.from(item as Map)),
          ),
        );
      await CacheStore.write('tasks', response);
      _isOffline = false;
      await _syncReminders();
      _error = null;
    } on ApiException catch (error) {
      final cache = error.isNetworkError
          ? await CacheStore.read('tasks')
          : null;
      if (cache is Map) {
        _tasks
          ..clear()
          ..addAll(
            (cache['tasks'] as List<dynamic>? ?? []).map(
              (item) =>
                  TaskItem.fromJson(Map<String, dynamic>.from(item as Map)),
            ),
          );
        _isOffline = true;
        _error = null;
      } else {
        _error = error.message;
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> save({
    String? id,
    required String title,
    required String description,
    required String priority,
    required String status,
    DateTime? dueDate,
    String? studentId,
  }) async {
    _setLoading(true);
    final body = {
      'title': title.trim(),
      'description': description.trim(),
      'priority': priority,
      'status': status,
      'dueDate': dueDate?.toIso8601String(),
      'student': studentId,
    };

    try {
      late dynamic response;
      if (id == null) {
        response = await _apiClient.post('/api/tasks', body: body);
      } else {
        response = await _apiClient.put('/api/tasks/$id', body: body);
      }
      final savedTask = TaskItem.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
      await _updateReminder(savedTask);
      await load();
      return true;
    } on ApiException catch (error) {
      _error = error.message;
      _setLoading(false);
      return false;
    }
  }

  Future<bool> toggleCompleted(TaskItem task) {
    return save(
      id: task.id,
      title: task.title,
      description: task.description,
      priority: task.priority,
      status: task.isCompleted ? 'pending' : 'completed',
      dueDate: task.dueDate,
      studentId: task.studentId,
    );
  }

  Future<bool> delete(String id) async {
    _setLoading(true);

    try {
      await _apiClient.delete('/api/tasks/$id');
      _tasks.removeWhere((task) => task.id == id);
      await NotificationService.cancel(id);
      _error = null;
      return true;
    } on ApiException catch (error) {
      _error = error.message;
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> setNotificationsEnabled(bool value) async {
    if (_notificationsEnabled == value) {
      return;
    }
    _notificationsEnabled = value;
    await _syncReminders();
  }

  Future<void> _syncReminders() async {
    for (final task in _tasks) {
      await _updateReminder(task);
    }
  }

  Future<void> _updateReminder(TaskItem task) async {
    if (!_notificationsEnabled || task.isCompleted || task.dueDate == null) {
      await NotificationService.cancel(task.id);
      return;
    }
    final due = task.dueDate!;
    final reminder = DateTime(due.year, due.month, due.day, 8);
    await NotificationService.scheduleTask(
      id: task.id,
      title: 'Task due: ${task.title}',
      date: reminder,
    );
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
