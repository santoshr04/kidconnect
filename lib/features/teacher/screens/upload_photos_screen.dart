import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/avatar_widget.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/teacher_photo_provider.dart';

/// Smart Bulk Upload Screen for Teachers.
///
/// Teachers select photos → compress to WebP → upload to Firebase Storage.
/// Progress bar with real byte progress. Survives tab switches.
class UploadPhotosScreen extends ConsumerStatefulWidget {
  const UploadPhotosScreen({super.key});

  @override
  ConsumerState<UploadPhotosScreen> createState() => _UploadPhotosScreenState();
}

class _UploadPhotosScreenState extends ConsumerState<UploadPhotosScreen> {
  final ImagePicker _picker = ImagePicker();
  final List<File> _selectedFiles = [];

  Future<void> _pickImages() async {
    final images = await _picker.pickMultiImage(imageQuality: 90);
    if (images.isNotEmpty) {
      setState(() {
        _selectedFiles.addAll(images.map((x) => File(x.path)));
      });
    }
  }

  Future<void> _takePhoto() async {
    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
    if (photo != null) {
      setState(() => _selectedFiles.add(File(photo.path)));
    }
  }

  void _startUpload() {
    if (_selectedFiles.isEmpty) return;
    final user = ref.read(authProvider).currentUser;
    final uploadedBy = user?.id ?? 'teacher_1';

    // Copy files before clearing (notifier takes ownership)
    final files = List<File>.from(_selectedFiles);
    setState(() => _selectedFiles.clear());

    // Background upload via notifier — survives tab switches
    ref.read(uploadStateProvider.notifier).uploadPhotos(files, uploadedBy);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final uploadState = ref.watch(uploadStateProvider);
    final isMock = authState.usingMockData;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Bulk Upload',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          if (isMock)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: Text('MOCK',
                    style: GoogleFonts.nunito(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.warning)),
                backgroundColor: AppColors.warningLight,
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: AvatarWidget(
              name: authState.currentUser?.name ?? 'Teacher',
              size: 36,
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Upload progress banner (persistent across tabs)
            if (uploadState.isUploading || uploadState.phase == 'done')
              _UploadProgressBanner(state: uploadState),

            if (uploadState.isUploading || uploadState.phase == 'done')
              const SizedBox(height: 20),

            // Camera & Gallery buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: uploadState.isUploading ? null : _takePhoto,
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: const Text('Camera'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: uploadState.isUploading ? null : _pickImages,
                    icon: const Icon(Icons.photo_library_rounded),
                    label: const Text('Gallery'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Selected photos count
            if (_selectedFiles.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.photo_rounded,
                      color: AppColors.secondary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${_selectedFiles.length} photos ready',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _startUpload,
                    icon: const Icon(Icons.cloud_upload_outlined, size: 20),
                    label: const Text('Upload'),
                  ),
                ],
              ),

            if (_selectedFiles.isNotEmpty)
              TextButton.icon(
                onPressed: () => setState(() => _selectedFiles.clear()),
                icon: const Icon(Icons.clear, size: 18),
                label: const Text('Clear Selection'),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
              ),

            // Empty state
            if (_selectedFiles.isEmpty && !uploadState.isUploading)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add_photo_alternate_outlined,
                            size: 40, color: AppColors.secondary),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tap Camera or Gallery to start',
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Photos are compressed to WebP before upload',
                        style: GoogleFonts.nunito(
                            color: AppColors.textTertiary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              )
            else
              const Spacer(),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// Animated upload progress banner with phase indicators.
class _UploadProgressBanner extends StatelessWidget {
  final UploadState state;

  const _UploadProgressBanner({required this.state});

  @override
  Widget build(BuildContext context) {
    final isDone = state.phase == 'done';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDone ? AppColors.success.withValues(alpha: 0.08) : AppColors.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDone
              ? AppColors.success.withValues(alpha: 0.2)
              : AppColors.secondary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          // Phase steps
          Row(
            children: [
              _PhaseStep(
                icon: Icons.compress,
                label: 'Compress',
                isActive: state.phase == 'compressing',
                isComplete: state.phase == 'uploading' || isDone,
              ),
              Expanded(
                child: Container(
                  height: 2,
                  color: (state.phase == 'uploading' || isDone)
                      ? AppColors.secondary
                      : AppColors.textTertiary.withValues(alpha: 0.3),
                ),
              ),
              _PhaseStep(
                icon: Icons.cloud_upload_outlined,
                label: 'Upload',
                isActive: state.phase == 'uploading',
                isComplete: isDone,
              ),
              Expanded(
                child: Container(
                  height: 2,
                  color: isDone
                      ? AppColors.success
                      : AppColors.textTertiary.withValues(alpha: 0.3),
                ),
              ),
              _PhaseStep(
                icon: Icons.check_circle_outline,
                label: 'Done',
                isActive: isDone,
                isComplete: isDone,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Progress bar
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: state.progress,
                minHeight: 8,
                backgroundColor: AppColors.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDone ? AppColors.success : AppColors.secondary,
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Status text
          Row(
            children: [
              if (!isDone)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.secondary,
                  ),
                )
              else
                const Icon(Icons.check_circle,
                    color: AppColors.success, size: 16),
              const SizedBox(width: 8),
              Text(
                state.statusMessage,
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w600,
                  color: isDone ? AppColors.success : AppColors.secondary,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Text(
                '${state.completedFiles}/${state.totalFiles}',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhaseStep extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool isComplete;

  const _PhaseStep({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.isComplete,
  });

  @override
  Widget build(BuildContext context) {
    final color = isComplete
        ? AppColors.success
        : isActive
            ? AppColors.secondary
            : AppColors.textTertiary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive || isComplete
                ? color.withValues(alpha: 0.15)
                : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}