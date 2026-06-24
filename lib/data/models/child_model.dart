/// Child/Student model
class ChildModel {
  final String id;
  final String name;
  final int age;
  final String classId;
  final String className;
  final String parentId;
  final String? avatarUrl;
  final String? bloodGroup;
  final List<String> allergies;
  final String? emergencyContact;
  final String? notes;
  final DateTime dateOfBirth;
  final DateTime enrollmentDate;

  // Face Learning Metadata
  final bool hasFaceProfile; // Whether the parent has uploaded anchor photos
  final int enrolledFaceCount; // Number of training photos provided

  const ChildModel({
    required this.id,
    required this.name,
    required this.age,
    required this.classId,
    required this.className,
    required this.parentId,
    this.avatarUrl,
    this.bloodGroup,
    this.allergies = const [],
    this.emergencyContact,
    this.notes,
    required this.dateOfBirth,
    required this.enrollmentDate,
    this.hasFaceProfile = false,
    this.enrolledFaceCount = 0,
  });

  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String get firstName => name.split(' ').first;

  ChildModel copyWith({
    bool? hasFaceProfile,
    int? enrolledFaceCount,
  }) {
    return ChildModel(
      id: id,
      name: name,
      age: age,
      classId: classId,
      className: className,
      parentId: parentId,
      avatarUrl: avatarUrl,
      bloodGroup: bloodGroup,
      allergies: allergies,
      emergencyContact: emergencyContact,
      notes: notes,
      dateOfBirth: dateOfBirth,
      enrollmentDate: enrollmentDate,
      hasFaceProfile: hasFaceProfile ?? this.hasFaceProfile,
      enrolledFaceCount: enrolledFaceCount ?? this.enrolledFaceCount,
    );
  }
}
