import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../data/models/photo_model.dart';
import '../../../data/mock/mock_data.dart';
import '../../../data/repositories/photo_repository.dart';

/// Upload state shared across screens (survives tab navigation).
class UploadState {
  final bool isUploading;
  final double progress;        // 0.0 to 1.0
  final String statusMessage;
  final String phase;           // 'compressing' | 'uploading' | 'done'
  final int totalFiles;
  final int completedFiles;

  const UploadState({
    this.isUploading = false,
    this.progress = 0,
    this.statusMessage = '',
    this.phase = '',
    this.totalFiles = 0,
    this.completedFiles = 0,
  });

  UploadState copyWith({
    bool? isUploading,
    double? progress,
    String? statusMessage,
    String? phase,
    int? totalFiles,
    int? completedFiles,
  }) {
    return UploadState(
      isUploading: isUploading ?? this.isUploading,
      progress: progress ?? this.progress,
      statusMessage: statusMessage ?? this.statusMessage,
      phase: phase ?? this.phase,
      totalFiles: totalFiles ?? this.totalFiles,
      completedFiles: completedFiles ?? this.completedFiles,
    );
  }
}

/// Compression helper — resize to max 2048px and convert to WebP quality 75.
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
  return file; // Return original if compression fails or doesn't help
}

/// Holds photos uploaded during the current session.
class TeacherPhotoState {
  final List<PhotoModel> uploadedPhotos;

  const TeacherPhotoState({this.uploadedPhotos = const []});
}

class TeacherPhotoNotifier extends StateNotifier<TeacherPhotoState> {
  TeacherPhotoNotifier() : super(const TeacherPhotoState());

  void addPhotoFromUrl(String url, String id, String uploadedBy) {
    final photo = PhotoModel(
      id: id,
      url: url,
      caption: '',
      childIds: [],
      uploadedBy: uploadedBy,
      uploadDate: DateTime.now(),
    );

    state = TeacherPhotoState(
      uploadedPhotos: [photo, ...state.uploadedPhotos],
    );
  }

  void addUploadedPhotos(List<File> files, String uploadedBy) {
    final newPhotos = files.map((file) => PhotoModel(
      id: 'upload_${DateTime.now().millisecondsSinceEpoch}_${files.indexOf(file)}',
      url: file.path,
      caption: '',
      childIds: [],
      uploadedBy: uploadedBy,
      uploadDate: DateTime.now(),
    )).toList();

    state = TeacherPhotoState(
      uploadedPhotos: [...newPhotos, ...state.uploadedPhotos],
    );
  }

  void updateTags(String photoId, List<String> childIds) {
    state = TeacherPhotoState(
      uploadedPhotos: state.uploadedPhotos.map((p) {
        if (p.id == photoId) {
          return PhotoModel(
            id: p.id,
            url: p.url,
            caption: p.caption,
            childIds: childIds,
            uploadedBy: p.uploadedBy,
            uploadDate: p.uploadDate,
          );
        }
        return p;
      }).toList(),
    );
  }

  void removePhoto(String photoId) {
    state = TeacherPhotoState(
      uploadedPhotos: state.uploadedPhotos.where((p) => p.id != photoId).toList(),
    );
  }
}

/// Upload notifier — handles compression + upload asynchronously,
/// survives tab switches so teacher can navigate away mid-upload.
class UploadNotifier extends StateNotifier<UploadState> {
  UploadNotifier() : super(const UploadState());

  Future<void> uploadPhotos(List<File> files, String uploadedBy) async {
    if (state.isUploading) return;

    final total = files.length;
    state = UploadState(
      isUploading: true,
      totalFiles: total,
      completedFiles: 0,
      progress: 0,
      phase: 'compressing',
      statusMessage: 'Compressing $total photos...',
    );

    int successCount = 0;

    for (int i = 0; i < files.length; i++) {
      // Phase 1: Compress
      state = state.copyWith(
        phase: 'compressing',
        progress: (i + 0.33) / total,
        statusMessage: 'Compressing photo ${i + 1} of $total...',
      );

      final compressed = await compressImage(files[i]);

      // Phase 2: Upload
      state = state.copyWith(
        phase: 'uploading',
        progress: (i + 0.66) / total,
        statusMessage: 'Uploading photo ${i + 1} of $total...',
      );

      // Upload via Firebase Storage with real progress
      final result = await PhotoRepository.uploadPhotoWithProgress(
        file: compressed,
        uploadedBy: uploadedBy,
        onProgress: (bytesUploaded, totalBytes) {
          final fileProgress = bytesUploaded / totalBytes;
          final overallProgress = (i + 0.66 + (fileProgress * 0.34)) / total;
          state = state.copyWith(
            progress: overallProgress.clamp(0.0, 1.0),
          );
        },
      );

      if (result != null) {
        successCount++;
      }

      state = state.copyWith(completedFiles: i + 1);
    }

    state = UploadState(
      isUploading: false,
      phase: 'done',
      progress: 1,
      statusMessage: 'Uploaded $successCount of $total photos',
      totalFiles: total,
      completedFiles: successCount,
    );

    // Auto-reset after 5 seconds
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
  return UploadNotifier();
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