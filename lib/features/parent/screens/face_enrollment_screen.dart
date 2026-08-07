import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import '../../../core/theme/app_colors.dart';
import '../../../core/services/insight_face_service.dart';
import '../../auth/providers/auth_provider.dart';

class FaceEnrollmentScreen extends ConsumerStatefulWidget {
  final String? childId;
  final String? childName;
  const FaceEnrollmentScreen({super.key, this.childId, this.childName});
  @override
  ConsumerState<FaceEnrollmentScreen> createState() =>
      _FaceEnrollmentScreenState();
}

class _FaceEnrollmentScreenState extends ConsumerState<FaceEnrollmentScreen> {
  final List<_EnrollmentPhoto> _photos = [];
  final ImagePicker _picker = ImagePicker();
  bool _isEnrolling = false;
  String _statusMessage = '';
  String? _errorMessage;
  int _enrolledCount = 0;

  bool _isLoadingStatus = true;
  bool _isCurrentlyEnrolled = false;
  int _existingEmbedCount = 0;
  bool _showTrainingView = false;
  List<_SavedTrainingPhoto> _savedTrainingPhotos = [];

  @override
  void initState() {
    super.initState();
    _loadChildName();
    _loadEnrollmentStatus();
  }

  Future<void> _loadEnrollmentStatus() async {
    final cId = _childId;
    // Load saved photo paths with metadata
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('trained_photos_v2_$cId');
    if (raw != null) {
      try {
        final list = (jsonDecode(raw) as List);
        _savedTrainingPhotos = list
            .map((e) => _SavedTrainingPhoto(
                  path: e['path'] as String,
                  serverId: e['serverId'] as String?,
                ))
            .toList();
      } catch (_) {
        // Fallback for old format (just string paths)
        try {
          final oldList = (jsonDecode(raw) as List);
          _savedTrainingPhotos = oldList
              .map((e) => _SavedTrainingPhoto(
                    path: e is String ? e : (e as Map)['path'] as String,
                    serverId: null,
                  ))
              .toList();
        } catch (_) {}
      }
    }
    try {
      final info = await InsightFaceService.getEnrollmentInfo(cId);
      if (mounted) {
        setState(() {
          _isLoadingStatus = false;
          _isCurrentlyEnrolled = info['enrolled'] == true;
          _existingEmbedCount = (info['embeddings_count'] ?? 0) as int;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingStatus = false);
    }
  }

  Future<void> _saveTrainedPhotos() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _savedTrainingPhotos
        .map((p) => {'path': p.path, 'serverId': p.serverId})
        .toList();
    await prefs.setString('trained_photos_v2_$_childId', jsonEncode(data));
  }

  Future<void> _deleteSinglePhoto(int index) async {
    final photo = _savedTrainingPhotos[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remove Training Photo?',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: Text(
            'This will unlearn this photo from $_childName\'s face model. It may reduce recognition accuracy.',
            style:
                GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w600))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text('Remove',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      // Note: Individual photo unlearn from server requires imageUrl (not available for local photos).
      // Deleting locally updates the count; full re-enrollment is needed for server sync.
      
      // Remove local file
      final file = File(photo.path);
      if (await file.exists()) await file.delete();

      // Update state
      setState(() {
        _savedTrainingPhotos.removeAt(index);
        _existingEmbedCount = (_existingEmbedCount - 1).clamp(0, 10);
      });
      await _saveTrainedPhotos();

      // Update Firestore count
      try {
        await FirebaseFirestore.instance.collection('children').doc(_childId).update({
          'enrolledFaceCount': _existingEmbedCount,
          'hasFaceProfile': _existingEmbedCount > 0,
        });
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Photo removed from $_childName\'s training'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String get _childId =>
      widget.childId ?? ref.read(authProvider).selectedChildId ?? '';
  String _childName = 'Child';

  Future<void> _loadChildName() async {
    if (widget.childName != null &&
        widget.childName!.isNotEmpty &&
        widget.childName != 'Child') {
      _childName = widget.childName!;
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('children')
          .doc(_childId)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        _childName = data['name'] as String? ?? 'Child';
      }
    } catch (_) {}
    if (mounted) setState(() {});
  }

  int get _totalTrainedCount =>
      _existingEmbedCount + _photos.where((p) => p.hasValidated && p.isValid).length;
  int get _validCount => _photos.where((p) => p.hasValidated && p.isValid).length;

  Future<void> _deleteEnrollment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Face Data for $_childName?',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: Text('This removes ALL trained photos. '
            'You\'ll need to re-train with new photos.',
            style: GoogleFonts.nunito(
                fontSize: 13, color: AppColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w600))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text('Delete All',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await InsightFaceService.deleteEnrollment(_childId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'All face data deleted for $_childName.' : 'Failed to delete'),
        backgroundColor: ok ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
      if (ok) {
        // Clear local saved photos
        _savedTrainingPhotos = [];
        await _saveTrainedPhotos();
        setState(() {
          _isCurrentlyEnrolled = false;
          _existingEmbedCount = 0;
          _showTrainingView = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            onPressed: () {
              final auth = ref.read(authProvider);
              if (auth.allChildren.length > 1) {
                context.go('/parent/select-child');
              } else if (context.canPop()) {
                context.pop();
              } else {
                context.go('/parent/gallery');
              }
            }),
        title: Text('Face Setup — $_childName',
            style: GoogleFonts.nunito(
                fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      ),
      body: _isLoadingStatus
          ? const Center(child: CircularProgressIndicator())
          : _isCurrentlyEnrolled && !_showTrainingView
              ? _buildEnrolledView()
              : _buildTrainingView(),
    );
  }

  Widget _buildEnrolledView() {
    final total = _savedTrainingPhotos.length + _existingEmbedCount;
    final displayCount = _existingEmbedCount > 0 ? _existingEmbedCount : total;
    final remaining = 10 - displayCount;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const SizedBox(height: 16),
        Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle),
            child: const Icon(Icons.verified_user,
                size: 40, color: AppColors.success)),
        const SizedBox(height: 16),
        Text('$_childName is Trained! 🎉',
            style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12)),
            child: Text('$displayCount / 10 photos trained',
                style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success))),
        const SizedBox(height: 8),

        // Progress bar for photo count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: displayCount / 10,
              minHeight: 6,
              backgroundColor: AppColors.success.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation(AppColors.success),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Show saved training photos with individual delete
        if (_savedTrainingPhotos.isNotEmpty) ...[
          Align(
              alignment: Alignment.centerLeft,
              child: Text('Your training photos (tap to delete):',
                  style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary))),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.8),
            itemCount: _savedTrainingPhotos.length,
            itemBuilder: (ctx, i) {
              final photo = _savedTrainingPhotos[i];
              return GestureDetector(
                onTap: () => _deleteSinglePhoto(i),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(photo.path),
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppColors.surfaceVariant,
                          child: const Icon(Icons.image,
                              color: AppColors.textTertiary),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 14),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Tap any photo to remove it from training',
            style: GoogleFonts.nunito(
                fontSize: 11,
                color: AppColors.textTertiary,
                fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 16),
        ] else if (_existingEmbedCount > 0) ...[
          Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.info_outline,
                    size: 18, color: AppColors.warning),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(
                        'Photos are stored on the server. Add more to see them here.',
                        style: GoogleFonts.nunito(
                            fontSize: 12, color: AppColors.warning))),
              ])),
          const SizedBox(height: 16),
        ],

        // Add more photos button (if under limit)
        if (remaining > 0) ...[
          SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                  onPressed: () =>
                      setState(() => _showTrainingView = true),
                  icon: const Icon(Icons.add_a_photo, size: 20),
                  label: Text('Add More Photos ($remaining left)',
                      style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))))),
          const SizedBox(height: 8),
        ] else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.check_circle, color: AppColors.success, size: 20),
              const SizedBox(width: 10),
              Text('Maximum 10 photos reached!',
                  style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w700,
                      color: AppColors.success)),
            ]),
          ),
          const SizedBox(height: 12),
        ],

        const SizedBox(height: 8),
        SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
                onPressed: _deleteEnrollment,
                icon: const Icon(Icons.delete_outline,
                    color: AppColors.error, size: 20),
                label: Text('Delete All & Retrain',
                    style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w700,
                        color: AppColors.error)),
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))))),
      ]),
    );
  }

  Widget _buildTrainingView() {
    final remaining = 10 - _existingEmbedCount - _photos.length;
    return Column(children: [
      Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            const Icon(Icons.info_outline,
                color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
                child: Text(
                    'Already trained: $_existingEmbedCount photos. '
                    'Take or upload up to $remaining more (max 10 total).',
                    style: GoogleFonts.nunito(
                        fontSize: 13, color: AppColors.textSecondary))),
          ])),
      if (_errorMessage != null)
        Container(
            margin:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.warning_amber_rounded,
                  color: AppColors.error, size: 18),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(_errorMessage!,
                      style: GoogleFonts.nunito(
                          fontSize: 13,
                          color: AppColors.error,
                          fontWeight: FontWeight.w600))),
              IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () =>
                      setState(() => _errorMessage = null),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints()),
            ])),
      Expanded(
        child: _photos.isEmpty
            ? Center(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    Icon(Icons.add_a_photo_rounded,
                        size: 64,
                        color: AppColors.textTertiary
                            .withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    Text('No new photos yet',
                        style: GoogleFonts.nunito(
                            fontSize: 15,
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('Add up to $remaining photos',
                        style: GoogleFonts.nunito(
                            fontSize: 13,
                            color: AppColors.textTertiary)),
                  ]))
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8),
                    itemCount: _photos.length,
                    itemBuilder: (ctx, i) {
                      final p = _photos[i];
                      return Stack(children: [
                        ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(p.file,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity)),
                        if (p.hasValidated)
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                    color: p.isValid
                                        ? AppColors.success
                                        : AppColors.error,
                                    shape: BoxShape.circle),
                                child: Icon(
                                    p.isValid
                                        ? Icons.check
                                        : Icons.close,
                                    color: Colors.white,
                                    size: 14)),
                          ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _photos.removeAt(i);
                                  _validateAllPhotos();
                                });
                              },
                              child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.close,
                                      color: Colors.white, size: 16))),
                        ),
                      ]);
                    })),
      ),
      if (_statusMessage.isNotEmpty)
        Padding(
            padding: const EdgeInsets.all(8),
            child: Text(_statusMessage,
                style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: _isEnrolling
                        ? AppColors.warning
                        : AppColors.textSecondary))),
      if (_photos.isNotEmpty)
        Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(children: [
              Icon(Icons.checklist,
                  size: 16,
                  color: _validCount >= 1
                      ? AppColors.success
                      : AppColors.textTertiary),
              const SizedBox(width: 6),
              Text(
                  '$_validCount valid · ${_photos.length} new · $_totalTrainedCount / 10 total',
                  style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: _validCount >= 1
                          ? AppColors.success
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w600)),
            ])),
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
                        padding: const EdgeInsets.all(16)))),
            const SizedBox(width: 12),
            Expanded(
                child: OutlinedButton.icon(
                    onPressed: remaining <= 0 ? null : _takePhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.accent,
                        padding: const EdgeInsets.all(16)))),
          ])),
      Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                  onPressed: (_isEnrolling || _validCount < 1)
                      ? null
                      : _enrollAll,
                  icon: _isEnrolling
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.fingerprint),
                  label: Text(
                      _isEnrolling
                          ? 'Training...'
                          : 'Train $_validCount New Photo${_validCount != 1 ? 's' : ''}',
                      style: GoogleFonts.nunito(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)))))),
    ]);
  }

  Future<void> _pickPhotos() async {
    final remaining = 10 - _existingEmbedCount - _photos.length;
    if (remaining <= 0) return;
    final picked =
        await _picker.pickMultiImage(imageQuality: 90, limit: remaining);
    if (picked != null) {
      setState(() => _statusMessage = 'Cropping faces...');
      for (final x in picked) {
        final cropped = await _cropFaceFromPhoto(File(x.path));
        _photos.add(cropped);
      }
      setState(() {});
      _validateAllPhotos();
    }
  }

  Future<void> _takePhoto() async {
    final remaining = 10 - _existingEmbedCount - _photos.length;
    if (remaining <= 0) return;
    final picked =
        await _picker.pickImage(source: ImageSource.camera, imageQuality: 90);
    if (picked != null) {
      setState(() => _statusMessage = 'Cropping face...');
      final cropped = await _cropFaceFromPhoto(File(picked.path));
      _photos.add(cropped);
      setState(() {});
      _validateAllPhotos();
    }
  }

  /// Detects the largest face in the photo and crops around it with padding.
  /// If no face is found, returns the original photo.
  Future<_EnrollmentPhoto> _cropFaceFromPhoto(File originalFile) async {
    try {
      final inputImage = InputImage.fromFilePath(originalFile.path);
      final faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableClassification: false,
          enableLandmarks: false,
          enableTracking: false,
        ),
      );
      final faces = await faceDetector.processImage(inputImage);
      faceDetector.close();

      if (faces.isEmpty) {
        // No face detected — use original
        return _EnrollmentPhoto(file: originalFile);
      }

      final bytes = await originalFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return _EnrollmentPhoto(file: originalFile);

      // Find the largest face
      double maxArea = 0;
      img.Rectangle faceRect = img.Rectangle(0, 0, image.width, image.height);
      for (final face in faces) {
        final rect = face.boundingBox;
        final area = (rect.right - rect.left) * (rect.bottom - rect.top);
        if (area > maxArea) {
          maxArea = area;
          faceRect = img.Rectangle(
            rect.left.toInt().clamp(0, image.width),
            rect.top.toInt().clamp(0, image.height),
            rect.right.toInt().clamp(0, image.width),
            rect.bottom.toInt().clamp(0, image.height),
          );
        }
      }

      // Add 30% padding around the face
      final padW = ((faceRect.right - faceRect.left) * 0.3).round();
      final padH = ((faceRect.bottom - faceRect.top) * 0.3).round();

      final cropLeft = (faceRect.left - padW).clamp(0, image.width);
      final cropTop = (faceRect.top - padH).clamp(0, image.height);
      final cropRight = (faceRect.right + padW).clamp(0, image.width);
      final cropBottom = (faceRect.bottom + padH).clamp(0, image.height);

      final cropped = img.copyCrop(image,
          x: cropLeft,
          y: cropTop,
          width: cropRight - cropLeft,
          height: cropBottom - cropTop);

      // Save cropped image to temp file
      final dir = await getTemporaryDirectory();
      final croppedPath =
          '${dir.path}/crop_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final croppedFile = File(croppedPath);
      await croppedFile.writeAsBytes(img.encodeJpg(cropped, quality: 90));

      return _EnrollmentPhoto(file: croppedFile);
    } catch (_) {
      return _EnrollmentPhoto(file: originalFile);
    }
  }

  Future<void> _validateAllPhotos() async {
    if (_photos.isEmpty) return;
    setState(() {
      _errorMessage = null;
      _statusMessage = 'Validating...';
    });
    for (final p in _photos) {
      if (p.hasValidated) continue;
      try {
        final bytes = await p.file.readAsBytes();
        final result = await InsightFaceService.validateFace(bytes);
        p.hasValidated = true;
        p.isValid = result['valid'] == true;
        p.error = result['error'] as String?;
      } catch (_) {
        p.hasValidated = true;
        p.isValid = false;
        p.error = 'Failed to validate';
      }
    }
    setState(() {});
    int invalidCount =
        _photos.where((p) => !p.isValid && p.hasValidated).length;
    if (invalidCount > 0) {
      final err =
          _photos.firstWhere((p) => !p.isValid && p.hasValidated).error;
      setState(() =>
          _errorMessage =
              invalidCount == 1 ? err : '$invalidCount photos invalid. $err');
    } else if (_validCount >= 1) {
      setState(() {
        _errorMessage = null;
        _statusMessage = '✅ $_validCount new photos validated. Ready!';
      });
    } else {
      setState(
          () => _statusMessage = 'Add at least 1 valid face photo');
    }
  }

  Future<void> _enrollAll() async {
    final validPhotos = _photos.where((p) => p.isValid).toList();
    if (validPhotos.isEmpty) return;
    setState(() {
      _isEnrolling = true;
      _statusMessage = 'Training $_childName...';
    });
    int success = 0;
    for (int i = 0; i < validPhotos.length; i++) {
      try {
        final bytes = await validPhotos[i].file.readAsBytes();
        final result = await InsightFaceService.enrollChild(
            childId: _childId, name: _childName, faceBytes: bytes);
        if (result['success'] == true) {
          success++;
          // Copy photo to app storage for persistent display
          final savedPath =
              await _savePhotoLocally(validPhotos[i].file);
          if (savedPath != null) {
            final serverId = result['serverId'] as String?;
            _savedTrainingPhotos.add(_SavedTrainingPhoto(
                path: savedPath, serverId: serverId));
          }
        }
        setState(() {
          _statusMessage = 'Training ${i + 1}/${validPhotos.length}...';
        });
      } catch (_) {}
    }
    if (!mounted) return;
    await _saveTrainedPhotos();
    setState(() {
      _isEnrolling = false;
      _statusMessage =
          success > 0 ? '✅ Trained $success new photo${success != 1 ? 's' : ''}!' : 'Training failed';
    });
    if (success > 0) {
      try {
        await FirebaseFirestore.instance
            .collection('children')
            .doc(_childId)
            .update({
          'hasFaceProfile': true,
          'enrolledFaceCount': FieldValue.increment(success),
        });
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$_childName trained with $success more photo${success != 1 ? 's' : ''}! 🎉'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _isCurrentlyEnrolled = true;
            _existingEmbedCount += success;
            _showTrainingView = false;
            _photos.clear();
          });
        }
      });
    }
  }

  Future<String?> _savePhotoLocally(File file) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final name =
          'train_${_childId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedPath = '${dir.path}/$name';
      file.copySync(savedPath);
      return savedPath;
    } catch (_) {
      return null;
    }
  }
}

class _SavedTrainingPhoto {
  final String path;
  final String? serverId;
  _SavedTrainingPhoto({required this.path, this.serverId});
}

class _EnrollmentPhoto {
  final File file;
  bool hasValidated = false;
  bool isValid = false;
  String? error;
  _EnrollmentPhoto({required this.file});
}