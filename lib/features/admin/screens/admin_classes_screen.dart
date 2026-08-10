import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_colors.dart';

class AdminClassesScreen extends ConsumerStatefulWidget {
  const AdminClassesScreen({super.key});
  @override
  ConsumerState<AdminClassesScreen> createState() => _AdminClassesScreenState();
}

class _AdminClassesScreenState extends ConsumerState<AdminClassesScreen> {
  final _nameCtrl = TextEditingController();
  final _sectionCtrl = TextEditingController();
  String? _selectedTeacherId;
  bool _saving = false;
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _teachers = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final cs = await FirebaseFirestore.instance.collection('classes').get();
      final ts = await FirebaseFirestore.instance.collection('teachers').get();
      if (mounted) setState(() {
        _classes = cs.docs.map((d) => d.data()..['id'] = d.id).toList();
        _teachers = ts.docs.map((d) => d.data()..['id'] = d.id).toList();
      });
    } catch (_) {}
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final exists = _classes.any((c) =>
          (c['name'] as String).toLowerCase() == _nameCtrl.text.trim().toLowerCase());
      if (exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Class name already exists'), backgroundColor: Colors.red));
        setState(() => _saving = false);
        return;
      }
      await FirebaseFirestore.instance.collection('classes').add({
        'name': _nameCtrl.text.trim(),
        'section': _sectionCtrl.text.trim(),
        'teacherId': _selectedTeacherId ?? '',
        'studentCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _nameCtrl.clear(); _sectionCtrl.clear(); _selectedTeacherId = null;
      await _load();
    } catch (_) {}
    setState(() => _saving = false);
  }

  Future<void> _delete(String id) async {
    await FirebaseFirestore.instance.collection('classes').doc(id).delete();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Classes', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)), backgroundColor: AppColors.background, elevation: 0),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: Row(children: [
          Expanded(child: TextField(controller: _nameCtrl, decoration: InputDecoration(hintText: 'Class name', filled: true, fillColor: AppColors.surfaceVariant, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
          const SizedBox(width: 8),
          SizedBox(width: 100, child: TextField(controller: _sectionCtrl, decoration: InputDecoration(hintText: 'Section', filled: true, fillColor: AppColors.surfaceVariant, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
          const SizedBox(width: 8),
          ElevatedButton(onPressed: _saving ? null : _save, child: Text(_saving ? '...' : 'Add', style: GoogleFonts.nunito(fontWeight: FontWeight.w700))),
        ])),
        Expanded(child: _classes.isEmpty ? Center(child: Text('No classes yet', style: GoogleFonts.nunito(color: AppColors.textTertiary))) : ListView.builder(
          itemCount: _classes.length,
          itemBuilder: (_, i) {
            final c = _classes[i];
            return ListTile(
              leading: CircleAvatar(backgroundColor: AppColors.primary.withValues(alpha: 0.1), child: Icon(Icons.school, color: AppColors.primary)),
              title: Text('${c['name']}${(c['section'] as String?)?.isNotEmpty == true ? ' - ${c['section']}' : ''}', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
              subtitle: Text('${c['studentCount'] ?? 0} students', style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textSecondary)),
              trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _delete(c['id'] as String)),
            );
          })),
      ]),
    );
  }
}