import 'dart:io';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Represents a detected face in a photo with its classification.
class DetectedFace {
  final Rect boundingBox;     // Normalized 0.0-1.0 coordinates
  final String? matchedChildId; // If matched to enrolled child
  final bool isKnownAdult;    // If matched to enrolled adult
  final bool isUnknown;       // Neither child nor adult matched

  const DetectedFace({
    required this.boundingBox,
    this.matchedChildId,
    this.isKnownAdult = false,
    this.isUnknown = true,
  });

  /// Color code for UI: green = child, red = adult, blue = unknown.
  String get colorCode {
    if (matchedChildId != null) return 'green';
    if (isKnownAdult) return 'red';
    return 'blue';
  }
}

/// Simple rectangle for face bounding box.
class Rect {
  final double left;
  final double top;
  final double width;
  final double height;

  const Rect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });
}

/// ML Kit Face Detection service.
///
/// Detects all faces in a photo and classifies them as:
/// - 🟢 Child (matched to enrolled child via face embedding comparison)
/// - 🔴 Adult (matched to enrolled adult)
/// - 🔵 Unknown (neither matched — teacher tags manually)
class FaceDetectionService {
  static final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableClassification: true,
      enableLandmarks: true,
      enableTracking: false,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  /// Detect faces in an image file.
  /// [enrolledAdults] — list of enrolled adult face file paths.
  /// [enrolledChildren] — map of childId → list of enrolled face file paths.
  static Future<List<DetectedFace>> detectFaces({
    required File imageFile,
    List<File> enrolledAdults = const [],
    Map<String, List<File>> enrolledChildren = const {},
  }) async {
    final inputImage = InputImage.fromFile(imageFile);
    final faces = await _detector.processImage(inputImage);

    if (faces.isEmpty) return [];

    final results = <DetectedFace>[];

    for (final face in faces) {
      final box = face.boundingBox;
      final rect = Rect(
        left: box.left / (imageFile.lengthSync() > 0 ? 1 : 1), // Will normalize in UI
        top: box.top, // Raw coordinates — normalized in UI
        width: box.width,
        height: box.height,
      );

      // For now: simple classification based on face size and available enrollment data.
      // Production: use face embedding vectors + cosine similarity for matching.
      //
      // Currently: all faces are "unknown" — teacher tags manually.
      // If enrollment data exists, could compare embeddings.
      final matchedChild = _findBestChildMatch(
        face,
        imageFile,
        enrolledChildren,
      );

      final matchedAdult = enrolledAdults.isNotEmpty
          ? await _isAdultFace(face, imageFile, enrolledAdults)
          : false;

      results.add(DetectedFace(
        boundingBox: rect,
        matchedChildId: matchedChild,
        isKnownAdult: matchedAdult,
        isUnknown: matchedChild == null && !matchedAdult,
      ));
    }

    _detector.close();
    return results;
  }

  /// Placeholder: match face to enrolled children using simple heuristics.
  /// In production, replace with actual face embedding comparison.
  static String? _findBestChildMatch(
    Face face,
    File imageFile,
    Map<String, List<File>> enrolledChildren,
  ) {
    // If no enrolled children, all faces are unknown
    if (enrolledChildren.isEmpty) return null;

    // TODO: Implement actual ML Kit face embedding extraction + comparison.
    // For now, return null (all faces are unknown — teacher tags manually).
    // This is the correct UX: first-time setup, teacher tags, then auto-matches.
    return null;
  }

  /// Check if face belongs to a known adult (enrolled parent/teacher).
  static Future<bool> _isAdultFace(
    Face face,
    File imageFile,
    List<File> enrolledAdults,
  ) async {
    if (enrolledAdults.isEmpty) return false;

    // TODO: Compare face embeddings against enrolled adult embeddings.
    // For now, return false (no adult matching without stored embeddings).
    return false;
  }

  /// Dispose the detector when done.
  static void dispose() {
    _detector.close();
  }
}