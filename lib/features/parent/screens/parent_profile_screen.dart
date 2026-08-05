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
  List<Map<String, dynamic>> _children = [];

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
    if (parentId == null) return;

    try {
      // Load parent data
      final parentDoc = await FirebaseFirestore.instance.collection('parents').doc(parentId).get();
      if (!mounted) return;
      if (parentDoc.exists) {
        final data = parentDoc.data()!;
        setState(() => _parentData = data);
        if (data['email'] != null && data['email'].toString().contains('@kidconnect.internal')) {
          _emailCtrl.text = '';
        } else {
          _emailCtrl.text = data['email'] ?? '';
        }
        _addressCtrl.text = data['address'] ?? '';
        _fatherNameCtrl.text = data['fatherName'] ?? '';
        _motherNameCtrl.text = data['motherName'] ?? '';
        _bloodGroupCtrl.text = data['bloodGroup'] ?? '';
        _allergiesCtrl.text = data['allergies'] ?? '';
        _medicalCtrl.text = data['medicalInfo'] ?? '';
        _emergencyCtrl.text = data['emergencyContact'] ?? '';
        _bloodGroup = data['bloodGroup'];
      }

      // Load children
      final childrenSnap = await FirebaseFirestore.instance
          .collection('children')
          .where('parentId', isEqualTo: parentId)
          .get();
      if (mounted) {
        setState(() => _children = childrenSnap.docs.map((d) => d.data()).toList());
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
        'bloodGroup': _bloodGroup,
        'allergies': _allergiesCtrl.text.trim(),
        'medicalInfo': _medicalCtrl.text.trim(),
        'emergencyContact': _emergencyCtrl.text.trim(),
        'status': 'active',
      });

      // Update children DOB and blood group
      for (final child in _children) {
        final childId = child['id'] as String? ?? '';
        if (childId.isNotEmpty) {
          await FirebaseFirestore.instance.collection('children').doc(childId).update({
            'bloodGroup': _bloodGroup,
          });
        }
      }

      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile completed! 🎉'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go('/parent/gallery');
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

    if (_parentData == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
            isView ? 'My Profile' : 'Complete Your Profile',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: widget.isViewMode
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
                onPressed: () => context.pop(),
              )
            : null,
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
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Teacher-entered (always read-only) ──
              _buildReadOnlySection(parentName, phone),
              const SizedBox(height: 24),
              // ── Parent details ──
              Text(
                  isView ? 'Your Details' : 'Complete the remaining details',
                  style: GoogleFonts.nunito(
                      fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              isView
                  ? _buildViewOnlyFields()
                  : _buildEditableFields(),
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
                        _saving ? 'Saving...' : 'Save & Continue',
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
      _buildTextField('Email Address *', _emailCtrl, TextInputType.emailAddress, 'Enter your email'),
      const SizedBox(height: 14),
      _buildTextField('Father\'s Name', _fatherNameCtrl, TextInputType.name, 'Father\'s full name'),
      const SizedBox(height: 14),
      _buildTextField('Mother\'s Name', _motherNameCtrl, TextInputType.name, 'Mother\'s full name'),
      const SizedBox(height: 14),
      _buildTextField('Residential Address', _addressCtrl, TextInputType.streetAddress, 'Your address'),
      const SizedBox(height: 14),
      _buildBloodGroupDropdown(),
      const SizedBox(height: 14),
      _buildTextField('Allergies', _allergiesCtrl, TextInputType.text, 'Any known allergies'),
      const SizedBox(height: 14),
      _buildTextField('Medical Information', _medicalCtrl, TextInputType.text, 'Medical conditions, medications'),
      const SizedBox(height: 14),
      _buildTextField('Emergency Contact', _emergencyCtrl, TextInputType.phone, 'Emergency contact number'),
    ]);
  }

  Widget _buildReadOnlySection(String parentName, String phone) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(width: 36, height: 36,
                decoration: BoxDecoration(gradient: AppColors.parentGradient, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.verified, color: Colors.white, size: 20)),
              const SizedBox(width: 10),
              Text('Verified by School', style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.success)),
            ]),
            const SizedBox(height: 14),
            _readOnlyRow('Parent Name', parentName),
            const SizedBox(height: 8),
            _readOnlyRow('Phone Number', '+91 $phone'),
            const Divider(height: 20),
            ..._children.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _readOnlyRow('Child', '${c['name']} — ${c['className']}${c['section'] != null ? ' · ${c['section']}' : ''}'),
            )),
          ],
        ),
      ),
    );
  }

  Widget _readOnlyRow(String label, String value) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 110, child: Text(label, style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textTertiary, fontWeight: FontWeight.w600))),
      Expanded(child: Text(value, style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700))),
    ]);
  }

  Widget _buildTextField(String label, TextEditingController ctrl, TextInputType keyboardType, String hint) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
      const SizedBox(height: 6),
      TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.nunito(color: AppColors.textTertiary, fontSize: 15),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          filled: true,
          fillColor: AppColors.surfaceVariant,
        ),
        validator: label.contains('*') ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
      ),
    ]);
  }

  Widget _buildBloodGroupDropdown() {
    const groups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Blood Group', style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
      const SizedBox(height: 6),
      Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(14)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            value: _bloodGroup,
            isExpanded: true,
            hint: Text('Select blood group', style: GoogleFonts.nunito(color: AppColors.textTertiary, fontSize: 15)),
            icon: const Icon(Icons.expand_more, color: AppColors.textSecondary),
            items: groups.map((g) => DropdownMenuItem<String?>(value: g, child: Text(g))).toList(),
            onChanged: (val) => setState(() => _bloodGroup = val),
          ),
        ),
      ),
    ]);
  }
}