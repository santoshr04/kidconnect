import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/photo_model.dart';
import '../../../data/repositories/photo_repository.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../../../core/services/insight_face_service.dart';
import '../../../core/services/background_service.dart';
/// Upload state shared across screens.
class UploadState {
  final bool isUploading;
  final double progress;
  final String statusMessage;
  final String phase;
  final int totalFiles;
  final int completedFiles;
  // Map of local ID → upload status
  final Map<String, String> fileUploadStatus; // 'pending' | 'uploading' | 'done' | 'error'

  const UploadState({
    this.isUploading = false,
    this.progress = 0,
    this.statusMessage = '',
    this.phase = '',
    this.totalFiles = 0,
    this.completedFiles = 0,
    this.fileUploadStatus = const {},
  });

  UploadState copyWith({
    bool? isUploading,
    double? progress,
    String? statusMessage,
    String? phase,
    int? totalFiles,
    int? completedFiles,
    Map<String, String>? fileUploadStatus,
  }) {
    return UploadState(
      isUploading: isUploading ?? this.isUploading,
      progress: progress ?? this.progress,
      statusMessage: statusMessage ?? this.statusMessage,
      phase: phase ?? this.phase,
      totalFiles: totalFiles ?? this.totalFiles,
      completedFiles: completedFiles ?? this.completedFiles,
      fileUploadStatus: fileUploadStatus ?? this.fileUploadStatus,
    );
  }
}

/// Compression helper.
Future<File> compressImage(File file) async {
  try {
    final dir = await getTemporaryDirectory();
    final targetPath = '${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.webp';

    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      minWidth: 720,
      minHeight: 720,
      quality: 65,
      format: CompressFormat.webp,
    );

    if (result != null && File(result.path).lengthSync() < file.lengthSync()) {
      return File(result.path);
    }
  } catch (_) {}
  return file;
}

/// Holds photos uploaded during the current session.
class TeacherPhotoState {
  final List<PhotoModel> uploadedPhotos;

  const TeacherPhotoState({this.uploadedPhotos = const []});
}

class TeacherPhotoNotifier extends StateNotifier<TeacherPhotoState> {
  TeacherPhotoNotifier() : super(const TeacherPhotoState()) {
    _loadPendingUploads();
  }

  Future<void> _loadPendingUploads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getStringList('pending_uploads') ?? [];
      if (pending.isEmpty) return;

      final validItems = <String>[];
      final restoredPhotos = <PhotoModel>[];
      for (final item in pending) {
        try {
          final data = jsonDecode(item);
          final path = data['path'] as String?;
          // Only restore if the local file still exists
          if (path != null && File(path).existsSync()) {
            restoredPhotos.add(PhotoModel(
              id: data['localId'],
              url: path,
              caption: '',
              childIds: [],
              uploadedBy: data['uploadedBy'] ?? '',
              uploadDate: DateTime.now(),
              tags: ['__pending__'],
            ));
            validItems.add(item);
          }
          // Invalid paths are dropped (file was deleted/moved)
        } catch (_) {}
      }

      // Clean up — remove any entries with missing files
      if (validItems.length != pending.length) {
        await prefs.setStringList('pending_uploads', validItems);
      }

