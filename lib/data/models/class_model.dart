/// Classroom model
class ClassModel {
  final String id;
  final String name;
  final String teacherId;
  final String teacherName;
  final List<String> studentIds;
  final String? description;
  final String? schedule;
  final int capacity;

  const ClassModel({
    required this.id,
    required this.name,
    required this.teacherId,
    required this.teacherName,
    this.studentIds = const [],
    this.description,
    this.schedule,
    this.capacity = 20,
  });

  int get studentCount => studentIds.length;
  bool get isFull => studentCount >= capacity;
}
