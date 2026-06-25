import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/avatar_widget.dart';
import '../../../data/models/photo_model.dart';
import '../../../data/repositories/photo_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/teacher_photo_provider.dart';

/// Teacher's uploaded photo gallery with tagging status.
///
/// Shows all photos uploaded by this teacher with status badges:
/// ✅ Tagged | ⚠ Needs Review
/// Long press for delete/download.
class TeacherGalleryScreen extends ConsumerStatefulWidget {
  const TeacherGalleryScreen({super.key});

  @override
  ConsumerState<TeacherGalleryScreen> createState() =>
      _TeacherGalleryScreenState();
}

class _TeacherGalleryScreenState extends ConsumerState<TeacherGalleryScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final allPhotos = ref.watch(allTeacherPhotosProvider);

    List<PhotoModel> filteredPhotos;
    switch (_filter) {
      case 'tagged':
        filteredPhotos = allPhotos.where((p) => p.childIds.isNotEmpty).toList();
        break;
      case 'pending':
        filteredPhotos = allPhotos.where((p) => p.childIds.isEmpty).toList();
        break;
      default:
        filteredPhotos = allPhotos;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('My Gallery',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: AvatarWidget(
              name: authState.currentUser?.name ?? 'Teacher',
              size: 36,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  count: allPhotos.length,
                  isSelected: _filter == 'all',
                  onTap: () => setState(() => _filter = 'all'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Tagged',
                  count: allPhotos.where((p) => p.childIds.isNotEmpty).length,
                  isSelected: _filter == 'tagged',
                  color: AppColors.success,
                  onTap: () => setState(() => _filter = 'tagged'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Needs Review',
                  count: allPhotos.where((p) => p.childIds.isEmpty).length,
                  isSelected: _filter == 'pending',
                  color: AppColors.warning,
                  onTap: () => setState(() => _filter = 'pending'),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Photo grid
          Expanded(
            child: filteredPhotos.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('📸', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text(
                          _filter == 'pending'
                              ? 'No photos need review! 🎉'
                              : 'No photos uploaded yet',
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(12),
                    child: MasonryGridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      itemCount: filteredPhotos.length,
                      itemBuilder: (context, index) {
                        final photo = filteredPhotos[index];
                        final isUntagged = photo.childIds.isEmpty;
                        return _TeacherPhotoCard(
                          photo: photo,
                          index: index,
                          showWarning: isUntagged,
                          onTap: () => context.push(
                            '/teacher/photo/${photo.id}',
                            extra: photo,
                          ),
                          onLongPress: () => _showPhotoActions(context, photo),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showPhotoActions(BuildContext context, PhotoModel photo) {
    final isMock = ref.read(authProvider).usingMockData;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Preview
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  photo.url,
                  height: 120,
                  width: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(height: 120, width: 120, color: AppColors.surfaceVariant),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                photo.caption?.isNotEmpty == true ? photo.caption! : 'Photo',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${photo.childIds.length} kid(s) tagged',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),

              const SizedBox(height: 20),
              const Divider(),

              // View
              ListTile(
                leading: const Icon(Icons.visibility_outlined, color: AppColors.textPrimary),
                title: const Text('View'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/teacher/photo/${photo.id}', extra: photo);
                },
              ),

              // Download
              ListTile(
                leading: const Icon(Icons.download_outlined, color: AppColors.primary),
                title: const Text('Download'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final uri = Uri.parse(photo.url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),

              // Delete
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
                title: const Text('Delete', style: TextStyle(color: AppColors.error)),
                onTap: () async {
                  Navigator.pop(ctx);

                  // Confirm
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Photo?'),
                      content: const Text('This will permanently remove the photo from storage.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: TextButton.styleFrom(foregroundColor: AppColors.error),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    if (!isMock) {
                      await PhotoRepository.deletePhoto(photo.id, photo.url);
                    }
                    ref.read(teacherPhotoStateProvider.notifier).removePhoto(photo.id);

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('🗑️ Photo deleted'),
                          backgroundColor: AppColors.error,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.isSelected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? chipColor.withValues(alpha: 0.12)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border:
              isSelected ? Border.all(color: chipColor, width: 1.5) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? chipColor : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? chipColor
                    : AppColors.textTertiary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? AppColors.white : AppColors.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeacherPhotoCard extends StatelessWidget {
  final PhotoModel photo;
  final int index;
  final bool showWarning;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _TeacherPhotoCard({
    required this.photo,
    required this.index,
    required this.showWarning,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final height = (index % 3 == 0) ? 200.0 : 160.0;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail — cache_network_image for fast loading
              Image.network(
                photo.url,
                fit: BoxFit.cover,
                cacheWidth: 400, // Scale down for gallery view
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.surfaceVariant,
                  child: const Icon(Icons.broken_image,
                      color: AppColors.textTertiary),
                ),
              ),

              // Status badge
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: showWarning
                        ? AppColors.warning
                        : AppColors.success.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        showWarning
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle,
                        color: Colors.white,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        showWarning ? 'Tag' : 'Done',
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Child count bottom bar
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black54],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Text(
                    photo.childIds.isEmpty
                        ? 'Long press for options'
                        : '${photo.childIds.length} kid(s) tagged',
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}