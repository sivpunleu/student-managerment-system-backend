import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/cache_store.dart';
import '../models/note_item.dart';

class NoteProvider extends ChangeNotifier {
  NoteProvider(this._apiClient);

  final ApiClient _apiClient;
  final List<NoteItem> _notes = [];
  bool _isLoading = false;
  bool _isOffline = false;
  String? _error;

  List<NoteItem> get notes => List.unmodifiable(_notes);
  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;
  String? get error => _error;

  Future<void> load() async {
    _setLoading(true);

    try {
      final response = await _apiClient.get(
        '/api/notes',
        query: {'limit': 100},
      );
      _notes
        ..clear()
        ..addAll(
          (response['notes'] as List<dynamic>? ?? []).map(
            (item) => NoteItem.fromJson(Map<String, dynamic>.from(item as Map)),
          ),
        );
      await CacheStore.write('notes', response);
      _isOffline = false;
      _error = null;
    } on ApiException catch (error) {
      final cache = error.isNetworkError
          ? await CacheStore.read('notes')
          : null;
      if (cache is Map) {
        _notes
          ..clear()
          ..addAll(
            (cache['notes'] as List<dynamic>? ?? []).map(
              (item) =>
                  NoteItem.fromJson(Map<String, dynamic>.from(item as Map)),
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
    required String content,
    String? studentId,
  }) async {
    _setLoading(true);
    final body = {
      'title': title.trim(),
      'content': content.trim(),
      'student': studentId,
    };

    try {
      if (id == null) {
        await _apiClient.post('/api/notes', body: body);
      } else {
        await _apiClient.put('/api/notes/$id', body: body);
      }
      await load();
      return true;
    } on ApiException catch (error) {
      _error = error.message;
      _setLoading(false);
      return false;
    }
  }

  Future<bool> delete(String id) async {
    _setLoading(true);

    try {
      await _apiClient.delete('/api/notes/$id');
      _notes.removeWhere((note) => note.id == id);
      _error = null;
      return true;
    } on ApiException catch (error) {
      _error = error.message;
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
