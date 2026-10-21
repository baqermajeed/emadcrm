class AppConstants {
  /// عنوان الباكند على السيرفر (يمكن تجاوزه بـ --dart-define=API_BASE_URL=...)
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://emadcrm.compassaccuracy.com',
  );

  static const String tokenKey = 'access_token';
  static const String userKey = 'current_user';
}
