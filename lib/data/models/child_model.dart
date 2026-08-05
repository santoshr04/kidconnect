/// Child/Student model
class ChildModel {
  final String id;
  final String name;
  final int age;
  final String classId;
  final String className;
  final String? section;
  final String parentId;
  final String? avatarUrl;
  final String? bloodGroup;
  final List<String> allergies;
  final String? emergencyContact;
  final String? notes;
  final DateTime? dateOfBirth;
  final DateTime enrollmentDate;

  // Face Learning Metadata
  final bool hasFaceProfile; // Whether the parent has uploaded anchor photos
  final int enrolledFaceCount; // Number of training photos provided

  ChildModel({
    required this.id,
    required this.name,
    this.age = 0,
    required this.classId,
    required this.className,
    this.section,
    required this.parentId,
    this.avatarUrl,
    this.bloodGroup,
    this.allergies = const [],
    this.emergencyContact,
    this.notes,
    this.dateOfBirth,
    DateTime? enrollmentDate,
    this.hasFaceProfile = false,
    this.enrolledFaceCount = 0,
  }) : enrollmentDate = enrollmentDate ?? DateTime.now();

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
    DateTime? dateOfBirth,
    DateTime? enrollmentDate,
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
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      enrollmentDate: enrollmentDate ?? this.enrollmentDate,
      hasFaceProfile: hasFaceProfile ?? this.hasFaceProfile,
      enrolledFaceCount: enrolledFaceCount ?? this.enrolledFaceCount,
    );
  }
}