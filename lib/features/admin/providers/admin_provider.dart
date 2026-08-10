import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/user_model.dart';

/// Admin dashboard state: live counts + recent activity
class AdminState {
  final bool isLoading;
  final int studentCount;
  final int parentCount;
  final int teacherCount;
  final int classCount;
  final int photosToday;
  final int pendingAiPhotos;
  final int untaggedPhotos;
  final List<Map<String, dynamic>> recentActivity;
  final String? error;

  const AdminState({
    this.isLoading = true,
    this.studentCount = 0,
    this.parentCount = 0,
    this.teacherCount = 0,
    this.classCount = 0,
    this.photosToday = 0,
    this.pendingAiPhotos = 0,
    this.untaggedPhotos = 0,
    this.recentActivity = const [],
    this.error,
  });

  AdminState copyWith({
    bool? isLoading,
    int? studentCount,
    int? parentCount,
    int? teacherCount,
    int? classCount,
    int? photosToday,
    int? pendingAiPhotos,
    int? untaggedPhotos,
    List<Map<String, dynamic>>? recentActivity,
    String? error,
  }) =>
      AdminState(
        isLoading: isLoading ?? this.isLoading,
        studentCount: studentCount ?? this.studentCount,
        parentCount: parentCount ?? this.parentCount,
        teacherCount: teacherCount ?? this.teacherCount,
        classCount: classCount ?? this.classCount,
        photosToday: photosToday ?? this.photosToday,
        pendingAiPhotos: pendingAiPhotos ?? this.pendingAiPhotos,
        untaggedPhotos: untaggedPhotos ?? this.untaggedPhotos,
        recentActivity: recentActivity ?? this.recentActivity,
        error: error,
      );
}

class AdminNotifier extends StateNotifier<AdminState> {
  AdminNotifier() : super(const AdminState()) {
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final db = FirebaseFirestore.instance;

      // Parallel counts
      final childrenSnap = await db.collection('children').get();
      final parentsSnap = await db.collection('parents').get();
      final photosSnap = await db.collection('photos').get();

      final sc = childrenSnap.docs.length;
      final pc = parentsSnap.docs.length;

      // Teachers: filter parent docs where role=teacher or from teachers collection
      int tc = 0;
      try {
        final tSnap = await db.collection('teachers').get();
        tc = tSnap.docs.length;
      } catch (_) {
        // Fallback: count parents with teacher flag
        tc = parentsSnap.docs.where((d) =>
            (d.data()['role'] as String? ?? 'parent') == 'teacher').length;
      }

      // Classes count
      int cc = 0;
      try {
        final cSnap = await db.collection('classes').get();
        cc = cSnap.docs.length;
      } catch (_) {}

      // Photos today (using server timestamp is best-effort on client)
      int pt = 0;
      int pending = 0;
      int untagged = 0;
      for (final doc in photosSnap.docs) {
        final data = doc.data();
        final tags = (data['tags'] as List<dynamic>? ?? []);
        final childIds = (data['childIds'] as List<dynamic>? ?? []);
        final detections = (data['aiDetections'] as List<dynamic>? ?? []);
        if (childIds.isEmpty && detections.isNotEmpty) pending++;
        if (tags.contains('__needs_review__') || tags.isEmpty) untagged++;
        pt++;
      }

      // Recent activity
      final activity = <Map<String, dynamic>>[];
      try {
        final recentSnap = await db
            .collection('photos')
            .orderBy('uploadDate', descending: true)
            .limit(5)
            .get();
        for (final d in recentSnap.docs) {
          final data = d.data();
          activity.add({
            'type': 'photo',
            'caption': data['caption'] as String? ?? 'Photo uploaded',
            'time': data['uploadDate']?.toString() ?? '',
          });
        }
      } catch (_) {}

      state = AdminState(
        isLoading: false,
        studentCount: sc,
        parentCount: pc,
        teacherCount: tc,
        classCount: cc,
        photosToday: pt,
        pendingAiPhotos: pending,
        untaggedPhotos: untagged,
        recentActivity: activity,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final adminProvider =
    StateNotifierProvider<AdminNotifier, AdminState>((ref) {
  return AdminNotifier();
});