      if (restoredPhotos.isNotEmpty) {
        state = TeacherPhotoState(
          uploadedPhotos: [...restoredPhotos, ...state.uploadedPhotos],
        );
      }
    } catch (e) {
      print('Error loading pending uploads: $e');
    }
  }

  /// WhatsApp-style: add photos instantly with local paths and pending status.
  void addPendingPhotos(List<File> files, String uploadedBy, List<String> localIds) {
    final newPhotos = files.asMap().entries.map((entry) => PhotoModel(
      id: localIds[entry.key],
      url: entry.value.path,
      caption: '',
      childIds: [],
      uploadedBy: uploadedBy,
      uploadDate: DateTime.now(),
      tags: ['__pending__'], // Marker for pending upload
    )).toList();

    state = TeacherPhotoState(
      uploadedPhotos: [...newPhotos, ...state.uploadedPhotos],
    );
  }

  /// Replace a pending photo's local path with the real Firebase URL.
  void markUploadComplete(String localId, String firebaseUrl, String realId) {
    state = TeacherPhotoState(
      uploadedPhotos: state.uploadedPhotos.map((p) {
        if (p.id == localId) {
          return PhotoModel(
            id: realId,
            url: firebaseUrl,
            caption: p.caption,
            childIds: p.childIds,
            uploadedBy: p.uploadedBy,
            uploadDate: p.uploadDate,
            tags: [], // Remove pending marker
          );
        }
        return p;
      }).toList(),
    );
  }

  void updateTags(String photoId, List<String> childIds) {
    state = TeacherPhotoState(
      uploadedPhotos: state.uploadedPhotos.map((p) {
        if (p.id == photoId) {
          return PhotoModel(
            id: p.id, url: p.url, caption: p.caption,
            childIds: childIds, uploadedBy: p.uploadedBy, uploadDate: p.uploadDate,
          );
        }
        return p;
      }).toList(),
    );
  }

  /// Batch remove multiple photos.
  void removePhotos(Set<String> photoIds) {
    state = TeacherPhotoState(
      uploadedPhotos: state.uploadedPhotos.where((p) => !photoIds.contains(p.id)).toList(),
    );
  }

  void removePhoto(String photoId) => removePhotos({photoId});
}

/// Upload notifier — WhatsApp-style: instant gallery + background upload.
class UploadNotifier extends StateNotifier<UploadState> {
  final Ref _ref;

  UploadNotifier(this._ref) : super(const UploadState());

  Future<void> uploadPhotos(List<File> files, String uploadedBy, List<String> localIds) async {
    if (state.isUploading) return;

    final total = files.length;
    final initialStatus = <String, String>{};
    for (final id in localIds) {
      initialStatus[id] = 'pending';
    }

    state = UploadState(
      isUploading: true,
      totalFiles: total,
      completedFiles: 0,
      progress: 0,
      phase: 'compressing',
      statusMessage: 'Processing ${total} photo${total == 1 ? '' : 's'}...',
      fileUploadStatus: initialStatus,
    );

    // Save to SharedPreferences for persistence
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getStringList('pending_uploads') ?? [];
      for (int i = 0; i < files.length; i++) {
        pending.add(jsonEncode({
          'localId': localIds[i],
          'path': files[i].path,
          'uploadedBy': uploadedBy,
        }));
      }
      await prefs.setStringList('pending_uploads', pending);
    } catch (_) {}

    // Register fallback WorkManager task
    try {
      await Workmanager().registerOneOffTask(
        'uploadPendingTask_${DateTime.now().millisecondsSinceEpoch}',
        'uploadPendingPhotos',
      );
    } catch (_) {}

    // Show upload progress notification
    await BackgroundService.showUploadProgress(completed: 0, total: total);

    // Collect uploaded photos for background auto-tagging after all uploads
    final uploadedPhotos = <Map<String, String>>[];

