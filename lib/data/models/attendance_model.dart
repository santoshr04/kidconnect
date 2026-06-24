/// Attendance status enum
enum AttendanceStatus { present, absent, late, holiday }

/// Attendance record for a child on a specific date
class AttendanceModel {
  final String id;
  final String childId;
  final DateTime date;
  final AttendanceStatus status;
  final String? checkInTime;
  final String? checkOutTime;
  final String? markedBy;
  final String? note;

  const AttendanceModel({
    required this.id,
    required this.childId,
    required this.date,
    required this.status,
    this.checkInTime,
    this.checkOutTime,
    this.markedBy,
    this.note,
  });

  bool get isPresent => status == AttendanceStatus.present;
  bool get isAbsent => status == AttendanceStatus.absent;
  bool get isLate => status == AttendanceStatus.late;
}
