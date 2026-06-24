import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/mock/mock_data.dart';
import '../../../data/models/attendance_model.dart';
import '../../auth/providers/auth_provider.dart';

/// Attendance screen with interactive calendar
class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final childId = ref.watch(authProvider).selectedChildId ?? 'child_1';
    final child = MockData.getChildById(childId);
    final attendanceRecords = MockData.getAttendanceForChild(childId);
    final attendancePercent = MockData.getAttendancePercentage(childId);

    // Build attendance map for calendar
    final Map<DateTime, AttendanceStatus> attendanceMap = {};
    for (final record in attendanceRecords) {
      final date = DateTime(record.date.year, record.date.month, record.date.day);
      attendanceMap[date] = record.status;
    }

    // Get selected day's record
    AttendanceModel? selectedRecord;
    if (_selectedDay != null) {
      final selected = attendanceRecords.where((r) =>
          r.date.year == _selectedDay!.year &&
          r.date.month == _selectedDay!.month &&
          r.date.day == _selectedDay!.day);
      selectedRecord = selected.isNotEmpty ? selected.first : null;
    }

    // Count stats
    final presentCount =
        attendanceRecords.where((r) => r.status == AttendanceStatus.present).length;
    final absentCount =
        attendanceRecords.where((r) => r.status == AttendanceStatus.absent).length;
    final lateCount =
        attendanceRecords.where((r) => r.status == AttendanceStatus.late).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Attendance',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Attendance Summary ─────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.coolGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.secondary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Attendance ring
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: Stack(
                        children: [
                          Center(
                            child: SizedBox(
                              width: 80,
                              height: 80,
                              child: CircularProgressIndicator(
                                value: attendancePercent / 100,
                                strokeWidth: 8,
                                backgroundColor:
                                    AppColors.white.withValues(alpha: 0.25),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    AppColors.white),
                                strokeCap: StrokeCap.round,
                              ),
                            ),
                          ),
                          Center(
                            child: Text(
                              '${attendancePercent.toStringAsFixed(0)}%',
                              style: GoogleFonts.nunito(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${child?.firstName ?? "Child"}\'s Attendance',
                            style: GoogleFonts.nunito(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _StatPill('✅ $presentCount', 'Present'),
                              const SizedBox(width: 8),
                              _StatPill('❌ $absentCount', 'Absent'),
                              const SizedBox(width: 8),
                              _StatPill('⏰ $lateCount', 'Late'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ─── Calendar ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadow.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TableCalendar(
                  firstDay: DateTime(2025, 1, 1),
                  lastDay: DateTime(2027, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  onFormatChanged: (format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  },
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    todayTextStyle: GoogleFonts.nunito(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                    selectedDecoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    selectedTextStyle: GoogleFonts.nunito(
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                    ),
                    defaultTextStyle: GoogleFonts.nunito(
                      fontWeight: FontWeight.w500,
                    ),
                    weekendTextStyle: GoogleFonts.nunito(
                      fontWeight: FontWeight.w500,
                      color: AppColors.textTertiary,
                    ),
                    outsideTextStyle: GoogleFonts.nunito(
                      color: AppColors.textTertiary.withValues(alpha: 0.5),
                    ),
                  ),
                  headerStyle: HeaderStyle(
                    formatButtonVisible: true,
                    titleCentered: true,
                    titleTextStyle: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    formatButtonTextStyle: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                    formatButtonDecoration: BoxDecoration(
                      border:
                          Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    leftChevronIcon: const Icon(Icons.chevron_left_rounded,
                        color: AppColors.textPrimary),
                    rightChevronIcon: const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textPrimary),
                  ),
                  daysOfWeekStyle: DaysOfWeekStyle(
                    weekdayStyle: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                    weekendStyle: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, day, focusedDay) {
                      final key =
                          DateTime(day.year, day.month, day.day);
                      final status = attendanceMap[key];
                      if (status != null) {
                        return _buildDayCell(day, status);
                      }
                      return null;
                    },
                  ),
                ),
              ),
            ),

            // ─── Legend ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _LegendItem(color: AppColors.present, label: 'Present'),
                  const SizedBox(width: 16),
                  _LegendItem(color: AppColors.absent, label: 'Absent'),
                  const SizedBox(width: 16),
                  _LegendItem(color: AppColors.late, label: 'Late'),
                ],
              ),
            ),

            // ─── Selected Day Details ───────────────────────
            if (_selectedDay != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border, width: 0.5),
                  ),
                  child: selectedRecord != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatDate(_selectedDay!),
                              style: GoogleFonts.nunito(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _DetailChip(
                                  icon: _getStatusIcon(selectedRecord.status),
                                  label: selectedRecord.status.name
                                      .toUpperCase(),
                                  color: _getStatusColor(selectedRecord.status),
                                ),
                                if (selectedRecord.checkInTime != null) ...[
                                  const SizedBox(width: 8),
                                  _DetailChip(
                                    icon: Icons.login_rounded,
                                    label:
                                        'In: ${selectedRecord.checkInTime}',
                                    color: AppColors.secondary,
                                  ),
                                ],
                                if (selectedRecord.checkOutTime != null) ...[
                                  const SizedBox(width: 8),
                                  _DetailChip(
                                    icon: Icons.logout_rounded,
                                    label:
                                        'Out: ${selectedRecord.checkOutTime}',
                                    color: AppColors.accent,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        )
                      : Text(
                          'No attendance record for ${_formatDate(_selectedDay!)}',
                          style: GoogleFonts.nunito(
                            color: AppColors.textTertiary,
                          ),
                        ),
                ),
              ),
            ],

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildDayCell(DateTime day, AttendanceStatus status) {
    Color bgColor;
    switch (status) {
      case AttendanceStatus.present:
        bgColor = AppColors.present;
        break;
      case AttendanceStatus.absent:
        bgColor = AppColors.absent;
        break;
      case AttendanceStatus.late:
        bgColor = AppColors.late;
        break;
      case AttendanceStatus.holiday:
        bgColor = AppColors.holiday;
        break;
    }

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: bgColor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Center(
        child: Text(
          '${day.day}',
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: bgColor,
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  IconData _getStatusIcon(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return Icons.check_circle_rounded;
      case AttendanceStatus.absent:
        return Icons.cancel_rounded;
      case AttendanceStatus.late:
        return Icons.schedule_rounded;
      case AttendanceStatus.holiday:
        return Icons.celebration_rounded;
    }
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
}

class _StatPill extends StatelessWidget {
  final String value;
  final String label;

  const _StatPill(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        value,
        style: GoogleFonts.nunito(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.white,
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _DetailChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