    for (int i = 0; i < files.length; i++) {
      final localId = localIds[i];

      // Update upload progress notification
      await BackgroundService.showUploadProgress(completed: i, total: total);

      // Mark this file as uploading
      final updatedStatus = Map<String, String>.from(state.fileUploadStatus);
      updatedStatus[localId] = 'uploading';
      state = state.copyWith(fileUploadStatus: updatedStatus,
        progress: (i + 0.33) / total,
        statusMessage: 'Uploading photo ${i + 1} of $total...',
      );

      final compressed = await compressImage(files[i]);

      final result = await PhotoRepository.uploadPhotoWithProgress(
        file: compressed,
        uploadedBy: uploadedBy,
        onProgress: (bytesUploaded, totalBytes) {
          final fileProgress = bytesUploaded / totalBytes;
          final overallProgress = (i + 0.66 + (fileProgress * 0.34)) / total;
          final perFileStatus = Map<String, String>.from(state.fileUploadStatus);
          perFileStatus[localId] = 'uploading';
          state = state.copyWith(progress: overallProgress.clamp(0.0, 1.0), fileUploadStatus: perFileStatus);
        },
      );

      if (result != null) {
        // Replace local preview with real Firebase URL
        _ref.read(teacherPhotoStateProvider.notifier).markUploadComplete(
              localId,
              result.url,
              result.id,
            );
        final doneStatus = Map<String, String>.from(state.fileUploadStatus);
        doneStatus[localId] = 'done';
        state = state.copyWith(fileUploadStatus: doneStatus);

        // Remove from SharedPreferences
        try {
          final prefs = await SharedPreferences.getInstance();
          final pending = prefs.getStringList('pending_uploads') ?? [];
          pending.removeWhere((item) {
            final parsed = jsonDecode(item);
            return parsed['localId'] == localId;
          });
          await prefs.setStringList('pending_uploads', pending);
        } catch (_) {}

        // Collect for background auto-tagging (non-blocking)
        uploadedPhotos.add({'id': result.id, 'url': result.url});
      } else {
        final errStatus = Map<String, String>.from(state.fileUploadStatus);
        errStatus[localId] = 'error';
        state = state.copyWith(fileUploadStatus: errStatus);
      }

      state = state.copyWith(completedFiles: i + 1);
    }

    // Cancel upload progress notification
    await BackgroundService.cancelUploadProgress();
    await BackgroundService.showUploadComplete(count: uploadedPhotos.length);

    // Fire-and-forget background auto-tagging for ALL uploaded photos
    if (uploadedPhotos.isNotEmpty) {
      _autoTagBatch(uploadedPhotos);
    }

    state = UploadState(
      isUploading: false,
      phase: 'done',
      progress: 1,
      statusMessage: 'All ${total} photo${total == 1 ? '' : 's'} uploaded',
      totalFiles: total,
      completedFiles: total,
      fileUploadStatus: state.fileUploadStatus,
    );

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && state.phase == 'done') {
        state = const UploadState();
      }
    });
  }
}

// ─── Providers ──────────────────────────────────────────

final teacherPhotoStateProvider =
    StateNotifierProvider<TeacherPhotoNotifier, TeacherPhotoState>((ref) {
  return TeacherPhotoNotifier();
});

final uploadStateProvider =
    StateNotifierProvider<UploadNotifier, UploadState>((ref) {
  return UploadNotifier(ref);
});

final allTeacherPhotosProvider = Provider<List<PhotoModel>>((ref) {
  return ref.watch(teacherPhotoStateProvider).uploadedPhotos;
});

/// Firestore-sourced photos (real uploaded photos from Firebase).
/// Survives app restart and login/logout cycles.
final firestorePhotosProvider = StreamProvider<List<PhotoModel>>((ref) {
  // Return all photos from Firestore. Falls back to empty if unavailable.
  try {
    return PhotoRepository.getAllPhotos();
  } catch (_) {
    return const Stream.empty();
  }
});

  /// Helper to check if a photo is still uploading.
bool isPhotoPending(PhotoModel photo) => photo.tags.contains('__pending__');

/// Auto-tag a single photo: runs InsightFace detection + recognition,
/// then updates Firestore with recognized childIds.
/// Only accepts child IDs that are registered in Firestore.
/// Non-blocking background auto-tag for a batch of uploaded photos.
void _autoTagBatch(List<Map<String, String>> photos) {
  for (final photo in photos) {
    _autoTagPhotoAsync(photo['id']!, photo['url']!);
  }
}

