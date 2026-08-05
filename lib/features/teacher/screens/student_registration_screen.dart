import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/registration_provider.dart';

class StudentRegistrationScreen extends ConsumerStatefulWidget {
  const StudentRegistrationScreen({super.key});

  @override
  ConsumerState<StudentRegistrationScreen> createState() =>
      _StudentRegistrationScreenState();
}

class _StudentRegistrationScreenState
    extends ConsumerState<StudentRegistrationScreen> {
  final _picker = ImagePicker();

  @override
  void dispose() {
    super.dispose();
  }

  // ── Photo Picker ──────────────────────────────────────────
  Future<void> _pickPhoto(int childIndex, ImageSource source) async {
    final file = await _picker.pickImage(source: source, imageQuality: 85);
    if (file != null) {
      ref
          .read(registrationProvider.notifier)
          .setChildPhoto(childIndex, File(file.path));
    }
  }

  void _showPhotoSourcePicker(int childIndex) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Student Photo',
                  style: GoogleFonts.nunito(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.infoLight,
                  child: Icon(Icons.camera_alt, color: AppColors.info),
                ),
                title: Text('Capture from Camera',
                    style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhoto(childIndex, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.successLight,
                  child: Icon(Icons.photo_library, color: AppColors.success),
                ),
                title: Text('Upload from Gallery',
                    style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhoto(childIndex, ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Class Dropdown ────────────────────────────────────────
  Widget _buildClassDropdown(
      int childIndex, String currentValue, List<String> options) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentValue,
          isExpanded: true,
          icon: const Icon(Icons.expand_more, color: AppColors.textSecondary),
          style: GoogleFonts.nunito(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600),
          items: options
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: (val) {
            if (val != null) {
              ref
                  .read(registrationProvider.notifier)
                  .setChildClass(childIndex, val);
            }
          },
        ),
      ),
    );
  }

  // ── Section Dropdown ──────────────────────────────────────
  Widget _buildSectionDropdown(
      int childIndex, String? currentValue, List<String> options) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: currentValue,
          isExpanded: true,
          hint: Text('Section',
              style: GoogleFonts.nunito(
                  color: AppColors.textTertiary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500)),
          icon: const Icon(Icons.expand_more, color: AppColors.textSecondary),
          style: GoogleFonts.nunito(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600),
          items: [
            DropdownMenuItem<String?>(
                value: null,
                child: Text('None',
                    style: GoogleFonts.nunito(
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w500))),
            ...options.map((o) =>
                DropdownMenuItem<String?>(value: o, child: Text(o))),
          ],
          onChanged: (val) {
            ref
                .read(registrationProvider.notifier)
                .setChildSection(childIndex, val);
          },
        ),
      ),
    );
  }

  // ── Photo Picker Widget ───────────────────────────────────
  Widget _buildPhotoPicker(int childIndex, File? photoFile) {
    return GestureDetector(
      onTap: () => _showPhotoSourcePicker(childIndex),
      child: Container(
        height: 100,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: photoFile != null
                ? AppColors.success
                : AppColors.border,
            width: photoFile != null ? 2 : 1,
          ),
        ),
        child: photoFile != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(photoFile, fit: BoxFit.cover),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined,
                      size: 32,
                      color: AppColors.textTertiary.withValues(alpha: 0.6)),
                  const SizedBox(height: 6),
                  Text('Tap to add photo',
                      style: GoogleFonts.nunito(
                          fontSize: 13,
                          color: AppColors.textTertiary,
                          fontWeight: FontWeight.w600)),
                ],
              ),
      ),
    );
  }

  // ── Child Info Card ───────────────────────────────────────
  Widget _buildChildCard(int index, StudentEntry child) {
    final state = ref.watch(registrationProvider);
    final label = state.children.length > 1 ? 'Child ${index + 1}' : 'Student';
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: AppColors.secondaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.child_care,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(label,
                      style: GoogleFonts.nunito(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                ),
                if (state.children.length > 1)
                  IconButton(
                    onPressed: () => ref
                        .read(registrationProvider.notifier)
                        .removeChild(index),
                    icon: const Icon(Icons.remove_circle_outline,
                        color: AppColors.error, size: 22),
                    tooltip: 'Remove $label',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Student Name
            Text('Student Name *',
                style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            TextField(
              onChanged: (val) => ref
                  .read(registrationProvider.notifier)
                  .setChildName(index, val),
              decoration: InputDecoration(
                hintText: 'Enter student name',
                hintStyle: GoogleFonts.nunito(
                    color: AppColors.textTertiary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500),
                prefixIcon: Icon(Icons.person_outline,
                    color: AppColors.textTertiary.withValues(alpha: 0.6)),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
                filled: true,
                fillColor: AppColors.surfaceVariant,
              ),
            ),
            const SizedBox(height: 14),

            // Class + Section Row
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Class *',
                          style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      _buildClassDropdown(
                          index, child.className, classOptions),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Section',
                          style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      _buildSectionDropdown(
                          index, child.section, sectionOptions),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Photo Picker
            Text('Student Photo *',
                style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            _buildPhotoPicker(index, child.photoFile),
          ],
        ),
      ),
    );
  }

  // ── Parent Info Card ──────────────────────────────────────
  Widget _buildParentCard(RegistrationState state) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: AppColors.parentGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.people_alt_outlined,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Text('Parent Information',
                    style: GoogleFonts.nunito(
                        fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 16),

            // Parent Name
            Text('Parent/Guardian Name *',
                style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            TextField(
              onChanged: (val) =>
                  ref.read(registrationProvider.notifier).setParentName(val),
              decoration: InputDecoration(
                hintText: 'Enter parent full name',
                hintStyle: GoogleFonts.nunito(
                    color: AppColors.textTertiary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500),
                prefixIcon: Icon(Icons.person_outline,
                    color: AppColors.textTertiary.withValues(alpha: 0.6)),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
                filled: true,
                fillColor: AppColors.surfaceVariant,
              ),
            ),
            const SizedBox(height: 14),

            // Mobile Number
            Text('Mobile Number *',
                style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            TextField(
              onChanged: (val) =>
                  ref.read(registrationProvider.notifier).setMobileNumber(val),
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: InputDecoration(
                hintText: 'Enter 10-digit mobile number',
                hintStyle: GoogleFonts.nunito(
                    color: AppColors.textTertiary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500),
                prefixIcon: Icon(Icons.phone_android_outlined,
                    color: AppColors.textTertiary.withValues(alpha: 0.6)),
                prefixText: '+91 ',
                prefixStyle: GoogleFonts.nunito(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600),
                counterText: '',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
                filled: true,
                fillColor: AppColors.surfaceVariant,
              ),
            ),
            const SizedBox(height: 14),

            // Alternate Mobile
            Text('Alternate Mobile Number (Optional)',
                style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            TextField(
              onChanged: (val) => ref
                  .read(registrationProvider.notifier)
                  .setAlternateMobile(val),
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: InputDecoration(
                hintText: 'Alternate contact number',
                hintStyle: GoogleFonts.nunito(
                    color: AppColors.textTertiary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500),
                prefixIcon: Icon(Icons.phone_outlined,
                    color: AppColors.textTertiary.withValues(alpha: 0.6)),
                prefixText: '+91 ',
                prefixStyle: GoogleFonts.nunito(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600),
                counterText: '',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
                filled: true,
                fillColor: AppColors.surfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleRegister() async {
    final notifier = ref.read(registrationProvider.notifier);
    final success = await notifier.register();

    if (!mounted) return;

    if (success) {
      // Show success dialog
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.successLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: AppColors.success),
              ),
              const SizedBox(width: 12),
              Text('Registration Complete!',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
            ],
          ),
          content: Text(
            '${ref.read(registrationProvider).parentName} and ${ref.read(registrationProvider).children.length} child(ren) registered successfully.\n\nOTP login credentials have been generated.',
            style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                ref.read(registrationProvider.notifier).clearForm();
              },
              child: Text('Register Another',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Done',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    } else {
      // Show error
      final errorMsg =
          ref.read(registrationProvider).errorMessage ?? 'Registration failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registrationProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Student Registration',
            style: GoogleFonts.nunito(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 20)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.sunsetGradient,
          ),
        ),
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: Colors.white, size: 20),
            onPressed: () => context.pop()),
      ),
      body: state.isSubmitting
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text('Registering...'),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Page subtitle
                        Text(
                            'Register a new family in under 30 seconds.\nParents will complete their profile later.',
                            style: GoogleFonts.nunito(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 20),

                        // Parent Info Card
                        _buildParentCard(state),

                        // Student Info Section Header
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                gradient: AppColors.secondaryGradient,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.school_outlined,
                                  color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Student Information',
                              style: GoogleFonts.nunito(
                                  fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Child Cards
                        for (int i = 0; i < state.children.length; i++)
                          _buildChildCard(i, state.children[i]),

                        // Add Another Child Button
                        GestureDetector(
                          onTap: () =>
                              ref.read(registrationProvider.notifier).addChild(),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: AppColors.accent.withValues(alpha: 0.4),
                                  width: 1.5),
                              borderRadius: BorderRadius.circular(16),
                              color:
                                  AppColors.accent.withValues(alpha: 0.05),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_circle_outline,
                                    color: AppColors.accent,
                                    size: 22),
                                const SizedBox(width: 8),
                                Text('Add Another Child',
                                    style: GoogleFonts.nunito(
                                        color: AppColors.accent,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Action Bar
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: OutlinedButton(
                            onPressed: () => ref
                                .read(registrationProvider.notifier)
                                .clearForm(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                              side: const BorderSide(
                                  color: AppColors.border),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text('Clear Form',
                                style: GoogleFonts.nunito(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _handleRegister,
                            icon: const Icon(Icons.check_circle_outline,
                                size: 20),
                            label: Text('Register Student',
                                style: GoogleFonts.nunito(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              elevation: 2,
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