import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/insight_face_service.dart';
import '../../../data/mock/mock_data.dart';
import '../../auth/providers/auth_provider.dart';

class FaceEnrollmentScreen extends ConsumerStatefulWidget {
  final String? childId;
  final String? childName;
  const FaceEnrollmentScreen({super.key, this.childId, this.childName});
  @override ConsumerState<FaceEnrollmentScreen> createState() => _FaceEnrollmentScreenState();
}

class _FaceEnrollmentScreenState extends ConsumerState<FaceEnrollmentScreen> {
  final List<File> _photos = [];
  final ImagePicker _picker = ImagePicker();
  bool _isEnrolling = false;
  String _statusMessage = '';

  Future<void> _pickPhotos() async {
    final remaining = 10 - _photos.length;
    if (remaining <= 0) return;
    final picked = await _picker.pickMultiImage(imageQuality: 90, limit: remaining);
    if (picked != null) setState(() => _photos.addAll(picked.map((x) => File(x.path))));
  }

  Future<void> _takePhoto() async {
    if (_photos.length >= 10) return;
    final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 90);
    if (picked != null) setState(() => _photos.add(File(picked.path)));
  }

  Future<void> _enroll() async {
    if (_photos.isEmpty) return;
    final authState = ref.read(authProvider);
    final cId = widget.childId ?? authState.selectedChildId ?? 'child_1';
    final cName = widget.childName ?? MockData.getChildById(cId)?.firstName ?? 'Child';

    setState(() { _isEnrolling = true; _statusMessage = 'Enrolling $cName...'; });
    int success = 0;
    for (int i = 0; i < _photos.length; i++) {
      try {
        final bytes = await _photos[i].readAsBytes();
        final result = await InsightFaceService.enrollChild(childId: cId, name: cName, faceBytes: bytes);
        if (result['success'] == true) success++;
        setState(() => _statusMessage = 'Processing ${i + 1}/${_photos.length}...');
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _isEnrolling = false;
      _statusMessage = success > 0 ? 'Enrolled $success photos!' : 'Enrollment failed';
    });
    if (success > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$cName enrolled with $success photos!'), backgroundColor: AppColors.success));
    }
  }

  void _removePhoto(int index) => setState(() => _photos.removeAt(index));

  @override Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final cId = widget.childId ?? authState.selectedChildId ?? 'child_1';
    final cName = widget.childName ?? MockData.getChildById(cId)?.firstName ?? 'Child';
    final remaining = 10 - _photos.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/parent/gallery'),
        ),
        title: Text('Enroll $cName',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      ),
      body: Column(children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            'Add up to 10 photos in different angles. More photos = better recognition.',
            style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
        Expanded(
          child: _photos.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add_a_photo, size: 64, color: AppColors.textTertiary.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  Text('Add photos of $cName',
                    style: GoogleFonts.nunito(fontSize: 15, color: AppColors.textTertiary)),
                ]))
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _photos.length,
                  itemBuilder: (ctx, i) => Stack(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_photos[i],
                        fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                    ),
                    Positioned(
                      top: 4, right: 4,
                      child: GestureDetector(
                        onTap: () => _removePhoto(i),
                        child: Container(
                          width: 28, height: 28,
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
        ),
        if (_statusMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(_statusMessage,
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: _isEnrolling ? AppColors.warning : AppColors.success,
              )),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: remaining <= 0 ? null : _pickPhotos,
                icon: const Icon(Icons.photo_library),
                label: Text('Gallery ($remaining left)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: remaining <= 0 ? null : _takePhoto,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Camera'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: (_isEnrolling || _photos.isEmpty) ? null : _enroll,
              icon: _isEnrolling
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.fingerprint),
              label: Text(
                _isEnrolling ? 'Enrolling...' : "Enroll $cName's Face",
                style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}