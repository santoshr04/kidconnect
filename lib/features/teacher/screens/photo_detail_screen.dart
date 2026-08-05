import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/photo_model.dart';
import '../../../data/repositories/photo_repository.dart';
import '../../../core/services/insight_face_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/teacher_photo_provider.dart';

const _faceColors = [
  Color(0xFFEF4444), Color(0xFF3B82F6), Color(0xFFEAB308),
  Color(0xFFA855F7), Color(0xFFF97316), Color(0xFFEC4899),
  Color(0xFF14B8A6), Color(0xFF6366F1),
];

class ChildOption {
  final String id; final String name; final String initials;
  const ChildOption({required this.id, required this.name, this.initials = ''});
}

class PhotoDetailScreen extends ConsumerStatefulWidget {
  final PhotoModel photo;
  const PhotoDetailScreen({super.key, required this.photo});
  @override ConsumerState<PhotoDetailScreen> createState() => _PhotoDetailScreenState();
}

class _PhotoDetailScreenState extends ConsumerState<PhotoDetailScreen> {
  late List<String> _taggedChildIds;
  List<_FaceCircle> _faceCircles = [];
  bool _isDetecting = false;
  String? _faceError;
  double _imgWidth = 1, _imgHeight = 1;
  List<ChildOption> _allChildren = [];
  Uint8List? _cachedImageBytes;
  Set<String> _hiddenChildIds = {};

  @override void initState() { super.initState(); _taggedChildIds = List<String>.from(widget.photo.childIds); _loadHiddenIds(); _loadChildren(); _loadFaces(); }

