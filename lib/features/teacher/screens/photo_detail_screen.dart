import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/photo_model.dart';
import '../../../data/mock/mock_data.dart';
import '../providers/teacher_photo_provider.dart';

/// Face color palette — each face gets a unique, distinguishable color.
const _faceColors = [
  Color(0xFFEF4444), // red
  Color(0xFF3B82F6), // blue
  Color(0xFFEAB308), // yellow
  Color(0xFFA855F7), // purple
  Color(0xFFF97316), // orange
  Color(0xFFEC4899), // pink
  Color(0xFF14B8A6), // teal
  Color(0xFF6366F1), // indigo
];

/// Photo detail with face tagging.
///
/// If the photo has aiDetections from cloud (Cloud Vision API),
/// colored circles appear on each face. Otherwise, manual tagging is available.
class PhotoDetailScreen extends ConsumerStatefulWidget {
  final PhotoModel photo;
  const PhotoDetailScreen({super.key, required this.photo});

  @override
  ConsumerState<PhotoDetailScreen> createState() => _PhotoDetailScreenState();
}

class _PhotoDetailScreenState extends ConsumerState<PhotoDetailScreen> {
  late List<String> _taggedChildIds;
  List<_FaceCircle> _faceCircles = [];

  @override
  void initState() {
    super.initState();
    _taggedChildIds = List<String>.from(widget.photo.childIds);
    _loadCloudFaces();
  }

  /// Read face detections from Firestore (populated by cloud function).
  void _loadCloudFaces() {
    final detections = widget.photo.aiDetections;

    if (detections.isNotEmpty) {
      final circs = <_FaceCircle>[];
      for (var i = 0; i < detections.length; i++) {
        final d = detections[i];
        final box = d.boundingBox;
        // boundingBox is [left, top, width, height] in pixels (from cloud function)
        final matchedChild =
            d.childId.isNotEmpty ? MockData.children.where((c) => c.id == d.childId).firstOrNull : null;

        circs.add(_FaceCircle(
          id: 'face_$i',
          index: i + 1,
          color: _faceColors[i % _faceColors.length],
          // Store pixel coordinates relative to original image dimensions
          rect: box.isNotEmpty && box.length >= 4
              ? Rect.fromLTWH(box[0], box[1], box[2], box[3])
              : Rect.zero,
          matchedChildId: d.childId.isNotEmpty ? d.childId : null,
          childName: matchedChild?.firstName ?? (d.childId.isNotEmpty ? d.childId : null),
        ));
      }

      setState(() => _faceCircles = circs);
    }
  }

