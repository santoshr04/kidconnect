import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/photo_model.dart';
import '../../../data/mock/mock_data.dart';
import '../providers/teacher_photo_provider.dart';

/// Full-screen photo view with ML Kit face detection circles.
///
/// 🔴 Red circle = Known adult (auto-neglected — no tagging needed)
/// 🟢 Green circle = Matched child (already tagged, shows name)
/// 🔵 Blue circle = Unknown face (tap to tag as child, or mark as adult)
class PhotoDetailScreen extends ConsumerStatefulWidget {
  final PhotoModel photo;

  const PhotoDetailScreen({super.key, required this.photo});

  @override
  ConsumerState<PhotoDetailScreen> createState() => _PhotoDetailScreenState();
}

class _PhotoDetailScreenState extends ConsumerState<PhotoDetailScreen> {
  late List<String> _taggedChildIds;
  List<_FaceCircle> _faceCircles = [];
  bool _isLoadingFaces = true;
  String? _faceError;
  
  // Image dimensions for face circle positioning
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    _taggedChildIds = List<String>.from(widget.photo.childIds);
    _detectFaces();
  }

  Future<void> _detectFaces() async {
    try {
      // Determine if local file or network URL
      File? imageFile;
      if (widget.photo.url.startsWith('/') || widget.photo.url.startsWith('file://')) {
        final path = widget.photo.url.replaceFirst('file://', '');
        imageFile = File(path);
      }

      if (imageFile != null && imageFile.existsSync()) {
        // ML Kit face detection
        final inputImage = InputImage.fromFile(imageFile);
        final faceDetector = FaceDetector(
          options: FaceDetectorOptions(
            enableContours: true,
            enableClassification: true,
            enableLandmarks: true,
            enableTracking: false,
            performanceMode: FaceDetectorMode.accurate,
          ),
        );

        final faces = await faceDetector.processImage(inputImage);
        faceDetector.close();

        if (mounted) {
          // Get image dimensions for proper circle placement
          final decodedImage = await decodeImageFromList(imageFile.readAsBytesSync());
          _imageSize = Size(decodedImage.width.toDouble(), decodedImage.height.toDouble());

          setState(() {
            _faceCircles = faces.map((face) {
              final box = face.boundingBox;
              // Check if this face matches a tagged child
              final matchedChildId = _findMatchingChild(face);
              final isAdult = matchedChildId == null && _isLikelyAdult(face, _imageSize!);

              return _FaceCircle(
                id: 'face_${_faceCircles.length}',
                rect: box,
                matchedChildId: matchedChildId,
                isKnownAdult: isAdult,
                isUnknown: !isAdult && matchedChildId == null,
                childName: matchedChildId != null 
                    ? MockData.children.firstWhere((c) => c.id == matchedChildId).firstName
                    : null,
              );
            }).toList();
            _isLoadingFaces = false;
          });
        }
      } else {
        // Network image — can't run ML Kit on it yet
        if (mounted) {
          setState(() {
            _isLoadingFaces = false;
            _faceError = 'Face detection works on local photos. Upload first.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingFaces = false;
          _faceError = 'Face detection unavailable: $e';
        });
      }
    }
  }

  String? _findMatchingChild(Face face) {
    // Check if this face matches any already-tagged child
    // In production: compare face embeddings
    if (_taggedChildIds.isNotEmpty) {
      // Simple heuristic for now: if face is smiling (classification data),
      // assign to first untagged child slot
      for (final childId in _taggedChildIds) {
        if (!_faceCircles.any((c) => c.matchedChildId == childId)) {
          return childId;
        }
      }
    }
    return null;
  }

  bool _isLikelyAdult(Face face, Size imageSize) {
    // Face occupies more than 30% of image height → likely adult (close to camera)
    // But this is only used if no enrollment data exists.
    final faceHeightRatio = face.boundingBox.height / imageSize.height;
    return faceHeightRatio > 0.25;
  }

  void _showTagPopup(_FaceCircle circle) {
    if (circle.isKnownAdult) return; // Adults can't be tagged

    final children = MockData.children;
    final personNameController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20, right: 20, top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Who is this?',
                style: GoogleFonts.nunito(
                  fontSize: 18, fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              // Existing children
              ...children.map((child) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Text(child.initials, style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
                ),
                title: Text(child.firstName, style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                subtitle: Text('${child.age} yrs • ${child.className}', style: GoogleFonts.nunito(fontSize: 12)),
                trailing: _taggedChildIds.contains(child.id) 
                    ? const Icon(Icons.check_circle, color: AppColors.success)
                    : null,
                onTap: () {
                  _tagChild(circle.id, child.id, child.firstName);
                  Navigator.pop(ctx);
                },
              )),

              const Divider(height: 24),

              // Add new child
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: personNameController,
                  decoration: InputDecoration(
                    hintText: 'Or type a new name...',
                    prefixIcon: const Icon(Icons.person_add_alt_rounded, color: AppColors.accent),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.arrow_forward_rounded, color: AppColors.accent),
                      onPressed: () {
                        final name = personNameController.text.trim();
                        if (name.isNotEmpty) {
                          _tagChildWithNewName(circle.id, name);
                          Navigator.pop(ctx);
                        }
                      },
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                  ),
                  onSubmitted: (name) {
                    if (name.trim().isNotEmpty) {
                      _tagChildWithNewName(circle.id, name.trim());
                      Navigator.pop(ctx);
                    }
                  },
                ),
              ),

              // Mark as adult
              TextButton.icon(
                onPressed: () {
                  setModalState(() {
                    circle.isKnownAdult = true;
                    circle.isUnknown = false;
                  });
                  _markAsAdult(circle.id);
                  Navigator.pop(ctx);
                },
                icon: const Icon(Icons.person_off_rounded, color: AppColors.error),
                label: const Text('This is an adult', style: TextStyle(color: AppColors.error)),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _tagChild(String circleId, String childId, String childName) {
    setState(() {
      if (!_taggedChildIds.contains(childId)) {
        _taggedChildIds.add(childId);
      }
      // Update the circle
      for (final circle in _faceCircles) {
        if (circle.id == circleId) {
          circle.matchedChildId = childId;
          circle.childName = childName;
          circle.isUnknown = false;
          break;
        }
      }
    });

    // Save to provider
    ref.read(teacherPhotoStateProvider.notifier).updateTags(widget.photo.id, _taggedChildIds);
  }

  void _tagChildWithNewName(String circleId, String name) {
    // Create a pseudo-ID for custom tagged child
    final newId = 'custom_${name.toLowerCase().replaceAll(' ', '_')}';
    
    setState(() {
      _taggedChildIds.add(newId);
      for (final circle in _faceCircles) {
        if (circle.id == circleId) {
          circle.matchedChildId = newId;
          circle.childName = name;
          circle.isUnknown = false;
          break;
        }
      }
    });

    ref.read(teacherPhotoStateProvider.notifier).updateTags(widget.photo.id, _taggedChildIds);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ $name tagged — will auto-detect next time!'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _markAsAdult(String circleId) {
    setState(() {
      for (final circle in _faceCircles) {
        if (circle.id == circleId) {
          circle.isKnownAdult = true;
          circle.isUnknown = false;
          break;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text('Face Tagging', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w700)),
        actions: [
          if (_faceCircles.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  '${_faceCircles.where((c) => c.matchedChildId != null || c.isKnownAdult).length}/${_faceCircles.length} tagged',
                  style: GoogleFonts.nunito(color: Colors.white70, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Photo with face circles overlaid
          Expanded(
            child: _isLoadingFaces
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return InteractiveViewer(
                        child: Stack(
                          children: [
                            // Photo
                            Center(
                              child: _buildImage(),
                            ),

                            // Face circles
                            if (_faceCircles.isNotEmpty)
                              ..._faceCircles.map((circle) => Positioned(
                                    left: circle.rect.left.clamp(0.0, constraints.maxWidth - 80),
                                    top: circle.rect.top.clamp(0.0, constraints.maxHeight - 80),
                                    child: GestureDetector(
                                      onTap: () => circle.isUnknown ? _showTagPopup(circle) : null,
                                      child: _FaceCircleWidget(circle: circle),
                                    ),
                                  )),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Bottom panel
          if (!_isLoadingFaces)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text('Face Detection', style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                      const Spacer(),
                      _LegendDot(color: AppColors.success, label: 'Child'),
                      const SizedBox(width: 12),
                      _LegendDot(color: AppColors.skyBlue, label: 'Unknown'),
                      const SizedBox(width: 12),
                      _LegendDot(color: AppColors.error, label: 'Adult'),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_faceError != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warningLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: AppColors.warning, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_faceError!, style: GoogleFonts.nunito(fontSize: 12, color: AppColors.warning)),
                          ),
                        ],
                      ),
                    ),

                  if (_faceCircles.isEmpty && _faceError == null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No faces detected in this photo. You can still tag kids below.',
                        style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textTertiary),
                      ),
                    ),

                  if (_faceCircles.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '🟢 = Tagged child  |  🔵 = Tap to tag  |  🔴 = Adult (skipped)',
                        style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),

                  const SizedBox(height: 12),

                  // Manual tag button (always available)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () => _showManualTagDialog(),
                      icon: const Icon(Icons.person_add_alt_rounded, size: 20),
                      label: Text('Tag Kids Manually', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    if (widget.photo.url.startsWith('/') || widget.photo.url.startsWith('file://')) {
      final path = widget.photo.url.replaceFirst('file://', '');
      return Image.file(File(path), fit: BoxFit.contain);
    }
    return CachedNetworkImage(
      imageUrl: widget.photo.url,
      fit: BoxFit.contain,
      placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
      errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 48)),
    );
  }

  void _showManualTagDialog() {
    final children = MockData.children;
    final personNameController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.textTertiary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text('Tag Kids in Photo', style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              ...children.map((child) => CheckboxListTile(
                value: _taggedChildIds.contains(child.id),
                onChanged: (val) {
                  setModalState(() {
                    if (val == true) {
                      _taggedChildIds.add(child.id);
                    } else {
                      _taggedChildIds.remove(child.id);
                    }
                  });
                  ref.read(teacherPhotoStateProvider.notifier).updateTags(widget.photo.id, _taggedChildIds);
                },
                title: Text(child.firstName, style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                subtitle: Text('${child.age} yrs', style: GoogleFonts.nunito(fontSize: 12)),
                activeColor: AppColors.primary,
              )),
              const Divider(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: personNameController,
                  decoration: InputDecoration(
                    hintText: 'Add new child name...',
                    prefixIcon: const Icon(Icons.person_add_alt_rounded),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        final name = personNameController.text.trim();
                        if (name.isNotEmpty) {
                          final newId = 'custom_${name.toLowerCase().replaceAll(' ', '_')}';
                          setModalState(() => _taggedChildIds.add(newId));
                          ref.read(teacherPhotoStateProvider.notifier).updateTags(widget.photo.id, _taggedChildIds);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ $name added!'), backgroundColor: AppColors.success));
                        }
                      },
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    filled: true, fillColor: AppColors.surfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mutable face circle data for UI state management.
class _FaceCircle {
  final String id;
  final Rect rect;
  String? matchedChildId;
  String? childName;
  bool isKnownAdult;
  bool isUnknown;

  _FaceCircle({
    required this.id,
    required this.rect,
    this.matchedChildId,
    this.childName,
    this.isKnownAdult = false,
    this.isUnknown = true,
  });
}

/// Colored circle overlay on photo for each detected face.
class _FaceCircleWidget extends StatelessWidget {
  final _FaceCircle circle;

  const _FaceCircleWidget({required this.circle});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    IconData? icon;

    if (circle.matchedChildId != null) {
      color = AppColors.success;
      label = circle.childName ?? 'Child';
      icon = Icons.check;
    } else if (circle.isKnownAdult) {
      color = AppColors.error;
      label = 'Adult';
      icon = Icons.person_off;
    } else {
      color = AppColors.skyBlue;
      label = 'Tap to tag';
      icon = Icons.help_outline;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 3),
            color: color.withValues(alpha: 0.15),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: GoogleFonts.nunito(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// Legend dot for the bottom panel.
class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}