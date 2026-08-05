/// User roles in the KidConnect app
enum UserRole { parent, teacher }

/// Status for parent accounts created by teachers
enum ParentStatus { pendingCompletion, active }

/// User model representing a parent or teacher
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
