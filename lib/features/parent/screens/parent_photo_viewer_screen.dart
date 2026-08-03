import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/photo_model.dart';

/// Full-screen photo viewer for parents with swipe left/right and pinch-to-zoom.
class ParentPhotoViewerScreen extends StatefulWidget {
  final List<PhotoModel> photos;
  final int initialIndex;

  const ParentPhotoViewerScreen({
    super.key,
    required this.photos,
    required this.initialIndex,
  });

  @override
  State<ParentPhotoViewerScreen> createState() =>
      _ParentPhotoViewerScreenState();
}

class _ParentPhotoViewerScreenState extends State<ParentPhotoViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showOverlay = true;

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
                    // Spacer to balance the close button
                    const SizedBox(width: 48),
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