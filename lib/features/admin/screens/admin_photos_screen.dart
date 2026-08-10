import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';

class AdminPhotosScreen extends ConsumerStatefulWidget {
  const AdminPhotosScreen({super.key});
  @override
  ConsumerState<AdminPhotosScreen> createState() => _AdminPhotosScreenState();
}

class _AdminPhotosScreenState extends ConsumerState<AdminPhotosScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _allPhotos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('photos')
          .orderBy('uploadDate', descending: true)
          .get();
      if (mounted)
        setState(() {
          _allPhotos =
              snap.docs.map((d) => d.data()..['id'] = d.id).toList();
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _pending =>
      _allPhotos.where((p) {
        final tags = (p['tags'] as List<dynamic>? ?? []);
        final childIds = (p['childIds'] as List<dynamic>? ?? []);
        return tags.contains('__needs_review__') || childIds.isEmpty;
      }).toList();

  List<Map<String, dynamic>> get _lowConfidence =>
      _allPhotos.where((p) {
        final detections = (p['aiDetections'] as List<dynamic>? ?? []);
        return detections.isNotEmpty &&
            detections.any((d) =>
                (d['confidenceTier'] as String? ?? '') == 'medium' ||
                (d['confidenceTier'] as String? ?? '') == 'low');
      }).toList();

  List<Map<String, dynamic>> get _tagged =>
      _allPhotos.where((p) {
        final childIds = (p['childIds'] as List<dynamic>? ?? []);
        return childIds.isNotEmpty;
      }).toList();

  Future<void> _markReviewed(String id) async {
    await FirebaseFirestore.instance.collection('photos').doc(id).update({
      'tags': ['reviewed'],
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Photos Review',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.background,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textTertiary,
          labelStyle: GoogleFonts.nunito(
              fontWeight: FontWeight.w700, fontSize: 13),
          tabs: [
            Tab(text: 'Pending (${_pending.length})'),
            Tab(text: 'Low Conf (${_lowConfidence.length})'),
            Tab(text: 'Tagged (${_tagged.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(_pending, showApprove: true),
                _buildList(_lowConfidence),
                _buildList(_tagged),
              ],
            ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> photos,
      {bool showApprove = false}) {
    if (photos.isEmpty) {
      return Center(
          child: Text('No photos',
              style: GoogleFonts.nunito(color: AppColors.textTertiary)));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          childAspectRatio: 0.85),
      itemCount: photos.length,
      itemBuilder: (_, i) {
        final p = photos[i];
        final childIds = (p['childIds'] as List<dynamic>? ?? []);
        final url = p['url'] as String? ?? '';
        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                height: double.infinity,
                placeholder: (_, __) =>
                    Container(color: AppColors.surfaceVariant),
                errorWidget: (_, __, ___) => Container(
                    color: AppColors.surfaceVariant,
                    child: const Icon(Icons.broken_image)),
              ),
            ),
            if (showApprove)
              Positioned(
                bottom: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => _markReviewed(p['id'] as String),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(6)),
                    child: const Icon(Icons.check,
                        color: Colors.white, size: 16),
                  ),
                ),
              ),
            if (childIds.isNotEmpty)
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6)),
                  child: Text('${childIds.length}',
                      style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
              ),
          ],
        );
      },
    );
  }
}