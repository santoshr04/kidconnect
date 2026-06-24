import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/avatar_widget.dart';
import '../../../data/mock/mock_data.dart';
import '../../../data/models/attendance_model.dart';
import '../../auth/providers/auth_provider.dart';

/// Mark attendance screen for teachers
class MarkAttendanceScreen extends ConsumerStatefulWidget {
  const MarkAttendanceScreen({super.key});

  @override
  ConsumerState<MarkAttendanceScreen> createState() =>
      _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends ConsumerState<MarkAttendanceScreen> {
  final Map<String, AttendanceStatus> _attendance = {};
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    // Default all to present
    final teacherId = 'teacher_1';
    final teacherClasses =
        MockData.classes.where((c) => c.teacherId == teacherId);
    if (teacherClasses.isNotEmpty) {
      final students = MockData.getChildrenInClass(teacherClasses.first.id);
      for (final student in students) {
        _attendance[student.id] = AttendanceStatus.present;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).currentUser;
    final teacherId = user?.id ?? 'teacher_1';
    final teacherClasses =
        MockData.classes.where((c) => c.teacherId == teacherId).toList();
    final primaryClass =
        teacherClasses.isNotEmpty ? teacherClasses.first : null;
    final students = primaryClass != null
        ? MockData.getChildrenInClass(primaryClass.id)
        : [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Mark Attendance',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                for (final key in _attendance.keys) {
                  _attendance[key] = AttendanceStatus.present;
                }
              });
            },
            child: Text(
              'All Present',
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w600,
                color: AppColors.secondary,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Date display
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded,
                      color: AppColors.secondary, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    _formatToday(),
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondary,
                    ),
                  ),
                  const Spacer(),
                  if (primaryClass != null)
                    Text(
                      primaryClass.name,
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Student list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: students.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final student = students[index];
                final status =
                    _attendance[student.id] ?? AttendanceStatus.present;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _getStatusColor(status).withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadow.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      AvatarWidget(name: student.name, size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student.name,
                              style: GoogleFonts.nunito(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Age ${student.age}${student.allergies.isNotEmpty ? " • ⚠️ ${student.allergies.join(", ")}" : ""}',
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Status buttons
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _StatusButton(
                            label: '✅',
                            isSelected:
                                status == AttendanceStatus.present,
                            color: AppColors.present,
                            onTap: () => setState(() =>
                                _attendance[student.id] =
                                    AttendanceStatus.present),
                          ),
                          const SizedBox(width: 6),
                          _StatusButton(
                            label: '⏰',
                            isSelected:
                                status == AttendanceStatus.late,
                            color: AppColors.late,
                            onTap: () => setState(() =>
                                _attendance[student.id] =
                                    AttendanceStatus.late),
                          ),
                          const SizedBox(width: 6),
                          _StatusButton(
                            label: '❌',
                            isSelected:
                                status == AttendanceStatus.absent,
                            color: AppColors.absent,
                            onTap: () => setState(() =>
                                _attendance[student.id] =
                                    AttendanceStatus.absent),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Submit button
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _submitted ? null : _submitAttendance,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                ),
                child: _submitted
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Attendance Saved!',
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        'Submit Attendance',
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AppColors.white,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _submitAttendance() {
    setState(() => _submitted = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Attendance saved successfully! ✅',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Color _getStatusColor(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return AppColors.present;
      case AttendanceStatus.absent:
        return AppColors.absent;
      case AttendanceStatus.late:
        return AppColors.late;
      case AttendanceStatus.holiday:
        return AppColors.holiday;
    }
  }

  String _formatToday() {
    final now = DateTime.now();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }
}

class _StatusButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _StatusButton({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(label, style: const TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}
