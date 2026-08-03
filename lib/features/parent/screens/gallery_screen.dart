import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/avatar_widget.dart';
import '../../../data/mock/mock_data.dart';
import '../../../data/models/photo_model.dart';
import '../../../data/repositories/photo_repository.dart';
import '../../../core/services/insight_face_service.dart';
import '../../auth/providers/auth_provider.dart';

class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});
  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isEnrolled = true;
  bool _checkingEnrollment = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkEnrollment());
  }

  Future<void> _checkEnrollment() async {
    final authState = ref.read(authProvider);
    if (authState.usingMockData) {
      if (mounted) setState(() { _checkingEnrollment = false; _isEnrolled = true; });
      return;
    }
    final childId = authState.selectedChildId ?? 'child_ruthvi';
    final enrolled = await InsightFaceService.isChildEnrolled(childId);
    if (mounted) setState(() { _checkingEnrollment = false; _isEnrolled = enrolled; });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final childId = authState.selectedChildId ?? 'child_ruthvi';
    final child = MockData.getChildById(childId);
    final isMock = authState.usingMockData;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, inner) => [
          SliverAppBar(
            floating: true,
            pinned: true,
            expandedHeight: 120,
            backgroundColor: AppColors.background,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              title: Text('Photo Feed',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontSize: 22)),
              centerTitle: false,
            ),
            actions: [
              if (!_checkingEnrollment && !_isEnrolled)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => context.go('/parent/face-setup'),
                    child: Chip(
                      label: Text('Train Face',
                          style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary)),
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      padding: EdgeInsets.zero,
                      avatar: const Icon(Icons.face, size: 16, color: AppColors.primary),
                    ),
                  ),
                ),
              if (isMock)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Chip(
                    label: Text('MOCK', style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.warning)),
                    backgroundColor: AppColors.warningLight,
                    padding: EdgeInsets.zero,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: AvatarWidget(name: authState.currentUser?.name ?? 'User', size: 36),
              ),
            ],
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverAppBarDelegate(TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textTertiary,
              labelStyle: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 15),
              tabs: [
                Tab(text: '${child?.firstName ?? "Ruthvi"}\'s Feed'),
                const Tab(text: 'Class Feed'),
              ],
            )),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildChildFeed(childId: childId),
            _buildTab(filterByChild: false),
          ],
        ),
      ),
    );
  }

  /// Child feed tab — shows training prompt if not enrolled, else shows tagged photos.
  Widget _buildChildFeed({required String childId}) {
    if (_checkingEnrollment) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_isEnrolled) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Icons.face, size: 40, color: AppColors.primary),
              ),
              const SizedBox(height: 20),
              Text('Train Your Child\'s Face',
                  style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Text('Help the app recognize your child in photos.\nTake 3-10 clear face photos from different angles.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => context.go('/parent/face-setup'),
                  icon: const Icon(Icons.fingerprint, size: 20),
                  label: Text('Start Face Training', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 16)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return _buildTab(childId: childId, filterByChild: true);
  }

  Widget _buildTab({String? childId, required bool filterByChild}) {
    final snap = ref.watch(_allPhotosProvider);
    return snap.when(
      data: (photos) {
        final filtered = filterByChild && childId != null
            ? photos.where((p) => p.childIds.contains(childId)).toList()
            : photos;
        final displayList = filtered.isNotEmpty ? filtered : MockData.photos;
        if (displayList.isEmpty) {
          return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('📸', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text('No photos yet', style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('Teachers haven\'t uploaded any photos yet'),
            ]),
          );
        }
        return _PhotoGrid(photos: displayList);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) {
        final filtered = filterByChild && childId != null
            ? MockData.getPhotosForChild(childId) : MockData.photos;
        return _PhotoGrid(photos: filtered);
      },
    );
  }
}

final _allPhotosProvider = StreamProvider<List<PhotoModel>>((ref) {
  return PhotoRepository.getAllPhotos();
});

class _PhotoGrid extends StatelessWidget {
  final List<PhotoModel> photos;
  const _PhotoGrid({required this.photos});

  @override
  Widget build(BuildContext context) {
    final sorted = List<PhotoModel>.from(photos)..sort((a, b) => b.uploadDate.compareTo(a.uploadDate));
    final items = <dynamic>[];
    String? lastDate;
    for (final photo in sorted) {
      final dateLabel = DateFormat('EEEE, MMM d').format(photo.uploadDate);
      if (dateLabel != lastDate) {
        items.add(_DateHeader(label: dateLabel));
        lastDate = dateLabel;
      }
      items.add(photo);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: MasonryGridView.count(
        crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10,
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          if (item is _DateHeader) {
            return Padding(padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Text(item.label, style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: AppColors.textSecondary, fontSize: 14)));
          }
          final photo = item as PhotoModel;
          return _PhotoCard(photo: photo, height: (index % 3 == 0) ? 220.0 : 160.0, onTap: () {
            final allPhotos = photos;
            final photoIdx = allPhotos.indexWhere((p) => p.id == photo.id);
            context.push('/parent/photo-viewer', extra: {'photos': allPhotos, 'index': photoIdx >= 0 ? photoIdx : 0});
          });
        },
      ),
    );
  }
}

class _DateHeader { final String label; const _DateHeader({required this.label}); }

class _PhotoCard extends StatelessWidget {
  final PhotoModel photo; final double height; final VoidCallback onTap;
  const _PhotoCard({required this.photo, required this.height, required this.onTap});

  @override
  Widget build(BuildContext ctx) {
    return GestureDetector(onTap: onTap, child: Container(height: height,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: AppColors.shadow.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2))]),
      child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Stack(fit: StackFit.expand, children: [
        CachedNetworkImage(imageUrl: photo.resolutions?.thumbnail ?? photo.url, fit: BoxFit.cover, memCacheWidth: 400,
          placeholder: (_, __) => Container(color: AppColors.surfaceVariant, child: const Center(child: Icon(Icons.image_outlined, color: AppColors.textTertiary, size: 32))),
          errorWidget: (_, __, ___) => Container(color: AppColors.surfaceVariant, child: const Center(child: Icon(Icons.broken_image, color: AppColors.textTertiary, size: 32)))),
        Positioned(bottom: 0, left: 0, right: 0,
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, Colors.black54], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
            child: Text(photo.aiDetections.isNotEmpty ? '${photo.childIds.length} kid(s)' : (photo.caption ?? ''), style: GoogleFonts.nunito(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis))),
        if (photo.aiDetections.isNotEmpty)
          Positioned(top: 8, right: 8,
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(6)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.auto_awesome, color: Colors.white, size: 10), SizedBox(width: 4), Text('AI', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800))]))),
      ]))));
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar; _SliverAppBarDelegate(this.tabBar);
  @override double get minExtent => tabBar.preferredSize.height;
  @override double get maxExtent => tabBar.preferredSize.height;
  @override Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(color: AppColors.background, child: tabBar);
  @override bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}