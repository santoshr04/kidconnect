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

/// Face Setup screen for parents:
/// - Shows enrolled status with photo count
/// - Option to delete & retrain
/// - Or start fresh training with validation
class FaceEnrollmentScreen extends ConsumerStatefulWidget {
  final String? childId;
  final String? childName;
  const FaceEnrollmentScreen({super.key, this.childId, this.childName});
  @override ConsumerState<FaceEnrollmentScreen> createState() => _FaceEnrollmentScreenState();
}

class _FaceEnrollmentScreenState extends ConsumerState<FaceEnrollmentScreen> {
  final List<_EnrollmentPhoto> _photos = [];
  final ImagePicker _picker = ImagePicker();
  bool _isEnrolling = false;
  String _statusMessage = '';
  String? _errorMessage;
  int _enrolledCount = 0;

  // Enrollment state
  bool _isLoadingStatus = true;
  bool _isCurrentlyEnrolled = false;
  int _existingEmbedCount = 0;
  bool _showTrainingView = false;

  @override void initState() {
    super.initState();
    _loadEnrollmentStatus();
  }

  Future<void> _loadEnrollmentStatus() async {
    final cId = _childId;
    try {
      final info = await InsightFaceService.getEnrollmentInfo(cId);
      if (mounted) setState(() {
        _isLoadingStatus = false;
        _isCurrentlyEnrolled = info['enrolled'] == true;
        _existingEmbedCount = (info['embeddings_count'] ?? 0) as int;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingStatus = false);
    }
  }

  String get _childId =>
      widget.childId ?? ref.read(authProvider).selectedChildId ?? 'child_ruthvi';
  String get _childName =>
      widget.childName ?? MockData.getChildById(_childId)?.firstName ?? 'Child';

  int get _validCount =>
      _photos.where((p) => p.hasValidated && p.isValid).length;

  Future<void> _deleteEnrollment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Face Data for $_childName?'),
        content: Text('This removes all trained photos. $_childName won\'t be recognized until retrained.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await InsightFaceService.deleteEnrollment(_childId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Deleted. You can retrain now.' : 'Failed to delete'),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ));
      if (ok) setState(() {
        _isCurrentlyEnrolled = false;
        _existingEmbedCount = 0;
        _showTrainingView = true;
      });
    }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/parent/gallery'),
        ),
        title: Text('Face Setup — $_childName',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      ),
      body: _isLoadingStatus
          ? const Center(child: CircularProgressIndicator())
          : _isCurrentlyEnrolled && !_showTrainingView
              ? _buildEnrolledView()
              : _buildTrainingView(),
    );
  }

  Widget _buildEnrolledView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.verified_user, size: 40, color: AppColors.success),
          ),
          const SizedBox(height: 20),
          Text('$_childName is Trained! 🎉',
              style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('$_existingEmbedCount photos trained',
                style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.success)),
          ),
          const SizedBox(height: 16),
          Text('Your child will be automatically recognized in class photos.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
          const SizedBox(height: 32),
          SizedBox(width: double.infinity, height: 48,
            child: OutlinedButton.icon(
              onPressed: _deleteEnrollment,
              icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
              label: Text('Delete & Retrain', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: AppColors.error)),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, height: 48,
            child: ElevatedButton.icon(
              onPressed: () => setState(() => _showTrainingView = true),
              icon: const Icon(Icons.add_a_photo, size: 20),
              label: Text('Add More Photos', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildTrainingView() {
    final remaining = 10 - _photos.length;
    return Column(children: [
      Container(
        width: double.infinity, margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text('Take or upload 2-10 photos of $_childName. Use different angles. Each photo must show only $_childName\'s face clearly.',
              style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary))),
        ]),
      ),
      if (_errorMessage != null)
        Container(margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(_errorMessage!, style: GoogleFonts.nunito(fontSize: 13, color: AppColors.error, fontWeight: FontWeight.w600))),
            IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => setState(() => _errorMessage = null), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          ])),
      Expanded(
        child: _photos.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_a_photo_rounded, size: 64, color: AppColors.textTertiary.withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                Text('No photos yet', style: GoogleFonts.nunito(fontSize: 15, color: AppColors.textTertiary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Add 2-10 clear photos of $_childName', style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textTertiary)),
              ]))
            : Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
                  itemCount: _photos.length,
                  itemBuilder: (ctx, i) {
                    final p = _photos[i];
                    return Stack(children: [
                      ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(p.file, fit: BoxFit.cover, width: double.infinity, height: double.infinity)),
                      if (p.hasValidated) Positioned(top: 4, left: 4,
                        child: Container(width: 22, height: 22, decoration: BoxDecoration(color: p.isValid ? AppColors.success : AppColors.error, shape: BoxShape.circle),
                          child: Icon(p.isValid ? Icons.check : Icons.close, color: Colors.white, size: 14))),
                      Positioned(top: 4, right: 4,
                        child: GestureDetector(
                          onTap: () { setState(() { _photos.removeAt(i); _validateAllPhotos(); }); },
                          child: Container(width: 28, height: 28, decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 16)))),
                    ]);
                  },
                ))),
      if (_statusMessage.isNotEmpty)
        Padding(padding: const EdgeInsets.all(8), child: Text(_statusMessage,
            style: GoogleFonts.nunito(fontSize: 13, color: _isEnrolling ? AppColors.warning : AppColors.textSecondary))),
      if (_photos.isNotEmpty)
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(children: [
            Icon(Icons.checklist, size: 16, color: _validCount >= 2 ? AppColors.success : AppColors.textTertiary),
            const SizedBox(width: 6),
            Text('$_validCount valid · ${_photos.length} total', style: GoogleFonts.nunito(fontSize: 12,
                color: _validCount >= 2 ? AppColors.success : AppColors.textSecondary, fontWeight: FontWeight.w600)),
            if (_enrolledCount > 0) ...[const SizedBox(width: 12), Text('$_enrolledCount enrolled',
                style: GoogleFonts.nunito(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600))],
          ])),
      Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: remaining <= 0 ? null : _pickPhotos,
            icon: const Icon(Icons.photo_library), label: Text('Gallery ($remaining left)'),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, padding: const EdgeInsets.all(16)))),
          const SizedBox(width: 12),
          Expanded(child: OutlinedButton.icon(
            onPressed: remaining <= 0 ? null : _takePhoto,
            icon: const Icon(Icons.camera_alt), label: const Text('Camera'),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.accent, padding: const EdgeInsets.all(16)))),
        ])),
      Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: SizedBox(width: double.infinity, height: 52,
          child: ElevatedButton.icon(
            onPressed: (_isEnrolling || _validCount < 2) ? null : _enrollAll,
            icon: _isEnrolling ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.fingerprint),
            label: Text(_isEnrolling ? 'Training...' : _enrolledCount > 0 ? 'Continue Training ($_validCount photos)' : 'Start Face Training ($_validCount photos)',
                style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))))),
    ]);
  }

  Future<void> _pickPhotos() async {
    final remaining = 10 - _photos.length;
    if (remaining <= 0) return;
    final picked = await _picker.pickMultiImage(imageQuality: 90, limit: remaining);
    if (picked != null) {
      for (final x in picked) _photos.add(_EnrollmentPhoto(file: File(x.path)));
      setState(() {});
      _validateAllPhotos();
    }
  }

  Future<void> _takePhoto() async {
    if (_photos.length >= 10) return;
    final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 90);
    if (picked != null) { _photos.add(_EnrollmentPhoto(file: File(picked.path))); setState(() {}); _validateAllPhotos(); }
  }

  Future<void> _validateAllPhotos() async {
    if (_photos.isEmpty) return;
    setState(() { _errorMessage = null; _statusMessage = 'Validating photos...'; });
    for (final p in _photos) {
      if (p.hasValidated) continue;
      try {
        final bytes = await p.file.readAsBytes();
        final result = await InsightFaceService.validateFace(bytes);
        p.hasValidated = true; p.isValid = result['valid'] == true; p.error = result['error'] as String?;
        if (result['embedding'] != null) p.embedding = (result['embedding'] as List).cast<double>();
      } catch (_) { p.hasValidated = true; p.isValid = false; p.error = 'Failed to validate'; }
    }
    setState(() {});
    int invalidCount = _photos.where((p) => !p.isValid && p.hasValidated).length;
    if (invalidCount > 0) {
      final firstError = _photos.firstWhere((p) => !p.isValid && p.hasValidated).error;
      setState(() => _errorMessage = invalidCount == 1 ? firstError : '$invalidCount photos are invalid. $firstError');
    } else if (_validCount >= 2) {
      setState(() { _errorMessage = null; _statusMessage = '✅ $_validCount photos validated. Ready to train!'; });
    } else {
      setState(() => _statusMessage = 'Need at least 2 valid photos (${_validCount}/2)');
    }
  }

  Future<void> _enrollAll() async {
    final validPhotos = _photos.where((p) => p.isValid).toList();
    if (validPhotos.isEmpty) return;
    setState(() { _isEnrolling = true; _statusMessage = 'Training $_childName...'; });
    int success = 0;
    for (int i = 0; i < validPhotos.length; i++) {
      if (validPhotos[i].isEnrolled) { success++; continue; }
      try {
        final bytes = await validPhotos[i].file.readAsBytes();
        final result = await InsightFaceService.enrollChild(childId: _childId, name: _childName, faceBytes: bytes);
        if (result['success'] == true) { success++; validPhotos[i].isEnrolled = true; }
        setState(() { _statusMessage = 'Training ${i + 1}/${validPhotos.length}...'; _enrolledCount = success; });
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() { _isEnrolling = false; _statusMessage = success > 0 ? '✅ Trained $_childName with $success photos!' : 'Training failed'; });
    if (success > 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$_childName trained with $success photos! 🎉'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating));
      Future.delayed(const Duration(seconds: 1), () { if (mounted) {
        setState(() { _isCurrentlyEnrolled = true; _existingEmbedCount += success; _showTrainingView = false; _photos.clear(); _enrolledCount = 0; });
      }});
    }
  }
}

class _EnrollmentPhoto {
  final File file;
  bool hasValidated = false;
  bool isValid = false;
  String? error;
  List<double>? embedding;
  bool isEnrolled = false;
  _EnrollmentPhoto({required this.file});
}