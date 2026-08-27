import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/photo_repository.dart';
import '../../../core/services/insight_face_service.dart';

class FaceTaggingDialog extends StatefulWidget {
  final Map<String, dynamic> pendingFace;

  const FaceTaggingDialog({super.key, required this.pendingFace});

  @override
  State<FaceTaggingDialog> createState() => _FaceTaggingDialogState();
}

class _FaceTaggingDialogState extends State<FaceTaggingDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  List<DocumentSnapshot> _allChildren = [];
  List<DocumentSnapshot> _filteredChildren = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _dropdownOpen = false;

  @override
  void initState() {
    super.initState();
    _fetchChildren();
    _searchController.addListener(_onSearchChanged);
    _searchFocus.addListener(() {
      if (_searchFocus.hasFocus) {
        setState(() => _dropdownOpen = true);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _fetchChildren() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('children').get();
      setState(() {
        _allChildren = snapshot.docs;
        _filteredChildren = _allChildren;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _dropdownOpen = true;
      _filteredChildren = _allChildren.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final name = (data['name'] as String? ?? '').toLowerCase();
        return name.contains(query);
      }).toList();
    });
  }

  Future<void> _tagChild(DocumentSnapshot childDoc) async {
    final childData = childDoc.data() as Map<String, dynamic>;
    final childId = childDoc.id;
    final childName = childData['name'] ?? 'Unknown';

    setState(() => _isSubmitting = true);
    
    try {
      final cropUrl = widget.pendingFace['cropUrl'];
      
      // 1. Call backend to incremental learn
      await InsightFaceService.incrementalLearn(
        childId: childId,
        name: childName,
        imageUrl: cropUrl,
      );

      // 2. Update Firestore documents
      final bbox = (widget.pendingFace['boundingBox'] as List?)
          ?.map((e) => (e as num).toDouble())
          .toList();
      await PhotoRepository.tagPendingFace(
        pendingFaceId: widget.pendingFace['id'],
        photoId: widget.pendingFace['photoId'],
        childId: childId,
        childInfo: childData,
        bbox: bbox,
      );
      
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Tagged $childName successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error tagging face: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _neglectFace() async {
    setState(() => _isSubmitting = true);
    try {
      final bbox = (widget.pendingFace['boundingBox'] as List?)
          ?.map((e) => (e as num).toDouble())
          .toList();
      await PhotoRepository.neglectPendingFace(
        pendingFaceId: widget.pendingFace['id'],
        photoId: widget.pendingFace['photoId'],
        bbox: bbox,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error skipping face: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Who is this?', style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            
            // Cropped Face Image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: widget.pendingFace['cropUrl'],
                height: 120,
                width: 120,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 120,
                  width: 120,
                  color: AppColors.surfaceVariant,
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 120,
                  width: 120,
                  color: AppColors.surfaceVariant,
                  child: const Icon(Icons.error),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Select2-style searchable dropdown
            TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              onTap: () => setState(() => _dropdownOpen = true),
              decoration: InputDecoration(
                hintText: 'Type to search kids...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _dropdownOpen
                    ? const Icon(Icons.arrow_drop_up)
                    : const Icon(Icons.arrow_drop_down),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
            ),

            const SizedBox(height: 8),

            // Dropdown suggestions (shown like select2)
            Expanded(
              child: !_dropdownOpen
                  ? Center(
                      child: Text('Tap the box and choose a kid',
                          style: GoogleFonts.nunito(color: AppColors.textSecondary)),
                    )
                  : _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredChildren.isEmpty
                          ? Center(
                              child: Text('No children found.',
                                  style: GoogleFonts.nunito(color: AppColors.textSecondary)),
                            )
                          : ListView.builder(
                              itemCount: _filteredChildren.length,
                              itemBuilder: (context, index) {
                                final childDoc = _filteredChildren[index];
                                final data = childDoc.data() as Map<String, dynamic>;
                                final name = data['name'] ?? 'Unknown';
                                final className = data['className'] ?? '';
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                    backgroundImage: data['photoUrl'] != null
                                        ? NetworkImage(data['photoUrl'])
                                        : null,
                                    child: data['photoUrl'] == null
                                        ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                                            style: const TextStyle(color: AppColors.primary))
                                        : null,
                                  ),
                                  title: Text(name, style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
                                  subtitle: className.isEmpty
                                      ? null
                                      : Text(className, style: GoogleFonts.nunito(fontSize: 12)),
                                  onTap: _isSubmitting ? null : () => _tagChild(childDoc),
                                  trailing: _isSubmitting
                                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                      : null,
                                );
                              },
                            ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : _neglectFace,
                    icon: const Icon(Icons.do_not_disturb_alt, size: 18),
                    label: const Text('Not a kid / Skip'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
