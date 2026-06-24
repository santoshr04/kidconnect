import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/avatar_widget.dart';
import '../../../data/repositories/photo_repository.dart';
import '../../auth/providers/auth_provider.dart';

/// Smart Bulk Upload Screen for Teachers.
///
/// Teachers select photos → AI (future ML Kit) detects faces →
/// auto-tags children → uploads to Firebase Storage.
/// Falls back to simulated upload in mock mode.
class UploadPhotosScreen extends ConsumerStatefulWidget {
  const UploadPhotosScreen({super.key});

  @override
  ConsumerState<UploadPhotosScreen> createState() => _UploadPhotosScreenState();
}

class _UploadPhotosScreenState extends ConsumerState<UploadPhotosScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  double _uploadProgress = 0;
  String _statusMessage = 'Select photos to upload';
  final List<File> _selectedFiles = [];
  int _autoTaggedCount = 0;
  int _needsReviewCount = 0;

  Future<void> _pickImages() async {
    final images = await _picker.pickMultiImage(
      imageQuality: 85,
    );

    if (images.isNotEmpty) {
      setState(() {
        _selectedFiles.addAll(images.map((x) => File(x.path)));
        _statusMessage = '${_selectedFiles.length} photos selected';
      });
    }
  }

  Future<void> _takePhoto() async {
    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    if (photo != null) {
      setState(() {
        _selectedFiles.add(File(photo.path));
        _statusMessage = '${_selectedFiles.length} photos selected';
      });
    }
  }

  Future<void> _uploadPhotos() async {
    if (_selectedFiles.isEmpty) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
      _autoTaggedCount = 0;
      _needsReviewCount = 0;
      _statusMessage = 'Uploading ${_selectedFiles.length} photos...';
    });

    final user = ref.read(authProvider).currentUser;
    final isMock = ref.read(authProvider).usingMockData;

    if (isMock) {
      // Simulate upload with progress (mock mode)
      for (int i = 1; i <= 100; i++) {
        await Future.delayed(const Duration(milliseconds: 30));
        if (!mounted) return;
        setState(() {
          _uploadProgress = i / 100;
          if (i == 40) _statusMessage = 'Compressing to WebP...';
          if (i == 60) _statusMessage = 'Running AI Face Detection...';
          if (i == 90) {
            _autoTaggedCount = _selectedFiles.length - 1;
            _needsReviewCount = 1;
          }
        });
      }

      setState(() {
        _statusMessage = 'Done! $_autoTaggedCount auto-tagged, $_needsReviewCount need review';
      });
    } else {
      // Real Firebase upload
      for (int i = 0; i < _selectedFiles.length; i++) {
        await PhotoRepository.uploadPhoto(
          file: _selectedFiles[i],
          caption: '',
          uploadedBy: user?.id ?? 'unknown',
        );

        if (!mounted) return;
        setState(() {
          _uploadProgress = (i + 1) / _selectedFiles.length;
          _statusMessage = 'Uploaded ${i + 1}/${_selectedFiles.length}';
        });
      }

      setState(() {
        _autoTaggedCount = _selectedFiles.length;
        _statusMessage = 'All ${_selectedFiles.length} photos uploaded!';
      });
    }

    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isMock
                ? '✅ $_autoTaggedCount photos auto-tagged! (Mock mode)'
                : '✅ ${_selectedFiles.length} photos uploaded!',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      setState(() {
        _isUploading = false;
        _selectedFiles.clear();
        _uploadProgress = 0;
        _statusMessage = 'Ready for next batch';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isMock = authState.usingMockData;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Bulk Upload',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
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
            child: AvatarWidget(
              name: authState.currentUser?.name ?? 'Teacher',
              size: 36,
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── AI Engine Info ─────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: AppColors.secondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isMock
                          ? '🔧 Mock Mode — Firebase not configured yet. Photos will simulate AI tagging.'
                          : '📸 Take or select photos. AI will auto-detect and tag kids.',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ─── Camera & Gallery Buttons ───────────────────
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isUploading ? null : _takePhoto,
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
                    onPressed: _isUploading ? null : _pickImages,
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

            // ─── Selected Photos Count ──────────────────────
            if (_selectedFiles.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.photo_rounded, color: AppColors.secondary, size: 20),
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
                  if (!_isUploading)
                    TextButton.icon(
                      onPressed: _uploadPhotos,
                      icon: const Icon(Icons.cloud_upload_outlined, size: 20),
                      label: const Text('Upload'),
                    ),
                ],
              ),

            if (_selectedFiles.isNotEmpty) const SizedBox(height: 16),

            // ─── Upload Progress ────────────────────────────
            if (_isUploading)
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _uploadProgress,
                      minHeight: 8,
                      backgroundColor: AppColors.surfaceVariant,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(AppColors.secondary),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _statusMessage,
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondary,
                      fontSize: 14,
                    ),
                  ),
                  if (_needsReviewCount > 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.warningLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '⚠ $_needsReviewCount photo(s) need manual review',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ],
              ),

            if (!_isUploading && _selectedFiles.isNotEmpty)
              TextButton.icon(
                onPressed: () => setState(() => _selectedFiles.clear()),
                icon: const Icon(Icons.clear, size: 18),
                label: const Text('Clear Selection'),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
              ),

            // ─── Empty State or flexible spacer ─────────────
            if (_selectedFiles.isEmpty && !_isUploading)
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
                        child: const Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 40,
                          color: AppColors.secondary,
                        ),
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
                        'AI will auto-tag kids in each photo',
                        style: GoogleFonts.nunito(color: AppColors.textTertiary, fontSize: 13),
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