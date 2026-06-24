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

/// Teacher Dashboard — Feature-rich home screen for teachers/admins
class TeacherDashboard extends ConsumerWidget {
  const TeacherDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).currentUser;
    final teacherId = user?.id ?? 'teacher_1';
    final screenWidth = MediaQuery.of(context).size.width;
    final contentWidth = screenWidth > 600 ? 540.0 : screenWidth;

    final teacherClasses =
        MockData.classes.where((c) => c.teacherId == teacherId).toList();
    final primaryClass =
        teacherClasses.isNotEmpty ? teacherClasses.first : null;
    final studentsInClass = primaryClass != null
        ? MockData.getChildrenInClass(primaryClass.id)
        : [];
    final todayAttendance = primaryClass != null
        ? MockData.getTodayAttendance(primaryClass.id)
        : <String, AttendanceStatus>{};
    final presentCount =
        todayAttendance.values.where((s) => s == AttendanceStatus.present).length;
    final absentCount =
        todayAttendance.values.where((s) => s == AttendanceStatus.absent).length;
    final recentActivities = MockData.activities
        .where((a) => a.teacherId == teacherId)
        .take(5)
        .toList();
    final conversations =
        MockData.getConversationsForUser(teacherId);
    final unreadMessages =
        conversations.fold<int>(0, (sum, c) => sum + c.unreadCount);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SizedBox(
          width: contentWidth,
          child: CustomScrollView(
            slivers: [
              // ─── Gradient Header ──────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 16,
                    left: 20,
                    right: 20,
                    bottom: 24,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF4ECDC4), Color(0xFF2CB5AC), Color(0xFF1FA198)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(28),
                      bottomRight: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top bar with greeting
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
                                user?.firstName ?? 'Teacher',
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
                              // Notification bell with badge
                              Stack(
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
                                  Positioned(
                                    right: 6,
                                    top: 6,
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: AppColors.tertiary,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: AppColors.secondary, width: 1.5),
                                      ),
                                    ),
                                  ),
                                ],
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

                      const SizedBox(height: 18),

                      // Class info card
                      if (primaryClass != null)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppColors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Center(
                                  child: Text('🏫', style: TextStyle(fontSize: 24)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      primaryClass.name,
                                      style: GoogleFonts.nunito(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.white,
                                      ),
                                    ),
                                    Text(
                                      '${studentsInClass.length} students • ${primaryClass.schedule ?? ""}',
                                      style: GoogleFonts.nunito(
                                        fontSize: 12,
                                        color: AppColors.white.withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.white.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${primaryClass.studentCount}/${primaryClass.capacity}',
                                  style: GoogleFonts.nunito(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // ─── Today's Overview Stats ───────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          label: 'Present',
                          value: '$presentCount',
                          icon: Icons.check_circle_outline,
                          color: AppColors.success,
                          index: 0,
                          subtitle: 'Today',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatCard(
                          label: 'Absent',
                          value: '$absentCount',
                          icon: Icons.cancel_outlined,
                          color: AppColors.error,
                          index: 1,
                          subtitle: 'Today',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatCard(
                          label: 'Activities',
                          value: '${recentActivities.length}',
                          icon: Icons.auto_awesome,
                          color: AppColors.accent,
                          index: 2,
                          subtitle: 'This week',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatCard(
                          label: 'Messages',
                          value: '$unreadMessages',
                          icon: Icons.chat_bubble_outline,
                          color: AppColors.skyBlue,
                          index: 3,
                          subtitle: 'Unread',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Quick Actions Grid ───────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Actions',
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 4,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.85,
                        children: [
                          _QuickActionTile(
                            emoji: '📋',
                            title: 'Attendance',
                            color: AppColors.success,
                            onTap: () => context.go('/teacher/attendance'),
                          ),
                          _QuickActionTile(
                            emoji: '✏️',
                            title: 'Post Activity',
                            color: AppColors.accent,
                            onTap: () => context.go('/teacher/post'),
                          ),
                          _QuickActionTile(
                            emoji: '📸',
                            title: 'Photos',
                            color: AppColors.skyBlue,
                            onTap: () => context.go('/teacher/photos'),
                          ),
                          _QuickActionTile(
                            emoji: '💬',
                            title: 'Messages',
                            color: AppColors.primary,
                            onTap: () => context.go('/teacher/chat'),
                          ),
                          _QuickActionTile(
                            emoji: '📊',
                            title: 'Reports',
                            color: AppColors.rose,
                            onTap: () => _showComingSoon(context, 'Reports'),
                          ),
                          _QuickActionTile(
                            emoji: '📅',
                            title: 'Schedule',
                            color: AppColors.peach,
                            onTap: () => _showComingSoon(context, 'Schedule'),
                          ),
                          _QuickActionTile(
                            emoji: '🍎',
                            title: 'Meals',
                            color: AppColors.mint,
                            onTap: () => _showComingSoon(context, 'Meal Tracker'),
                          ),
                          _QuickActionTile(
                            emoji: '📢',
                            title: 'Announce',
                            color: AppColors.tertiaryDark,
                            onTap: () => _showComingSoon(context, 'Announcements'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Today's Attendance Summary ───────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Today\'s Attendance',
                            style: GoogleFonts.nunito(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => context.go('/teacher/attendance'),
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: Text('Edit',
                                style: GoogleFonts.nunito(
                                    fontWeight: FontWeight.w600)),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Attendance progress bar
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border, width: 0.5),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                _AttendanceMiniStat(
                                  color: AppColors.present,
                                  label: 'Present',
                                  count: presentCount,
                                  emoji: '✅',
                                ),
                                const SizedBox(width: 16),
                                _AttendanceMiniStat(
                                  color: AppColors.absent,
                                  label: 'Absent',
                                  count: absentCount,
                                  emoji: '❌',
                                ),
                                const SizedBox(width: 16),
                                _AttendanceMiniStat(
                                  color: AppColors.late,
                                  label: 'Late',
                                  count: 0,
                                  emoji: '⏰',
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${studentsInClass.isNotEmpty ? ((presentCount / studentsInClass.length) * 100).toStringAsFixed(0) : 0}%',
                                    style: GoogleFonts.nunito(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: studentsInClass.isNotEmpty
                                    ? presentCount / studentsInClass.length
                                    : 0,
                                minHeight: 8,
                                backgroundColor: AppColors.error.withValues(alpha: 0.15),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    AppColors.success),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Students Grid ────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  child: Text(
                    'My Students',
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: studentsInClass.map((student) {
                      final status = todayAttendance[student.id];
                      return _StudentChip(
                        name: student.firstName,
                        fullName: student.name,
                        isPresent: status == AttendanceStatus.present,
                        allergies: student.allergies,
                      );
                    }).toList(),
                  ),
                ),
              ),

              // ─── Recent Activity Feed ─────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Posts',
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go('/teacher/post'),
                        child: Text('+ New Post',
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w700,
                              color: AppColors.secondary,
                            )),
                      ),
                    ],
                  ),
                ),
              ),

              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index >= recentActivities.length) return null;
                    final activity = recentActivities[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 4),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border, width: 0.5),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(activity.typeEmoji,
                                    style: const TextStyle(fontSize: 20)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    activity.title,
                                    style: GoogleFonts.nunito(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    _formatTimeAgo(activity.timestamp),
                                    style: GoogleFonts.nunito(
                                      fontSize: 12,
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (activity.photoUrls.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.skyBlue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.photo_outlined,
                                        size: 14, color: AppColors.skyBlue),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${activity.photoUrls.length}',
                                      style: GoogleFonts.nunito(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.skyBlue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: recentActivities.length,
                ),
              ),

              // ─── Parent Messages Preview ──────────────────
              if (conversations.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Parent Messages',
                          style: GoogleFonts.nunito(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.go('/teacher/chat'),
                          child: Text('View All',
                              style: GoogleFonts.nunito(
                                fontWeight: FontWeight.w600,
                                color: AppColors.secondary,
                              )),
                        ),
                      ],
                    ),
                  ),
                ),

              if (conversations.isNotEmpty)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index >= conversations.length) return null;
                      final conv = conversations[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 3),
                        child: GestureDetector(
                          onTap: () => context.push('/chat/${conv.otherUserId}'),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: conv.unreadCount > 0
                                  ? AppColors.primary.withValues(alpha: 0.04)
                                  : AppColors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: conv.unreadCount > 0
                                    ? AppColors.primary.withValues(alpha: 0.2)
                                    : AppColors.border,
                                width: conv.unreadCount > 0 ? 1 : 0.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                AvatarWidget(
                                  name: conv.otherUserName,
                                  size: 40,
                                  showStatus: true,
                                  isOnline: conv.isOnline,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        conv.otherUserName,
                                        style: GoogleFonts.nunito(
                                          fontSize: 14,
                                          fontWeight: conv.unreadCount > 0
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        conv.lastMessage,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.nunito(
                                          fontSize: 12,
                                          color: AppColors.textTertiary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (conv.unreadCount > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${conv.unreadCount}',
                                      style: GoogleFonts.nunito(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: conversations.length,
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

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$feature — Coming soon! 🚀',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.secondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
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
              leading: const Icon(Icons.class_outlined),
              title: Text('Class Settings',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: Text('App Settings',
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

class _QuickActionTile extends StatefulWidget {
  final String emoji;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.emoji,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: widget.color.withValues(alpha: 0.12)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(widget.emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(height: 6),
              Text(
                widget.title,
                textAlign: TextAlign.center,
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
    );
  }
}

class _AttendanceMiniStat extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  final String emoji;

  const _AttendanceMiniStat({
    required this.color,
    required this.label,
    required this.count,
    required this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$count',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 10,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StudentChip extends StatelessWidget {
  final String name;
  final String fullName;
  final bool isPresent;
  final List<String> allergies;

  const _StudentChip({
    required this.name,
    required this.fullName,
    required this.isPresent,
    required this.allergies,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPresent
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.error.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AvatarWidget(name: fullName, size: 28),
          const SizedBox(width: 8),
          Text(
            name,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (allergies.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text('⚠️', style: TextStyle(fontSize: 12)),
          ],
          const SizedBox(width: 6),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isPresent ? AppColors.success : AppColors.error,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
