import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/avatar_widget.dart';
import '../../../data/models/photo_model.dart';
import '../../../data/repositories/photo_repository.dart';
import '../../../core/services/insight_face_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/teacher_photo_provider.dart';

class TeacherGalleryScreen extends ConsumerStatefulWidget {
  const TeacherGalleryScreen({super.key});
  @override
  ConsumerState<TeacherGalleryScreen> createState() => _TeacherGalleryScreenState();
}

class _TeacherGalleryScreenState extends ConsumerState<TeacherGalleryScreen> {
  String _filter = 'all';
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};
  bool _isAutoTagging = false;
  int _autoTagProgress = 0;

  Future<void> _autoTagAll() async {
    setState(() { _isAutoTagging = true; _autoTagProgress = 0; });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('photos')
          .get();
      final docs = snapshot.docs.where((d) {
        final cids = List<String>.from(d.data()['childIds'] ?? []);
        return cids.isEmpty;
      }).toList();
      if (docs.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ All photos are already tagged!')));
        setState(() => _isAutoTagging = false);
        return;
      }
      int count = 0;
      for (int i = 0; i < docs.length; i++) {
        final doc = docs[i];
        final url = doc.data()['url'] as String?;
        if (url == null || !url.startsWith('https://')) continue;
        setState(() => _autoTagProgress = i + 1);
        try {
          final result = await InsightFaceService.detectAndRecognize(url);
          if (result.error != null || result.faces.isEmpty) continue;
          final totalFaces = result.faces.length;
          final childIds = <String>[];
          final aiDetections = <Map<String, dynamic>>[];
          int matchedCount = 0;
          for (final face in result.faces) {
            if (face.matched && face.childId != null) {
              matchedCount++;
              if (!childIds.contains(face.childId!)) childIds.add(face.childId!);
            }
            aiDetections.add({'childId': face.childId ?? '', 'confidence': face.confidence ?? 0, 'matched': face.matched});
          }
          // Only auto-complete if ALL faces are recognized
          if (matchedCount == totalFaces && childIds.isNotEmpty) {
            await doc.reference.update({'childIds': childIds, 'aiDetections': aiDetections, 'totalFaces': totalFaces, 'taggedFaces': matchedCount});
            count++;
          }
        } catch (_) {}
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(count > 0 ? '✅ Auto-tagged $count photo(s)!' : 'No faces recognized in untagged photos'), backgroundColor: count > 0 ? AppColors.success : AppColors.warning));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
    }
    if (mounted) setState(() => _isAutoTagging = false);
  }

  void _toggleSelection(String photoId) {
    setState(() {
      if (_selectedIds.contains(photoId)) { _selectedIds.remove(photoId); if (_selectedIds.isEmpty) _selectionMode = false; }
      else { _selectedIds.add(photoId); }
    });
  }

  void _enterSelectionMode(String photoId) => setState(() { _selectionMode = true; _selectedIds.add(photoId); });

  /// Removes all existing tagging from all photos and re-runs AI auto-tagging.
  Future<void> _reTagAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Smart Re-tag?', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: Text('This will only attempt to recognize faces that are currently Unknown or pending review.\n\nExisting tags and teacher-confirmed tags will NOT be modified.', style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.nunito(fontWeight: FontWeight.w600))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text('Re-tag Unknown', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() { _isAutoTagging = true; _autoTagProgress = 0; });

    try {
      // Fetch valid registered child IDs
      final validIds = <String>{};
      try {
        final childrenSnap = await FirebaseFirestore.instance.collection('children').get();
        for (final doc in childrenSnap.docs) {
          validIds.add(doc.id);
        }
      } catch (_) {}

      final snapshot = await FirebaseFirestore.instance.collection('photos').get();
      final allDocs = snapshot.docs;

      int photosProcessed = 0;
      int facesResolved = 0;
      int photosSkipped = 0;

      for (int i = 0; i < allDocs.length; i++) {
        final doc = allDocs[i];
        final data = doc.data();
        final url = data['url'] as String?;
        if (url == null || !url.startsWith('https://')) continue;
        setState(() => _autoTagProgress = i + 1);

        final existingDetections = (data['aiDetections'] as List?)
            ?.map((d) => d as Map<String, dynamic>)
            .toList() ?? [];
        final existingChildIds = List<String>.from(data['childIds'] ?? []);

        // Count untagged faces (those without a valid childId or with low tier)
        final untaggedFaces = existingDetections.where((d) {
          final cid = d['childId'] as String? ?? '';
          final tier = d['tier'] as String? ?? 'low';
          final matched = d['matched'] == true;
          // Consider face untagged if: no childId, or tier is low/medium with no valid match
          return cid.isEmpty || (!matched && tier != 'high');
        }).toList();

        // Skip if all faces are already properly tagged
        if (untaggedFaces.isEmpty && existingChildIds.isNotEmpty) {
          photosSkipped++;
          continue;
        }

        // If no existing detections or all faces untagged, run full detection
        final needFullDetection = existingDetections.isEmpty ||
            untaggedFaces.length == existingDetections.length;

        try {
          if (needFullDetection) {
            // Full detection for photos with no existing data
            final result = await InsightFaceService.detectAndRecognize(url);
            if (result.error != null || result.faces.isEmpty) continue;

            final newChildIds = <String>[];
            final newDetections = <Map<String, dynamic>>[];
            int matchedCount = 0;

            for (final face in result.faces) {
              final matchedId = face.childId;
              final isValid = matchedId != null && validIds.contains(matchedId);
              final tier = face.confidenceTier;

              if (face.matched && isValid && tier == 'high') {
                matchedCount++;
                if (!newChildIds.contains(matchedId!)) newChildIds.add(matchedId);
                newDetections.add({
                  'childId': matchedId,
                  'confidence': face.confidence ?? 0,
                  'matched': true,
                  'tier': tier,
                });
              } else if (face.matched && isValid && tier == 'medium') {
                newDetections.add({
                  'childId': '',
                  'confidence': face.confidence ?? 0,
                  'matched': false,
                  'tier': tier,
                  'suggestedId': matchedId ?? '',
                  'suggestedName': face.name ?? '',
                });
              } else {
                newDetections.add({
                  'childId': '',
                  'confidence': face.confidence ?? 0,
                  'matched': false,
                  'tier': tier,
                });
              }
            }

            if (newChildIds.isNotEmpty) {
              // Merge with any existing tags (shouldn't be any since we do full detection)
              final mergedChildIds = <String>{...existingChildIds, ...newChildIds};
              await doc.reference.update({
                'childIds': mergedChildIds.toList(),
                'aiDetections': newDetections,
                'totalFaces': result.faces.length,
                'taggedFaces': matchedCount,
                if (mergedChildIds.isEmpty) 'tags': ['__needs_review__'] else 'tags': [],
              });
            } else if (existingChildIds.isEmpty) {
              // Still save the detections even without matches
              await doc.reference.update({
                'aiDetections': newDetections,
                'totalFaces': result.faces.length,
                'taggedFaces': 0,
                'tags': ['__needs_review__'],
              });
            }
          } else {
            // Partial re-tag: only re-evaluate untagged faces
            // Run full detection to get current face positions and recognition
            final result = await InsightFaceService.detectAndRecognize(url);
            if (result.error != null || result.faces.isEmpty) continue;

            final updatedDetections = <Map<String, dynamic>>[];
            bool changed = false;

            for (int j = 0; j < result.faces.length; j++) {
              final newFace = result.faces[j];

              // Try to match this new face to an existing detection by position overlap
              int? matchedExistingIndex;
              for (int k = 0; k < existingDetections.length; k++) {
                final existing = existingDetections[k];
                if (_boxesOverlap(
                  newFace.left, newFace.top, newFace.width, newFace.height,
                  (existing['left'] as num?)?.toDouble() ?? 0,
                  (existing['top'] as num?)?.toDouble() ?? 0,
                  (existing['width'] as num?)?.toDouble() ?? 0,
                  (existing['height'] as num?)?.toDouble() ?? 0,
                )) {
                  matchedExistingIndex = k;
                  break;
                }
              }

              if (matchedExistingIndex != null) {
                final existing = existingDetections[matchedExistingIndex];
                final existingCid = existing['childId'] as String? ?? '';
                final existingTier = existing['tier'] as String? ?? 'low';

                // Preserve confirmed/tagged faces
                if (existingCid.isNotEmpty && existingTier == 'high') {
                  updatedDetections.add(existing);
                } else {
                  // This face was untagged — try to recognize it now
                  final matchedId = newFace.childId;
                  final isValid = matchedId != null && validIds.contains(matchedId);
                  final tier = newFace.confidenceTier;

                  if (newFace.matched && isValid && tier == 'high') {
                    // New high-confidence match found!
                    updatedDetections.add({
                      'childId': matchedId!,
                      'confidence': newFace.confidence ?? 0,
                      'matched': true,
                      'tier': tier,
                    });
                    facesResolved++;
                    changed = true;
                  } else if (newFace.matched && isValid && tier == 'medium') {
                    updatedDetections.add({
                      'childId': '',
                      'confidence': newFace.confidence ?? 0,
                      'matched': false,
                      'tier': tier,
                      'suggestedId': matchedId ?? '',
                      'suggestedName': newFace.name ?? '',
                    });
                    if (existingCid.isEmpty) changed = true;
                  } else {
                    // Still unknown — keep as is
                    updatedDetections.add(existing);
                  }
                }
              } else {
                // New face not in previous detections
                final matchedId = newFace.childId;
                final isValid = matchedId != null && validIds.contains(matchedId);
                final tier = newFace.confidenceTier;

                if (newFace.matched && isValid && tier == 'high') {
                  updatedDetections.add({
                    'childId': matchedId!,
                    'confidence': newFace.confidence ?? 0,
                    'matched': true,
                    'tier': tier,
                  });
                  facesResolved++;
                  changed = true;
                } else if (newFace.matched && isValid && tier == 'medium') {
                  updatedDetections.add({
                    'childId': '',
                    'confidence': newFace.confidence ?? 0,
                    'matched': false,
                    'tier': tier,
                    'suggestedId': matchedId ?? '',
                    'suggestedName': newFace.name ?? '',
                  });
                  changed = true;
                } else {
                  updatedDetections.add({
                    'childId': '',
                    'confidence': newFace.confidence ?? 0,
                    'matched': false,
                    'tier': tier,
                  });
                }
              }
            }

            if (changed) {
              // Recompute childIds from updated detections
              final newChildIds = <String>{};
              for (final d in updatedDetections) {
                final cid = d['childId'] as String? ?? '';
                if (cid.isNotEmpty && validIds.contains(cid)) {
                  newChildIds.add(cid);
                }
              }
              final hasUntagged = updatedDetections.any((d) =>
                  (d['childId'] as String? ?? '').isEmpty);

              await doc.reference.update({
                'childIds': newChildIds.toList(),
                'aiDetections': updatedDetections,
                'totalFaces': updatedDetections.length,
                'taggedFaces': updatedDetections.where((d) =>
                    d['matched'] == true && (d['childId'] as String? ?? '').isNotEmpty).length,
                if (hasUntagged && newChildIds.isEmpty)
                  'tags': ['__needs_review__']
                else
                  'tags': [],
              });
            }
          }
          photosProcessed++;
        } catch (_) {}
      }

      if (mounted) {
        final message = photosSkipped > 0
            ? '✅ Processed $photosProcessed photo(s). Resolved $facesResolved face(s). Skipped $photosSkipped already tagged.'
            : '✅ Processed $photosProcessed photo(s). Resolved $facesResolved face(s).';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
    }
    if (mounted) setState(() => _isAutoTagging = false);
  }

  /// Check if two bounding boxes overlap (IoU > 0.3).
  static bool _boxesOverlap(double x1, double y1, double w1, double h1,
      double x2, double y2, double w2, double h2) {
    final left = x1 > x2 ? x1 : x2;
    final top = y1 > y2 ? y1 : y2;
    final right = (x1 + w1) < (x2 + w2) ? (x1 + w1) : (x2 + w2);
    final bottom = (y1 + h1) < (y2 + h2) ? (y1 + h1) : (y2 + h2);
    if (left >= right || top >= bottom) return false;
    final intersection = (right - left) * (bottom - top);
    final area1 = w1 * h1;
    final area2 = w2 * h2;
    final union = area1 + area2 - intersection;
    return (intersection / union) > 0.3;
  }

  void _exitSelectionMode() => setState(() { _selectionMode = false; _selectedIds.clear(); });

  Widget _buildEmpty() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('📸', style: TextStyle(fontSize: 48)),
      const SizedBox(height: 12),
      Text('No photos yet', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
    ]),
  );

  Future<void> _deleteSelected() async {
    final count = _selectedIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $count photo${count == 1 ? '' : 's'}?'),
        content: Text('This will permanently remove the selected photo${count == 1 ? '' : 's'} from storage.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: AppColors.error), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    final idsToDelete = Set<String>.from(_selectedIds);
    final isMock = ref.read(authProvider).usingMockData;
    ref.read(teacherPhotoStateProvider.notifier).removePhotos(idsToDelete);
    _exitSelectionMode();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🗑️ $count photo${count == 1 ? '' : 's'} deleted'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 1)));
    if (!isMock) {
      final photos = ref.read(allTeacherPhotosProvider);
      for (final id in idsToDelete) {
        final photo = photos.firstWhere((p) => p.id == id, orElse: () => photos.first);
        PhotoRepository.deletePhoto(photo.id, photo.url);
      }
    }
  }

  void _showPhotoActions(BuildContext context, PhotoModel photo) {
    final isMock = ref.read(authProvider).usingMockData;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.textTertiary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              ClipRRect(borderRadius: BorderRadius.circular(12), child: CachedNetworkImage(imageUrl: photo.url, height: 120, width: 120, fit: BoxFit.cover, placeholder: (_, __) => Container(height: 120, width: 120, color: AppColors.surfaceVariant), errorWidget: (_, __, ___) => Container(height: 120, width: 120, color: AppColors.surfaceVariant, child: const Icon(Icons.broken_image)))),
              const SizedBox(height: 12),
              Text(photo.caption?.isNotEmpty == true ? photo.caption! : 'Photo', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 4),
              Text('${photo.childIds.length} kid(s) tagged', style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textTertiary)),
              const SizedBox(height: 20), const Divider(),
              ListTile(leading: const Icon(Icons.visibility_outlined, color: AppColors.textPrimary), title: const Text('View'), onTap: () { Navigator.pop(ctx); context.push('/teacher/photo/${photo.id}', extra: photo); }),
              ListTile(leading: const Icon(Icons.download_outlined, color: AppColors.primary), title: const Text('Download'), onTap: () async { Navigator.pop(ctx); final uri = Uri.parse(photo.url); if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication); }),
              ListTile(leading: const Icon(Icons.checklist_rounded, color: AppColors.accent), title: const Text('Select Multiple'), subtitle: const Text('Enter selection mode to delete many at once'), onTap: () { Navigator.pop(ctx); _enterSelectionMode(photo.id); }),
              ListTile(leading: const Icon(Icons.delete_outline, color: AppColors.error), title: const Text('Delete', style: TextStyle(color: AppColors.error)), onTap: () async {
                Navigator.pop(ctx);
                final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Delete Photo?'), content: const Text('This will permanently remove the photo from storage.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: AppColors.error), child: const Text('Delete'))]));
                if (confirm == true) { if (!isMock) await PhotoRepository.deletePhoto(photo.id, photo.url); ref.read(teacherPhotoStateProvider.notifier).removePhoto(photo.id); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('🗑️ Photo deleted'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating)); }
              }),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final sessionPhotos = ref.watch(allTeacherPhotosProvider);
    final firestorePhotos = ref.watch(firestorePhotosProvider).valueOrNull ?? [];
    final uploadState = ref.watch(uploadStateProvider);
    // Deduplicate by ID: prefer session photos, add Firestore photos only if ID not already present
    final seen = <String>{};
    final allPhotos = <PhotoModel>[];
    for (final p in sessionPhotos) {
      if (seen.add(p.id)) allPhotos.add(p);
    }
    for (final p in firestorePhotos) {
      // Also check URL to avoid same photo with different IDs (pending vs real)
      final alreadyByUrl = allPhotos.any((existing) => existing.url == p.url);
      if (seen.add(p.id) && !alreadyByUrl) allPhotos.add(p);
    }

    List<PhotoModel> filteredPhotos;
    switch (_filter) {
      case 'tagged':
        filteredPhotos = allPhotos.where((p) => p.childIds.isNotEmpty).toList();
        break;
      case 'pending':
        filteredPhotos = allPhotos.where((p) => p.childIds.isEmpty || p.tags.contains('__needs_review__')).toList();
        break;
      default:
        filteredPhotos = allPhotos;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: _selectionMode ? Text('${_selectedIds.length} selected', style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 18)) : Text('My Gallery', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.background, elevation: 0,
        leading: _selectionMode ? IconButton(icon: const Icon(Icons.close), onPressed: _exitSelectionMode) : null,
        actions: [
          if (!_selectionMode) ...[
            IconButton(
              icon: _isAutoTagging
                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                  : const Icon(Icons.auto_awesome, color: AppColors.primary),
              tooltip: 'Auto-Tag All',
              onPressed: _isAutoTagging ? null : _autoTagAll,
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.secondary),
              tooltip: 'Re-tag All Photos',
              onPressed: _reTagAll,
            ),
          ],
          if (_selectionMode)
            IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.error), onPressed: _selectedIds.isEmpty ? null : _deleteSelected)
          else
            Padding(padding: const EdgeInsets.only(right: 16), child: AvatarWidget(name: authState.currentUser?.name ?? 'Teacher', size: 36)),
        ],
      ),
      body: Column(children: [
        if (_isAutoTagging)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.primary.withValues(alpha: 0.06),
            child: Row(children: [
              SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
              const SizedBox(width: 10),
              Text('🔍 Auto-tagging... $_autoTagProgress processed',
                  style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
            ]),
          ),
        if (uploadState.isUploading)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.secondary.withValues(alpha: 0.06),
            child: Row(children: [
              SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.secondary)),
              const SizedBox(width: 10),
              Text('${uploadState.totalFiles - uploadState.completedFiles} uploading...', style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.secondary)),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            _FilterChip(label: 'All', count: allPhotos.length, isSelected: _filter == 'all', onTap: () => setState(() => _filter = 'all')),
            const SizedBox(width: 8),
            _FilterChip(label: 'Tagged', count: allPhotos.where((p) => p.childIds.isNotEmpty).length, isSelected: _filter == 'tagged', color: AppColors.success, onTap: () => setState(() => _filter = 'tagged')),
            const SizedBox(width: 8),
            _FilterChip(label: 'Needs Review', count: allPhotos.where((p) => p.childIds.isEmpty).length, isSelected: _filter == 'pending', color: AppColors.warning, onTap: () => setState(() => _filter = 'pending')),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: filteredPhotos.isEmpty
              ? _buildEmpty()
              : Padding(
                  padding: const EdgeInsets.all(12),
                  child: MasonryGridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    itemCount: filteredPhotos.length,
                    itemBuilder: (context, index) {
                      final photo = filteredPhotos[index];
                      return _TeacherPhotoCard(
                        photo: photo,
                        index: index,
                        showWarning: photo.childIds.isEmpty,
                        isSelected: _selectedIds.contains(photo.id),
                        isPending: isPhotoPending(photo),
                        selectionMode: _selectionMode,
                        uploadStatus: uploadState.fileUploadStatus[photo.id],
                        onTap: () {
                          if (_selectionMode) {
                            _toggleSelection(photo.id);
                          } else {
                            if (photo.childIds.isNotEmpty) {
                              // Already tagged — use simple photo viewer
                              final allPhotosList = filteredPhotos;
                              final photoIdx = allPhotosList.indexWhere((p) => p.id == photo.id);
                              context.push('/photo-viewer', extra: {
                                'photos': allPhotosList,
                                'index': photoIdx >= 0 ? photoIdx : 0,
                              });
                            } else {
                              context.push('/teacher/photo/${photo.id}', extra: photo);
                            }
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
      ]),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label; final int count; final bool isSelected; final Color? color; final VoidCallback onTap;
  const _FilterChip({required this.label, required this.count, required this.isSelected, this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppColors.primary;
    return GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: isSelected ? chipColor.withValues(alpha: 0.12) : AppColors.surfaceVariant, borderRadius: BorderRadius.circular(20), border: isSelected ? Border.all(color: chipColor, width: 1.5) : null), child: Row(mainAxisSize: MainAxisSize.min, children: [Text(label, style: GoogleFonts.nunito(fontSize: 13, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600, color: isSelected ? chipColor : AppColors.textSecondary)), const SizedBox(width: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: isSelected ? chipColor : AppColors.textTertiary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)), child: Text('$count', style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700, color: isSelected ? AppColors.white : AppColors.textTertiary)))])));
  }
}

