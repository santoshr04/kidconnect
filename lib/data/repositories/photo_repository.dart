import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../models/photo_model.dart';

class PhotoRepository {
  static bool get _isFirebaseAvailable {
    try { FirebaseFirestore.instance; return true; } catch (_) { return false; }
  }

  static const _collection = 'photos';
  static const _uuid = Uuid();

  static Future<PhotoModel?> uploadPhoto({
    required File file, String? caption,
    List<String> childIds = const [],
    List<FaceDetection> aiDetections = const [],
    required String uploadedBy,
  }) async {
    if (!_isFirebaseAvailable) return null;
    try {
      final photoId = _uuid.v4();
      final ref = FirebaseStorage.instance.ref().child('photos').child(uploadedBy).child('$photoId.webp');
      await ref.putFile(file, SettableMetadata(contentType: 'image/webp'));
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance.collection(_collection).doc(photoId).set({
        'id': photoId, 'url': url, 'caption': caption ?? '',
        'childIds': childIds,
        'aiDetections': aiDetections.map((d) => {'childId': d.childId, 'confidence': d.confidence, 'boundingBox': d.boundingBox}).toList(),
        'uploadedBy': uploadedBy, 'uploadDate': FieldValue.serverTimestamp(),
      });
      return PhotoModel(id: photoId, url: url, caption: caption, childIds: childIds, aiDetections: aiDetections, uploadedBy: uploadedBy, uploadDate: DateTime.now());
    } catch (_) { return null; }
  }

  static Future<PhotoModel?> uploadPhotoWithProgress({
    required File file, String? caption,
    List<String> childIds = const [],
    List<FaceDetection> aiDetections = const [],
    required String uploadedBy,
    required void Function(int, int) onProgress,
  }) async {
    if (!_isFirebaseAvailable) return null;
    try {
      final photoId = _uuid.v4();
      final ref = FirebaseStorage.instance.ref().child('photos').child(uploadedBy).child('$photoId.webp');
      final task = ref.putFile(file, SettableMetadata(contentType: 'image/webp'));
      task.snapshotEvents.listen((s) => onProgress(s.bytesTransferred, s.totalBytes));
      await task;
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance.collection(_collection).doc(photoId).set({
        'id': photoId, 'url': url, 'caption': caption ?? '',
        'childIds': childIds,
        'aiDetections': aiDetections.map((d) => {'childId': d.childId, 'confidence': d.confidence, 'boundingBox': d.boundingBox}).toList(),
        'uploadedBy': uploadedBy, 'uploadDate': FieldValue.serverTimestamp(),
      });
      return PhotoModel(id: photoId, url: url, childIds: childIds, aiDetections: aiDetections, uploadedBy: uploadedBy, uploadDate: DateTime.now());
    } catch (_) { return null; }
  }

  static Future<void> deletePhoto(String photoId, String url) async {
    if (!_isFirebaseAvailable) return;
    // Delete from Storage (may fail if permissions are insufficient — continue anyway)
    try {
      await FirebaseStorage.instance.refFromURL(url).delete();
    } catch (_) {
      // If storage delete fails, try extracting the path and deleting by ref
      try {
        final ref = FirebaseStorage.instance.refFromURL(url);
        await ref.delete();
      } catch (_) {}
    }
    // Always delete the Firestore document regardless of storage outcome
    try {
      await FirebaseFirestore.instance.collection(_collection).doc(photoId).delete();
    } catch (_) {}
  }

  static Stream<List<PhotoModel>> getPhotosForChild(String childId) {
    if (!_isFirebaseAvailable) return const Stream.empty();
    // Fetch all photos ordered by date, filter client-side (no composite index needed)
    return FirebaseFirestore.instance.collection(_collection)
        .orderBy('uploadDate', descending: true)
        .snapshots().map((s) => s.docs
            .map((d) => _fromFirestore(d.data()))
            .where((p) => p.childIds.contains(childId))
            .toList());
  }

  static Stream<List<PhotoModel>> getAllPhotos() {
    if (!_isFirebaseAvailable) return const Stream.empty();
    return FirebaseFirestore.instance.collection(_collection)
        .orderBy('uploadDate', descending: true)
        .snapshots().map((s) => s.docs.map((d) => _fromFirestore(d.data())).toList());
  }

  static Stream<List<Map<String, dynamic>>> getPendingFaces() {
    if (!_isFirebaseAvailable) return const Stream.empty();
    return FirebaseFirestore.instance.collection('pending_faces')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots().map((s) => s.docs.map((d) {
          final data = d.data();
          data['id'] = d.id;
          return data;
        }).toList());
  }
  
