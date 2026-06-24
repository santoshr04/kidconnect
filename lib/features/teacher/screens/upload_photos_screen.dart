import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/avatar_widget.dart';
import '../../auth/providers/auth_provider.dart';

/// Smart Bulk Upload Screen for Teachers
class UploadPhotosScreen extends ConsumerStatefulWidget {
  const UploadPhotosScreen({super.key});

  @override
  ConsumerState<UploadPhotosScreen> createState() => _UploadPhotosScreenState();
}

class _UploadPhotosScreenState extends ConsumerState<UploadPhotosScreen> {
  bool _isUploading = false;
  double _uploadProgress = 0;
  String _statusMessage = 'Waiting for selection...';
  final List<String> _selectedFiles = [];

  void _simulateUpload() async {
    if (_selectedFiles.isEmpty) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
      _statusMessage = 'Uploading ${_selectedFiles.length} photos...';
    });

    // Simulate high compression & upload
    for (int i = 1; i <= 100; i++) {
      await Future.delayed(const Duration(milliseconds: 30));
      setState(() {
        _uploadProgress = i / 100;
        if (i == 40) _statusMessage = 'Compressing to WebP (Max efficiency)...';
        if (i == 80) _statusMessage = 'Running AI Face Detection...';
      });
    }

    setState(() {
      _statusMessage = 'AI Tagging Complete! Found 3 kids.';
    });

    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Successfully shared with parents! 🚀',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {
        _isUploading = false;
        _selectedFiles.clear();
        _statusMessage = 'Ready for next batch';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Bulk Upload',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: AvatarWidget(
              name: authState.currentUser?.name ?? 'Teacher',
              size: 36,
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── AI Engine Info ─────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: AppColors.secondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Zero-Effort Tagging',
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w700,
                            color: AppColors.secondary,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'AI will automatically detect and notify parents of their child.',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ─── Upload Area ────────────────────────────────
            Expanded(
              child: GestureDetector(
                onTap: _isUploading ? null : () {
                  setState(() {
                    _selectedFiles.addAll(List.generate(5, (i) => 'img_$i.jpg'));
                  });
                },
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.border,
                      width: 2,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_selectedFiles.isEmpty) ...[
                        const Icon(Icons.add_photo_alternate_outlined,
                            size: 64, color: AppColors.textTertiary),
                        const SizedBox(height: 16),
                        Text(
                          'Tap to select photos',
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Select up to 100 photos at once',
                          style: GoogleFonts.nunito(color: AppColors.textTertiary),
                        ),
                      ] else ...[
                        Text(
                          '${_selectedFiles.length} Photos Selected',
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_isUploading) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: LinearProgressIndicator(
                              value: _uploadProgress,
                              borderRadius: BorderRadius.circular(10),
                              minHeight: 8,
                              backgroundColor: AppColors.surfaceVariant,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.secondary),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _statusMessage,
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondary,
                            ),
                          ),
                        ] else ...[
                          ElevatedButton.icon(
                            onPressed: _simulateUpload,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondary,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            ),
                            icon: const Icon(Icons.cloud_upload_outlined),
                            label: const Text('Start AI Processing'),
                          ),
                          TextButton(
                            onPressed: () => setState(() => _selectedFiles.clear()),
                            child: const Text('Clear Selection', style: TextStyle(color: AppColors.error)),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}
