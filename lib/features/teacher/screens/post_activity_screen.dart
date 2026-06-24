import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/activity_model.dart';

/// Post activity screen for teachers
class PostActivityScreen extends StatefulWidget {
  const PostActivityScreen({super.key});

  @override
  State<PostActivityScreen> createState() => _PostActivityScreenState();
}

class _PostActivityScreenState extends State<PostActivityScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  ActivityType? _selectedType;
  bool _posted = false;

  final _activityTypes = [
    {'type': ActivityType.art, 'emoji': '🎨', 'label': 'Art & Craft'},
    {'type': ActivityType.music, 'emoji': '🎵', 'label': 'Music'},
    {'type': ActivityType.sports, 'emoji': '⚽', 'label': 'Sports'},
    {'type': ActivityType.learning, 'emoji': '📚', 'label': 'Learning'},
    {'type': ActivityType.play, 'emoji': '🎮', 'label': 'Play Time'},
    {'type': ActivityType.story, 'emoji': '📖', 'label': 'Story'},
    {'type': ActivityType.outdoor, 'emoji': '🌳', 'label': 'Outdoor'},
    {'type': ActivityType.meal, 'emoji': '🍎', 'label': 'Meal'},
    {'type': ActivityType.nap, 'emoji': '😴', 'label': 'Nap'},
    {'type': ActivityType.celebration, 'emoji': '🎉', 'label': 'Celebration'},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Post Activity',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Activity Type Selector ─────────────────────
            Text(
              'Activity Type',
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _activityTypes.map((item) {
                final type = item['type'] as ActivityType;
                final isSelected = _selectedType == type;
                return GestureDetector(
                  onTap: () => setState(() => _selectedType = type),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.secondary.withValues(alpha: 0.12)
                          : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.secondary
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(item['emoji'] as String,
                            style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 6),
                        Text(
                          item['label'] as String,
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? AppColors.secondary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // ─── Title ──────────────────────────────────────
            Text(
              'Title',
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'e.g., Finger Painting Fun',
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                      color: AppColors.secondary, width: 1.5),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ─── Description ────────────────────────────────
            Text(
              'Description',
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText:
                    'Describe the activity — what the children did, learned, and enjoyed...',
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                      color: AppColors.secondary, width: 1.5),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ─── Photo Attachment ───────────────────────────
            Text(
              'Photos (optional)',
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Photo picker — coming soon!',
                      style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
                    ),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.border,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined,
                        color: AppColors.textTertiary, size: 32),
                    const SizedBox(height: 6),
                    Text(
                      'Tap to add photos',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // ─── Post Button ────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _posted ? null : _handlePost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                ),
                child: _posted
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Activity Posted! 🎉',
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        'Post Activity',
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AppColors.white,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _handlePost() {
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select an activity type',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _posted = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Activity posted successfully! Parents will be notified.',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
