import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.details});

  final String message;
  final int? statusCode;
  final Object? details;
  bool get isNetworkError => statusCode == null;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? _token;
  Future<bool> Function()? _unauthorizedHandler;
  bool _isRefreshing = false;

  String? get token => _token;

  void setToken(String? token) {
    _token = token;
  }

  void setUnauthorizedHandler(Future<bool> Function() handler) {
    _unauthorizedHandler = handler;
  }

  Future<dynamic> get(String path, {Map<String, Object?>? query}) {
    return _send('GET', path, query: query);
  }

  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, Object?>? query,
  }) {
    return _send('POST', path, body: body, query: query);
  }

  Future<dynamic> put(
    String path, {
    Object? body,
    Map<String, Object?>? query,
  }) {
    return _send('PUT', path, body: body, query: query);
  }

  Future<dynamic> delete(String path, {Map<String, Object?>? query}) {
    return _send('DELETE', path, query: query);
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, Object?>? query,
    bool allowRefresh = true,
  }) async {
    final uri = _buildUri(path, query);
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };

    try {
      late http.Response response;

      switch (method) {
        case 'GET':
          response = await _client
              .get(uri, headers: headers)
              .timeout(ApiConfig.requestTimeout);
          break;
        case 'POST':
          response = await _client
              .post(
                uri,
                headers: headers,
                body: body == null ? null : jsonEncode(body),
              )
              .timeout(ApiConfig.requestTimeout);
          break;
        case 'PUT':
          response = await _client
              .put(
                uri,
                headers: headers,
                body: body == null ? null : jsonEncode(body),
              )
              .timeout(ApiConfig.requestTimeout);
          break;
        case 'DELETE':
          response = await _client
              .delete(uri, headers: headers)
              .timeout(ApiConfig.requestTimeout);
          break;
        default:
          throw const ApiException('Unsupported request method');
      }

      final decoded = response.body.isEmpty
          ? null
          : jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded;
      }

      if (response.statusCode == 401 &&
          allowRefresh &&
          path != '/api/auth/refresh' &&
          _unauthorizedHandler != null &&
          !_isRefreshing) {
        _isRefreshing = true;
        try {
          if (await _unauthorizedHandler!()) {
            return _send(
              method,
              path,
              body: body,
              query: query,
              allowRefresh: false,
            );
          }
        } finally {
          _isRefreshing = false;
        }
      }

      final message = decoded is Map<String, dynamic>
          ? decoded['message']?.toString() ?? 'Request failed'
          : 'Request failed';
      final details = decoded is Map<String, dynamic>
          ? decoded['details']
          : null;

      throw ApiException(
        message,
        statusCode: response.statusCode,
        details: details,
      );
    } on ApiException {
      rethrow;
    } on FormatException {
      throw const ApiException('The server returned an invalid response');
    } catch (error) {
      throw ApiException(
        'Cannot connect to ${ApiConfig.baseUrl}. Check the backend server.',
        details: error,
      );
    }
  }

  Uri _buildUri(String path, Map<String, Object?>? query) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final base = Uri.parse(ApiConfig.baseUrl);
    final queryParameters = <String, String>{};

    query?.forEach((key, value) {
      if (value != null && value.toString().isNotEmpty) {
        queryParameters[key] = value.toString();
      }
    });

    return base.replace(
      path: '${base.path}$normalizedPath'.replaceAll('//', '/'),
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
  }
}
