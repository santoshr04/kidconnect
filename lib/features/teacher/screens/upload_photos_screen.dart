import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/avatar_widget.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/teacher_photo_provider.dart';

/// WhatsApp-style upload: instant gallery preview + background upload.
/// Auto-navigates to My Gallery after picking photos.
class UploadPhotosScreen extends ConsumerStatefulWidget {
  const UploadPhotosScreen({super.key});

  @override
  ConsumerState<UploadPhotosScreen> createState() => _UploadPhotosScreenState();
}

class _UploadPhotosScreenState extends ConsumerState<UploadPhotosScreen> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImages() async {
    final images = await _picker.pickMultiImage(imageQuality: 90);
    if (images.isNotEmpty) {
      _addToGalleryAndNavigate(images.map((x) => File(x.path)).toList());
    }
  }

  Future<void> _takePhoto() async {
    final photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 90);
    if (photo != null) {
      _addToGalleryAndNavigate([File(photo.path)]);
    }
  }

  void _addToGalleryAndNavigate(List<File> files) {
    final user = ref.read(authProvider).currentUser;
    final uploadedBy = user?.id ?? 'teacher_1';

    // 1. Instantly add to gallery with local previews
    ref.read(teacherPhotoStateProvider.notifier).addPendingPhotos(files, uploadedBy);

    // 2. Start background upload
    final localIds = ref.read(teacherPhotoStateProvider).uploadedPhotos
        .where((p) => isPhotoPending(p))
        .map((p) => p.id)
        .toList()
        .take(files.length)
        .toList();

    ref.read(uploadStateProvider.notifier).uploadPhotos(files, uploadedBy, localIds);

    // 3. AUTO-NAVIGATE to gallery so teacher sees progress
    context.go('/teacher/gallery');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final uploadState = ref.watch(uploadStateProvider);
    final isMock = authState.usingMockData;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Upload Photos', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          if (isMock)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: Text('MOCK', style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.warning)),
                backgroundColor: AppColors.warningLight,
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: AvatarWidget(name: authState.currentUser?.name ?? 'Teacher', size: 36),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Upload progress banner
            if (uploadState.isUploading || uploadState.phase == 'done')
              _CompactProgressBanner(state: uploadState),

            if (uploadState.isUploading || uploadState.phase == 'done')
              const SizedBox(height: 20),

            // Camera & Gallery buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _takePhoto,
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: const Text('Camera'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickImages,
                    icon: const Icon(Icons.photo_library_rounded),
                    label: const Text('Gallery'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Register New Student ──────────────────────
            GestureDetector(
              onTap: () => context.push('/teacher/register'),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: AppColors.sunsetGradient,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_add_alt_rounded,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Register New Student',
                              style: GoogleFonts.nunito(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                          const SizedBox(height: 2),
                          Text('Add a new family in under 30 seconds',
                              style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios,
                        color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Info card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.secondary.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.flash_on_rounded, color: AppColors.secondary, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Instant Upload ⚡', style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                        const SizedBox(height: 4),
                        Text('Pick photos → auto-navigates to gallery.', style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 80, height: 80, decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.08), shape: BoxShape.circle), child: const Icon(Icons.add_photo_alternate_outlined, size: 40, color: AppColors.secondary)),
                const SizedBox(height: 16),
                Text('Tap to add photos', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: AppColors.textSecondary, fontSize: 16)),
              ]),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _CompactProgressBanner extends StatelessWidget {
  final UploadState state;
  const _CompactProgressBanner({required this.state});

  @override
  Widget build(BuildContext context) {
    final isDone = state.phase == 'done';
    final pending = state.fileUploadStatus.values.where((s) => s == 'pending' || s == 'uploading').length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDone ? AppColors.success.withValues(alpha: 0.08) : AppColors.secondary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDone ? AppColors.success.withValues(alpha: 0.2) : AppColors.secondary.withValues(alpha: 0.15)),
      ),
      child: Row(children: [
        if (!isDone) SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.secondary))
        else const Icon(Icons.cloud_done_rounded, color: AppColors.success, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(isDone ? state.statusMessage : '$pending uploading...', style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600))),
        Text('${state.completedFiles}/${state.totalFiles}', style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textTertiary)),
      ]),
    );
  }
}