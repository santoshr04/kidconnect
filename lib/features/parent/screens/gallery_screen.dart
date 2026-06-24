import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/avatar_widget.dart';
import '../../../data/mock/mock_data.dart';
import '../../../data/models/photo_model.dart';
import '../../../data/repositories/photo_repository.dart';
import '../../auth/providers/auth_provider.dart';

/// Intelligent Gallery Screen with AI-filtered feeds.
///
/// Tab 1: Only photos where YOUR child was detected by AI.
/// Tab 2: All class photos (no filter).
/// Uses Firestore streams in production, mock data as fallback.
class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final childId = authState.selectedChildId ?? 'child_1';
    final child = MockData.getChildById(childId);
    final isMock = authState.usingMockData;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            floating: true,
            pinned: true,
            expandedHeight: 120,
            backgroundColor: AppColors.background,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              title: Text(
                'Photo Feed',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  fontSize: 22,
                ),
              ),
              centerTitle: false,
            ),
            actions: [
              if (isMock)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Chip(
                    label: Text('MOCK',
                        style: GoogleFonts.nunito(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.warning)),
                    backgroundColor: AppColors.warningLight,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: AvatarWidget(
                  name: authState.currentUser?.name ?? 'User',
                  size: 36,
                ),
              ),
            ],
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverAppBarDelegate(
              TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textTertiary,
                labelStyle: GoogleFonts.nunito(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
                tabs: [
                  Tab(text: 'For ${child?.firstName ?? "You"}'),
                  const Tab(text: 'Class Feed'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: AI-filtered (only child's photos)
            _PhotoGrid(
              childId: childId,
              isMock: isMock,
            ),
            // Tab 2: All class photos
            _PhotoGrid(
              childId: null,
              isMock: isMock,
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoGrid extends ConsumerWidget {
  final String? childId;
  final bool isMock;

  const _PhotoGrid({this.childId, required this.isMock});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isMock) {
      // Use mock data
      final photos = childId != null
          ? MockData.getPhotosForChild(childId!)
          : MockData.photos;
      return _PhotoList(photos: photos, isEmpty: photos.isEmpty);
    }

    // Use Firestore stream
    final stream = childId != null
        ? PhotoRepository.getPhotosForChild(childId!)
        : PhotoRepository.getAllPhotos();

    return StreamBuilder<List<PhotoModel>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _buildEmptyState();
        }
        final photos = snapshot.data!;
        return _PhotoList(photos: photos, isEmpty: photos.isEmpty);
      },
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
            childId != null ? 'No photos of your child yet' : 'Class gallery is empty',
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text('Teachers haven\'t uploaded any photos yet'),
        ],
      ),
    );
  }
}

class _PhotoList extends StatelessWidget {
  final List<PhotoModel> photos;
  final bool isEmpty;

  const _PhotoList({required this.photos, required this.isEmpty});

  @override
  Widget build(BuildContext context) {
    if (isEmpty) {
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
              ),
            ),
            const SizedBox(height: 4),
            const Text('Teachers haven\'t uploaded any photos yet'),
          ],
        ),
      );
    }

    // Group photos by date
    final groupedPhotos = <String, List<PhotoModel>>{};
    for (var photo in photos) {
      final dateStr = DateFormat('EEEE, MMM d').format(photo.uploadDate);
      if (!groupedPhotos.containsKey(dateStr)) {
        groupedPhotos[dateStr] = [];
      }
      groupedPhotos[dateStr]!.add(photo);
    }

    final dateKeys = groupedPhotos.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.only(top: 16, bottom: 100),
      itemCount: dateKeys.length,
      itemBuilder: (context, index) {
        final date = dateKeys[index];
        final dayPhotos = groupedPhotos[date]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Text(
                date,
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: MasonryGridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                itemCount: dayPhotos.length,
                itemBuilder: (context, i) {
                  final photo = dayPhotos[i];
                  return _PhotoCard(
                    photo: photo,
                    height: (i % 3 == 0) ? 240 : 180,
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

class _PhotoCard extends StatelessWidget {
  final PhotoModel photo;
  final double height;

  const _PhotoCard({required this.photo, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
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
              photo.resolutions?.thumbnail ?? photo.url,
              fit: BoxFit.cover,
            ),
            // AI Confidence Badge
            if (photo.aiDetections.isNotEmpty)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome,
                          color: Colors.white, size: 10),
                      const SizedBox(width: 4),
                      Text(
                        'AI',
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.background,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}