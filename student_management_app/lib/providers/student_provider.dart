import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/cache_store.dart';
import '../models/department.dart';
import '../models/student.dart';
import '../models/student_overview.dart';

class StudentProvider extends ChangeNotifier {
  StudentProvider(this._apiClient);

  final ApiClient _apiClient;
  final List<Student> _students = [];
  final List<Department> _departments = [];
  final Map<String, StudentOverview> _overviews = {};
  final Set<String> _loadingOverviews = {};
  final Map<String, String> _overviewErrors = {};
  bool _isLoading = false;
  bool _isOffline = false;
  String? _error;

  List<Student> get students => List.unmodifiable(_students);
  List<Department> get departments => List.unmodifiable(_departments);
  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;
  String? get error => _error;
  StudentOverview? overviewFor(String studentId) => _overviews[studentId];
  bool isOverviewLoading(String studentId) =>
      _loadingOverviews.contains(studentId);
  String? overviewErrorFor(String studentId) => _overviewErrors[studentId];

  Future<void> load({String search = ''}) async {
    _setLoading(true);

    try {
      final results = await Future.wait([
        _apiClient.get(
          '/api/students',
          query: {'limit': 100, if (search.isNotEmpty) 'search': search},
        ),
        _apiClient.get('/api/departments', query: {'limit': 100}),
      ]);
      final studentResponse = results[0] as Map<String, dynamic>;
      final departmentResponse = results[1] as Map<String, dynamic>;
      _applyResponses(studentResponse, departmentResponse);
      await Future.wait([
        CacheStore.write('students', studentResponse),
        CacheStore.write('departments', departmentResponse),
      ]);
      _isOffline = false;
      _error = null;
    } on ApiException catch (error) {
      if (error.isNetworkError && await _loadCache()) {
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
    Map<String, dynamic> studentResponse,
    Map<String, dynamic> departmentResponse,
  ) {
    _students
      ..clear()
      ..addAll(
        (studentResponse['students'] as List<dynamic>? ?? []).map(
          (item) => Student.fromJson(Map<String, dynamic>.from(item as Map)),
        ),
      );
    _departments
      ..clear()
      ..addAll(
        (departmentResponse['departments'] as List<dynamic>? ?? []).map(
          (item) => Department.fromJson(Map<String, dynamic>.from(item as Map)),
        ),
      );
  }

  Future<bool> _loadCache() async {
    final results = await Future.wait([
      CacheStore.read('students'),
      CacheStore.read('departments'),
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

  Future<bool> saveStudent({
    String? id,
    required Map<String, dynamic> data,
  }) async {
    _setLoading(true);

    try {
      final response = id == null
          ? await _apiClient.post('/api/students', body: data)
          : await _apiClient.put('/api/students/$id', body: data);
      final student = Student.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
      final index = _students.indexWhere((item) => item.id == student.id);

      if (index == -1) {
        _students.insert(0, student);
      } else {
        _students[index] = student;
      }

      _error = null;
      return true;
    } on ApiException catch (error) {
      _error = error.message;
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> loadOverview(String studentId) async {
    _loadingOverviews.add(studentId);
    _overviewErrors.remove(studentId);
    notifyListeners();

    try {
      final response = Map<String, dynamic>.from(
        await _apiClient.get('/api/students/$studentId/overview') as Map,
      );
      _overviews[studentId] = StudentOverview.fromJson(response);
      await CacheStore.write('student.overview.$studentId', response);
      return true;
    } on ApiException catch (error) {
      final cache = error.isNetworkError
          ? await CacheStore.read('student.overview.$studentId')
          : null;
      if (cache is Map) {
        _overviews[studentId] = StudentOverview.fromJson(
          Map<String, dynamic>.from(cache),
        );
        return true;
      }
      _overviewErrors[studentId] = error.message;
      return false;
    } finally {
      _loadingOverviews.remove(studentId);
      notifyListeners();
    }
  }

  Future<bool> deleteStudent(String id) async {
    _setLoading(true);

    try {
      await _apiClient.delete('/api/students/$id');
      _students.removeWhere((student) => student.id == id);
      _overviews.remove(id);
      _overviewErrors.remove(id);
      _error = null;
      return true;
    } on ApiException catch (error) {
      _error = _withDetails(error);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> createDepartment({
    required String name,
    String description = '',
  }) async {
    _setLoading(true);

    try {
      final response = await _apiClient.post(
        '/api/departments',
        body: {'name': name.trim(), 'description': description.trim()},
      );
      _departments.add(
        Department.fromJson(Map<String, dynamic>.from(response as Map)),
      );
      _departments.sort((a, b) => a.name.compareTo(b.name));
      _error = null;
      return true;
    } on ApiException catch (error) {
      _error = error.message;
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteDepartment(String id) async {
    _setLoading(true);

    try {
      await _apiClient.delete('/api/departments/$id');
      _departments.removeWhere((department) => department.id == id);
      _error = null;
      return true;
    } on ApiException catch (error) {
      _error = _withDetails(error);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  String _withDetails(ApiException error) {
    if (error.details is! Map) {
      return error.message;
    }

    final details = Map<String, dynamic>.from(error.details! as Map);
    final records = details.entries
        .where((entry) => entry.value is num && entry.value != 0)
        .map((entry) => '${entry.key}: ${entry.value}')
        .join(', ');
    return records.isEmpty ? error.message : '${error.message} ($records)';
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
