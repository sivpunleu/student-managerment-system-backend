import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/local_store.dart';
import '../models/user.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._apiClient) {
    _apiClient.setUnauthorizedHandler(_refreshSession);
  }

  static const _refreshTokenKey = 'auth.refreshToken';
  static const _userKey = 'auth.user';

  final ApiClient _apiClient;
  AppUser? _user;
  String? _refreshToken;
  bool _isInitializing = true;
  bool _isLoading = false;
  String? _error;

  AppUser? get user => _user;
  bool get isAuthenticated => _user != null && _apiClient.token != null;
  bool get isAdmin => _user?.isAdmin ?? false;
  bool get isInitializing => _isInitializing;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> initialize() async {
    try {
      _refreshToken = await LocalStore.getString(_refreshTokenKey);
      final savedUser = await LocalStore.getString(_userKey);
      if (savedUser != null) {
        _user = AppUser.fromJson(
          Map<String, dynamic>.from(jsonDecode(savedUser) as Map),
        );
      }

      if (_refreshToken != null) {
        final response = await _apiClient.post(
          '/api/auth/refresh',
          body: {'refreshToken': _refreshToken},
        );
        await _applySession(response);
      } else {
        _user = null;
      }
    } catch (_) {
      await _clearSession();
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) {
    return _authenticate('/api/auth/login', {
      'email': email.trim(),
      'password': password,
    });
  }

  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
  }) {
    return _authenticate('/api/auth/register', {
      'fullName': fullName.trim(),
      'email': email.trim(),
      'password': password,
    });
  }

  Future<bool> _authenticate(String path, Map<String, dynamic> body) async {
    _setLoading(true);

    try {
      final response = await _apiClient.post(path, body: body);
      await _applySession(response);
      return true;
    } on ApiException catch (error) {
      _error = error.message;
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateProfile({
    required String fullName,
    required String email,
  }) async {
    _setLoading(true);
    try {
      final response = await _apiClient.put(
        '/api/auth/profile',
        body: {'fullName': fullName.trim(), 'email': email.trim()},
      );
      _user = AppUser.fromJson(
        Map<String, dynamic>.from(response['user'] as Map),
      );
      await LocalStore.setString(_userKey, jsonEncode(_user!.toJson()));
      return true;
    } on ApiException catch (error) {
      _error = error.message;
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _setLoading(true);
    try {
      final response = await _apiClient.put(
        '/api/auth/change-password',
        body: {'currentPassword': currentPassword, 'newPassword': newPassword},
      );
      await _applySession(response);
      return true;
    } on ApiException catch (error) {
      _error = error.message;
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<String?> forgotPassword(String email) async {
    _setLoading(true);
    try {
      final response = await _apiClient.post(
        '/api/auth/forgot-password',
        body: {'email': email.trim()},
      );
      return response['resetToken']?.toString();
    } on ApiException catch (error) {
      _error = error.message;
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> resetPassword({
    required String resetToken,
    required String newPassword,
  }) async {
    _setLoading(true);
    try {
      final response = await _apiClient.post(
        '/api/auth/reset-password',
        body: {'resetToken': resetToken.trim(), 'newPassword': newPassword},
      );
      await _applySession(response);
      return true;
    } on ApiException catch (error) {
      _error = error.message;
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    try {
      if (_apiClient.token != null) {
        await _apiClient.post('/api/auth/logout');
      }
    } catch (_) {
      // Local logout must still work when the server is unavailable.
    }
    await _clearSession();
    _error = null;
    notifyListeners();
  }

  Future<void> _applySession(dynamic response) async {
    final token =
        response['accessToken']?.toString() ?? response['token']?.toString();
    final refreshToken = response['refreshToken']?.toString();
    if (token == null || token.isEmpty || refreshToken == null) {
      throw const ApiException('The server did not return a complete session');
    }

    _apiClient.setToken(token);
    _refreshToken = refreshToken;
    _user = AppUser.fromJson(
      Map<String, dynamic>.from(response['user'] as Map),
    );
    await Future.wait([
      LocalStore.setString(_refreshTokenKey, refreshToken),
      LocalStore.setString(_userKey, jsonEncode(_user!.toJson())),
    ]);
    _error = null;
  }

  Future<bool> _refreshSession() async {
    if (_refreshToken == null) {
      return false;
    }
    try {
      final response = await _apiClient.post(
        '/api/auth/refresh',
        body: {'refreshToken': _refreshToken},
      );
      await _applySession(response);
      return true;
    } on ApiException {
      await _clearSession();
      notifyListeners();
      return false;
    }
  }

  Future<void> _clearSession() async {
    _apiClient.setToken(null);
    _refreshToken = null;
    _user = null;
    await Future.wait([
      LocalStore.remove(_refreshTokenKey),
      LocalStore.remove(_userKey),
    ]);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    if (value) {
      _error = null;
    }
    notifyListeners();
  }
}
