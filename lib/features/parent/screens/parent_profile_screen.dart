import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';

class ParentProfileScreen extends ConsumerStatefulWidget {
  final bool isViewMode;
  const ParentProfileScreen({super.key, this.isViewMode = false});

  @override
  ConsumerState<ParentProfileScreen> createState() => _ParentProfileScreenState();
}

class _ParentProfileScreenState extends ConsumerState<ParentProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _fatherNameCtrl = TextEditingController();
  final _motherNameCtrl = TextEditingController();
  final _bloodGroupCtrl = TextEditingController();
  final _allergiesCtrl = TextEditingController();
  final _medicalCtrl = TextEditingController();
  final _emergencyCtrl = TextEditingController();
  String? _bloodGroup;
  bool _saving = false;
  bool _editing = false;
  Map<String, dynamic>? _parentData;
  Map<String, dynamic>? _childData;
  String? _selectedChildId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _fatherNameCtrl.dispose();
    _motherNameCtrl.dispose();
    _bloodGroupCtrl.dispose();
    _allergiesCtrl.dispose();
    _medicalCtrl.dispose();
    _emergencyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final auth = ref.read(authProvider);
    final parentId = auth.currentUser?.id;
    _selectedChildId = auth.selectedChildId;
    if (parentId == null) return;

    try {
      // Load parent data
      final parentDoc =
          await FirebaseFirestore.instance.collection('parents').doc(parentId).get();
      if (!mounted) return;
      if (parentDoc.exists) {
        final data = parentDoc.data()!;
        setState(() => _parentData = data);
        if (data['email'] != null &&
            data['email'].toString().contains('@kidconnect.internal')) {
          _emailCtrl.text = '';
        } else {
          _emailCtrl.text = data['email'] ?? '';
        }
        _addressCtrl.text = data['address'] ?? '';
        _fatherNameCtrl.text =
            data['fatherName'] as String? ?? (data['name'] as String? ?? '');
        _motherNameCtrl.text = data['motherName'] ?? '';
      }

      // Load the single selected child
      await _loadChildData(_selectedChildId);
    } catch (_) {}
  }

  Future<void> _loadChildData(String? childId) async {
    if (childId == null || childId.isEmpty) return;
    try {
      final childDoc = await FirebaseFirestore.instance
          .collection('children')
          .doc(childId)
          .get();
      if (!mounted) return;
      if (childDoc.exists) {
        final childData = childDoc.data()!;
        setState(() => _childData = childData);
        _bloodGroupCtrl.text = childData['bloodGroup'] as String? ?? '';
        _allergiesCtrl.text = childData['allergies'] as String? ?? '';
        _medicalCtrl.text = childData['medicalInfo'] as String? ?? '';
        _emergencyCtrl.text = childData['emergencyContact'] as String? ?? '';
        _bloodGroup = (_bloodGroupCtrl.text.isNotEmpty) ? _bloodGroupCtrl.text : null;
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final auth = ref.read(authProvider);
    final parentId = auth.currentUser?.id;
    if (parentId == null) return;

    try {
      await FirebaseFirestore.instance.collection('parents').doc(parentId).update({
        'email': _emailCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'fatherName': _fatherNameCtrl.text.trim(),
        'motherName': _motherNameCtrl.text.trim(),
        'status': 'active',
      });

      if (_selectedChildId != null && _selectedChildId!.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('children')
            .doc(_selectedChildId)
            .update({
          'bloodGroup': _bloodGroupCtrl.text.trim(),
          'allergies': _allergiesCtrl.text.trim(),
          'medicalInfo': _medicalCtrl.text.trim(),
          'emergencyContact': _emergencyCtrl.text.trim(),
          'status': 'active',
        });
      }

      if (mounted) {
        setState(() => _saving = false);

        if (widget.isViewMode) {
          setState(() => _editing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('✅ Profile updated!'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  '✅ Profile saved! Now train your child\'s face for AI recognition.'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
          context.go('/parent/face-setup');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final parentName = _parentData?['name'] ?? '';
    final phone = _parentData?['phone'] ?? '';
    final isView = widget.isViewMode && !_editing;
    final childName = _childData?['name'] as String? ?? 'Your Child';
    final className = _childData?['className'] as String? ?? '';
    final section = _childData?['section'] as String?;
    final classDisplay =
        '$className${section != null && section.isNotEmpty ? ' · Section $section' : ''}';

    if (_parentData == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isView ? 'My Profile' : 'Complete Setup',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
            onPressed: () {
              final auth = ref.read(authProvider);
              if (auth.allChildren.length > 1) {
                context.go('/parent/select-child');
              } else if (context.canPop()) {
                context.pop();
              } else {
                context.go('/parent/gallery');
              }
            },
          ),
        actions: [
          if (!widget.isViewMode)
            TextButton(
              onPressed: () => context.go('/parent/gallery'),
              child: Text('Skip',
                  style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary)),
            ),
          if (isView)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
              tooltip: 'Edit Profile',
              onPressed: () => setState(() => _editing = true),
            ),
          if (_editing && widget.isViewMode)
            TextButton(
              onPressed: () => setState(() => _editing = false),
              child: Text('Cancel',
                  style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Child name & class
              _buildChildHeader(childName, classDisplay),
              const SizedBox(height: 20),
              // Teacher-entered details
              _buildTeacherDetailsCard(parentName, phone),
              const SizedBox(height: 24),
              // Parent-editable fields
              Text(
                  isView
                      ? 'Parent Details'
                      : widget.isViewMode
                          ? 'Edit Details'
                          : 'Complete the remaining details',
                  style: GoogleFonts.nunito(
                      fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              isView ? _buildViewOnlyFields() : _buildEditableFields(),
              if (!isView) ...[
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle_outline, size: 22),
                    label: Text(
                        _saving
                            ? 'Saving...'
                            : widget.isViewMode
                                ? 'Save Changes'
                                : 'Save & Continue',
                        style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w800, fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
              if (isView) ...[
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.close, size: 20),
                    label: Text('Close',
                        style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─── Child header — name at top, then class ───────
  Widget _buildChildHeader(String childName, String classDisplay) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.2), width: 1),
      ),
      color: AppColors.primary.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: AppColors.parentGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  childName.isNotEmpty ? childName[0].toUpperCase() : '🧒',
                  style: GoogleFonts.nunito(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    childName,
                    style: GoogleFonts.nunito(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      classDisplay.isNotEmpty
                          ? classDisplay
                          : 'Class info pending',
                      style: GoogleFonts.nunito(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Teacher-entered details card (always read-only) ──
  Widget _buildTeacherDetailsCard(String parentName, String phone) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.verified,
                      color: AppColors.success, size: 18)),
              const SizedBox(width: 10),
              Text('Details Registered by School',
                  style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success)),
            ]),
            const SizedBox(height: 14),
            _teacherRow('Parent Name', parentName),
            const SizedBox(height: 8),
            _teacherRow('Phone Number', '+91 $phone'),
          ],
        ),
      ),
    );
  }

  // ─── View-only fields ─────────────────────────────
  Widget _buildViewOnlyFields() {
    return Column(children: [
      _viewOnlyRow('Email', _emailCtrl.text),
      const SizedBox(height: 12),
      _viewOnlyRow('Father\'s Name', _fatherNameCtrl.text),
      const SizedBox(height: 12),
      _viewOnlyRow('Mother\'s Name', _motherNameCtrl.text),
      const SizedBox(height: 12),
      _viewOnlyRow('Address', _addressCtrl.text),
      const SizedBox(height: 12),
      _viewOnlyRow('Blood Group', _bloodGroupCtrl.text),
      const SizedBox(height: 12),
      _viewOnlyRow('Allergies', _allergiesCtrl.text),
      const SizedBox(height: 12),
      _viewOnlyRow('Medical Info', _medicalCtrl.text),
      const SizedBox(height: 12),
      _viewOnlyRow('Emergency Contact', _emergencyCtrl.text),
    ]);
  }

  Widget _viewOnlyRow(String label, String value) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
          width: 130,
          child: Text(label,
              style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary))),
      Expanded(
          child: Text(value.isNotEmpty ? value : '—',
              style: GoogleFonts.nunito(
                  fontSize: 14, fontWeight: FontWeight.w700))),
    ]);
  }

  // ─── Editable fields ─────────────────────────────
  Widget _buildEditableFields() {
    return Column(children: [
      _buildTextField('Father\'s Name *', _fatherNameCtrl, TextInputType.name,
          'Father\'s full name'),
      const SizedBox(height: 14),
      _buildTextField('Mother\'s Name', _motherNameCtrl, TextInputType.name,
          'Mother\'s full name'),
      const SizedBox(height: 14),
      _buildTextField('Email Address *', _emailCtrl,
          TextInputType.emailAddress, 'Enter your email'),
      const SizedBox(height: 14),
      _buildTextField('Residential Address', _addressCtrl,
          TextInputType.streetAddress, 'Your address'),
      const SizedBox(height: 14),
      _buildBloodGroupDropdown(),
      const SizedBox(height: 14),
      _buildTextField(
          'Allergies', _allergiesCtrl, TextInputType.text, 'Any known allergies'),
      const SizedBox(height: 14),
      _buildTextField('Medical Information', _medicalCtrl, TextInputType.text,
          'Medical conditions, medications'),
      const SizedBox(height: 14),
      _buildTextField('Emergency Contact', _emergencyCtrl,
          TextInputType.phone, 'Emergency contact number'),
    ]);
  }

  Widget _teacherRow(String label, String value) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
          width: 110,
          child: Text(label,
              style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w600))),
      Expanded(
          child: Text(value,
              style: GoogleFonts.nunito(
                  fontSize: 14, fontWeight: FontWeight.w700))),
    ]);
  }

  Widget _buildTextField(String label, TextEditingController ctrl,
      TextInputType keyboardType, String hint) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary)),
      const SizedBox(height: 6),
      TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
            const SizedBox(height: 8),
            _teacherRow('Phone Number', '+91 $phone'),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // 3) Editable fields
  // ──────────────────────────────────────────────────────────────────────
  Widget _buildViewOnlyFields() {
    return Column(children: [
      _viewOnlyRow('Email', _emailCtrl.text),
      const SizedBox(height: 12),
      _viewOnlyRow('Father\'s Name', _fatherNameCtrl.text),
      const SizedBox(height: 12),
      _viewOnlyRow('Mother\'s Name', _motherNameCtrl.text),
      const SizedBox(height: 12),
      _viewOnlyRow('Address', _addressCtrl.text),
      const SizedBox(height: 12),
      _viewOnlyRow('Blood Group', _bloodGroupCtrl.text),
      const SizedBox(height: 12),
      _viewOnlyRow('Allergies', _allergiesCtrl.text),
      const SizedBox(height: 12),
      _viewOnlyRow('Medical Info', _medicalCtrl.text),
      const SizedBox(height: 12),
      _viewOnlyRow('Emergency Contact', _emergencyCtrl.text),
    ]);
  }

  Widget _viewOnlyRow(String label, String value) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
          width: 130,
          child: Text(label,
              style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary))),
      Expanded(
          child: Text(value.isNotEmpty ? value : '—',
              style: GoogleFonts.nunito(
                  fontSize: 14, fontWeight: FontWeight.w700))),
    ]);
  }

  Widget _buildEditableFields() {
    return Column(children: [
      // Father name — auto-populated from parent name, but editable
      _buildTextField('Father\'s Name *', _fatherNameCtrl, TextInputType.name,
          'Father\'s full name'),
      const SizedBox(height: 14),
      _buildTextField('Mother\'s Name', _motherNameCtrl, TextInputType.name,
          'Mother\'s full name'),
      const SizedBox(height: 14),
      _buildTextField('Email Address *', _emailCtrl,
          TextInputType.emailAddress, 'Enter your email'),
      const SizedBox(height: 14),
      _buildTextField('Residential Address', _addressCtrl,
          TextInputType.streetAddress, 'Your address'),
      const SizedBox(height: 14),
      _buildBloodGroupDropdown(),
      const SizedBox(height: 14),
      _buildTextField(
          'Allergies', _allergiesCtrl, TextInputType.text, 'Any known allergies'),
      const SizedBox(height: 14),
      _buildTextField('Medical Information', _medicalCtrl, TextInputType.text,
          'Medical conditions, medications'),
      const SizedBox(height: 14),
      _buildTextField('Emergency Contact', _emergencyCtrl,
          TextInputType.phone, 'Emergency contact number'),
    ]);
  }

  Widget _teacherRow(String label, String value) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
          width: 110,
          child: Text(label,
              style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w600))),
      Expanded(
          child: Text(value,
              style: GoogleFonts.nunito(
                  fontSize: 14, fontWeight: FontWeight.w700))),
    ]);
  }

  Widget _buildTextField(String label, TextEditingController ctrl,
      TextInputType keyboardType, String hint) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary)),
      const SizedBox(height: 6),
      TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.nunito(
              color: AppColors.textTertiary, fontSize: 15),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          filled: true,
          fillColor: AppColors.surfaceVariant,
        ),
        validator: label.contains('*')
            ? (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
      ),
    ]);
  }

  Widget _buildBloodGroupDropdown() {
    const groups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Blood Group',
          style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary)),
      const SizedBox(height: 6),
      Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(14)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            value: _bloodGroup,
            isExpanded: true,
            hint: Text('Select blood group',
                style: GoogleFonts.nunito(
                    color: AppColors.textTertiary, fontSize: 15)),
            icon: const Icon(Icons.expand_more,
                color: AppColors.textSecondary),
            items: groups
                .map((g) =>
                    DropdownMenuItem<String?>(value: g, child: Text(g)))
                .toList(),
            onChanged: (val) => setState(() {
              _bloodGroup = val;
              _bloodGroupCtrl.text = val ?? '';
            }),
          ),
        ),
      ),
    ]);
  }
}