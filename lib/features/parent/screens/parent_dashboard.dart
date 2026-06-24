import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/avatar_widget.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../data/mock/mock_data.dart';
import '../../../data/models/attendance_model.dart';
import '../../auth/providers/auth_provider.dart';

/// Parent Dashboard — Clean, simple, visual-first design
class ParentDashboard extends ConsumerWidget {
  const ParentDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.currentUser;
    final childId = authState.selectedChildId ?? 'child_1';
    final child = MockData.getChildById(childId);
    final children = MockData.getChildrenForParent(user?.id ?? 'parent_1');
    final attendancePercent = MockData.getAttendancePercentage(childId);
    final recentActivities = MockData.getActivitiesForChild(childId);
    final todayAttendance = MockData.getAttendanceForChild(childId);
    final todayRecord = todayAttendance.isNotEmpty ? todayAttendance.first : null;

    final screenWidth = MediaQuery.of(context).size.width;
    final contentWidth = screenWidth > 500 ? 420.0 : screenWidth;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SizedBox(
          width: contentWidth,
          child: CustomScrollView(
            slivers: [
              // ─── Warm Gradient Header ─────────────────────
              SliverToBoxAdapter(
                child: Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 16,
                    left: 20,
                    right: 20,
                    bottom: 28,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_getGreeting()} 👋',
                                style: GoogleFonts.nunito(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.white.withValues(alpha: 0.85),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user?.firstName ?? 'Parent',
                                style: GoogleFonts.nunito(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.white,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  onPressed: () {},
                                  icon: const Icon(Icons.notifications_outlined,
                                      color: AppColors.white, size: 22),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _showProfileMenu(context, ref),
                                child: AvatarWidget(
                                  name: user?.name ?? 'User',
                                  size: 42,
                                  borderColor: AppColors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 22),

                      // Child info / selector
                      if (children.length > 1)
                        SizedBox(
                          height: 44,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: children.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final c = children[index];
                              final isSelected = c.id == childId;
                              return GestureDetector(
                                onTap: () => ref
                                    .read(authProvider.notifier)
                                    .selectChild(c.id),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.white
                                        : AppColors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      AvatarWidget(name: c.name, size: 24),
                                      const SizedBox(width: 8),
                                      Text(
                                        c.firstName,
                                        style: GoogleFonts.nunito(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected
                                              ? AppColors.primary
                                              : AppColors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      else if (child != null)
                        Row(
                          children: [
                            AvatarWidget(
                              name: child.name,
                              size: 52,
                              borderColor: AppColors.white,
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  child.name,
                                  style: GoogleFonts.nunito(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.white,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${child.className} • Age ${child.age}',
                                    style: GoogleFonts.nunito(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),

              // ─── Today's Status ───────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: _TodayStatusCard(
                    attendance: todayRecord,
                    childName: child?.firstName ?? 'Child',
                  ),
                ),
              ),

              // ─── Quick Stats ──────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          label: 'Attendance',
                          value: '${attendancePercent.toStringAsFixed(0)}%',
                          icon: Icons.check_circle_outline,
                          color: AppColors.success,
                          index: 0,
                          subtitle: 'This month',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatCard(
                          label: 'Activities',
                          value: '${recentActivities.length}',
                          icon: Icons.auto_awesome,
                          color: AppColors.accent,
                          index: 1,
                          subtitle: 'This week',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatCard(
                          label: 'Messages',
                          value: '1',
                          icon: Icons.chat_bubble_outline,
                          color: AppColors.skyBlue,
                          index: 2,
                          subtitle: 'Unread',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Quick Actions (Simple for Parents) ───────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                  child: Row(
                    children: [
                      _SimpleAction(
                        emoji: '📅',
                        label: 'Attendance',
                        color: AppColors.success,
                        onTap: () => context.go('/parent/attendance'),
                      ),
                      const SizedBox(width: 10),
                      _SimpleAction(
                        emoji: '📊',
                        label: 'Progress',
                        color: AppColors.accent,
                        onTap: () => context.push('/progress'),
                      ),
                      const SizedBox(width: 10),
                      _SimpleAction(
                        emoji: '📸',
                        label: 'Gallery',
                        color: AppColors.skyBlue,
                        onTap: () => context.go('/parent/gallery'),
                      ),
                      const SizedBox(width: 10),
                      _SimpleAction(
                        emoji: '💬',
                        label: 'Chat',
                        color: AppColors.primary,
                        onTap: () => context.go('/parent/chat'),
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Recent Activities ────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'What happened today? 🎯',
                        style: GoogleFonts.nunito(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go('/parent/activities'),
                        child: Text('See All',
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            )),
                      ),
                    ],
                  ),
                ),
              ),

              // Activity cards — simple list (not horizontal scroll)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index >= recentActivities.take(4).length) return null;
                    final activity = recentActivities[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 4),
                      child: _ActivityCard(
                        emoji: activity.typeEmoji,
                        title: activity.title,
                        teacher: activity.teacherName,
                        time: _formatTimeAgo(activity.timestamp),
                        description: activity.description,
                      ),
                    );
                  },
                  childCount: recentActivities.take(4).length,
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }

  void _showProfileMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text('My Profile',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.child_care_outlined),
              title: Text('My Children',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(context),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.error),
              title: Text('Sign Out',
                  style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w600, color: AppColors.error)),
              onTap: () {
                Navigator.pop(context);
                ref.read(authProvider.notifier).logout();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Today's attendance status
class _TodayStatusCard extends StatelessWidget {
  final AttendanceModel? attendance;
  final String childName;

  const _TodayStatusCard({this.attendance, required this.childName});

  @override
  Widget build(BuildContext context) {
    final isPresent =
        attendance?.isPresent == true || attendance?.isLate == true;
    final statusEmoji = attendance == null
        ? '⏳'
        : attendance!.isPresent
            ? '✅'
            : attendance!.isLate
                ? '⏰'
                : '❌';
    final statusText = attendance == null
        ? 'Not marked yet'
        : attendance!.isPresent
            ? '$childName is at school!'
            : attendance!.isLate
                ? '$childName arrived late'
                : '$childName is absent today';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPresent
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.warning.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(statusEmoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Today's Status",
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textTertiary,
                  ),
                ),
                Text(
                  statusText,
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (attendance?.checkInTime != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                attendance!.checkInTime!,
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Simple quick action button for parents
class _SimpleAction extends StatefulWidget {
  final String emoji;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SimpleAction({
    required this.emoji,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_SimpleAction> createState() => _SimpleActionState();
}

class _SimpleActionState extends State<_SimpleAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.9 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: widget.color.withValues(alpha: 0.12)),
            ),
            child: Column(
              children: [
                Text(widget.emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 4),
                Text(
                  widget.label,
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Activity card with description
class _ActivityCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String teacher;
  final String time;
  final String description;

  const _ActivityCard({
    required this.emoji,
    required this.title,
    required this.teacher,
    required this.time,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      'by $teacher',
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      time,
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
