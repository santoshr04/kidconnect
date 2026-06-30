import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/photo_model.dart';
import '../../../data/mock/mock_data.dart';
import '../../../core/services/cloud_vision_service.dart';
import '../../../core/services/insight_face_service.dart';
import '../providers/teacher_photo_provider.dart';

const _faceColors = [
  Color(0xFFEF4444), Color(0xFF3B82F6), Color(0xFFEAB308),
  Color(0xFFA855F7), Color(0xFFF97316), Color(0xFFEC4899),
  Color(0xFF14B8A6), Color(0xFF6366F1),
];

class ChildOption { final String id, name, initials; const ChildOption({required this.id, required this.name, this.initials = ''}); }

class PhotoDetailScreen extends ConsumerStatefulWidget {
  final PhotoModel photo; const PhotoDetailScreen({super.key, required this.photo});
  @override ConsumerState<PhotoDetailScreen> createState() => _PhotoDetailScreenState();
}

class _PhotoDetailScreenState extends ConsumerState<PhotoDetailScreen> {
  late List<String> _taggedChildIds;
  List<_FaceCircle> _faceCircles = [];
  bool _isLoading = true;
  String? _statusMessage = 'Loading...';
  double _imgWidth = 1, _imgHeight = 1;
  List<ChildOption> _allChildren = [];
  Uint8List? _cachedImageBytes;

  @override void initState() { super.initState(); _taggedChildIds = List<String>.from(widget.photo.childIds); _loadChildren(); _loadFaces(); }

  Future<void> _loadChildren() async {
    final children = MockData.children.map((c) => ChildOption(id: c.id, name: c.firstName, initials: c.initials)).toList();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('custom_children');
    if (raw != null) for (final item in (jsonDecode(raw) as List).cast<Map<String, dynamic>>()) children.add(ChildOption(id: item['id'] as String, name: item['name'] as String, initials: (item['name'] as String).substring(0, 1).toUpperCase()));
    setState(() => _allChildren = children);
  }

  Future<void> _loadFaces() async {
    // If photo already has aiDetections from Firestore → display instantly
    if (widget.photo.aiDetections.isNotEmpty) {
      _loadFromFirestore();
      return;
    }

    // If photo is a Firebase URL and not yet processed → show processing state
    if (widget.photo.url.startsWith('https://')) {
      setState(() => _statusMessage = 'AI is analyzing this photo...');

      // Download for dimensions
      try {
        final response = await http.get(Uri.parse(widget.photo.url));
        _cachedImageBytes = response.bodyBytes;
        final decoded = img.decodeImage(_cachedImageBytes!);
        if (decoded != null) { _imgWidth = decoded.width.toDouble(); _imgHeight = decoded.height.toDouble(); }
      } catch (_) { _imgWidth = 4000; _imgHeight = 3000; }

      // Run live detection
      final faces = await CloudVisionService.detectFaces(widget.photo.url);
      if (!mounted) return;

      if (faces.isEmpty) { setState(() { _isLoading = false; _statusMessage = 'No faces detected'; }); return; }

      final circs = <_FaceCircle>[];
      for (var i = 0; i < faces.length; i++) {
        final f = faces[i];
        circs.add(_FaceCircle(id: 'face_$i', index: i + 1, color: _faceColors[i % _faceColors.length],
          rect: Rect.fromLTWH(f.left / _imgWidth, f.top / _imgHeight, f.width / _imgWidth, f.height / _imgHeight),
          faceLeft: f.left.toInt(), faceTop: f.top.toInt(), faceWidth: f.width.toInt(), faceHeight: f.height.toInt()));
      }
      setState(() { _faceCircles = circs; _isLoading = false; });

      // Background recognition
      _runBatchRecognition();
    } else {
      setState(() { _isLoading = false; _statusMessage = null; });
    }
  }

  void _loadFromFirestore() {
    final circs = <_FaceCircle>[];
    for (var i = 0; i < widget.photo.aiDetections.length; i++) {
      final d = widget.photo.aiDetections[i];
      final box = d.boundingBox;
      final child = d.childId.isNotEmpty ? MockData.children.where((c) => c.id == d.childId).firstOrNull : null;
      if (box.length >= 4) {
        circs.add(_FaceCircle(id: 'face_$i', index: i + 1, color: _faceColors[i % _faceColors.length],
          rect: Rect.fromLTWH(box[0] / _imgWidth, box[1] / _imgHeight, box[2] / _imgWidth, box[3] / _imgHeight),
          matchedChildId: d.childId.isNotEmpty ? d.childId : null,
          childName: child?.firstName ?? (d.childId.isNotEmpty ? d.childId : null),
          faceLeft: box[0].toInt(), faceTop: box[1].toInt(), faceWidth: box[2].toInt(), faceHeight: box[3].toInt()));
      }
    }
    setState(() { _faceCircles = circs; _isLoading = false; _statusMessage = null; });
  }

