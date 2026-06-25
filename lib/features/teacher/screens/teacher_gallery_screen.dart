import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/avatar_widget.dart';
import '../../../data/models/photo_model.dart';
import '../../../data/repositories/photo_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/teacher_photo_provider.dart';

/// Teacher's uploaded photo gallery with tagging status.
///
/// Long press to enter multi-select mode → delete multiple photos.
/// Pending uploads show pulsing indicator.
class TeacherGalleryScreen extends ConsumerStatefulWidget {
  const TeacherGalleryScreen({super.key});

  @override
  ConsumerState<TeacherGalleryScreen> createState() => _TeacherGalleryScreenState();
}

class _TeacherGalleryScreenState extends ConsumerState<TeacherGalleryScreen> {
  String _filter = 'all';
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  void _toggleSelection(String photoId) {
    setState(() {
      if (_selectedIds.contains(photoId)) {
        _selectedIds.remove(photoId);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(photoId);
      }
    });
  }

  void _enterSelectionMode(String photoId) {
    setState(() {
      _selectionMode = true;
      _selectedIds.add(photoId);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _deleteSelected() async {
    final count = _selectedIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $count photo${count == 1 ? '' : 's'}?'),
        content: Text('This will permanently remove the selected photo${count == 1 ? '' : 's'} from storage.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final isMock = ref.read(authProvider).usingMockData;
    if (!isMock) {
      // Delete from Firebase
      final photos = ref.read(allTeacherPhotosProvider);
      for (final id in _selectedIds) {
        final photo = photos.firstWhere((p) => p.id == id);
        await PhotoRepository.deletePhoto(photo.id, photo.url);
      }
    }

    ref.read(teacherPhotoStateProvider.notifier).removePhotos(_selectedIds);
    _exitSelectionMode();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🗑️ $count photo${count == 1 ? '' : 's'} deleted'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showPhotoActions(BuildContext context, PhotoModel photo) {
    final isMock = ref.read(authProvider).usingMockData;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.textTertiary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: photo.url,
                  height: 120, width: 120, fit: BoxFit.cover,
                  placeholder: (_, __) => Container(height: 120, width: 120, color: AppColors.surfaceVariant),
                  errorWidget: (_, __, ___) => Container(height: 120, width: 120, color: AppColors.surfaceVariant, child: const Icon(Icons.broken_image)),
                ),
              ),
              const SizedBox(height: 12),
              Text(photo.caption?.isNotEmpty == true ? photo.caption! : 'Photo', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 4),
              Text('${photo.childIds.length} kid(s) tagged', style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textTertiary)),
              const SizedBox(height: 20), const Divider(),
              ListTile(
                leading: const Icon(Icons.visibility_outlined, color: AppColors.textPrimary),
                title: const Text('View'),
                onTap: () { Navigator.pop(ctx); context.push('/teacher/photo/${photo.id}', extra: photo); },
              ),
              ListTile(
                leading: const Icon(Icons.download_outlined, color: AppColors.primary),
                title: const Text('Download'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final uri = Uri.parse(photo.url);
                  if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
              ),
              // Multi-select entry
              ListTile(
                leading: const Icon(Icons.checklist_rounded, color: AppColors.accent),
                title: const Text('Select Multiple'),
                subtitle: const Text('Enter selection mode to delete many at once'),
                onTap: () { Navigator.pop(ctx); _enterSelectionMode(photo.id); },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
                title: const Text('Delete', style: TextStyle(color: AppColors.error)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Photo?'),
                      content: const Text('This will permanently remove the photo from storage.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: AppColors.error), child: const Text('Delete')),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    if (!isMock) await PhotoRepository.deletePhoto(photo.id, photo.url);
                    ref.read(teacherPhotoStateProvider.notifier).removePhoto(photo.id);
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('🗑️ Photo deleted'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating));
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final allPhotos = ref.watch(allTeacherPhotosProvider);
    final uploadState = ref.watch(uploadStateProvider);

    List<PhotoModel> filteredPhotos;
    switch (_filter) {
      case 'tagged': filteredPhotos = allPhotos.where((p) => p.childIds.isNotEmpty).toList(); break;
      case 'pending': filteredPhotos = allPhotos.where((p) => p.childIds.isEmpty).toList(); break;
      default: filteredPhotos = allPhotos;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: _selectionMode
            ? Text('${_selectedIds.length} selected', style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 18))
            : Text('My Gallery', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: _selectionMode
            ? IconButton(icon: const Icon(Icons.close), onPressed: _exitSelectionMode)
            : null,
        actions: [
          if (_selectionMode)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: AvatarWidget(name: authState.currentUser?.name ?? 'Teacher', size: 36),
            ),
        ],
      ),
      body: Column(
        children: [
          if (uploadState.isUploading)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.secondary.withValues(alpha: 0.06),
              child: Row(
                children: [
                  SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.secondary)),
                  const SizedBox(width: 10),
                  Text('${uploadState.totalFiles - uploadState.completedFiles} uploading...', style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.secondary)),
                ],
              ),
            ),

          // Filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _FilterChip(label: 'All', count: allPhotos.length, isSelected: _filter == 'all', onTap: () => setState(() => _filter = 'all')),
                const SizedBox(width: 8),
                _FilterChip(label: 'Tagged', count: allPhotos.where((p) => p.childIds.isNotEmpty).length, isSelected: _filter == 'tagged', color: AppColors.success, onTap: () => setState(() => _filter = 'tagged')),
                const SizedBox(width: 8),
                _FilterChip(label: 'Needs Review', count: allPhotos.where((p) => p.childIds.isEmpty).length, isSelected: _filter == 'pending', color: AppColors.warning, onTap: () => setState(() => _filter = 'pending')),
              ],
            ),
          ),

          const Divider(height: 1),

          Expanded(
            child: filteredPhotos.isEmpty
                ? Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Text('📸', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 12),
                      Text('No photos yet', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text(_filter == 'pending' ? 'All photos are tagged! 🎉' : 'Photos you add will appear here instantly', style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textTertiary)),
                    ]),
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
                        final isSelected = _selectedIds.contains(photo.id);
                        final isPending = isPhotoPending(photo);

                        return _TeacherPhotoCard(
                          photo: photo, index: index,
                          showWarning: isUntagged,
                          isSelected: isSelected,
                          isPending: isPending,
                          selectionMode: _selectionMode,
                          uploadStatus: uploadState.fileUploadStatus[photo.id],
                          onTap: () {
                            if (_selectionMode) {
                              _toggleSelection(photo.id);
                            } else {
                              context.push('/teacher/photo/${photo.id}', extra: photo);
                            }
                          },
                          onLongPress: () {
                            if (!_selectionMode) _showPhotoActions(context, photo);
                          },
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label; final int count; final bool isSelected; final Color? color; final VoidCallback onTap;
  const _FilterChip({required this.label, required this.count, required this.isSelected, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? chipColor.withValues(alpha: 0.12) : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? Border.all(color: chipColor, width: 1.5) : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: GoogleFonts.nunito(fontSize: 13, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600, color: isSelected ? chipColor : AppColors.textSecondary)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(color: isSelected ? chipColor : AppColors.textTertiary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
            child: Text('$count', style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700, color: isSelected ? AppColors.white : AppColors.textTertiary)),
          ),
        ]),
      ),
    );
  }
}