  Future<void> _loadHiddenIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('hidden_child_ids');
    if (raw != null) {
      _hiddenChildIds = Set<String>.from(jsonDecode(raw) as List);
    }
  }

  Future<void> _saveHiddenIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('hidden_child_ids', jsonEncode(_hiddenChildIds.toList()));
  }

  Future<void> _loadChildren() async {
    final children = <ChildOption>[];

    // Only Firestore-registered children
    try {
      final snap = await FirebaseFirestore.instance.collection('children').get();
      for (final doc in snap.docs) {
        final data = doc.data();
        if (!_hiddenChildIds.contains(doc.id)) {
          final name = data['name'] as String? ?? '';
          if (name.isNotEmpty) {
            children.add(ChildOption(
              id: doc.id,
              name: name,
              initials: name.isNotEmpty ? name[0].toUpperCase() : '?',
            ));
          }
        }
      }
    } catch (_) {}

    setState(() => _allChildren = children);
  }

  Future<void> _saveCustomChild(ChildOption child) async {
    if (_allChildren.any((c) => c.id == child.id)) return;
    _allChildren.add(child); setState(() {});
    final prefs = await SharedPreferences.getInstance();
    final existing = _allChildren.where((c) => c.id.startsWith('custom_')).map((c) => {'id': c.id, 'name': c.name}).toList();
    await prefs.setString('custom_children', jsonEncode(existing));
  }

  Future<void> _removeChildFromList(ChildOption child, int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remove "${child.name}"?', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: Text('This child will be hidden from the tagging list but data is preserved.', style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.nunito(fontWeight: FontWeight.w600))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text('Remove', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    _hiddenChildIds.add(child.id);
    await _saveHiddenIds();
    setState(() => _allChildren.removeAt(index));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"${child.name}" hidden from list'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _loadFaces() async {
    if (!widget.photo.url.startsWith('https://')) return;

    // If photo already has tagged children with AI detections, skip the AI call
    if (widget.photo.childIds.isNotEmpty && widget.photo.aiDetections.isNotEmpty) {
      setState(() { _isDetecting = false; _imgWidth = 4000; _imgHeight = 3000; });
      return;
    }

    setState(() => _isDetecting = true);

    try {
      final response = await http.get(Uri.parse(widget.photo.url));
      _cachedImageBytes = response.bodyBytes;
      final decoded = img.decodeImage(_cachedImageBytes!);
      if (decoded != null) {
        _imgWidth = decoded.width.toDouble();
        _imgHeight = decoded.height.toDouble();
      }
    } catch (_) { _imgWidth = 4000; _imgHeight = 3000; }

    final result = await InsightFaceService.detectAndRecognize(widget.photo.url);
    if (!mounted) return;

    if (result.error != null) {
      setState(() { _isDetecting = false; _faceError = result.error; });
      return;
    }

    if (result.faces.isEmpty) {
      setState(() { _isDetecting = false; _faceError = 'No faces detected'; });
      return;
    }

    _imgWidth = result.imageWidth;
    _imgHeight = result.imageHeight;

    final circs = <_FaceCircle>[];
    for (var i = 0; i < result.faces.length; i++) {
      final f = result.faces[i];
      final faceLeft = f.left.toInt();
      final faceTop = f.top.toInt();
      final faceW = f.width.toInt();
      final faceH = f.height.toInt();

      final circle = _FaceCircle(
        id: 'face_$i',
        index: i + 1,
        color: _faceColors[i % _faceColors.length],
        rect: Rect.fromLTWH(f.left / _imgWidth, f.top / _imgHeight, f.width / _imgWidth, f.height / _imgHeight),
        faceLeft: faceLeft, faceTop: faceTop, faceWidth: faceW, faceHeight: faceH,
      );

      if (f.matched && f.childId != null) {
        // Only accept match if the child ID is a registered Firestore child
        final validChild = _allChildren.firstWhere(
          (c) => c.id == f.childId,
          orElse: () => ChildOption(id: '', name: '', initials: ''),
        );
        if (validChild.id.isNotEmpty) {
          circle.matchedChildId = f.childId;
          circle.childName = validChild.name;
          circle.confidence = f.confidence;
          if (!_taggedChildIds.contains(f.childId)) {
            _taggedChildIds.add(f.childId!);
          }
        }
      }
      circs.add(circle);
    }

    setState(() { _faceCircles = circs; _isDetecting = false; });
    _updateGalleryState();
  }

  bool get _allFacesHandled =>
      _faceCircles.every((c) => c.matchedChildId != null || c.isNeglected);

  int get _handledCount => _faceCircles.where((c) => c.isHandled).length;
  int get _neglectedCount => _faceCircles.where((c) => c.isNeglected).length;
  int get _remainingCount => _faceCircles.where((c) => !c.isHandled).length;

  void _updateGalleryState() {
    ref.read(teacherPhotoStateProvider.notifier).updateTags(widget.photo.id, _taggedChildIds);
  }

  Future<Uint8List?> _cropFaceBytes(int left, int top, int width, int height) async {
    if (_cachedImageBytes == null) return null;
    try {
      final original = img.decodeImage(_cachedImageBytes!);
      if (original == null) return null;
      final padW = (width * 0.2).toInt();
      final padH = (height * 0.2).toInt();
      final cropLeft = (left - padW).clamp(0, original.width - 1);
      final cropTop = (top - padH).clamp(0, original.height - 1);
      final cropWidth = (width + padW * 2).clamp(1, original.width - cropLeft);
      final cropHeight = (height + padH * 2).clamp(1, original.height - cropTop);
      final cropped = img.copyCrop(original, x: cropLeft, y: cropTop, width: cropWidth, height: cropHeight);
      return Uint8List.fromList(img.encodeJpg(cropped, quality: 90));
    } catch (_) { return null; }
  }

  Future<void> _doneTagging() async {
    try {
      await FirebaseFirestore.instance.collection('photos').doc(widget.photo.id).update({
        'childIds': _taggedChildIds,
      });
    } catch (_) {}

    _updateGalleryState();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(' Done  $_handledCount face(s) handled'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop();
    }
  }

  void _showTagPopup(_FaceCircle circle) {
    final existingMatch = circle.matchedChildId != null
        ? '${circle.childName} (${((circle.confidence ?? 1) * 100).toInt()}% match)' : null;

    // One child per face: exclude children already tagged to other faces
    final otherTaggedIds = _faceCircles
        .where((c) => c.id != circle.id && c.matchedChildId != null)
        .map((c) => c.matchedChildId!)
        .toSet();
    final availableChildren = _allChildren
        .where((c) => !otherTaggedIds.contains(c.id))
        .toList();

    showModalBottomSheet(context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (ctx, scrollController) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: ListView(
            controller: scrollController,
            shrinkWrap: true,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.textTertiary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(children: [
                Container(width: 48, height: 48, decoration: BoxDecoration(color: circle.color.withValues(alpha: 0.15), shape: BoxShape.circle, border: Border.all(color: circle.color, width: 2.5)),
                  child: Center(child: Icon(Icons.person, color: circle.color, size: 24))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text('Tag this face', style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800)),
                  if (existingMatch != null) Text('AI: $existingMatch', style: GoogleFonts.nunito(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w600)),
                  if (availableChildren.isEmpty) Text('All registered children are already tagged to other faces',
                      style: GoogleFonts.nunito(fontSize: 12, color: AppColors.warning, fontWeight: FontWeight.w600)),
                ])),
              ]),
              const SizedBox(height: 12),
              for (int i = 0; i < availableChildren.length; i++)
                ListTile(
                  leading: CircleAvatar(backgroundColor: AppColors.primary.withValues(alpha: 0.12), child: Text(availableChildren[i].initials.isNotEmpty ? availableChildren[i].initials : availableChildren[i].name[0].toUpperCase(), style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary))),
                  title: Text(availableChildren[i].name, style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                  onTap: () { _tagFace(circle, availableChildren[i].id, availableChildren[i].name); Navigator.pop(ctx); },
                ),
              if (availableChildren.isEmpty && _allChildren.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('All registered children have already been tagged to other faces in this photo.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary)),
                ),
              const SizedBox(height: 12),
              if (availableChildren.isNotEmpty || _allChildren.isEmpty) ...[
                const Divider(height: 1),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity,
                height: 44,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      circle.isNeglected = true;
                      circle.matchedChildId = null;
                      circle.childName = null;
                      circle.confidence = null;
                    });
                    _updateGalleryState();
                    Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.do_not_disturb_alt_outlined, size: 18, color: Colors.grey),
                  label: const Text('Neglect Face', style: TextStyle(color: Colors.grey)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ));
  }

  void _addNewName(_FaceCircle circle, String name) {
    final newId = 'custom_${name.toLowerCase().replaceAll(' ', '_')}';
    _saveCustomChild(ChildOption(id: newId, name: name, initials: name[0].toUpperCase()));
    _tagFace(circle, newId, name);
  }

  Future<void> _tagFace(_FaceCircle circle, String childId, String childName) async {
    setState(() {
      if (!_taggedChildIds.contains(childId)) _taggedChildIds.add(childId);
      circle.matchedChildId = childId;
      circle.childName = childName;
      circle.confidence = null;
      circle.isNeglected = false;
    });
    _updateGalleryState();

    if (_cachedImageBytes != null) {
      try {
        final cropBytes = await _cropFaceBytes(circle.faceLeft, circle.faceTop, circle.faceWidth, circle.faceHeight);
        if (cropBytes != null) {
          await InsightFaceService.enrollChild(childId: childId, name: childName, faceBytes: cropBytes);
        }
      } catch (_) {}
    }

    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(' $childName tagged & enrolled!'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating));
  }

  @override Widget build(BuildContext context) {
    final alreadyTagged = widget.photo.childIds.isNotEmpty && widget.photo.aiDetections.isNotEmpty;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white), onPressed: () => context.pop()),
        title: Text(alreadyTagged ? 'Tagged Kids' : 'Tag Faces', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
            tooltip: 'Delete Photo',
            onPressed: _deletePhoto,
          ),
          if (_faceCircles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text('$_handledCount/${_faceCircles.length} handled',
                    style: GoogleFonts.nunito(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
        ]),
      body: Column(children: [
        if (_isDetecting) Container(padding: const EdgeInsets.all(16), color: Colors.white, child: const Row(children: [CircularProgressIndicator(strokeWidth: 2), SizedBox(width: 12), Text(' AI detecting & recognizing faces...')])),
        if (_faceError != null && !_isDetecting) Container(padding: const EdgeInsets.all(16), color: Colors.amber.shade50, child: Row(children: [const Icon(Icons.info_outline, color: Colors.amber, size: 18), const SizedBox(width: 8), Expanded(child: Text(_faceError!, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600)))])),
        Expanded(child: Container(color: Colors.black, child: LayoutBuilder(builder: (ctx, c) {
          final cw = c.maxWidth, ch = c.maxHeight; double dw, dh, ox, oy;
          final ia = _imgWidth / (_imgHeight > 0 ? _imgHeight : 1);
          final ca = cw / (ch > 0 ? ch : 1);
          if (ia > ca) { dw = cw; dh = cw / ia; ox = 0; oy = (ch - dh) / 2; } else { dh = ch; dw = ch * ia; ox = (cw - dw) / 2; oy = 0; }
          return Stack(children: [
            Positioned(left: ox, top: oy, width: dw, height: dh,
              child: CachedNetworkImage(imageUrl: widget.photo.url, fit: BoxFit.fill, placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: Colors.white)))),
            for (final fc in _faceCircles) if (fc.rect != Rect.zero)
              Positioned(left: ox + fc.rect.left * dw, top: oy + fc.rect.top * dh,
                child: GestureDetector(onTap: fc.isNeglected ? null : () => _showTagPopup(fc), child: _FaceCircleWidget(circle: fc))),
          ]);
        }))),
        Container(width: double.infinity, padding: const EdgeInsets.all(20), color: Colors.white,
          child: alreadyTagged
              ? _buildTaggedInfo()
              : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  if (_faceCircles.isNotEmpty) ...[
                    Row(children: [
                      Text(' Face Status', style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                      const Spacer(),
                      Text('$_handledCount tagged   $_neglectedCount neglected   $_remainingCount left', style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [const _LegendDot(color: AppColors.success, label: 'Tagged'), const SizedBox(width: 12), const _LegendDot(color: AppColors.textTertiary, label: 'Neglected'), const SizedBox(width: 12), const _LegendDot(color: Colors.blue, label: 'Needs action')]),
                    const SizedBox(height: 14),
                  ],
                  if (_faceCircles.isEmpty) Text('Tag Kids', style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  if (_allFacesHandled && _faceCircles.isNotEmpty)
                    SizedBox(width: double.infinity, height: 48, child: ElevatedButton.icon(onPressed: _doneTagging, icon: const Icon(Icons.check_circle, size: 20), label: Text(' Done  $_handledCount kid(s)', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)), style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white))),
                  if (!_allFacesHandled && _faceCircles.isNotEmpty) ...[
                    SizedBox(width: double.infinity, height: 48, child: OutlinedButton.icon(onPressed: _showManualTagDialog, icon: const Icon(Icons.person_add_alt_rounded, size: 20), label: Text('Tag Kids Manually', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)), style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary))),
                    const SizedBox(height: 8),
                    SizedBox(width: double.infinity, height: 42,
                      child: TextButton.icon(
                        onPressed: _neglectAllRemaining,
                        icon: const Icon(Icons.do_not_disturb_alt_outlined, size: 18, color: Colors.grey),
                        label: Text(' Neglect All Remaining ($_remainingCount)', style: GoogleFonts.nunito(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey)),
                        style: TextButton.styleFrom(foregroundColor: Colors.grey),
                      ),
                    ),
                  ],
                  if (_faceCircles.isEmpty)
                    SizedBox(width: double.infinity, height: 48, child: OutlinedButton.icon(onPressed: _showManualTagDialog, icon: const Icon(Icons.person_add_alt_rounded, size: 20), label: Text('Tag Kids Manually', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)), style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary))),
                ],
              ),
        ),
      ]),
    );
  }

  Widget _buildTaggedInfo() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(' Tagged Kids', style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 6,
        children: widget.photo.aiDetections.map((d) {
          final name = d.childId.isNotEmpty ? d.childId.toString() : 'Unknown';
          final child = _allChildren.firstWhere((c) => c.id == d.childId, orElse: () => ChildOption(id: d.childId, name: name, initials: name.isNotEmpty ? name[0].toUpperCase() : '?'));
          return Chip(
            avatar: CircleAvatar(backgroundColor: AppColors.success.withValues(alpha: 0.15), child: Text(child.initials, style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.success))),
            label: Text('${child.name} (${(d.confidence * 100).toInt()}%)', style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600)),
            backgroundColor: AppColors.success.withValues(alpha: 0.08), side: BorderSide.none,
          );
        }).toList(),
      ),
      const SizedBox(height: 12),
      SizedBox(width: double.infinity, height: 48, child: OutlinedButton.icon(onPressed: _showManualTagDialog, icon: const Icon(Icons.edit, size: 20), label: Text('Edit Tags', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)), style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary))),
    ]);
  }

  void _neglectAllRemaining() {
    setState(() {
      for (final c in _faceCircles) {
        if (c.matchedChildId == null && !c.isNeglected) {
          c.isNeglected = true;
        }
      }
    });
    _updateGalleryState();
  }

  Future<void> _deletePhoto() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title:
            Text('Delete Photo?', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: Text(
            'This will permanently remove the photo from storage. This action cannot be undone.',
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

    final photoId = widget.photo.id;
    final photoUrl = widget.photo.url;
    final isMock = ref.read(authProvider).usingMockData;

    // Remove from session state immediately
    ref.read(teacherPhotoStateProvider.notifier).removePhoto(photoId);

    // Pop back to gallery
    if (mounted) {
      context.pop();
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
  }

  void _showManualTagDialog() {
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5, minChildSize: 0.3, maxChildSize: 0.85, expand: false,
        builder: (ctx, scrollController) => StatefulBuilder(
          builder: (ctx, setModalState) => Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
            child: ListView(controller: scrollController, shrinkWrap: true, children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.textTertiary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text('Tag Kids in Photo', style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800)),
              ..._allChildren.map((child) => CheckboxListTile(
                value: _taggedChildIds.contains(child.id),
                onChanged: (val) {
                  setModalState(() {
                    if (val == true) { _taggedChildIds.add(child.id); }
                    else { _taggedChildIds.remove(child.id); }
                  });
                  _updateGalleryState();
                },
                title: Text(child.name, style: GoogleFonts.nunito(fontWeight: FontWeight.w700)))),
              const SizedBox(height: 24),
            ]),
          ),
        ),
      ));
  }
}

