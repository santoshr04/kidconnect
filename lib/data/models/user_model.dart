/// User roles in the SnapPix-AI app
enum UserRole { parent, teacher, admin }

/// Status for parent accounts created by teachers
enum ParentStatus { pendingCompletion, active }

/// User model representing a parent, teacher, or admin
class UserModel {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? avatarUrl;
  final String? phone;
  final String? alternatePhone;
  final ParentStatus status;
  final String? createdBy;
  final DateTime createdAt;
  final List<String> permissions;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.avatarUrl,
    this.phone,
    this.alternatePhone,
    this.status = ParentStatus.active,
    this.createdBy,
    required this.createdAt,
    this.permissions = const [],
  });

  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  String get firstName => name.split(' ').first;
}