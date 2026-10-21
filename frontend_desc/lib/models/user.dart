import '../utils/enums.dart';

class AppUser {
  AppUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    this.phone,
    this.isActive = true,
  });

  final String id;
  final String username;
  final String fullName;
  final UserRole role;
  final String? phone;
  final bool isActive;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        username: json['username'] as String,
        fullName: json['full_name'] as String,
        role: UserRoleX.fromApi(json['role'] as String),
        phone: json['phone'] as String?,
        isActive: json['is_active'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'full_name': fullName,
        'role': role.api,
        'phone': phone,
        'is_active': isActive,
      };
}
