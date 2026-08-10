import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_colors.dart';

class AdminStudentsScreen extends ConsumerStatefulWidget {
  const AdminStudentsScreen({super.key});
  @override
  ConsumerState<AdminStudentsScreen> createState() => _AdminStudentsScreenState();
}

class _AdminStudentsScreenState extends ConsumerState<AdminStudentsScreen> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _children = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('children')
          .orderBy('name')
          .get();
      if (mounted)
        setState(() {
          _children = snap.docs.map((d) => d.data()..['id'] = d.id).toList();
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleArchive(String id, bool archived) async {
    await FirebaseFirestore.instance
        .collection('children')
        .doc(id)
        .update({'archived': !archived});
    await _load();
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _children;
    return _children
        .where((c) =>
            (c['name'] as String? ?? '').toLowerCase().contains(q) ||
            (c['className'] as String? ?? '').toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: Text('Students',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search students...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: AppColors.surfaceVariant,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
        ),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Text('No students found',
                        style: GoogleFonts.nunito(
                            color: AppColors.textTertiary)))
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final c = list[i];
                      final archived = c['archived'] == true;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.1),
                          child: Text(
                            (c['name'] as String? ?? '?')[0].toUpperCase(),
                            style: GoogleFonts.nunito(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary),
                          ),
                        ),
                        title: Text(c['name'] as String? ?? '',
                            style: GoogleFonts.nunito(
                                fontWeight: FontWeight.w700)),
                        subtitle: Text(
                            '${c['className'] ?? ''}${c['section'] != null ? ' · ${c['section']}' : ''}',
                            style: GoogleFonts.nunito(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                        trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(archived ? 'Archived' : 'Active',
                                  style: GoogleFonts.nunito(
                                      fontSize: 11,
                                      color: archived
                                          ? AppColors.warning
                                          : AppColors.success)),
                              const SizedBox(width: 8),
                              Switch(
                                  value: archived,
                                  onChanged: (_) => _toggleArchive(
                                      c['id'] as String, archived)),
                            ]),
                      );
                    }),
          ),
      ]),
    );
  }
}