  static Future<void> tagPendingFace({
    required String pendingFaceId,
    required String photoId,
    required String childId,
    Map<String, dynamic>? childInfo,
    List<double>? bbox,
  }) async {
    if (!_isFirebaseAvailable) return;

    // Update the pending face status
    await FirebaseFirestore.instance.collection('pending_faces').doc(pendingFaceId).update({
      'status': 'tagged',
      'taggedChildId': childId,
      'taggedAt': FieldValue.serverTimestamp(),
    });

    // Update the per-face state on the photo so the backend won't re-crop it.
    await _updatePhotoFace(
      photoId: photoId,
      bbox: bbox,
      status: 'tagged',
      childId: childId,
    );
  }

  static Future<void> neglectPendingFace({
    required String pendingFaceId,
    required String photoId,
    List<double>? bbox,
  }) async {
    if (!_isFirebaseAvailable) return;

    await FirebaseFirestore.instance.collection('pending_faces').doc(pendingFaceId).update({
      'status': 'neglected',
      'neglectedAt': FieldValue.serverTimestamp(),
    });

    await _updatePhotoFace(
      photoId: photoId,
      bbox: bbox,
      status: 'neglected',
    );
  }

  /// Update (or insert) a single face's state on the original photo and
  /// recompute the photo-level counts + completion flag.
  static Future<void> _updatePhotoFace({
    required String photoId,
    required String status,
    List<double>? bbox,
    String? childId,
  }) async {
    final photoRef = FirebaseFirestore.instance.collection(_collection).doc(photoId);
    final snap = await photoRef.get();
    if (!snap.exists) return;
    final data = snap.data()!;

    final detections = <Map<String, dynamic>>[];
    final raw = data['aiDetections'];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          detections.add(Map<String, dynamic>.from(e));
        }
      }
    }

    if (bbox != null) {
      final idx = _findDetectionIndex(detections, bbox);
      if (idx >= 0) {
        detections[idx]['status'] = status;
        detections[idx]['childId'] = status == 'tagged' ? (childId ?? '') : '';
      } else {
        detections.add({
          'bbox': bbox,
          'childId': status == 'tagged' ? (childId ?? '') : '',
          'confidence': 0.0,
          'status': status,
        });
      }
    }

    final taggedIds = <String>{
      ...List<String>.from(data['childIds'] ?? []),
    };
    for (final d in detections) {
      if (d['status'] == 'tagged') {
        final cid = d['childId'] as String? ?? '';
        if (cid.isNotEmpty) taggedIds.add(cid);
      }
    }

    await photoRef.update({
      'aiDetections': detections,
      'childIds': taggedIds.toList(),
      'totalFaces': detections.length,
      'taggedFaces': detections.where((d) => d['status'] == 'tagged').length,
      'neglectedFaces': detections.where((d) => d['status'] == 'neglected').length,
      'pendingFaces': detections.where((d) => d['status'] == 'pending').length,
      'tagging_completed': !detections.any((d) => d['status'] == 'pending'),
    });
  }

  static int _findDetectionIndex(List<Map<String, dynamic>> detections, List<double> bbox) {
    var best = 0.5;
    var bestIdx = -1;
    for (var i = 0; i < detections.length; i++) {
      final b = detections[i]['bbox'];
      if (b is! List || b.length < 4) continue;
      final other = b.map((e) => (e as num).toDouble()).toList();
      final iou = _iou(bbox, other);
      if (iou > best) {
        best = iou;
        bestIdx = i;
      }
    }
    return bestIdx;
  }

  static double _iou(List<double> a, List<double> b) {
    final ax1 = a[0], ay1 = a[1], ax2 = a[2], ay2 = a[3];
    final bx1 = b[0], by1 = b[1], bx2 = b[2], by2 = b[3];
    final left = ax1 > bx1 ? ax1 : bx1;
    final top = ay1 > by1 ? ay1 : by1;
    final right = ax2 < bx2 ? ax2 : bx2;
    final bottom = ay2 < by2 ? ay2 : by2;
    if (left >= right || top >= bottom) return 0.0;
    final inter = (right - left) * (bottom - top);
    final areaA = (ax2 - ax1) * (ay2 - ay1);
    final areaB = (bx2 - bx1) * (by2 - by1);
    final union = areaA + areaB - inter;
    return union <= 0 ? 0.0 : inter / union;
  }

  static PhotoModel _fromFirestore(Map<String, dynamic> data) {
    return PhotoModel(
      id: data['id'] ?? '',
      url: data['url'] ?? '',
      caption: data['caption'],
      childIds: List<String>.from(data['childIds'] ?? []),
      aiDetections: (data['aiDetections'] as List?)
          ?.map((d) => FaceDetection(
                childId: d['childId']?.toString() ?? '',
                confidence: (d['confidence'] ?? 0.0).toDouble(),
                boundingBox: (d['boundingBox'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [],
              ))
          .toList() ?? [],
      uploadedBy: data['uploadedBy'] ?? '',
      uploadDate: (data['uploadDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}