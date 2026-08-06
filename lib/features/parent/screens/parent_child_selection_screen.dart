import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';

/// Shows all children for a parent after phone login.
/// Parent taps a child to proceed.
class ParentChildSelectionScreen extends ConsumerWidget {
  const ParentChildSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final children = authState.allChildren;

    if (children.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Text('No children registered',
              style: GoogleFonts.nunito(
                  fontSize: 16, color: AppColors.textSecondary)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Select Your Child',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => ref.read(authProvider.notifier).logout(),
            child: Text('Logout',
                style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${authState.currentUser?.name ?? 'Welcome'}!',
              style: GoogleFonts.nunito(
                  fontSize: 15, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text('Which child would you like to view?',
                style: GoogleFonts.nunito(
                    fontSize: 13, color: AppColors.textTertiary)),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchChildDetails(children),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final details = snapshot.data!;
                  return ListView.builder(
                    itemCount: details.length,
                    itemBuilder: (context, index) {
                      final child = details[index];
                      return _buildChildCard(
                        context, ref, child,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchChildDetails(
      List<Map<String, String>> children) async {
    final details = <Map<String, dynamic>>[];
    for (final child in children) {
      final id = child['id']!;
      try {
        final doc = await FirebaseFirestore.instance
            .collection('children')
            .doc(id)
            .get();
        if (doc.exists) {
          final data = doc.data()!;
          data['docId'] = id;
          data['displayName'] = child['name'];
          details.add(data);
        }
      } catch (_) {}
    }
    return details;
  }

  Widget _buildChildCard(
      BuildContext context, WidgetRef ref, Map<String, dynamic> child) {
    final name = child['displayName'] as String? ?? child['name'] ?? 'Child';
    final className = child['className'] as String? ?? '';
    final section = child['section'] as String?;
    final hasFaceProfile = child['hasFaceProfile'] == true;
    final status = child['status'] as String? ?? 'pending_completion';
    final isComplete = status == 'active';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _selectChild(context, ref, child),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: GoogleFonts.nunito(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: GoogleFonts.nunito(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Row(children: [
                      if (className.isNotEmpty) ...[
                        Icon(Icons.school_outlined,
                            size: 13, color: AppColors.secondary),
                        const SizedBox(width: 4),
                        Text(
                            section != null
                                ? '$className · $section'
                                : className,
                            style: GoogleFonts.nunito(
                                fontSize: 12,
                                color: AppColors.secondary,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(width: 12),
                      ],
                      Icon(
                        isComplete
                            ? Icons.check_circle
                            : Icons.warning_amber_rounded,
                        size: 14,
                        color: isComplete
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isComplete ? 'Ready' : 'Needs Setup',
                        style: GoogleFonts.nunito(
                            fontSize: 11,
                            color: isComplete
                                ? AppColors.success
                                : AppColors.warning,
                            fontWeight: FontWeight.w600),
                      ),
                    ]),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: AppColors.textTertiary, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  void _selectChild(
      BuildContext context, WidgetRef ref, Map<String, dynamic> child) {
    final childId = child['docId'] as String? ?? child['id'] ?? '';
    ref.read(authProvider.notifier).selectChild(childId);

    final isComplete = child['status'] == 'active';
    final hasFace = child['hasFaceProfile'] == true;

    if (!isComplete) {
      context.go('/parent/complete-profile');
    } else if (!hasFace) {
      context.go('/parent/face-setup');
    } else {
      context.go('/parent/gallery');
    }
  }
}