  Future<void> _runBatchRecognition() async {
    if (_cachedImageBytes == null) return;
    final untagged = <int>[]; final crops = <Uint8List>[];
    for (var i = 0; i < _faceCircles.length; i++) {
      if (_faceCircles[i].matchedChildId == null) {
        final crop = await _cropFaceBytes(_faceCircles[i].faceLeft, _faceCircles[i].faceTop, _faceCircles[i].faceWidth, _faceCircles[i].faceHeight);
        if (crop != null) { untagged.add(i); crops.add(crop); }
      }
    }
    if (crops.isEmpty || !mounted) return;
    try {
      final results = await InsightFaceService.recognizeBatch(crops);
      if (!mounted) return;
      setState(() {
        for (var j = 0; j < results.length && j < untagged.length; j++) {
          final r = results[j];
          if (r['matched'] == true) {
            final idx = untagged[j];
            _faceCircles[idx].matchedChildId = r['child_id'] as String?;
            _faceCircles[idx].childName = r['name'] as String?;
            if (_faceCircles[idx].matchedChildId != null && !_taggedChildIds.contains(_faceCircles[idx].matchedChildId)) _taggedChildIds.add(_faceCircles[idx].matchedChildId!);
          }
        }
      });
    } catch (_) {}
  }

  Future<Uint8List?> _cropFaceBytes(int left, int top, int width, int height) async {
    if (_cachedImageBytes == null) return null;
    try {
      final original = img.decodeImage(_cachedImageBytes!); if (original == null) return null;
      final padW = (width * 0.2).toInt(), padH = (height * 0.2).toInt();
      final cropped = img.copyCrop(original, x: (left - padW).clamp(0, original.width - 1), y: (top - padH).clamp(0, original.height - 1), width: (width + padW * 2).clamp(1, original.width), height: (height + padH * 2).clamp(1, original.height));
      return Uint8List.fromList(img.encodeJpg(cropped, quality: 90));
    } catch (_) { return null; }
  }