  void _showTagPopup(_FaceCircle circle) {
    final children = MockData.children;
    final nameController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.textTertiary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Row(children: [
            Container(width: 32, height: 32, decoration: BoxDecoration(color: circle.color, shape: BoxShape.circle), child: Center(child: Text('${circle.index}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)))),
            const SizedBox(width: 10),
            Text('Tag Face #${circle.index}', style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 8),
          ...children.map((child) => ListTile(
            leading: CircleAvatar(backgroundColor: AppColors.primary.withValues(alpha: 0.12), child: Text(child.initials, style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary))),
            title: Text(child.firstName, style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
            onTap: () { _tagFace(circle, child.id, child.firstName); Navigator.pop(ctx); },
          )),
          const Divider(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: nameController,
              decoration: InputDecoration(hintText: 'Or type a new name...', prefixIcon: const Icon(Icons.person_add_alt_rounded, color: AppColors.accent), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none), filled: true, fillColor: AppColors.surfaceVariant),
              onSubmitted: (name) { if (name.trim().isNotEmpty) { _tagNewName(circle, name.trim()); Navigator.pop(ctx); } },
            ),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  void _tagFace(_FaceCircle circle, String childId, String childName) {
    setState(() {
      if (!_taggedChildIds.contains(childId)) _taggedChildIds.add(childId);
      circle.matchedChildId = childId;
      circle.childName = childName;
    });
    ref.read(teacherPhotoStateProvider.notifier).updateTags(widget.photo.id, _taggedChildIds);
  }

  void _tagNewName(_FaceCircle circle, String name) {
    final newId = 'custom_${name.toLowerCase().replaceAll(' ', '_')}';
    setState(() {
      _taggedChildIds.add(newId);
      circle.matchedChildId = newId;
      circle.childName = name;
    });
    ref.read(teacherPhotoStateProvider.notifier).updateTags(widget.photo.id, _taggedChildIds);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ $name tagged!'), backgroundColor: AppColors.success));
  }

  @override
  Widget build(BuildContext context) {
    final taggedCount = _faceCircles.where((c) => c.matchedChildId != null).length;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white), onPressed: () => context.pop()),
        title: Text('Face Tagging', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w700)),
        actions: [
          if (_faceCircles.isNotEmpty)
            Center(child: Padding(padding: const EdgeInsets.only(right: 16), child: Text('$taggedCount/${_faceCircles.length} tagged', style: GoogleFonts.nunito(color: Colors.white70, fontSize: 13)))),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: LayoutBuilder(builder: (context, constraints) {
            final cw = constraints.maxWidth;
            final ch = constraints.maxHeight;
            return InteractiveViewer(
              child: Stack(children: [
                Center(child: _buildImage()),
                for (final circle in _faceCircles)
                  if (circle.rect != Rect.zero)
                    Positioned(
                      left: (circle.rect.left / (_imgWidth ?? 1) * cw).clamp(0, cw - 72),
                      top: (circle.rect.top / (_imgHeight ?? 1) * ch).clamp(0, ch - 72),
                      child: GestureDetector(
                        onTap: () => circle.matchedChildId == null ? _showTagPopup(circle) : null,
                        child: _FaceCircleWidget(circle: circle),
                      ),
                    ),
              ]),
            );
          }),
        ),
        Container(
          width: double.infinity, padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Text(_faceCircles.isEmpty ? 'Tag Kids' : 'Face Detection', style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800)),
              if (_faceCircles.isNotEmpty) ...[
                const Spacer(),
                _LegendDot(color: AppColors.success, label: 'Tagged'),
                const SizedBox(width: 8),
                _LegendDot(color: AppColors.skyBlue, label: 'Untagged'),
              ],
            ]),
            if (_faceCircles.isEmpty) ...[
              const SizedBox(height: 4),
              Text('Cloud face detection runs on upload (deploy function first). Manual tagging always works!', style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textTertiary)),
            ],
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, height: 48, child: OutlinedButton.icon(onPressed: _showManualTagDialog, icon: const Icon(Icons.person_add_alt_rounded, size: 20), label: Text('Tag Kids Manually', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)), style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary))),
          ]),
        ),
      ]),
    );
  }

  Widget _buildImage() {
    return CachedNetworkImage(
      imageUrl: widget.photo.url,
      fit: BoxFit.contain,
      placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
      errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 48)),
    );
  }

  void _showManualTagDialog() {
    final children = MockData.children;
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.textTertiary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('Tag Kids in Photo', style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800)),
            ...children.map((child) => CheckboxListTile(
              value: _taggedChildIds.contains(child.id),
              onChanged: (val) {
                setModalState(() { if (val == true) _taggedChildIds.add(child.id); else _taggedChildIds.remove(child.id); });
                ref.read(teacherPhotoStateProvider.notifier).updateTags(widget.photo.id, _taggedChildIds);
              },
              title: Text(child.firstName, style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
            )),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }

  // Image dimensions cached for circle scaling
  double? _imgWidth;
  double? _imgHeight;
}

class _FaceCircle {
  final String id;
  final int index;
  final Color color;
  final Rect rect;
  String? matchedChildId;
  String? childName;

  _FaceCircle({required this.id, required this.index, required this.color, required this.rect, this.matchedChildId, this.childName});
  bool get isTagged => matchedChildId != null;
}

class _FaceCircleWidget extends StatelessWidget {
  final _FaceCircle circle;
  const _FaceCircleWidget({required this.circle});

  @override
  Widget build(BuildContext context) {
    final color = circle.isTagged ? AppColors.success : circle.color;
    final label = circle.isTagged ? (circle.childName ?? 'Tagged') : '${circle.index}';

    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 64, height: 64,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 3), color: color.withValues(alpha: 0.15)),
        child: circle.isTagged
            ? const Icon(Icons.check_circle, color: AppColors.success, size: 32)
            : Center(child: Text('$circle.index', style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w800, color: color))),
      ),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: GoogleFonts.nunito(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    ]);
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 4), Text(label, style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textSecondary))]);
}