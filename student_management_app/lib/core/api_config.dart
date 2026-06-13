class ApiConfig {
  ApiConfig._();

  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://student-management-api-fqf8.onrender.com',
  );

  static const requestTimeout = Duration(seconds: 15);
}
