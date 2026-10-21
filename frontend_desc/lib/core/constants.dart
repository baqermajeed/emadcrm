class AppConstants {
  /// غيّر العنوان حسب جهازك (Android emulator: 10.0.2.2)
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static const String tokenKey = 'access_token';
  static const String userKey = 'current_user';
}
