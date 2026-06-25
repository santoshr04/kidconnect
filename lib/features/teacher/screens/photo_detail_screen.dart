import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/photo_model.dart';
import '../../../data/mock/mock_data.dart';

/// Full-screen photo view with tagging capability.
///
/// Teachers tap a photo in the gallery → see it full-screen →
/// can tag which kids are in the photo.
class PhotoDetailScreen extends ConsumerStatefulWidget {
  final PhotoModel photo;

  const PhotoDetailScreen({super.key, required this.photo});

  @override
  ConsumerState<PhotoDetailScreen> createState() => _PhotoDetailScreenState();
}

class _PhotoDetailScreenState extends ConsumerState<PhotoDetailScreen> {
  late List<String> _taggedChildIds;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _taggedChildIds = List<String>.from(widget.photo.childIds);
  }

  void _toggleChild(String childId) {
    setState(() {
      if (_taggedChildIds.contains(childId)) {
        _taggedChildIds.remove(childId);
      } else {
        _taggedChildIds.add(childId);
      }
      _isSaved = false;
    });
  }

  Future<void> _saveTags() async {
    // In production: update Firestore document
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() => _isSaved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ ${_taggedChildIds.length} kid(s) tagged!',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final children = MockData.children;
    final taggedCount = _taggedChildIds.length;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Photo Detail',
          style: GoogleFonts.nunito(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          // Full-screen photo
          Expanded(
            child: InteractiveViewer(
              child: Center(
                child: Image.network(
                  widget.photo.resolutions?.optimized ?? widget.photo.url,
                  fit: BoxFit.contain,
                  width: double.infinity,
                ),
              ),
            ),
          ),

          // Tagging panel
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
                    Text(
                      'Tag Kids in Photo',
                      style: GoogleFonts.nunito(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (taggedCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$taggedCount selected',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 4),
                Text(
                  widget.photo.caption ?? 'No caption',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: AppColors.textTertiary,
                  ),
                ),

                const SizedBox(height: 16),

                // Child chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: children.map((child) {
                    final isSelected = _taggedChildIds.contains(child.id);
                    return GestureDetector(
                      onTap: () => _toggleChild(child.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.12)
                              : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textTertiary
                                        .withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  child.initials,
                                  style: GoogleFonts.nunito(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? AppColors.white
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              child.firstName,
                              style: GoogleFonts.nunito(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.check_circle,
                                  color: AppColors.primary, size: 18),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSaved ? null : _saveTags,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _isSaved ? AppColors.success : AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      _isSaved ? '✅ Saved!' : 'Save Tags',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}