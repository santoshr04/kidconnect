import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/mock/mock_data.dart';

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
            onPressed: () => context.push('/teacher/register'),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('children')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          // Loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Error or empty → show mock children
          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildMockList();
          }

          final children = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: children.length,
            itemBuilder: (context, index) {
              final doc = children[index];
              final data = doc.data() as Map<String, dynamic>;
              return _buildStudentCard(
                name: data['name'] ?? 'Unknown',
                className: data['className'] ?? 'N/A',
                section: data['section'],
                parentId: data['parentId'] ?? '',
                photoUrl: data['photoUrl'],
                hasFaceProfile: data['hasFaceProfile'] ?? false,
                enrolledFaceCount: data['enrolledFaceCount'] ?? 0,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMockList() {
    final children = MockData.children;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: children.length,
      itemBuilder: (context, index) {
        final child = children[index];
        return _buildStudentCard(
          name: child.name,
          className: child.className,
          section: child.section,
          parentId: child.parentId,
          photoUrl: child.avatarUrl,
          hasFaceProfile: child.hasFaceProfile,
          enrolledFaceCount: child.enrolledFaceCount,
        );
      },
    );
  }

  Widget _buildStudentCard({
    required String name,
    required String className,
    String? section,
    required String parentId,
    String? photoUrl,
    required bool hasFaceProfile,
    required int enrolledFaceCount,
  }) {
    final parentName = MockData.getUserById(parentId)?.name ?? 'Unknown Parent';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
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
            // Info
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
                          AppColors.secondary),
                      const SizedBox(width: 8),
                      _buildInfoChip(
                          parentName,
                          AppColors.textSecondary),
                    ],
                  ),
                ],
              ),
            ),
            // Face status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}