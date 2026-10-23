import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/user.dart';

class AuthService {
  AuthService(this._api);

  final ApiClient _api;

  Future<AppUser> login(String username, String password) async {
    final data = await _api.post('/api/auth/login', body: {
      'username': username,
      'password': password,
    }) as Map<String, dynamic>;

    final token = data['access_token'] as String;
    final user = AppUser.fromJson(data['user'] as Map<String, dynamic>);
    _api.setToken(token);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.tokenKey, token);
    await prefs.setString(AppConstants.userKey, jsonEncode(user.toJson()));
    return user;
  }

  /// Instant local restore (no network). Returns null if nothing saved.
  Future<AppUser?> restoreLocalSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey);
    final userRaw = prefs.getString(AppConstants.userKey);
    if (token == null || userRaw == null) return null;
    _api.setToken(token);
    try {
      return AppUser.fromJson(jsonDecode(userRaw) as Map<String, dynamic>);
    } catch (_) {
      await logout();
      return null;
    }
  }

  /// Confirm token with server and refresh cached user. Returns null if invalid.
  Future<AppUser?> refreshSession() async {
    try {
      final me = await _api.get('/api/auth/me') as Map<String, dynamic>;
      final user = AppUser.fromJson(me);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.userKey, jsonEncode(user.toJson()));
      return user;
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        await logout();
        return null;
      }
      // Network/server hiccup — keep local session.
      rethrow;
    }
  }

  Future<void> logout() async {
    _api.setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.userKey);
  }
}
