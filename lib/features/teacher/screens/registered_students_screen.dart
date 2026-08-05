import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
            icon: const Icon(Icons.person_add_alt_rounded, color: AppColors.primary),
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

  Future<Map<String, Map<String, dynamic>>> _fetchParents(
      List<QueryDocumentSnapshot> children) async {
    final parentIds = children
        .map((d) => (d.data() as Map<String, dynamic>)['parentId'] as String?)
        .where((id) => id != null && id.isNotEmpty)
        .toSet();
    final parents = <String, Map<String, dynamic>>{};
    for (final id in parentIds) {
      try {
        final doc = await FirebaseFirestore.instance.collection('parents').doc(id!).get();
        if (doc.exists) parents[id] = doc.data()!;
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
              // Avatar
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                child: photoUrl == null
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              // Info — stacked vertically
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(name, style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 3),
                    // Class
                    Row(children: [
                      Icon(Icons.school_outlined, size: 13, color: AppColors.secondary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '$className${section != null ? ' · $section' : ''}',
                          style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.secondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 2),
                    // Parent
                    Row(children: [
                      Icon(parentInfo.icon, size: 13, color: parentInfo.color),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          parentInfo.label,
                          style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: parentInfo.color),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Face status — icon only
              Icon(
                hasFaceProfile ? Icons.check_circle : Icons.warning_amber_rounded,
                size: 22,
                color: hasFaceProfile ? AppColors.success : AppColors.warning,
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  _ParentInfo _resolveParentInfo(String? parentName, String status) {
    if (parentName != null && parentName.isNotEmpty) {
      return _ParentInfo(label: parentName, color: AppColors.textSecondary, icon: Icons.person);
    }
    final isPending = status == 'pending_completion' || status == 'invited';
    if (isPending) {
      return _ParentInfo(label: 'Awaiting parent setup', color: AppColors.info, icon: Icons.person_outline);
    }
    return _ParentInfo(label: 'Parent not linked', color: AppColors.textTertiary, icon: Icons.person_outline);
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
    notifier.setEditMode(parentId, [docId]);
    notifier.loadExisting(
      parentName: parentName,
      mobileNumber: parentPhone,
      alternateMobile: parentAlternatePhone,
      children: [
        {'name': childName, 'className': childClass, 'section': childSection},
      ],
    );
  }

  Future<void> _deleteStudent({
    required BuildContext context,
    required String docId,
    required String name,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Delete Student?', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: Text('This will permanently delete "$name" and their photo data.\n\nThis action cannot be undone.',
            style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Delete', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      // Delete Firestore document
      await FirebaseFirestore.instance.collection('children').doc(docId).delete();
      // Delete enrollment photos from Storage
      try {
        final storageRef = FirebaseStorage.instance.ref().child('children/$docId');
        final listResult = await storageRef.listAll();
        for (final item in listResult.items) {
          await item.delete();
        }
      } catch (_) {}
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$name" deleted'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
            Text(name, style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            _detailRow(Icons.school, 'Class', '$className${section != null ? ' · Section $section' : ''}'),
            const SizedBox(height: 12),
            _detailRow(parentInfo.icon, 'Parent', displayParentName),
            const SizedBox(height: 12),
            _detailRow(
              hasFaceProfile ? Icons.check_circle : Icons.warning_amber_rounded,
              'Face Profile',
              hasFaceProfile ? 'Completed' : 'Pending',
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
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
                      label: Text('Edit', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _deleteStudent(context: context, docId: docId, name: name);
                      },
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: Text('Delete', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ),
              ],
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
            Text(label, style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textTertiary, fontWeight: FontWeight.w600)),
            Text(value, style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700)),
          ],
        ),
      ],
    );
  }
}

class _ParentInfo {
  final String label;
  final Color color;
  final IconData icon;
  const _ParentInfo({required this.label, required this.color, required this.icon});
}