Future<void> _autoTagPhotoAsync(String photoId, String photoUrl) async {
  // Small stagger to avoid overwhelming the server
  await Future.delayed(const Duration(milliseconds: 500));
  try {
    final healthy = await InsightFaceService.isHealthy();
    if (!healthy) return;

    final result = await InsightFaceService.detectAndRecognize(photoUrl);
    if (result.error != null || result.faces.isEmpty) return;

    // Fetch valid child IDs from Firestore — only accept registered children
    final validIds = <String>{};
    try {
      final childrenSnap =
          await FirebaseFirestore.instance.collection('children').get();
      for (final doc in childrenSnap.docs) {
        validIds.add(doc.id);
      }
    } catch (_) {}

    final totalFaces = result.faces.length;
    final childIds = <String>[];
    final aiDetections = <Map<String, dynamic>>[];
    int matchedCount = 0;
    for (final face in result.faces) {
      if (face.matched && face.childId != null) {
        // Accept any backend-validated match
        matchedCount++;
        if (!childIds.contains(face.childId!)) childIds.add(face.childId!);
      }
      aiDetections.add({
        'childId': face.childId ?? '',
        'confidence': face.confidence ?? 0,
        'matched': face.matched,
        'tier': face.confidenceTier,
      });
    }

    final needsReview = matchedCount < totalFaces || childIds.isEmpty;
    await FirebaseFirestore.instance.collection('photos').doc(photoId).update({
      'childIds': childIds,
      'aiDetections': aiDetections,
      'totalFaces': totalFaces,
      'taggedFaces': matchedCount,
      if (needsReview) 'tags': ['__needs_review__'] else 'tags': [],
    });
  } catch (e) {
    print('Auto-tag failed: $e');
  }
}

/// Auto-tag a single photo (legacy for photo detail screen).
Future<void> _autoTagPhoto(String photoId, String photoUrl) async {
  try {
    final healthy = await InsightFaceService.isHealthy();
    if (!healthy) return;

    final result = await InsightFaceService.detectAndRecognize(photoUrl);
    if (result.error != null || result.faces.isEmpty) return;

    final totalFaces = result.faces.length;
    final childIds = <String>[];
    final aiDetections = <Map<String, dynamic>>[];
    int matchedCount = 0;
    for (final face in result.faces) {
      if (face.matched && face.childId != null) {
        matchedCount++;
        if (!childIds.contains(face.childId!)) childIds.add(face.childId!);
      }
      aiDetections.add({
        'childId': face.childId ?? '',
        'confidence': face.confidence ?? 0,
        'matched': face.matched,
      });
    }

    // Always save recognized childIds — partial is better than nothing
    if (childIds.isNotEmpty) {
      await FirebaseFirestore.instance.collection('photos').doc(photoId).update({
        'childIds': childIds,
        'aiDetections': aiDetections,
        'totalFaces': totalFaces,
        'taggedFaces': matchedCount,
      });
    }
  } catch (e) {
    print('Auto-tag failed: $e');
  }
}

/// Auto-tag all untagged photos in the gallery.
/// Used by the "Auto-Tag All" button.
Future<int> _autoTagAllPhotos() async {
  int count = 0;
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('photos')
        .get();
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final existingChildIds = List<String>.from(data['childIds'] ?? []);
      if (existingChildIds.isNotEmpty) continue; // Skip already tagged
      final url = data['url'] as String?;
      if (url == null || !url.startsWith('https://')) continue;
      try {
        final result = await InsightFaceService.detectAndRecognize(url);
        if (result.error != null || result.faces.isEmpty) continue;
        final totalFaces = result.faces.length;
        final childIds = <String>[];
        final aiDetections = <Map<String, dynamic>>[];
        int matchedCount = 0;
        for (final face in result.faces) {
          if (face.matched && face.childId != null) {
            matchedCount++;
            if (!childIds.contains(face.childId!)) childIds.add(face.childId!);
          }
          aiDetections.add({
            'childId': face.childId ?? '',
            'confidence': face.confidence ?? 0,
            'matched': face.matched,
          });
        }
        // Only complete if ALL faces are recognized
        if (matchedCount == totalFaces && childIds.isNotEmpty) {
          await doc.reference.update({
            'childIds': childIds,
            'aiDetections': aiDetections,
            'totalFaces': totalFaces,
            'taggedFaces': matchedCount,
          });
          count++;
        }
      } catch (_) {}
    }
  } catch (_) {}
  return count;
}

/// Provider for auto-tagging all photos.
final autoTagProvider = FutureProvider.family<int, int>((ref, trigger) async {
  return _autoTagAllPhotos();
});
