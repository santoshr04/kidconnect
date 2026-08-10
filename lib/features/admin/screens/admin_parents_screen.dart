import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_colors.dart';

class AdminParentsScreen extends ConsumerStatefulWidget {
  const AdminParentsScreen({super.key});
  @override
  ConsumerState<AdminParentsScreen> createState() => _AdminParentsScreenState();
}

class _AdminParentsScreenState extends ConsumerState<AdminParentsScreen> {
  final _phoneCtrl = TextEditingController();
  List<Map<String, dynamic>> _parents = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final snap =
          await FirebaseFirestore.instance.collection('parents').get();
      if (mounted)
        setState(() {
          _parents = snap.docs.map((d) => d.data()..['id'] = d.id).toList();
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updatePhone(String id, String phone) async {
    await FirebaseFirestore.instance
        .collection('parents')
        .doc(id)
        .update({'phone': phone});
    await _load();
  }

  Future<void> _toggleActive(String id, bool active) async {
    final newStatus = active ? 'inactive' : 'active';
    await FirebaseFirestore.instance
        .collection('parents')
        .doc(id)
        .update({'status': newStatus});
    await _load();
  }

  Future<void> _loadChildren(String parentId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('children')
          .where('parentId', isEqualTo: parentId)
          .get();
      final names =
          snap.docs.map((d) => d.data()['name'] as String? ?? '').join(', ');
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Linked Children'),
          content: Text(names.isEmpty ? 'No children linked' : names),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'))
          ],
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Parents',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _parents.isEmpty
              ? Center(
                  child: Text('No parents',
                      style: GoogleFonts.nunito(
                          color: AppColors.textTertiary)))
              : ListView.builder(
                  itemCount: _parents.length,
                  itemBuilder: (_, i) {
                    final p = _parents[i];
                    final isActive = p['status'] == 'active';
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.1),
                        child: Text(
                          (p['name'] as String? ?? '?')[0].toUpperCase(),
                          style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary),
                        ),
                      ),
                      title: Text(p['name'] as String? ?? '',
                          style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w700)),
                      subtitle: Text(
                          '+91 ${p['phone'] ?? ''}',
                          style: GoogleFonts.nunito(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                      trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                                icon: const Icon(Icons.child_care,
                                    size: 20),
                                onPressed: () => _loadChildren(
                                    p['id'] as String)),
                            Switch(
                                value: isActive,
                                onChanged: (_) => _toggleActive(
                                    p['id'] as String, isActive)),
                          ]),
                    );
                  }),
    );
  }
}