import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/mock/mock_data.dart';
import '../../../data/models/photo_model.dart';
import '../../auth/providers/auth_provider.dart';

/// Photo gallery with masonry grid layout
class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  String _selectedFilter = 'All';
  bool _smartSortEnabled = true;

  final _filters = [
    'All',
    'Art',
    'Sports',
    'Learning',
    'Celebration',
    'Outdoor',
  ];

  @override
  Widget build(BuildContext context) {
    final childId = ref.watch(authProvider).selectedChildId ?? 'child_1';
    var photos = MockData.getPhotosForChild(childId);

    // If parent has multiple children, show all photos
    final authState = ref.watch(authProvider);
    if (authState.isParent) {
      final children = MockData.getChildrenForParent(authState.currentUser?.id ?? '');
      photos = [];
      for (final child in children) {
        photos.addAll(MockData.getPhotosForChild(child.id));
      }
    }

    // Apply filter
    if (_selectedFilter != 'All') {
      photos = photos
          .where((p) => p.tags.any((t) =>
              t.toLowerCase().contains(_selectedFilter.toLowerCase())))
          .toList();
    }

    // Sort by date or smart sort
    photos.sort((a, b) {
      if (_smartSortEnabled) {
        final aHasChild = a.childIds.contains(childId);
        final bHasChild = b.childIds.contains(childId);
        if (aHasChild && !bHasChild) return -1;
        if (!aHasChild && bHasChild) return 1;
      }
      return b.uploadDate.compareTo(a.uploadDate);
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Gallery',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.search_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Filter Chips ─────────────────────────────────
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = _selectedFilter == filter;
                return GestureDetector(
                  onTap: () => setState(() => _selectedFilter = filter),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        filter,
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? AppColors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // ─── Photo Count & Smart Sort Toggle ──────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  '${photos.length} Photos',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  'Smart Sort 🎯',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _smartSortEnabled ? AppColors.primary : AppColors.textTertiary,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 24,
                  width: 40,
                  child: Switch(
                    value: _smartSortEnabled,
                    onChanged: (val) => setState(() => _smartSortEnabled = val),
                    activeColor: AppColors.primary,
                    activeTrackColor: AppColors.primaryLight.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ─── Photo Grid ───────────────────────────────────
          Expanded(
            child: photos.isEmpty
                ? _buildEmptyState()
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: MasonryGridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      itemCount: photos.length,
                      itemBuilder: (context, index) {
                        final photo = photos[index];
                        // Alternate heights for masonry effect
                        final isLarge = index % 3 == 0;

                        return GestureDetector(
                          onTap: () =>
                              _showPhotoViewer(context, photos, index),
                          child: _PhotoCard(
                            photo: photo,
                            height: isLarge ? 240 : 180,
                            index: index,
                            childId: childId,
                            showBadge: _smartSortEnabled && photo.childIds.contains(childId),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📸', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            'No photos yet',
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Photos will appear here when teachers upload them',
            style: GoogleFonts.nunito(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  void _showPhotoViewer(
      BuildContext context, List<PhotoModel> photos, int initialIndex) {
    showDialog(
      context: context,
      builder: (context) => _PhotoViewerDialog(
        photos: photos,
        initialIndex: initialIndex,
      ),
    );
  }
}

/// Individual photo card with animation
class _PhotoCard extends StatefulWidget {
  final PhotoModel photo;
  final double height;
  final int index;
  final String childId;
  final bool showBadge;

  const _PhotoCard({
    required this.photo,
    required this.height,
    required this.index,
    required this.childId,
    this.showBadge = false,
  });

  @override
  State<_PhotoCard> createState() => _PhotoCardState();
}

class _PhotoCardState extends State<_PhotoCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    Future.delayed(Duration(milliseconds: 60 * widget.index), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                widget.photo.url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.surfaceVariant,
                  child: const Center(
                    child: Icon(Icons.image_not_supported_outlined,
                        color: AppColors.textTertiary, size: 32),
                  ),
                ),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: AppColors.surfaceVariant,
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                        color: AppColors.primary,
                      ),
                    ),
                  );
                },
              ),
              // Face Detected Badge
              if (widget.showBadge)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.center_focus_strong, color: AppColors.white, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          'Detected',
                          style: GoogleFonts.nunito(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // Caption overlay
              if (widget.photo.caption != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.6),
                        ],
                      ),
                    ),
                    child: Text(
                      widget.photo.caption!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full screen photo viewer dialog
class _PhotoViewerDialog extends StatefulWidget {
  final List<PhotoModel> photos;
  final int initialIndex;

  const _PhotoViewerDialog({
    required this.photos,
    required this.initialIndex,
  });

  @override
  State<_PhotoViewerDialog> createState() => _PhotoViewerDialogState();
}

class _PhotoViewerDialogState extends State<_PhotoViewerDialog> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          // Photo pages
          PageView.builder(
            controller: _pageController,
            itemCount: widget.photos.length,
            onPageChanged: (index) =>
                setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              final photo = widget.photos[index];
              return InteractiveViewer(
                child: Center(
                  child: Image.network(
                    photo.url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.white,
                      size: 48,
                    ),
                  ),
                ),
              );
            },
          ),
          // Close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded,
                  color: AppColors.white, size: 28),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black45,
              ),
            ),
          ),
          // Caption
          if (widget.photos[_currentIndex].caption != null)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.photos[_currentIndex].caption!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    color: AppColors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          // Page indicator
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_currentIndex + 1} / ${widget.photos.length}',
                  style: GoogleFonts.nunito(
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
