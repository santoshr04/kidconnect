import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import '../../../core/theme/app_colors.dart';
import '../../../data/models/photo_model.dart';
import '../../../data/mock/mock_data.dart';
import '../../../core/services/cloud_vision_service.dart';
import '../providers/teacher_photo_provider.dart';

const _faceColors = [
  Color(0xFFEF4444), Color(0xFF3B82F6), Color(0xFFEAB308),
  Color(0xFFA855F7), Color(0xFFF97316), Color(0xFFEC4899),
  Color(0xFF14B8A6), Color(0xFF6366F1),
];

/// Face tagging with circles placed directly on each face in the photo.
/// Cloud Vision detects faces → circles appear exactly on faces.
/// Tap a circle to tag that person.
class PhotoDetailScreen extends ConsumerStatefulWidget {
  final PhotoModel photo;
  const PhotoDetailScreen({super.key, required this.photo});

  @override
  ConsumerState<PhotoDetailScreen> createState() => _PhotoDetailScreenState();
}

class _PhotoDetailScreenState extends ConsumerState<PhotoDetailScreen> {
  late List<String> _taggedChildIds;
  List<_FaceCircle> _faceCircles = [];
 bool _isetecting = false;
  String? _faceError;

  // Image dimensions from the actual photo file
  double _imgWidth = 1;
  double _imgHeight = 1;

  @override
  void initState() {
    super.initState();
    _taggedChildIds = List<String>.from(widget.photo.childIds);
    _loadFaces();
  }

  Future<void> _loadFaces() async {
    if (widget.photo.aiDetections.isNotEmpty) {
      _loadFromFirestore();
      return;
    }
    if (widget.photo.url.startsWith('https://')) {
      setState(() => _isDetecting = true);

      // Download image bytes to get actual dimensions
      try {
        final response = await http.get(Uri.parse(widget.photo.url));
        final bytes = response.bodyBytes;
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        _imgWidth = frame.image.width.toDouble();
        _imgHeight = frame.image.height.toDouble();
        frame.image.dispose();
        codec.dispose();
      } catch (_) {
        // Fallback to default 4:3 ratio
        _imgWidth = 4000;
        _imgHeight = 3000;
      }

      final result = await CloudVisionService.detectFaces(widget.photo.url);
      if (!mounted) return;
      final faces = result['faces'] as List;
      if (faces.isNotEmpty) {
        final circs = <_FaceCircle>[];
        for (var i = 0; i < faces.length; i++) {
          final f = faces[i] as Map<String, dynamic>;
          circs.add(_FaceCircle(
            id: 'face_$i', index: i + 1,
            color: _faceColors[i % _faceColors.length],
            // Store normalized coords (0.0-1.0) for accurate display scaling
            rect: Rect.fromLTWH(
              (f['left'] as num).toDouble() / _imgWidth,
              (f['top'] as num).toDouble() / _imgHeight,
              (f['width'] as num).toDouble() / _imgWidth,
              (f['height'] as num).toDouble() / _imgHeight,
            ),
          ));
        }
        setState(() { _faceCircles = circs; _isDetecting = false; });
      } else {
        setState(() { _isDetecting = false; _faceError = 'No faces detected'; });
      }
    }
  }

  void _loadFromFirestore() {
    // Firestore coords are already in original pixels — need to normalize
    final circs = <_FaceCircle>[];
    for (var i = 0; i < widget.photo.aiDetections.length; i++) {
      final d = widget.photo.aiDetections[i];
      final box = d.boundingBox;
      final child = d.childId.isNotEmpty
          ? MockData.children.where((c) => c.id == d.childId).firstOrNull
          : null;
      if (box.length >= 4 && _imgWidth > 1) {
        circs.add(_FaceCircle(
          id: 'face_$i', index: i + 1, color: _faceColors[i % _faceColors.length],
          rect: Rect.fromLTWH(box[0] / _imgWidth, box[1] / _imgHeight, box[2] / _imgWidth, box[3] / _imgHeight),
          matchedChildId: d.childId.isNotEmpty ? d.childId : null,
          childName: child?.firstName ?? (d.childId.isNotEmpty ? d.childId : null),
        ));
      }
    }
    setState(() => _faceCircles = circs);
  }