class _TeacherPhotoCard extends StatelessWidget {
  final PhotoModel photo; final int index; final bool showWarning; final bool isSelected; final bool isPending; final bool selectionMode; final String? uploadStatus; final VoidCallback onTap; final VoidCallback onLongPress;
  const _TeacherPhotoCard({required this.photo, required this.index, required this.showWarning, required this.isSelected, required this.isPending, required this.selectionMode, this.uploadStatus, required this.onTap, required this.onLongPress});
  @override
  Widget build(BuildContext context) {
    final height = (index % 3 == 0) ? 200.0 : 160.0;
    final showUploadOverlay = isPending || uploadStatus == 'uploading' || uploadStatus == 'pending';
    return GestureDetector(onTap: onTap, onLongPress: onLongPress, child: Container(height: height, decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: AppColors.shadow.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2))], border: isSelected ? Border.all(color: AppColors.primary, width: 3) : null), child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Stack(fit: StackFit.expand, children: [
      if (isPending || photo.url.startsWith('/')) Image.file(File(photo.url), fit: BoxFit.cover, cacheWidth: 400, errorBuilder: (_, __, ___) => _placeholder()) else CachedNetworkImage(imageUrl: photo.url, fit: BoxFit.cover, memCacheWidth: 400, placeholder: (_, __) => _placeholder(), errorWidget: (_, __, ___) => _placeholder()),
      if (showUploadOverlay) Container(color: Colors.black38, child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)), const SizedBox(height: 8), Text(uploadStatus == 'uploading' ? 'Uploading...' : 'Pending', style: GoogleFonts.nunito(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600))]))),
      if (selectionMode) Positioned(top: 8, left: 8, child: Container(width: 26, height: 26, decoration: BoxDecoration(color: isSelected ? AppColors.primary : Colors.white.withValues(alpha: 0.8), shape: BoxShape.circle, border: Border.all(color: isSelected ? AppColors.primary : AppColors.textTertiary, width: 2)), child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null)),
      if (!showUploadOverlay) Positioned(top: 8, right: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: showWarning ? AppColors.warning : AppColors.success.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(8)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(showWarning ? Icons.warning_amber_rounded : Icons.check_circle, color: Colors.white, size: 12), const SizedBox(width: 4), Text(showWarning ? 'Tag' : 'Done', style: GoogleFonts.nunito(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700))]))),
      Positioned(bottom: 0, left: 0, right: 0, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, Colors.black54], begin: Alignment.topCenter, end: Alignment.bottomCenter)), child: Text(showUploadOverlay ? 'Uploading...' : photo.childIds.isEmpty ? 'Tap to tag' : '${photo.childIds.length} kid(s)', style: GoogleFonts.nunito(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)))),
    ]))));
  }
  Widget _placeholder() => Container(color: AppColors.surfaceVariant, child: const Center(child: Icon(Icons.image_outlined, color: AppColors.textTertiary, size: 32)));
}