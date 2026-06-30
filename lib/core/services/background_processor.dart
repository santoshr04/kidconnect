import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'cloud_vision_service.dart';
import 'insight_face_service.dart';

/// Runs after a photo is uploaded to Firebase Storage.
/// Downloads the image, detects faces with Cloud Vision,
/// recognizes them with InsightFace, and saves everything to Firestore.
class BackgroundProcessor {
  static Future<void> processPhoto(String photoId, String imageUrl) async {
    try {
      // Mark as processing
      await FirebaseFirestore.instance.collection('photos').doc(photoId).update({
        'processingStatus': 'analyzing',
      });

      // Download image
      final response = await http.get(Uri.parse(imageUrl));
      final imageBytes = response.bodyBytes;
      final original = img.decodeImage(imageBytes);
      if (original == null) return;

      // Detect faces with Cloud Vision
      final faces = await CloudVisionService.detectFaces(imageUrl);
      if (faces.isEmpty) {
        await FirebaseFirestore.instance.collection('photos').doc(photoId).update({
          'aiDetections': [],
          'processingStatus': 'complete',
        });
        return;
      }

      // Crop each face
      final crops = <Uint8List>[];
      for (final face in faces) {
        final padW = (face.width * 0.2).toInt();
        final padH = (face.height * 0.2).toInt();
        final cropLeft = (face.left.toInt() - padW).clamp(0, original.width - 1);
        final cropTop = (face.top.toInt() - padH).clamp(0, original.height - 1);
        final cropWidth = (face.width.toInt() + padW * 2).clamp(1, original.width - cropLeft);
        final cropHeight = (face.height.toInt() + padH * 2).clamp(1, original.height - cropTop);

        final cropped = img.copyCrop(original,
          x: cropLeft, y: cropTop,
          width: cropWidth, height: cropHeight,
        );
        crops.add(Uint8List.fromList(img.encodeJpg(cropped, quality: 90)));
      }

      // Batch recognize
      final results = await InsightFaceService.recognizeBatch(crops);

      // Build aiDetections for Firestore
      final detections = <Map<String, dynamic>>[];
      final matchedChildIds = <String>[];

      for (var i = 0; i < faces.length && i < results.length; i++) {
        final face = faces[i];
        final result = results[i];

        final detection = <String, dynamic>{
          'childId': '',
          'confidence': 0.9,
          'boundingBox': [face.left, face.top, face.width, face.height],
        };

        if (result['matched'] == true) {
          detection['childId'] = result['child_id'] ?? '';
          detection['confidence'] = (result['confidence'] ?? 90) / 100;
          if (result['child_id'] != null) {
            matchedChildIds.add(result['child_id'] as String);
          }
        }

        detections.add(detection);
      }

      // Save to Firestore
      await FirebaseFirestore.instance.collection('photos').doc(photoId).update({
        'aiDetections': detections,
        'childIds': matchedChildIds,
        'faceDetectionComplete': true,
        'detectedAt': FieldValue.serverTimestamp(),
        'processingStatus': 'complete',
      });
    } catch (e) {
      await FirebaseFirestore.instance.collection('photos').doc(photoId).update({
        'processingStatus': 'failed',
        'faceDetectionError': e.toString(),
      });
    }
  }
}