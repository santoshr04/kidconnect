import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_colors.dart';

class AdminTeachersScreen extends ConsumerStatefulWidget {
  const AdminTeachersScreen({super.key});
  @override
  ConsumerState<AdminTeachersScreen> createState() => _AdminTeachersScreenState();
}

class _AdminTeachersScreenState extends ConsumerState<AdminTeachersScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _saving = false;
  List<Map<String, dynamic>> _teachers = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final ts = await FirebaseFirestore.instance.collection('teachers').get();
      if (mounted) setState(() => _teachers = ts.docs.map((d) => d.data()..['id'] = d.id).toList());
    } catch (_) {}
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('teachers').add({
        'name': _nameCtrl.text.trim(), 'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(), 'active': true,
        'role': 'teacher', 'createdAt': FieldValue.serverTimestamp(),
      });
      _nameCtrl.clear(); _emailCtrl.clear(); _phoneCtrl.clear();
      await _load();
    } catch (_) {}
    setState(() => _saving = false);
  }

  Future<void> _toggleActive(String id, bool active) async {
    await FirebaseFirestore.instance.collection('teachers').doc(id).update({'active': !active});
    await _load();
  }

  Future<void> _delete(String id) async {
    await FirebaseFirestore.instance.collection('teachers').doc(id).delete();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Teachers', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)), backgroundColor: AppColors.background, elevation: 0),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: Row(children: [
          Expanded(child: TextField(controller: _nameCtrl, decoration: InputDecoration(hintText: 'Name', filled: true, fillColor: AppColors.surfaceVariant, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(hintText: 'Email', filled: true, fillColor: AppColors.surfaceVariant, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
          const SizedBox(width: 8),
          ElevatedButton(onPressed: _saving ? null : _save, child: const Icon(Icons.add)),
        ])),
        Expanded(child: _teachers.isEmpty ? Center(child: Text('No teachers', style: GoogleFonts.nunito(color: AppColors.textTertiary))) : ListView.builder(
          itemCount: _teachers.length,
          itemBuilder: (_, i) {
            final t = _teachers[i];
            final active = t['active'] == true;
            return ListTile(
              leading: CircleAvatar(backgroundColor: AppColors.primary.withValues(alpha: 0.1), child: Text((t['name'] as String? ?? '?')[0].toUpperCase(), style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: AppColors.primary))),
              title: Text(t['name'] as String? ?? '', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
              subtitle: Text(t['email'] as String? ?? '', style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textSecondary)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Switch(value: active, onChanged: (_) => _toggleActive(t['id'] as String, active)),
                IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () => _delete(t['id'] as String)),
              ]),
            );
          })),
      ]),
    );
  }
}