  void _showTagPopup(_FaceCircle circle) {
    final children = MockData.children;
    final nameController = TextEditingController();
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.textTertiary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Row(children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(color: circle.color.withValues(alpha: 0.15), shape: BoxShape.circle, border: Border.all(color: circle.color, width: 2.5)),
              child: Center(child: Icon(Icons.person, color: circle.color, size: 24))),
            const SizedBox(width: 12),
            Text('Tag this face', style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 12),
          ...children.map((child) => ListTile(
            leading: CircleAvatar(backgroundColor: AppColors.primary.withValues(alpha: 0.12), child: Text(child.initials, style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary))),
            title: Text(child.firstName, style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
            onTap: () { _tagFace(circle, child.id, child.firstName); Navigator.pop(ctx); },
          )),
          const Divider(height: 24),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(controller: nameController, decoration: InputDecoration(hintText: 'Or type a new name...', prefixIcon: const Icon(Icons.person_add_alt_rounded, color: AppColors.accent), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none), filled: true, fillColor: AppColors.surfaceVariant),
              onSubmitted: (name) { if (name.trim().isNotEmpty) { _tagNewName(circle, name.trim()); Navigator.pop(ctx); } })),
          const SizedBox(height: 8),
          TextButton(onPressed: () { final name = nameController.text.trim(); if (name.isNotEmpty) { _tagNewName(circle, name); Navigator.pop(ctx); } }, child: const Text('Save Name')),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  void _tagFace(_FaceCircle circle, String childId, String childName) {
    setState(() { if (!_taggedChildIds.contains(childId)) _taggedChildIds.add(childId); circle.matchedChildId = childId; circle.childName = childName; });
    ref.read(teacherPhotoStateProvider.notifier).updateTags(widget.photo.id, _taggedChildIds);
  }

  void _tagNewName(_FaceCircle circle, String name) {
    final newId = 'custom_${name.toLowerCase().replaceAll(' ', '_')}';
    setState(() { _taggedChildIds.add(newId); circle.matchedChildId = newId; circle.childName = name; });
    ref.read(teacherPhotoStateProvider.notifier).updateTags(widget.photo.id, _taggedChildIds);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ $name tagged!'), backgroundColor: AppColors.success));
  }

  @override
  Widget build(BuildContext context) {
    final taggedCount = _faceCircles.where((c) => c.matchedChildId != null).length;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white), onPressed: () => context.pop()),
        title: Text('Tag Faces', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w700)),
        actions: [_faceCircles.isNotEmpty ? Center(child: Padding(padding: const EdgeInsets.only(right: 16), child: Text('$taggedCount/${_faceCircles.length} tagged', style: GoogleFonts.nunito(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)))) : const SizedBox.shrink()],
      ),
      body: Column(children: [
        // Detecting spinner
        if (_isDetecting)
          Container(padding: const EdgeInsets.all(16), color: Colors.white, child: const Row(children: [CircularProgressIndicator(strokeWidth: 2), SizedBox(width: 12), Text('🤖 AI detecting faces...')])),

        // Photo with face circles overlay
        Expanded(
          child: Container(
            color: Colors.black,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cw = constraints.maxWidth;
                final ch = constraints.maxHeight;

                // Calculate BoxFit.contain dimensions
                double displayImgW, displayImgH, offsetX, offsetY;
                final imgAspect = _imgWidth / (_imgHeight > 0 ? _imgHeight : 1);
                final containerAspect = cw / (ch > 0 ? ch : 1);

                if (imgAspect > containerAspect) {
                  // Image is wider — fit to width
                  displayImgW = cw;
                  displayImgH = cw / imgAspect;
                  offsetX = 0;
                  offsetY = (ch - displayImgH) / 2;
                } else {
                  // Image is taller — fit to height
                  displayImgH = ch;
                  displayImgW = ch * imgAspect;
                  offsetX = (cw - displayImgW) / 2;
                  offsetY = 0;
                }

                return Stack(children: [
                  // Photo
                  Positioned(
                    left: offsetX, top: offsetY,
                    width: displayImgW, height: displayImgH,
                    child: CachedNetworkImage(
                      imageUrl: widget.photo.url, fit: BoxFit.fill,
                      placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: Colors.white)),
                      errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 48)),
                    ),
                  ),

                  // Face circles — positioned precisely on faces
                  for (final circle in _faceCircles)
                    if (circle.rect != Rect.zero)
                      Positioned(
                        // Scale normalized coords (0-1) to display image size, then add container offset
                        left: offsetX + circle.rect.left * displayImgW,
                        top: offsetY + circle.rect.top * displayImgH,
                        child: GestureDetector(
                          onTap: () => circle.matchedChildId == null ? _showTagPopup(circle) : null,
                          child: _FaceCircleWidget(circle: circle),
                        ),
                      ),
                ]);
              },
            ),
          ),
        ),

        // Bottom legend panel
        Container(
          width: double.infinity, padding: const EdgeInsets.all(20), color: AppColors.white,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Text(_faceCircles.isEmpty ? 'Tag Kids' : '🤖 Face Detection', style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              if (_faceCircles.isNotEmpty) ...[const Spacer(), _LegendDot(color: AppColors.success, label: 'Tagged'), const SizedBox(width: 12), _LegendDot(color: AppColors.skyBlue, label: 'Tap to tag')],
            ]),
            if (_faceError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_faceError!, style: GoogleFonts.nunito(fontSize: 12, color: AppColors.warning))),
            if (_faceCircles.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('🟢 Tagged  |  🔵 Tap circle on face to tag', style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textSecondary))),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, height: 48, child: OutlinedButton.icon(onPressed: _showManualTagDialog, icon: const Icon(Icons.person_add_alt_rounded, size: 20), label: Text('Tag Kids Manually', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)), style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary))),
          ]),
        ),
      ]),
    );
  }

  void _showManualTagDialog() {
    final children = MockData.children;
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModalState) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.textTertiary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16), Text('Tag Kids in Photo', style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800)),
          ...children.map((child) => CheckboxListTile(value: _taggedChildIds.contains(child.id), onChanged: (val) { setModalState(() { if (val == true) _taggedChildIds.add(child.id); else _taggedChildIds.remove(child.id); }); ref.read(teacherPhotoStateProvider.notifier).updateTags(widget.photo.id, _taggedChildIds); }, title: Text(child.firstName, style: GoogleFonts.nunito(fontWeight: FontWeight.w700)))),
          const SizedBox(height: 16),
        ]))));
  }
}

