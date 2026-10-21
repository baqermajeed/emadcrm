import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._authService);

  final AuthService _authService;

  AppUser? user;
  bool bootstrapping = true;
  bool loading = false;
  String? error;

  bool get isLoggedIn => user != null;

  Future<void> bootstrap() async {
    bootstrapping = true;
    notifyListeners();
    user = await _authService.restoreSession();
    bootstrapping = false;
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      user = await _authService.login(username.trim(), password);
      loading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      error = e.message;
      loading = false;
      notifyListeners();
      return false;
    } catch (_) {
      error = 'تعذر الاتصال بالخادم';
      loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    user = null;
    notifyListeners();
  }
}
