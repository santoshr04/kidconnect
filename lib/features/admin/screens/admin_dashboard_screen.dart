import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/admin_provider.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminProvider);

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Error loading dashboard',
                style: GoogleFonts.nunito(
                    fontSize: 16, color: AppColors.error)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () =>
                  ref.read(adminProvider.notifier).loadDashboard(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Dashboard',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(adminProvider.notifier).loadDashboard(),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.error),
            onPressed: () => context.go('/role-select'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(adminProvider.notifier).loadDashboard(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stat cards grid
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.1,
                children: [
                  _StatCard(
                      label: 'Students',
                      count: state.studentCount,
                      icon: Icons.child_care,
                      color: const Color(0xFF4CAF50)),
                  _StatCard(
                      label: 'Parents',
                      count: state.parentCount,
                      icon: Icons.family_restroom,
                      color: const Color(0xFF2196F3)),
                  _StatCard(
                      label: 'Teachers',
                      count: state.teacherCount,
                      icon: Icons.people,
                      color: const Color(0xFFFF9800)),
                  _StatCard(
                      label: 'Classes',
                      count: state.classCount,
                      icon: Icons.school,
                      color: const Color(0xFF9C27B0)),
                  _StatCard(
                      label: 'Photos',
                      count: state.photosToday,
                      icon: Icons.photo_library,
                      color: const Color(0xFF00BCD4)),
                  _StatCard(
                      label: 'Pending AI',
                      count: state.pendingAiPhotos,
                      icon: Icons.auto_awesome,
                      color: state.pendingAiPhotos > 0
                          ? AppColors.warning
                          : AppColors.success),
                ],
              ),
              const SizedBox(height: 20),

              // Action cards
              Text('Quick Actions',
                  style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ActionCard(
                      label: 'Untagged\nPhotos',
                      count: state.untaggedPhotos,
                      icon: Icons.photo_outlined,
                      onTap: () => context.go('/admin/photos'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionCard(
                      label: 'Pending AI\nReview',
                      count: state.pendingAiPhotos,
                      icon: Icons.auto_fix_high,
                      onTap: () => context.go('/admin/photos'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Recent activity
              if (state.recentActivity.isNotEmpty) ...[
                Text('Recent Activity',
                    style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                ...state.recentActivity.map((a) => Card(
                      elevation: 0,
                      color: AppColors.surface,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(
                              color: AppColors.border, width: 1)),
                      child: ListTile(
                        leading: const CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.primary,
                          child: Icon(Icons.photo, color: Colors.white, size: 18),
                        ),
                        title: Text(a['caption'] as String? ?? '',
                            style: GoogleFonts.nunito(
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        subtitle: Text(a['time'] as String? ?? '',
                            style: GoogleFonts.nunito(
                                fontSize: 11,
                                color: AppColors.textTertiary)),
                      ),
                    )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  const _StatCard(
      {required this.label,
      required this.count,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 6),
          Text('$count',
              style: GoogleFonts.nunito(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: color)),
          Text(label,
              style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionCard(
      {required this.label,
      required this.count,
      required this.icon,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10)),
                child:
                    Icon(icon, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: GoogleFonts.nunito(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 2),
                    Text('$count',
                        style: GoogleFonts.nunito(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: AppColors.textTertiary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}