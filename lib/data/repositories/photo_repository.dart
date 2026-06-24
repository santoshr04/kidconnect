import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../models/photo_model.dart';

/// Firebase photo repository.
class PhotoRepository {
  static bool get _isFirebaseAvailable {
    try {
      FirebaseFirestore.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  static const _collection = 'photos';
  static const _uuid = Uuid();

  static Future<PhotoModel?> uploadPhoto({
    required File file,
    String? caption,
    List<String> childIds = const [],
    List<FaceDetection> aiDetections = const [],
    required String uploadedBy,
  }) async {
    if (!_isFirebaseAvailable) return null;

    try {
      final photoId = _uuid.v4();
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('photos')
          .child(uploadedBy)
          .child('$photoId.jpg');

      await storageRef.putFile(file);
      final url = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance.collection(_collection).doc(photoId).set({
        'id': photoId,
        'url': url,
        'caption': caption ?? '',
        'childIds': childIds,
        'aiDetections': aiDetections
            .map((d) => {'childId': d.childId, 'confidence': d.confidence})
            .toList(),
        'uploadedBy': uploadedBy,
        'uploadDate': FieldValue.serverTimestamp(),
      });

      return PhotoModel(
        id: photoId,
        url: url,
        caption: caption,
        childIds: childIds,
        aiDetections: aiDetections,
        uploadedBy: uploadedBy,
        uploadDate: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  static Stream<List<PhotoModel>> getPhotosForChild(String childId) {
    if (!_isFirebaseAvailable) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection(_collection)
        .where('childIds', arrayContains: childId)
        .orderBy('uploadDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _photoFromFirestore(doc.data()))
            .toList());
  }

  static Stream<List<PhotoModel>> getAllPhotos() {
    if (!_isFirebaseAvailable) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection(_collection)
        .orderBy('uploadDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _photoFromFirestore(doc.data()))
            .toList());
  }

  static PhotoModel _photoFromFirestore(Map<String, dynamic> data) {
    return PhotoModel(
      id: data['id'] ?? '',
      url: data['url'] ?? '',
      caption: data['caption'],
      childIds: List<String>.from(data['childIds'] ?? []),
      aiDetections: (data['aiDetections'] as List?)
              ?.map((d) => FaceDetection(
                    childId: d['childId'] ?? '',
                    confidence: (d['confidence'] ?? 0.0).toDouble(),
                  ))
              .toList() ??
          [],
      uploadedBy: data['uploadedBy'] ?? '',
      uploadDate: (data['uploadDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}