class _FaceCircle {
  final String id; final int index; final Color color;
  final Rect rect; // normalized 0.0-1.0
  String? matchedChildId; String? childName;
  _FaceCircle({required this.id, required this.index, required this.color, required this.rect, this.matchedChildId, this.childName});
}

/// Circle widget placed on each face.
class _FaceCircleWidget extends StatelessWidget {
  final _FaceCircle circle;
  const _FaceCircleWidget({required this.circle});

  @override
  Widget build(BuildContext context) {
    final isTagged = circle.matchedChildId != null;
    final color = isTagged ? AppColors.success : circle.color;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 3),
          color: color.withValues(alpha: 0.15),
        ),
        child: Center(
          child: isTagged
              ? const Icon(Icons.check, color: AppColors.success, size: 22)
              : Icon(Icons.person, color: color, size: 22),
        ),
      ),
      Container(
        margin: const EdgeInsets.only(top: 2),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(6)),
        child: Text(
          isTagged ? (circle.childName ?? 'OK') : 'Tap',
          style: GoogleFonts.nunito(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
        ),
      ),
    ]);
  }
}

class _LegendDot extends StatelessWidget {
  final Color color; final String label;
  const _LegendDot({required this.color, required this.label});
  @override Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 4), Text(label, style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textSecondary))]);
}