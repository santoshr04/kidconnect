import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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
  // Controllers — created once, survive rebuilds
  final _parentNameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _altMobileCtrl = TextEditingController();
  final Map<int, TextEditingController> _childNameCtrls = {};
  bool _synced = false;

  @override
  void initState() {
    super.initState();
    // Sync controllers with provider state on first build
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncFromProvider());
  }

  @override
  void dispose() {
    _parentNameCtrl.dispose();
    _mobileCtrl.dispose();
    _altMobileCtrl.dispose();
    for (final c in _childNameCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Copies provider state into the text controllers (one-time sync for edit flow).
  void _syncFromProvider() {
    if (_synced) return;
    final state = ref.read(registrationProvider);
    if (state.parentName.isNotEmpty) _parentNameCtrl.text = state.parentName;
    if (state.mobileNumber.isNotEmpty) _mobileCtrl.text = state.mobileNumber;
    if (state.alternateMobile.isNotEmpty) _altMobileCtrl.text = state.alternateMobile;
    for (int i = 0; i < state.children.length; i++) {
      final ctrl = _getChildCtrl(i);
      if (state.children[i].name.isNotEmpty) ctrl.text = state.children[i].name;
    }
    _synced = true;
  }

  TextEditingController _getChildCtrl(int index) {
    if (!_childNameCtrls.containsKey(index)) {
      final state = ref.read(registrationProvider);
      final initial = index < state.children.length ? state.children[index].name : '';
      _childNameCtrls[index] = TextEditingController(text: initial);
    }
    return _childNameCtrls[index]!;
  }

  void _syncToProvider() {
    final notifier = ref.read(registrationProvider.notifier);
    notifier.setParentName(_parentNameCtrl.text);
    notifier.setMobileNumber(_mobileCtrl.text);
    notifier.setAlternateMobile(_altMobileCtrl.text);
    for (final entry in _childNameCtrls.entries) {
      notifier.setChildName(entry.key, entry.value.text);
    }
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

  // ── Child Info Card ───────────────────────────────────────
  Widget _buildChildCard(int index, StudentEntry child) {
    final state = ref.watch(registrationProvider);
    final label = state.children.length > 1 ? 'Child ${index + 1}' : 'Student';
    final nameCtrl = _getChildCtrl(index);
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
            Text('Student Name *',
                style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            TextField(
              controller: nameCtrl,
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
            Text('Parent/Guardian Name *',
                style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            TextField(
              controller: _parentNameCtrl,
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
            Text('Mobile Number *',
                style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            TextField(
              controller: _mobileCtrl,
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
            Text('Alternate Mobile Number (Optional)',
                style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            TextField(
              controller: _altMobileCtrl,
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
    _syncToProvider(); // Sync controllers → provider before validate/register
    final notifier = ref.read(registrationProvider.notifier);
    final success = await notifier.register();

    if (!mounted) return;

    if (success) {
      // Reset controllers for fresh form
      _parentNameCtrl.clear();
      _mobileCtrl.clear();
      _altMobileCtrl.clear();
      for (final c in _childNameCtrls.values) {
        c.clear();
      }
      _childNameCtrls.clear();
      _synced = false;

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
      final errorMsg =
          ref.read(registrationProvider).errorMessage ?? 'Registration failed';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

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
                        Text(
                            'Register a new family in under 30 seconds.\nParents will complete their profile later.',
                            style: GoogleFonts.nunito(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 20),
                        _buildParentCard(state),
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
                        for (int i = 0; i < state.children.length; i++)
                          _buildChildCard(i, state.children[i]),
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
                                    color: AppColors.accent, size: 22),
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
                            onPressed: () {
                              _parentNameCtrl.clear();
                              _mobileCtrl.clear();
                              _altMobileCtrl.clear();
                              for (final c in _childNameCtrls.values) {
                                c.clear();
                              }
                              _childNameCtrls.clear();
                              _synced = false;
                              ref.read(registrationProvider.notifier).clearForm();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                              side: const BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text('Clear Form',
                                style: GoogleFonts.nunito(
                                    fontWeight: FontWeight.w700, fontSize: 15)),
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
                            icon: const Icon(Icons.check_circle_outline, size: 20),
                            label: Text('Register Student',
                                style: GoogleFonts.nunito(
                                    fontWeight: FontWeight.w800, fontSize: 15)),
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