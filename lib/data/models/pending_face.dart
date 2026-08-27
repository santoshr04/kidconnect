import 'package:cloud_firestore/cloud_firestore.dart';

class PendingFace {
  final String id;
  final String photoId;
  final int faceIndex;
  final String cropUrl;
  final List<double> boundingBox;
  final String status;
  final double score;
  final DateTime createdAt;

  PendingFace({
    required this.id,
    required this.photoId,
    required this.faceIndex,
    required this.cropUrl,
    required this.boundingBox,
    required this.status,
    required this.score,
    required this.createdAt,
  });

  factory PendingFace.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PendingFace(
      id: doc.id,
      photoId: data['photoId'] ?? '',
      faceIndex: data['faceIndex'] ?? 0,
      cropUrl: data['cropUrl'] ?? '',
      boundingBox: (data['boundingBox'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [],
      status: data['status'] ?? 'pending',
      score: (data['score'] ?? 0.0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
