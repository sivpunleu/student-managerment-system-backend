import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/cache_store.dart';
import '../core/date_utils.dart';
import '../models/attendance.dart';

class AttendanceProvider extends ChangeNotifier {
  AttendanceProvider(this._apiClient);

  final ApiClient _apiClient;
  final List<AttendanceRecord> _records = [];
  AttendanceSummary? _summary;
  AttendanceReport? _report;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isOffline = false;
  String? _error;

  List<AttendanceRecord> get records => List.unmodifiable(_records);
  AttendanceSummary? get summary => _summary;
  AttendanceReport? get report => _report;
  DateTime get selectedDate => _selectedDate;
  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;
  String? get error => _error;

  Future<void> load({DateTime? date}) async {
    if (date != null) {
      _selectedDate = date;
    }

    _setLoading(true);
    final dateValue = formatDateOnly(_selectedDate);

    try {
      final results = await Future.wait([
        _apiClient.get('/api/attendances/summary', query: {'date': dateValue}),
        _apiClient.get(
          '/api/attendances',
          query: {'from': dateValue, 'to': dateValue, 'limit': 100},
        ),
      ]);

      final summaryResponse = Map<String, dynamic>.from(results[0] as Map);
      final attendanceResponse = Map<String, dynamic>.from(results[1] as Map);
      _applyResponses(summaryResponse, attendanceResponse);
      await Future.wait([
        CacheStore.write('attendance.summary.$dateValue', summaryResponse),
        CacheStore.write('attendance.records.$dateValue', attendanceResponse),
      ]);
      _isOffline = false;
      _error = null;
    } on ApiException catch (error) {
      if (error.isNetworkError && await _loadCache(dateValue)) {
        _isOffline = true;
        _error = null;
      } else {
        _error = error.message;
      }
    } finally {
      _setLoading(false);
    }
  }

  void _applyResponses(
    Map<String, dynamic> summaryResponse,
    Map<String, dynamic> attendanceResponse,
  ) {
    _summary = AttendanceSummary.fromJson(summaryResponse);
    _records
      ..clear()
      ..addAll(
        (attendanceResponse['attendances'] as List<dynamic>? ?? []).map(
          (item) =>
              AttendanceRecord.fromJson(Map<String, dynamic>.from(item as Map)),
        ),
      );
  }

  Future<bool> _loadCache(String dateValue) async {
    final results = await Future.wait([
      CacheStore.read('attendance.summary.$dateValue'),
      CacheStore.read('attendance.records.$dateValue'),
    ]);
    if (results[0] is! Map || results[1] is! Map) {
      return false;
    }
    _applyResponses(
      Map<String, dynamic>.from(results[0] as Map),
      Map<String, dynamic>.from(results[1] as Map),
    );
    return true;
  }

  Future<bool> markAttendance({
    required String studentId,
    required String status,
    String note = '',
  }) async {
    _setLoading(true);

    try {
      await _apiClient.post(
        '/api/attendances',
        body: {
          'student': studentId,
          'date': formatDateOnly(_selectedDate),
          'status': status,
          'note': note.trim(),
        },
      );
      await load();
      return true;
    } on ApiException catch (error) {
      _error = error.message;
      _setLoading(false);
      return false;
    }
  }

  Future<bool> markBulkAttendance({
    required Map<String, String> statuses,
    Map<String, String> notes = const {},
  }) async {
    if (statuses.isEmpty) {
      _error = 'Select at least one student';
      notifyListeners();
      return false;
    }

    _setLoading(true);
    try {
      await _apiClient.post(
        '/api/attendances/bulk',
        body: {
          'date': formatDateOnly(_selectedDate),
          'records': statuses.entries
              .map(
                (entry) => {
                  'student': entry.key,
                  'status': entry.value,
                  'note': notes[entry.key]?.trim() ?? '',
                },
              )
              .toList(),
        },
      );
      await load();
      return true;
    } on ApiException catch (error) {
      _error = error.message;
      _setLoading(false);
      return false;
    }
  }

  Future<bool> deleteAttendance(String id) async {
    _setLoading(true);

    try {
      await _apiClient.delete('/api/attendances/$id');
      await load();
      return true;
    } on ApiException catch (error) {
      _error = error.message;
      _setLoading(false);
      return false;
    }
  }

  Future<bool> loadReport({
    required DateTime from,
    required DateTime to,
    String? studentId,
  }) async {
    _setLoading(true);
    try {
      final response = await _apiClient.get(
        '/api/attendances/report',
        query: {
          'from': formatDateOnly(from),
          'to': formatDateOnly(to),
          if (studentId != null) 'student': studentId,
        },
      );
      _report = AttendanceReport.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
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
