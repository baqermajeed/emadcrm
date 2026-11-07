import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/user.dart';

class AuthService {
  AuthService(this._api) {
    _api.onAccessTokenUpdated = (token, userJson) {
      unawaited(_quietly(() => _persistAccessToken(token, userJson)));
    };
    _api.onRefreshTokenUpdated = (refreshToken) {
      unawaited(_quietly(() => _persistRefreshToken(refreshToken)));
    };
  }

  final ApiClient _api;

  Future<void> Function()? onSessionInvalid;

  void bindSessionHandler() {
    _api.onSessionInvalid = () async {
      await clearLocalSession();
      await onSessionInvalid?.call();
    };
  }

  Future<AppUser> login(String username, String password) async {
    final data = await _api.post('/api/auth/login', body: {
      'username': username,
      'password': password,
    }) as Map<String, dynamic>;

    final token = data['access_token'] as String;
    final user = AppUser.fromJson(data['user'] as Map<String, dynamic>);
    _api.setToken(token);

    await _persistAccessToken(token, user.toJson());
    await _persistRefreshToken(_api.refreshCookie);
    return user;
  }

  /// Instant local restore (no network). Returns null if nothing saved.
  Future<AppUser?> restoreLocalSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey);
    final refreshToken = prefs.getString(AppConstants.refreshTokenKey);
    final userRaw = prefs.getString(AppConstants.userKey);
    if ((token == null && refreshToken == null) || userRaw == null) return null;
    _api.setToken(token);
    _api.setRefreshToken(refreshToken);
    try {
      return AppUser.fromJson(jsonDecode(userRaw) as Map<String, dynamic>);
    } catch (_) {
      await clearLocalSession();
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
        return null;
      }
      // Network/server hiccup — keep local session.
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await _api.post('/api/auth/logout');
    } catch (_) {
      // Local logout should still succeed if the network is down.
    }
    await clearLocalSession();
  }

  Future<void> clearLocalSession() async {
    _api.setToken(null);
    _api.setRefreshToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.refreshTokenKey);
    await prefs.remove(AppConstants.userKey);
  }

  Future<void> _persistAccessToken(String token, Map<String, dynamic>? userJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.tokenKey, token);
    if (userJson != null) {
      try {
        final user = AppUser.fromJson(userJson);
        await prefs.setString(AppConstants.userKey, jsonEncode(user.toJson()));
      } catch (_) {
        // Keep the previously cached user if the payload is incomplete.
      }
    }
  }

  Future<void> _quietly(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {}
  }

  Future<void> _persistRefreshToken(String? refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    if (refreshToken == null || refreshToken.isEmpty) {
      await prefs.remove(AppConstants.refreshTokenKey);
    } else {
      await prefs.setString(AppConstants.refreshTokenKey, refreshToken);
    }
  }
}