  void _showTagPopup(_FaceCircle circle) {
    final nameController = TextEditingController();
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.textTertiary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Row(children: [Container(width: 48, height: 48, decoration: BoxDecoration(color: circle.color.withValues(alpha: 0.15), shape: BoxShape.circle, border: Border.all(color: circle.color, width: 2.5)), child: Center(child: Icon(Icons.person, color: circle.color, size: 24))), const SizedBox(width: 12),
            Expanded(child: Text('Tag this face', style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800)))]),
          const SizedBox(height: 12),
          ..._allChildren.map((child) => ListTile(leading: CircleAvatar(backgroundColor: AppColors.primary.withValues(alpha: 0.12), child: Text(child.initials.isNotEmpty ? child.initials : child.name[0].toUpperCase(), style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary))), title: Text(child.name, style: GoogleFonts.nunito(fontWeight: FontWeight.w700)), trailing: _taggedChildIds.contains(child.id) ? const Icon(Icons.check_circle, color: AppColors.success, size: 20) : null, onTap: () { _tagFace(circle, child.id, child.name); Navigator.pop(ctx); })),
          const Divider(height: 24),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: TextField(controller: nameController, decoration: InputDecoration(hintText: 'Or type a NEW name...', prefixIcon: const Icon(Icons.person_add_alt_rounded, color: AppColors.accent), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none), filled: true, fillColor: AppColors.surfaceVariant), onSubmitted: (name) { if (name.trim().isNotEmpty) { _addNewName(circle, name.trim()); Navigator.pop(ctx); } })),
          const SizedBox(height: 8), TextButton(onPressed: () { final name = nameController.text.trim(); if (name.isNotEmpty) { _addNewName(circle, name); Navigator.pop(ctx); } }, child: const Text('Add & Tag')),
          const SizedBox(height: 16)])));
  }

  void _addNewName(_FaceCircle circle, String name) {
    _saveCustomChild(ChildOption(id: 'custom_${name.toLowerCase().replaceAll(' ', '_')}', name: name, initials: name[0].toUpperCase()));
    _tagFace(circle, 'custom_${name.toLowerCase().replaceAll(' ', '_')}', name);
  }

  Future<void> _saveCustomChild(ChildOption child) async {
    if (_allChildren.any((c) => c.id == child.id)) return; _allChildren.add(child); setState(() {});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_children', jsonEncode(_allChildren.where((c) => c.id.startsWith('custom_')).map((c) => {'id': c.id, 'name': c.name}).toList()));
  }

  void _tagFace(_FaceCircle circle, String childId, String childName) {
    setState(() { if (!_taggedChildIds.contains(childId)) _taggedChildIds.add(childId); circle.matchedChildId = childId; circle.childName = childName; });
    ref.read(teacherPhotoStateProvider.notifier).updateTags(widget.photo.id, _taggedChildIds);
    // Enroll face
    if (_cachedImageBytes != null) {
      _cropFaceBytes(circle.faceLeft, circle.faceTop, circle.faceWidth, circle.faceHeight).then((crop) {
        if (crop != null) InsightFaceService.enrollChild(childId: childId, name: childName, faceBytes: crop);
      });
    }
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ $childName tagged & enrolled!'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating));
  }

  @override Widget build(BuildContext context) {
    final taggedCount = _faceCircles.where((c) => c.matchedChildId != null).length;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white), onPressed: () => context.pop()),
        title: Text('Tag Faces', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w700)),
        actions: [_faceCircles.isNotEmpty ? Center(child: Padding(padding: const EdgeInsets.only(right: 16), child: Text('$taggedCount/${_faceCircles.length} tagged', style: GoogleFonts.nunito(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)))) : const SizedBox.shrink()]),
      body: Column(children: [
        if (_isLoading) Container(padding: const EdgeInsets.all(20), color: Colors.white, child: Row(children: [const CircularProgressIndicator(strokeWidth: 2), const SizedBox(width: 12), Text(_statusMessage ?? 'Loading...')])),
        if (_statusMessage != null && !_isLoading) Container(padding: const EdgeInsets.all(12), color: AppColors.warningLight, child: Row(children: [const Icon(Icons.info_outline, color: AppColors.warning, size: 16), const SizedBox(width: 8), Text(_statusMessage!, style: GoogleFonts.nunito(fontSize: 12, color: AppColors.warning))])),
        Expanded(child: Container(color: Colors.black, child: LayoutBuilder(builder: (ctx, c) {
          final cw = c.maxWidth, ch = c.maxHeight; double dw, dh, ox, oy;
          final ia = _imgWidth / (_imgHeight > 0 ? _imgHeight : 1), ca = cw / (ch > 0 ? ch : 1);
          if (ia > ca) { dw = cw; dh = cw / ia; ox = 0; oy = (ch - dh) / 2; } else { dh = ch; dw = ch * ia; ox = (cw - dw) / 2; oy = 0; }
          return Stack(children: [
            Positioned(left: ox, top: oy, width: dw, height: dh, child: CachedNetworkImage(imageUrl: widget.photo.url, fit: BoxFit.fill, placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: Colors.white)))),
            for (final fc in _faceCircles) if (fc.rect != Rect.zero) Positioned(left: ox + fc.rect.left * dw, top: oy + fc.rect.top * dh, child: GestureDetector(onTap: () => _showTagPopup(fc), child: _FaceCircleWidget(circle: fc))),
          ]);
        }))),
        Container(width: double.infinity, padding: const EdgeInsets.all(20), color: Colors.white, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [Text(_faceCircles.isEmpty ? 'Tag Kids' : '🤖 Face Detection', style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            if (_faceCircles.isNotEmpty) ...[const Spacer(), _LegendDot(color: AppColors.success, label: 'Tagged'), const SizedBox(width: 12), _LegendDot(color: Colors.blue, label: 'Tap to tag')]]),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, height: 48, child: OutlinedButton.icon(onPressed: _showManualTagDialog, icon: const Icon(Icons.person_add_alt_rounded, size: 20), label: Text('Tag Kids Manually', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)), style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary))),
        ])),
      ]));
  }

  void _showManualTagDialog() {
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModalState) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.textTertiary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))), const SizedBox(height: 16),
        Text('Tag Kids in Photo', style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800)),
        ..._allChildren.map((child) => CheckboxListTile(value: _taggedChildIds.contains(child.id), onChanged: (val) { setModalState(() { if (val == true) _taggedChildIds.add(child.id); else _taggedChildIds.remove(child.id); }); ref.read(teacherPhotoStateProvider.notifier).updateTags(widget.photo.id, _taggedChildIds); }, title: Text(child.name, style: GoogleFonts.nunito(fontWeight: FontWeight.w700)))),
        const SizedBox(height: 16)]))));
  }
}

class _FaceCircle { final String id; final int index; final Color color; final Rect rect; String? matchedChildId, childName; final int faceLeft, faceTop, faceWidth, faceHeight; _FaceCircle({required this.id, required this.index, required this.color, required this.rect, this.matchedChildId, this.childName, required this.faceLeft, required this.faceTop, required this.faceWidth, required this.faceHeight}); }

class _FaceCircleWidget extends StatelessWidget {
  final _FaceCircle circle; const _FaceCircleWidget({required this.circle});
  @override Widget build(_) {
    final tagged = circle.matchedChildId != null; final color = tagged ? AppColors.success : circle.color;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 44, height: 44, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 3), color: color.withValues(alpha: 0.15)), child: Center(child: tagged ? const Icon(Icons.check, color: AppColors.success, size: 22) : Icon(Icons.person, color: color, size: 22))),
      Container(margin: const EdgeInsets.only(top: 2), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: color.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(6)), child: Text(tagged ? (circle.childName ?? 'OK') : 'Tap', style: GoogleFonts.nunito(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)))]); }
}

class _LegendDot extends StatelessWidget { final Color color; final String label; const _LegendDot({required this.color, required this.label}); @override Widget build(_) => Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 4), Text(label, style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textSecondary))]); }