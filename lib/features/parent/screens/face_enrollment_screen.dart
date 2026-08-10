import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:cached_network_image/cached_network_image.dart';
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

enum _TrainingStage { cropping, validating, uploading, training, done }

class _FaceEnrollmentScreenState extends ConsumerState<FaceEnrollmentScreen> {
  final List<_EnrollmentPhoto> _photos = [];
  final ImagePicker _picker = ImagePicker();
  bool _isEnrolling = false;
  String _statusMessage = '';
  String? _errorMessage;

  bool _isLoadingStatus = true;
  bool _isCurrentlyEnrolled = false;
  int _existingEmbedCount = 0;
  bool _showTrainingView = false;
  List<_PersistedPhoto> _persistedPhotos = [];

  // Animated progress overlay
  bool _showProgress = false;
  _TrainingStage _stage = _TrainingStage.cropping;
  int _current = 0;
  int _total = 0;
  int _succeeded = 0;

  @override
  void initState() {
    super.initState();
    _loadChildName();
    _loadEnrollmentStatus();
  }

  String get _childId =>
      widget.childId ?? ref.read(authProvider).selectedChildId ?? '';
  String _childName = 'Child';

  int get _validCount =>
      _photos.where((p) => p.hasValidated && p.isValid).length;
  int get _totalTrainedCount => _existingEmbedCount + _validCount;

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
        _childName = doc.data()!['name'] as String? ?? 'Child';
      }
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _loadEnrollmentStatus() async {
    try {
      final childDoc = await FirebaseFirestore.instance
          .collection('children')
          .doc(_childId)
          .get();
      if (childDoc.exists) {
        final raw = childDoc.data()!['trainingPhotos'] as List<dynamic>?;
        if (raw != null) {
          _persistedPhotos = raw
              .map((e) => _PersistedPhoto(
                    url: e['url'] as String,
                    storagePath: e['storagePath'] as String? ?? '',
                    uploadedAt: e['uploadedAt'] as String? ?? '',
                  ))
              .toList();
        }
      }
    } catch (_) {}
    try {
      final info = await InsightFaceService.getEnrollmentInfo(_childId);
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

  Future<void> _savePersistedPhotos() async {
    try {
      await FirebaseFirestore.instance
          .collection('children')
          .doc(_childId)
          .update({
        'trainingPhotos': _persistedPhotos
            .map((p) => {
                  'url': p.url,
                  'storagePath': p.storagePath,
                  'uploadedAt': p.uploadedAt
                })
            .toList(),
      });
    } catch (_) {}
  }

  void _setProgress(_TrainingStage s, int cur, int tot) {
    if (!mounted) return;
    setState(() {
      _showProgress = true;
      _stage = s;
      _current = cur;
      _total = tot < 1 ? 1 : tot;
    });
  }
  void _hideProgress() {
    if (mounted) setState(() => _showProgress = false);
  }

  // ─── BUILD ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext ctx) {
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
            } else if (ctx.widget is Scaffold) {
              context.pop();
            } else {
              context.go('/parent/gallery');
            }
          },
        ),
        title: Text(
          'Face Setup — $_childName',
          style: GoogleFonts.nunito(
              fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
      ),
      body: Stack(
        children: [
          _isLoadingStatus
              ? const Center(child: CircularProgressIndicator())
              : _isCurrentlyEnrolled && !_showTrainingView
                  ? _buildEnrolled()
                  : _buildTraining(),
          if (_showProgress) _buildProgressOverlay(),
        ],
      ),
    );
  }

  // ─── ENROLLED VIEW ─────────────────────────────────────────

  Widget _buildEnrolled() {
    final dc = _existingEmbedCount > 0
        ? _existingEmbedCount
        : _persistedPhotos.length;
    final remaining = 10 - dc;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle),
            child: const Icon(Icons.verified_user,
                size: 40, color: AppColors.success),
          ),
          const SizedBox(height: 16),
          Text(
            '$_childName is Trained! 🎉',
            style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12)),
            child: Text(
              '$dc / 10 photos trained',
              style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.success),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: dc / 10,
                minHeight: 6,
                backgroundColor: AppColors.success.withValues(alpha: 0.15),
                valueColor: const AlwaysStoppedAnimation(AppColors.success),
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_persistedPhotos.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Your training photos (tap to delete):',
                style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 0.8),
              itemCount: _persistedPhotos.length,
              itemBuilder: (c, i) {
                return GestureDetector(
                  onTap: () => _deletePhoto(i),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: _persistedPhotos[i].url,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: AppColors.surfaceVariant),
                          errorWidget: (_, __, ___) => Container(
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
                              shape: BoxShape.circle),
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
              'Tap any photo to delete it permanently',
              style: GoogleFonts.nunito(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                  fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 16),
          ],
          if (remaining > 0)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () =>
                    setState(() => _showTrainingView = true),
                icon: const Icon(Icons.add_a_photo, size: 20),
                label: Text(
                  'Add More Photos ($remaining left)',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            )
          else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: AppColors.success, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Maximum 10 photos reached!',
                    style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w700,
                        color: AppColors.success),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _deleteAll,
              icon: const Icon(Icons.delete_outline,
                  color: AppColors.error, size: 20),
              label: Text(
                'Delete All & Retrain',
                style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w700,
                    color: AppColors.error),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── TRAINING VIEW ─────────────────────────────────────────

  Widget _buildTraining() {
    final remaining = 10 - _existingEmbedCount - _photos.length;
    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              const Icon(Icons.info_outline,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Already trained: $_existingEmbedCount photos. '
                  'Upload up to $remaining more (max 10 total).',
                  style: GoogleFonts.nunito(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        if (_errorMessage != null)
          Container(
            margin:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppColors.error, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: GoogleFonts.nunito(
                        fontSize: 13,
                        color: AppColors.error,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () =>
                      setState(() => _errorMessage = null),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        Expanded(
          child: _photos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_a_photo_rounded,
                        size: 64,
                        color: AppColors.textTertiary
                            .withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No new photos yet',
                        style: GoogleFonts.nunito(
                            fontSize: 15,
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add up to $remaining photos',
                        style: GoogleFonts.nunito(
                            fontSize: 13,
                            color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8),
                    itemCount: _photos.length,
                    itemBuilder: (c, i) {
                      final p = _photos[i];
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius:
                                BorderRadius.circular(12),
                            child: Image.file(p.file,
                                fit: BoxFit.cover),
                          ),
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
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  p.isValid
                                      ? Icons.check
                                      : Icons.close,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _photos.removeAt(i);
                                  _validateAll();
                                });
                              },
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle),
                                child: const Icon(Icons.close,
                                    color: Colors.white,
                                    size: 16),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
        ),
        if (_statusMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              _statusMessage,
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: _isEnrolling
                    ? AppColors.warning
                    : AppColors.textSecondary,
              ),
            ),
          ),
        if (_photos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Icon(
                  Icons.checklist,
                  size: 16,
                  color: _validCount >= 1
                      ? AppColors.success
                      : AppColors.textTertiary,
                ),
                const SizedBox(width: 6),
                Text(
                  '$_validCount valid · ${_photos.length} new · $_totalTrainedCount / 10 total',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: _validCount >= 1
                        ? AppColors.success
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: remaining <= 0 ? null : _pick,
                  icon: const Icon(Icons.photo_library),
                  label: Text('Gallery ($remaining left)'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.all(16)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: remaining <= 0 ? null : _take,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      padding: const EdgeInsets.all(16)),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed:
                  (_isEnrolling || _validCount < 1) ? null : _enrollAll,
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
                    fontSize: 16, fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── PROGRESS OVERLAY ──────────────────────────────────────

  static const _stageLabels = [
    'Cropping Face',
    'Quality Check',
    'Cloud Upload',
    'AI Training',
    'Complete!',
  ];

  static const _stageIcons = [
    Icons.auto_fix_high,
    Icons.search,
    Icons.cloud_upload_outlined,
    Icons.psychology_outlined,
    Icons.celebration,
  ];

  String _getFunMessage() {
    const msgs = <_TrainingStage, List<String>>{
      _TrainingStage.cropping: [
        'Scanning pixel by pixel... 👀',
        'Found a face! Locking on target... 🎯',
        'Measuring nose-to-ear ratios... 📐',
        'This one\'s a keeper! ✨',
      ],
      _TrainingStage.validating: [
        'Is it really a face? Let\'s check... 🤔',
        'Counting eyes: 2 ✓  Nose: 1 ✓  Smile: pending...',
        'Lighting check: passed! ☀️',
        'Face clarity score: Excellent! 🏆',
      ],
      _TrainingStage.uploading: [
        'Compressing pixels for their journey... 📦',
        'Rocket engines ignited! 🚀',
        'Dodging cosmic dust in the cloud... ☁️',
        'Safely arrived at Firebase HQ! 🏢',
      ],
      _TrainingStage.training: [
        'AI neurons firing up... ⚡',
        'Running 128 face measurements... 📏',
        'Embedding locked in memory! 💾',
      ],
      _TrainingStage.done: [
        'Mission accomplished! 🎖️',
      ],
    };
    final stageMsgs = msgs[_stage] ?? ['Working...'];
    final idx = _current % stageMsgs.length;
    return stageMsgs[idx];
  }

  Widget _buildProgressOverlay() {
    final pct = _total > 0 ? _current / _total : 0.0;
    final percentage = (pct * 100).round();
    final isDone = _stage == _TrainingStage.done;

    // Overall progress: stage index + per-stage progress
    final stageIndex = _TrainingStage.values.indexOf(_stage);
    final totalStages = _TrainingStage.values.length - 1; // exclude 'done'
    final overallPct = isDone
        ? 1.0
        : (stageIndex / totalStages) + (pct / totalStages).clamp(0.0, 1.0 / totalStages);

    return Container(
      color: AppColors.background.withValues(alpha: 0.97),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Circular progress ring
              SizedBox(
                width: 160,
                height: 160,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 160,
                      height: 160,
                      child: CircularProgressIndicator(
                        value: overallPct,
                        strokeWidth: 8,
                        strokeCap: StrokeCap.round,
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation(
                          isDone
                              ? AppColors.success
                              : const Color(0xFFFF8E53),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isDone)
                          const Icon(Icons.check_circle,
                              color: AppColors.success, size: 40)
                        else ...[
                          Text(
                            '$percentage%',
                            style: GoogleFonts.nunito(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: isDone
                                  ? AppColors.success
                                  : AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '${_current + 1}/$_total',
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Stage title
              Text(
                isDone
                    ? 'Training Complete! 🎉'
                    : '${_stageLabels[stageIndex]} (${stageIndex + 1}/${totalStages + 1})',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),

              // Fun status message
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: Text(
                  _getFunMessage(),
                  key: ValueKey('$_current-$_stage'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Stage stepping dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  totalStages + 1,
                  (i) {
                    final isCompleted = i < stageIndex || isDone;
                    final isCurrent = i == stageIndex && !isDone;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      width: isCurrent ? 32 : 12,
                      height: 12,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: isCompleted
                            ? AppColors.success
                            : isCurrent
                                ? const Color(0xFFFF8E53)
                                : AppColors.primary.withValues(alpha: 0.2),
                      ),
                      child: isCurrent
                          ? const Center(
                              child: Icon(Icons.circle,
                                  size: 6, color: Colors.white))
                          : isCompleted
                              ? const Center(
                                  child: Icon(Icons.check,
                                      size: 8, color: Colors.white))
                              : null,
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),

              // Stage icon labels
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    totalStages + 1,
                    (i) => Expanded(
                      child: Icon(
                        _stageIcons[i],
                        size: 20,
                        color: i <= stageIndex
                            ? AppColors.textPrimary
                            : AppColors.textTertiary,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Done button
              if (isDone)
                SizedBox(
                  width: 200,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _hideProgress,
                    icon: const Icon(Icons.check, size: 20),
                    label: Text('Show Results',
                        style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── PICK / TAKE / CROP ───────────────────────────────────

  Future<void> _pick() async {
    final remaining = 10 - _existingEmbedCount - _photos.length;
    if (remaining <= 0) return;
    final picked =
        await _picker.pickMultiImage(imageQuality: 90, limit: remaining);
    if (picked == null) return;
    final total = picked.length;
    _setProgress(_TrainingStage.cropping, 0, total);
    for (int i = 0; i < total; i++) {
      final cropped = await _cropFace(File(picked[i].path));
      _photos.add(cropped);
      _setProgress(_TrainingStage.cropping, i + 1, total);
    }
    _hideProgress();
    setState(() {});
    _validateAll();
  }

  Future<void> _take() async {
    final remaining = 10 - _existingEmbedCount - _photos.length;
    if (remaining <= 0) return;
    final picked =
        await _picker.pickImage(source: ImageSource.camera, imageQuality: 90);
    if (picked == null) return;
    _setProgress(_TrainingStage.cropping, 0, 1);
    final cropped = await _cropFace(File(picked.path));
    _photos.add(cropped);
    _setProgress(_TrainingStage.cropping, 1, 1);
    _hideProgress();
    setState(() {});
    _validateAll();
  }

  Future<_EnrollmentPhoto> _cropFace(File original) async {
    try {
      final inputImage = InputImage.fromFilePath(original.path);
      final fd = FaceDetector(
        options: FaceDetectorOptions(
          enableClassification: false,
          enableLandmarks: false,
          enableTracking: false,
        ),
      );
      final faces = await fd.processImage(inputImage);
      fd.close();
      if (faces.isEmpty) return _EnrollmentPhoto(file: original);
      final bytes = await original.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return _EnrollmentPhoto(file: original);
      double maxArea = 0;
      double l = 0, t = 0, r = image.width.toDouble(), b = image.height.toDouble();
      for (final f in faces) {
        final rect = f.boundingBox;
        final a = (rect.right - rect.left) * (rect.bottom - rect.top);
        if (a > maxArea) {
          maxArea = a;
          l = rect.left.clamp(0, image.width.toDouble());
          t = rect.top.clamp(0, image.height.toDouble());
          r = rect.right.clamp(0, image.width.toDouble());
          b = rect.bottom.clamp(0, image.height.toDouble());
        }
      }
      final pw = ((r - l) * 0.3), ph = ((b - t) * 0.3);
      final cl = (l - pw).clamp(0, image.width.toDouble()).toInt();
      final ct = (t - ph).clamp(0, image.height.toDouble()).toInt();
      final cw = ((r + pw).clamp(0, image.width.toDouble()) - cl).toInt();
      final ch = ((b + ph).clamp(0, image.height.toDouble()) - ct).toInt();
      final cropped =
          img.copyCrop(image, x: cl, y: ct, width: cw, height: ch);
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/crop_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(path).writeAsBytes(img.encodeJpg(cropped, quality: 90));
      return _EnrollmentPhoto(file: File(path));
    } catch (_) {
      return _EnrollmentPhoto(file: original);
    }
  }

  // ─── VALIDATE ─────────────────────────────────────────────

  Future<void> _validateAll() async {
    if (_photos.isEmpty) return;
    final unvalidated = _photos.where((p) => !p.hasValidated).toList();
    if (unvalidated.isEmpty) return;
    _setProgress(_TrainingStage.validating, 0, unvalidated.length);
    for (int i = 0; i < unvalidated.length; i++) {
      try {
        final bytes = await unvalidated[i].file.readAsBytes();
        final result = await InsightFaceService.validateFace(bytes);
        unvalidated[i].hasValidated = true;
        unvalidated[i].isValid = result['valid'] == true;
        unvalidated[i].error = result['error'] as String?;
      } catch (_) {
        unvalidated[i].hasValidated = true;
        unvalidated[i].isValid = false;
        unvalidated[i].error = 'Failed to validate';
      }
      _setProgress(_TrainingStage.validating, i + 1, unvalidated.length);
    }
    _hideProgress();
    setState(() {
      final ic =
          _photos.where((p) => !p.isValid && p.hasValidated).length;
      _errorMessage = ic > 0
          ? _photos.firstWhere((p) => !p.isValid && p.hasValidated).error
          : null;
      _statusMessage = _validCount >= 1
          ? '✅ $_validCount new photos validated. Ready!'
          : 'Add at least 1 valid face photo';
    });
  }

  // ─── ENROLL ALL ───────────────────────────────────────────

  Future<void> _enrollAll() async {
    final valid = _photos.where((p) => p.isValid).toList();
    if (valid.isEmpty) return;
    _setProgress(_TrainingStage.uploading, 0, valid.length);

    int success = 0;
    for (int i = 0; i < valid.length; i++) {
      try {
        final bytes = await valid[i].file.readAsBytes();
        final ts = DateTime.now().millisecondsSinceEpoch + i;
        final sp = 'children/$_childId/training/$ts.jpg';
        final ref = FirebaseStorage.instance.ref(sp);
        await ref.putData(
            bytes, SettableMetadata(contentType: 'image/jpeg'));
        final url = await ref.getDownloadURL();
        _setProgress(_TrainingStage.training, i, valid.length);
        final result = await InsightFaceService.enrollChild(
            childId: _childId, name: _childName, faceBytes: bytes);
        if (result['success'] == true) {
          success++;
          _persistedPhotos.add(_PersistedPhoto(
            url: url,
            storagePath: sp,
            uploadedAt: DateTime.now().toIso8601String(),
          ));
        } else {
          try {
            await ref.delete();
          } catch (_) {}
        }
      } catch (_) {}
    }

    if (!mounted) return;
    await _savePersistedPhotos();
    _showProgress = true;
    _stage = _TrainingStage.done;
    _succeeded = success;
    setState(() {});
    await Future.delayed(const Duration(seconds: 2));
    _hideProgress();

    setState(() {
      _isEnrolling = false;
      _statusMessage = success > 0
          ? '✅ Trained $success new photo${success != 1 ? 's' : ''}!'
          : 'Training failed';
      if (success > 0) {
        _isCurrentlyEnrolled = true;
        _existingEmbedCount += success;
        _showTrainingView = false;
        _photos.clear();
      }
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
        content: Text('$_childName trained! 🎉'),
        backgroundColor: AppColors.success,
      ));
    }
  }

  // ─── DELETE ───────────────────────────────────────────────

  Future<void> _deletePhoto(int index) async {
    final photo = _persistedPhotos[index];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remove Photo?',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: Text(
            'Delete permanently & unlearn from $_childName?',
            style: GoogleFonts.nunito(
                fontSize: 13, color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white),
            child: Text('Delete',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      if (photo.storagePath.isNotEmpty) {
        try {
          await FirebaseStorage.instance.ref(photo.storagePath).delete();
        } catch (_) {}
      }
      try {
        await InsightFaceService.unlearn(
            childId: _childId, imageUrl: photo.url);
      } catch (_) {}
      setState(() {
        _persistedPhotos.removeAt(index);
        _existingEmbedCount = (_existingEmbedCount - 1).clamp(0, 10);
      });
      await _savePersistedPhotos();
      try {
        await FirebaseFirestore.instance
            .collection('children')
            .doc(_childId)
            .update({
          'enrolledFaceCount': _existingEmbedCount,
          'hasFaceProfile': _existingEmbedCount > 0,
        });
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Deleted from $_childName'),
        backgroundColor: AppColors.success,
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed: $e'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Future<void> _deleteAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete all for $_childName?',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: Text('Removes ALL trained photos.',
            style: GoogleFonts.nunito(
                fontSize: 13, color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white),
            child: Text('Delete All',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    for (final p in _persistedPhotos) {
      if (p.storagePath.isNotEmpty) {
        try {
          await FirebaseStorage.instance.ref(p.storagePath).delete();
        } catch (_) {}
      }
    }
    await InsightFaceService.deleteEnrollment(_childId);
    setState(() {
      _persistedPhotos = [];
      _isCurrentlyEnrolled = false;
      _existingEmbedCount = 0;
      _showTrainingView = true;
    });
    await _savePersistedPhotos();
  }
}

class _PersistedPhoto {
  final String url, storagePath, uploadedAt;
  _PersistedPhoto(
      {required this.url,
      required this.storagePath,
      required this.uploadedAt});
}

class _EnrollmentPhoto {
  final File file;
  bool hasValidated = false;
  bool isValid = false;
  String? error;
  _EnrollmentPhoto({required this.file});
}