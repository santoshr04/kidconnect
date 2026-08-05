import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/mock/mock_data.dart';
import '../providers/registration_provider.dart';

class RegisteredStudentsScreen extends ConsumerWidget {
  const RegisteredStudentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Registered Students',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_rounded,
                color: AppColors.primary),
            tooltip: 'Register New Student',
            onPressed: () => _navigateToRegister(context, ref),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('children')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildMockList(context, ref);
          }

          final children = snapshot.data!.docs;

          // Also fetch parents for status
          return FutureBuilder<Map<String, Map<String, dynamic>>>(
            future: _fetchParents(children),
            builder: (ctx, parentSnapshot) {
              final parents = parentSnapshot.data ?? {};
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                itemCount: children.length,
                itemBuilder: (context, index) {
                  final doc = children[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final parentId = data['parentId'] as String? ?? '';
                  final parentData = parents[parentId];
                  return _buildStudentCard(
                    context: context,
                    ref: ref,
                    docId: doc.id,
                    name: data['name'] ?? '—',
                    className: data['className'] ?? 'N/A',
                    section: data['section'],
                    parentId: parentId,
                    parentStatus: parentData?['status'] ?? 'pending_completion',
                    parentName: parentData?['name'] as String?,
                    parentPhone: parentData?['phone'] as String?,
                    parentAlternatePhone: parentData?['alternatePhone'] as String?,
                    photoUrl: data['photoUrl'],
                    hasFaceProfile: data['hasFaceProfile'] ?? false,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  /// Fetches all parent documents referenced by the children list.
  Future<Map<String, Map<String, dynamic>>> _fetchParents(
      List<QueryDocumentSnapshot> children) async {
    final parentIds = children
        .map((d) => (d.data() as Map<String, dynamic>)['parentId'] as String?)
        .where((id) => id != null && id.isNotEmpty)
        .toSet();

    final parents = <String, Map<String, dynamic>>{};
    for (final id in parentIds) {
      try {
        final doc =
            await FirebaseFirestore.instance.collection('parents').doc(id!).get();
        if (doc.exists) {
          parents[id] = doc.data()!;
        }
      } catch (_) {}
    }
    return parents;
  }

  Widget _buildMockList(BuildContext context, WidgetRef ref) {
    final children = MockData.children;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: children.length,
      itemBuilder: (context, index) {
        final child = children[index];
        final parent = MockData.getUserById(child.parentId);
        return _buildStudentCard(
          context: context,
          ref: ref,
          docId: child.id,
          name: child.name,
          className: child.className,
          section: child.section,
          parentId: child.parentId,
          parentStatus: 'active',
          parentName: parent?.name,
          parentPhone: parent?.phone,
          parentAlternatePhone: null,
          photoUrl: child.avatarUrl,
          hasFaceProfile: child.hasFaceProfile,
        );
      },
    );
  }

  Widget _buildStudentCard({
    required BuildContext context,
    required WidgetRef ref,
    required String docId,
    required String name,
    required String className,
    String? section,
    required String parentId,
    required String parentStatus,
    String? parentName,
    String? parentPhone,
    String? parentAlternatePhone,
    String? photoUrl,
    required bool hasFaceProfile,
  }) {
    final parentInfo = _resolveParentInfo(parentName, parentStatus);

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
        onTap: () => _showStudentDetailSheet(
          context,
          ref,
          name: name,
          className: className,
          section: section,
          parentId: parentId,
          parentStatus: parentStatus,
          parentName: parentName,
          parentPhone: parentPhone,
          parentAlternatePhone: parentAlternatePhone,
          hasFaceProfile: hasFaceProfile,
          parentInfo: parentInfo,
          docId: docId,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                backgroundImage:
                    photoUrl != null ? NetworkImage(photoUrl) : null,
                child: photoUrl == null
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: GoogleFonts.nunito(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: GoogleFonts.nunito(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildInfoChip(
                            '$className${section != null ? ' · $section' : ''}',
                            AppColors.secondary,
                            Icons.school_outlined),
                        const SizedBox(width: 8),
                        _buildInfoChip(
                            parentInfo.label, parentInfo.color, parentInfo.icon),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: hasFaceProfile
                      ? AppColors.successLight
                      : AppColors.warningLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasFaceProfile ? Icons.face : Icons.face_outlined,
                      size: 16,
                      color: hasFaceProfile
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hasFaceProfile ? 'Trained' : 'Pending',
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: hasFaceProfile
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right,
                  color: AppColors.textTertiary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  _ParentInfo _resolveParentInfo(String? parentName, String status) {
    if (parentName != null && parentName.isNotEmpty) {
      return _ParentInfo(
        label: parentName,
        color: AppColors.success,
        icon: Icons.person,
      );
    }

    final isPending = status == 'pending_completion' || status == 'invited';
    if (isPending) {
      return _ParentInfo(
        label: 'Awaiting parent setup',
        color: AppColors.info,
        icon: Icons.person_outline,
      );
    }

    return _ParentInfo(
      label: 'Parent not linked',
      color: AppColors.textTertiary,
      icon: Icons.person_outline,
    );
  }

  void _navigateToRegister(BuildContext context, WidgetRef ref) {
    ref.read(registrationProvider.notifier).clearForm();
    context.push('/teacher/register');
  }

  void _editStudent({
    required BuildContext context,
    required WidgetRef ref,
    required String parentId,
    required String parentName,
    required String parentPhone,
    required String parentAlternatePhone,
    required String docId,
    required String childName,
    required String childClass,
    String? childSection,
  }) {
    final notifier = ref.read(registrationProvider.notifier);
    // Set edit mode so we UPDATE instead of CREATE
    notifier.setEditMode(parentId, [docId]);
    // Pre-fill the registration form with existing data
    notifier.loadExisting(
      parentName: parentName,
      mobileNumber: parentPhone,
      alternateMobile: parentAlternatePhone,
      children: [
        {
          'name': childName,
          'className': childClass,
          'section': childSection,
        },
      ],
    );
  }

  void _showStudentDetailSheet(
    BuildContext context,
    WidgetRef ref, {
    required String name,
    required String className,
    String? section,
    required String parentId,
    required String parentStatus,
    String? parentName,
    String? parentPhone,
    String? parentAlternatePhone,
    required bool hasFaceProfile,
    required _ParentInfo parentInfo,
    required String docId,
  }) {
    final displayParentName = parentName ?? parentInfo.label;
    final displayPhone = parentPhone ?? '';
    final displayAltPhone = parentAlternatePhone ?? '';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.textTertiary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text(name,
                style: GoogleFonts.nunito(
                    fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            _detailRow(Icons.school, 'Class',
                '$className${section != null ? ' · Section $section' : ''}'),
            const SizedBox(height: 12),
            _detailRow(parentInfo.icon, 'Parent', displayParentName),
            const SizedBox(height: 12),
            _detailRow(
              hasFaceProfile ? Icons.face : Icons.face_outlined,
              'Face Profile',
              hasFaceProfile ? 'AI trained ✓' : 'Not yet trained',
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _editStudent(
                    context: context,
                    ref: ref,
                    parentId: parentId,
                    parentName: displayParentName,
                    parentPhone: displayPhone,
                    parentAlternatePhone: displayAltPhone,
                    docId: docId,
                    childName: name,
                    childClass: className,
                    childSection: section,
                  );
                  context.push('/teacher/register');
                },
                icon: const Icon(Icons.edit, size: 18),
                label: Text('Edit Details',
                    style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w600)),
            Text(value,
                style: GoogleFonts.nunito(
                    fontSize: 15, fontWeight: FontWeight.w700)),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ParentInfo {
  final String label;
  final Color color;
  final IconData icon;
  const _ParentInfo(
      {required this.label, required this.color, required this.icon});
}