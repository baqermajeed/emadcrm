import '../core/api_client.dart';
import '../models/user.dart';
import '../utils/enums.dart';

class UserService {
  UserService(this._api);

  final ApiClient _api;

  Future<List<AppUser>> list({
    UserRole? role,
    bool includeInactive = false,
  }) async {
    final query = <String, String>{};
    if (role != null) query['role'] = role.api;
    if (includeInactive) query['include_inactive'] = 'true';
    final data = await _api.get('/api/users', query: query) as List<dynamic>;
    return data.map((e) => AppUser.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AppUser> create({
    required String username,
    required String password,
    required String fullName,
    required UserRole role,
    String? phone,
    bool isActive = true,
  }) async {
    final data = await _api.post(
      '/api/users',
      body: {
        'username': username.trim(),
        'password': password,
        'full_name': fullName.trim(),
        'role': role.api,
        'phone': phone?.trim().isEmpty == true ? null : phone?.trim(),
        'is_active': isActive,
      },
    ) as Map<String, dynamic>;
    return AppUser.fromJson(data);
  }

  Future<AppUser> update(
    String id, {
    String? username,
    String? fullName,
    String? phone,
    UserRole? role,
    String? password,
    bool? isActive,
    bool clearAvatar = false,
  }) async {
    final body = <String, dynamic>{};
    if (username != null) body['username'] = username.trim();
    if (fullName != null) body['full_name'] = fullName.trim();
    if (phone != null) {
      final p = phone.trim();
      body['phone'] = p.isEmpty ? null : p;
    }
    if (role != null) body['role'] = role.api;
    if (password != null && password.isNotEmpty) body['password'] = password;
    if (isActive != null) body['is_active'] = isActive;
    if (clearAvatar) body['clear_avatar'] = true;

    final data = await _api.patch('/api/users/$id', body: body) as Map<String, dynamic>;
    return AppUser.fromJson(data);
  }

  Future<AppUser> uploadAvatar(String id, String filePath, String filename) async {
    final data = await _api.multipart(
      '/api/users/$id/avatar',
      field: 'file',
      filePath: filePath,
      filename: filename,
    ) as Map<String, dynamic>;
    return AppUser.fromJson(data);
  }
}