class _FaceCircle {
  final String id; final int index; final Color color; final Rect rect;
  String? matchedChildId; String? childName; double? confidence;
  bool isNeglected = false;
  final int faceLeft, faceTop, faceWidth, faceHeight;

  _FaceCircle({required this.id, required this.index, required this.color, required this.rect,
    required this.faceLeft, required this.faceTop, required this.faceWidth, required this.faceHeight});

  bool get isHandled => matchedChildId != null || isNeglected;
}

class _FaceCircleWidget extends StatelessWidget {
  final _FaceCircle circle; const _FaceCircleWidget({required this.circle});
  @override Widget build(BuildContext _) {
    final tagged = circle.matchedChildId != null;
    final neglected = circle.isNeglected;
    Color color; IconData icon; String label;
    if (neglected) {
      color = AppColors.textTertiary;
      icon = Icons.do_not_disturb_alt;
      label = 'Skipped';
    } else if (tagged) {
      color = AppColors.success;
      icon = Icons.check;
      label = circle.childName ?? 'OK';
    } else {
      color = circle.color;
      icon = Icons.person;
      label = 'Tap';
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 44, height: 44, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 3), color: color.withValues(alpha: 0.15)),
        child: Center(child: Icon(icon, color: color, size: 22))),
      Container(margin: const EdgeInsets.only(top: 2), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: color.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: GoogleFonts.nunito(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700))),
    ]);
  }
}

class _LegendDot extends StatelessWidget {
  final Color color; final String label; const _LegendDot({required this.color, required this.label});
  @override Widget build(BuildContext _) => Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 4), Text(label, style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textSecondary))]);
}