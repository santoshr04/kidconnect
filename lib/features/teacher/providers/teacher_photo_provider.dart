import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import '../../../data/models/photo_model.dart';
import '../../../data/mock/mock_data.dart';
import '../../../data/repositories/photo_repository.dart';

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
  final dir = await getTemporaryDirectory();
  final targetPath = '${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.webp';

  final result = await FlutterImageCompress.compressAndGetFile(
    file.absolute.path,
    targetPath,
    minWidth: 1024,
    minHeight: 1024,
    quality: 75,
    format: CompressFormat.webp,
  );

  if (result != null && File(result.path).lengthSync() < file.lengthSync()) {
    return File(result.path);
  }
  return file;
}

/// Holds photos uploaded during the current session.
class TeacherPhotoState {
  final List<PhotoModel> uploadedPhotos;

  const TeacherPhotoState({this.uploadedPhotos = const []});
}

class TeacherPhotoNotifier extends StateNotifier<TeacherPhotoState> {
  TeacherPhotoNotifier() : super(const TeacherPhotoState());

  /// WhatsApp-style: add photos instantly with local paths and pending status.
  void addPendingPhotos(List<File> files, String uploadedBy) {
    final newPhotos = files.map((file) => PhotoModel(
      id: 'pending_${DateTime.now().millisecondsSinceEpoch}_${files.indexOf(file)}',
      url: file.path,
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

    for (int i = 0; i < files.length; i++) {
      final localId = localIds[i];

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
      } else {
        final errStatus = Map<String, String>.from(state.fileUploadStatus);
        errStatus[localId] = 'error';
        state = state.copyWith(fileUploadStatus: errStatus);
      }

      state = state.copyWith(completedFiles: i + 1);
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
  final uploaded = ref.watch(teacherPhotoStateProvider).uploadedPhotos;
  final mockData = MockData.photos;

  final seen = <String>{};
  final merged = <PhotoModel>[];

  for (final photo in [...uploaded, ...mockData]) {
    if (seen.add(photo.id)) {
      merged.add(photo);
    }
  }

  return merged;
});

/// Helper to check if a photo is still uploading.
bool isPhotoPending(PhotoModel photo) => photo.tags.contains('__pending__');