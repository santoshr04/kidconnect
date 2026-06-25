import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/mock/mock_data.dart';
import '../../auth/providers/auth_provider.dart';

/// Parent face enrollment screen.
///
/// Parents take 3-5 photos of their child's face.
/// These are used by the AI to recognize the child in class photos.
class FaceEnrollmentScreen extends ConsumerStatefulWidget {
  const FaceEnrollmentScreen({super.key});

  @override
  ConsumerState<FaceEnrollmentScreen> createState() =>
      _FaceEnrollmentScreenState();
}

class _FaceEnrollmentScreenState extends ConsumerState<FaceEnrollmentScreen> {
  final ImagePicker _picker = ImagePicker();
  final List<File> _facePhotos = [];
  bool _isSaving = false;

  Future<void> _takePhoto() async {
    if (_facePhotos.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Maximum 5 photos reached'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
      maxWidth: 800,
      maxHeight: 800,
    );

    if (photo != null) {
      setState(() => _facePhotos.add(File(photo.path)));
    }
  }

  Future<void> _pickFromGallery() async {
    final remaining = 5 - _facePhotos.length;
    if (remaining <= 0) return;

    final photos = await _picker.pickMultiImage(
      imageQuality: 90,
      limit: remaining,
    );

    if (photos.isNotEmpty) {
      setState(() {
        _facePhotos.addAll(photos.map((p) => File(p.path)));
        if (_facePhotos.length > 5) {
          _facePhotos.removeRange(5, _facePhotos.length);
        }
      });
    }
  }

  void _removePhoto(int index) {
    setState(() => _facePhotos.removeAt(index));
  }

  Future<void> _saveFaceProfile() async {
    if (_facePhotos.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please add at least 3 photos for best results'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    // In production: upload to Firebase Storage → save references to Firestore
    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✅ Face profile saved! AI can now recognize your child.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/parent/gallery');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final childId = authState.selectedChildId ?? 'child_1';
    final child = MockData.getChildById(childId);
    final progress = _facePhotos.length / 5.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Face Enrollment',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.purpleGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.face_retouching_natural,
                      color: AppColors.white, size: 36),
                  const SizedBox(height: 12),
                  Text(
                    'Help AI Recognize ${child?.firstName ?? "Your Child"}',
                    style: GoogleFonts.nunito(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Take 3-5 clear photos of your child\'s face. The AI uses these to find your child in class photos automatically.',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      color: AppColors.white.withValues(alpha: 0.85),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Progress indicator
            Row(
              children: [
                Text(
                  '${_facePhotos.length} of 5 photos',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _facePhotos.length >= 3
                        ? AppColors.success.withValues(alpha: 0.12)
                        : AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _facePhotos.length >= 3 ? '✅ Ready' : 'Need ${3 - _facePhotos.length} more',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _facePhotos.length >= 3
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: AppColors.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress >= 0.6 ? AppColors.success : AppColors.primary,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        _facePhotos.length >= 5 ? null : _takePhoto,
                    icon: const Icon(Icons.camera_alt_rounded, size: 20),
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
                    onPressed:
                        _facePhotos.length >= 5 ? null : _pickFromGallery,
                    icon: const Icon(Icons.photo_library_rounded, size: 20),
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

            // Photo previews
            if (_facePhotos.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add_a_photo_outlined,
                            size: 36, color: AppColors.primary),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No photos yet',
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.85,
                ),
                itemCount: _facePhotos.length + (_facePhotos.length < 5 ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= _facePhotos.length) {
                    // Add more placeholder
                    return GestureDetector(
                      onTap: _pickFromGallery,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.border,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_rounded,
                                color: AppColors.textTertiary, size: 28),
                            const SizedBox(height: 4),
                            Text(
                              'Add',
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return _FacePhotoTile(
                    file: _facePhotos[index],
                    index: index + 1,
                    onRemove: () => _removePhoto(index),
                  );
                },
              ),

            const SizedBox(height: 32),

            // Tips
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.skyBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lightbulb_outline,
                          color: AppColors.skyBlue, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Tips for best results',
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.skyBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _tip('Use good lighting (natural daylight is best)'),
                  _tip('Face should be clearly visible, no sunglasses or masks'),
                  _tip('Take photos from different angles (front, slight left, slight right)'),
                  _tip('Include a neutral expression photo'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: (_facePhotos.length >= 3 && !_isSaving)
                    ? _saveFaceProfile
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.white,
                        ),
                      )
                    : Text(
                        _facePhotos.length < 3
                            ? 'Add ${3 - _facePhotos.length} More Photo${_facePhotos.length < 2 ? '' : 's'}'
                            : 'Save Face Profile',
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _tip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ', style: TextStyle(color: AppColors.skyBlue, fontSize: 14)),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FacePhotoTile extends StatelessWidget {
  final File file;
  final int index;
  final VoidCallback onRemove;

  const _FacePhotoTile({
    required this.file,
    required this.index,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.file(
            file,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
        Positioned(
          top: 6,
          left: 6,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '$index',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.white,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }
}