class _TeacherPhotoCard extends StatelessWidget {
  final PhotoModel photo; final int index; final bool showWarning;
  final bool isSelected; final bool isPending; final bool selectionMode;
  final String? uploadStatus;
  final VoidCallback onTap; final VoidCallback onLongPress;

  const _TeacherPhotoCard({
    required this.photo, required this.index, required this.showWarning,
    required this.isSelected, required this.isPending, required this.selectionMode,
    this.uploadStatus, required this.onTap, required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final height = (index % 3 == 0) ? 200.0 : 160.0;
    final showUploadOverlay = isPending || uploadStatus == 'uploading' || uploadStatus == 'pending';

    return GestureDetector(
      onTap: onTap, onLongPress: onLongPress,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppColors.shadow.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2))],
          border: isSelected ? Border.all(color: AppColors.primary, width: 3) : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Cached image with disk cache
              if (isPending || photo.url.startsWith('/'))
                Image.file(File(photo.url), fit: BoxFit.cover, cacheWidth: 400, errorBuilder: (_, __, ___) => _placeholder())
              else
                CachedNetworkImage(
                  imageUrl: photo.url,
                  fit: BoxFit.cover,
                  memCacheWidth: 400,
                  placeholder: (_, __) => _placeholder(),
                  errorWidget: (_, __, ___) => _placeholder(),
                ),

              // Upload overlay
              if (showUploadOverlay)
                Container(
                  color: Colors.black38,
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
                      const SizedBox(height: 8),
                      Text(uploadStatus == 'uploading' ? 'Uploading...' : 'Pending', style: GoogleFonts.nunito(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),

              // Selection checkbox
              if (selectionMode)
                Positioned(
                  top: 8, left: 8,
                  child: Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.white.withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                      border: Border.all(color: isSelected ? AppColors.primary : AppColors.textTertiary, width: 2),
                    ),
                    child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                  ),
                ),

              // Status badge (not pending)
              if (!showUploadOverlay)
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: showWarning ? AppColors.warning : AppColors.success.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(showWarning ? Icons.warning_amber_rounded : Icons.check_circle, color: Colors.white, size: 12),
                      const SizedBox(width: 4),
                      Text(showWarning ? 'Tag' : 'Done', style: GoogleFonts.nunito(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),

              // Bottom bar
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, Colors.black54], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
                  child: Text(
                    showUploadOverlay ? 'Uploading...' : photo.childIds.isEmpty ? 'Tap to tag' : '${photo.childIds.length} kid(s)',
                    style: GoogleFonts.nunito(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() => Container(color: AppColors.surfaceVariant, child: const Center(child: Icon(Icons.image_outlined, color: AppColors.textTertiary, size: 32)));
}