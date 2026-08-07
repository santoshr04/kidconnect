import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/photo_model.dart';
import '../../../data/repositories/photo_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../teacher/providers/teacher_photo_provider.dart';

/// Full-screen photo viewer with swipe left/right and pinch-to-zoom.
/// Used by both parents and teachers. Teachers see a delete button.
class ParentPhotoViewerScreen extends ConsumerStatefulWidget {
  final List<PhotoModel> photos;
  final int initialIndex;

  const ParentPhotoViewerScreen({
    super.key,
    required this.photos,
    required this.initialIndex,
  });

  @override
  ConsumerState<ParentPhotoViewerScreen> createState() =>
      _ParentPhotoViewerScreenState();
}

class _ParentPhotoViewerScreenState
    extends ConsumerState<ParentPhotoViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showOverlay = true;
  // Track which photos have been deleted locally for immediate UI update
  final Set<int> _deletedIndices = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggleOverlay() => setState(() => _showOverlay = !_showOverlay);

  Future<void> _retagCurrentPhoto() async {
    if (_currentIndex >= widget.photos.length) return;
    final photo = widget.photos[_currentIndex];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Re-tag Photo?',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: Text(
            'This will clear existing tags and re-open the photo for manual tagging. The photo will appear in "Needs Review".',
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
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: Text('Re-tag',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final isMock = ref.read(authProvider).usingMockData;

    // Clear existing tagging in Firestore so it appears in "Needs Review"
    if (!isMock) {
      try {
        await FirebaseFirestore.instance
            .collection('photos')
            .doc(photo.id)
            .update({
          'childIds': <String>[],
          'aiDetections': <Map<String, dynamic>>[],
          'tags': ['__needs_review__'],
        });
      } catch (_) {}
    }

    // Remove from session state so it re-fetches from Firestore
    ref.read(teacherPhotoStateProvider.notifier).removePhoto(photo.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('🔁 Photo marked for re-tagging — find it in Needs Review'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteCurrentPhoto() async {
    if (_currentIndex >= widget.photos.length) return;

    final photo = widget.photos[_currentIndex];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Photo?',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: Text(
            'This will permanently remove the photo from storage.',
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: Text('Delete',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final photoId = photo.id;
    final photoUrl = photo.url;
    final isMock = ref.read(authProvider).usingMockData;

    // Remove from session state immediately
    ref.read(teacherPhotoStateProvider.notifier).removePhoto(photoId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('🗑️ Photo deleted'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    // Perform actual deletion from Firebase
    if (!isMock) {
      await PhotoRepository.deletePhoto(photoId, photoUrl);
    }

    // Navigate away: pop if only one photo left, otherwise remove from list
    if (!mounted) return;
    if (widget.photos.length <= 1) {
      Navigator.of(context).pop();
      return;
    }

    // Remove from list and adjust index
    setState(() {
      widget.photos.removeAt(_currentIndex);
      if (_currentIndex >= widget.photos.length) {
        _currentIndex = widget.photos.length - 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photos[_currentIndex];
    final total = widget.photos.length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Swipeable photos
          PageView.builder(
            controller: _pageController,
            itemCount: widget.photos.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: widget.photos[index].url,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    errorWidget: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image,
                          color: Colors.white54, size: 64),
                    ),
                  ),
                ),
              );
            },
          ),

          // Tap-to-toggle overlay area
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggleOverlay,
              behavior: HitTestBehavior.translucent,
            ),
          ),

          // Top bar — auto-hides
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            top: _showOverlay ? 0 : -100,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        '${_currentIndex + 1} / $total',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    // Only teachers see re-tag and delete options
                    if (!ref.read(authProvider).isParent) ...[
                      IconButton(
                        icon: const Icon(Icons.auto_fix_high,
                            color: Color(0xFF64B5F6), size: 22),
                        tooltip: 'Re-tag Photo',
                        onPressed: _retagCurrentPhoto,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent, size: 22),
                        tooltip: 'Delete Photo',
                        onPressed: _deleteCurrentPhoto,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Bottom info bar — auto-hides
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            bottom: _showOverlay ? 0 : -120,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black87],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (photo.caption?.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          photo.caption!,
                          style: GoogleFonts.nunito(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    if (photo.childIds.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: photo.childIds.map((id) {
                          // Try to look up child name from mock data
                          final child = _getChildName(id);
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              child,
                              style: GoogleFonts.nunito(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getChildName(String childId) {
    // Simple lookup — we'd use MockData here but to avoid circular imports,
    // use a basic switch for known children
    switch (childId) {
      case 'child_ruthvi':
        return 'Ruthvi Aisiri S';
      case 'child_1':
        return 'Emma Davis';
      case 'child_2':
        return 'Liam Wilson';
      case 'child_3':
        return 'Sophia Martinez';
      default:
        if (childId.startsWith('custom_')) {
          return childId.replaceFirst('custom_', '').replaceAll('_', ' ');
        }
        return childId;
    }
  }
}