import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Single detected face returned from /detect_and_recognize
class DetectedFace {
  final double left, top, width, height;
  final bool matched;
  final String? childId;
  final String? name;
  final double? confidence;
  final String confidenceTier; // 'high', 'medium', 'low', 'low_quality'
  final String confidenceLabel; // 'Auto-tagged', 'Suggested', 'Unknown', 'Low quality'
  final Map<String, dynamic>? suggestion; // Alternative match for medium confidence

  const DetectedFace({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.matched = false,
    this.childId,
    this.name,
    this.confidence,
    this.confidenceTier = 'low',
    this.confidenceLabel = 'Unknown',
    this.suggestion,
  });

  factory DetectedFace.fromJson(Map<String, dynamic> json) => DetectedFace(
        left: (json['left'] as num).toDouble(),
        top: (json['top'] as num).toDouble(),
        width: (json['width'] as num).toDouble(),
        height: (json['height'] as num).toDouble(),
        matched: json['matched'] == true,
        childId: json['child_id'] as String?,
        name: json['name'] as String?,
        confidence: (json['confidence'] as num?)?.toDouble(),
        confidenceTier: json['confidence_tier'] as String? ?? 'low',
        confidenceLabel: json['confidence_label'] as String? ?? 'Unknown',
        suggestion: json['suggestion'] as Map<String, dynamic>?,
      );
}

/// Full response from /detect_and_recognize
class DetectResult {
  final List<DetectedFace> faces;
  final double imageWidth;
  final double imageHeight;
  final String? error;

  const DetectResult({
    required this.faces,
    required this.imageWidth,
    required this.imageHeight,
    this.error,
  });

  factory DetectResult.fromJson(Map<String, dynamic> json) => DetectResult(
        faces: (json['faces'] as List?)
                ?.map((e) => DetectedFace.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        imageWidth: (json['image_width'] as num?)?.toDouble() ?? 1,
        imageHeight: (json['image_height'] as num?)?.toDouble() ?? 1,
        error: json['error'] as String?,
      );
}

class InsightFaceService {
  static const _baseUrl = 'http://10.10.11.68:5000';

  static Future<bool> isHealthy() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/health')).timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) { return false; }
  }

  /// Enroll a child with one face photo.
  static Future<Map<String, dynamic>> enrollChild({
    required String childId, required String name, required Uint8List faceBytes,
  }) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/enroll'));
      request.fields['child_id'] = childId; request.fields['name'] = name;
      request.files.add(http.MultipartFile.fromBytes('face', faceBytes, filename: '$childId.jpg'));
      final response = await request.send().timeout(const Duration(seconds: 10));
      final body = await response.stream.bytesToString();
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (e) { return {'error': e.toString()}; }
  }

  /// Universal JSON-safe parsing for all API responses.
  static Map<String, dynamic> _safeDecode(String body) {
    if (body.trim().startsWith('<')) {
      return {'error': 'Backend server returned HTML — check if it is running at $_baseUrl'};
    }
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      return {'error': 'Invalid server response: ${e.toString().substring(0, 100)}'};
    }
  }

  /// Unified detection + recognition: sends image URL, gets back
  /// all face bounding boxes + matching child info in one response.
  static Future<DetectResult> detectAndRecognize(String imageUrl) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/detect_and_recognize'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'image_url': imageUrl}),
      ).timeout(const Duration(seconds: 30));
      final data = _safeDecode(response.body);
      return DetectResult.fromJson(data);
    } catch (e) {
      return DetectResult(faces: [], imageWidth: 1, imageHeight: 1, error: e.toString());
    }
  }

  /// Validate a face photo: checks 1 face, quality, returns embedding.
  static Future<Map<String, dynamic>> validateFace(Uint8List faceBytes) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/validate_face'));
      request.files.add(http.MultipartFile.fromBytes('face', faceBytes, filename: 'validate.jpg'));
      final response = await request.send().timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        return {'valid': false, 'error': 'Server returned status ${response.statusCode}'};
      }
      final body = await response.stream.bytesToString();
      // Guard against non-JSON responses (HTML error pages, etc.)
      if (body.trim().startsWith('<')) {
        return {'valid': false, 'error': 'Server unavailable — restart the backend'};
      }
      try {
        return jsonDecode(body) as Map<String, dynamic>;
      } catch (_) {
        return {'valid': false, 'error': 'Invalid server response'};
      }
    } catch (e) {
      return {'valid': false, 'error': 'Cannot reach server. Check if backend is running at $_baseUrl'};
    }
  }

  /// Check if a specific child is enrolled on the server.
  static Future<bool> isChildEnrolled(String childId) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/enrolled'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return false;
      final body = response.body;
      if (body.trim().startsWith('<')) return false;
      try {
        final enrolled = (jsonDecode(body) as List).cast<Map<String, dynamic>>();
        return enrolled.any((e) => e['child_id'] == childId);
      } catch (_) {
        return false;
      }
    } catch (_) {
      return false;
    }
  }

  /// Verify two face embeddings belong to the same child.
  static Future<bool> verifySameChild(List<double> emb1, List<double> emb2) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/verify_same_child'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'embedding1': emb1, 'embedding2': emb2}),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return false;
      final body = response.body;
      if (body.trim().startsWith('<')) return false;
      try {
        final data = jsonDecode(body) as Map<String, dynamic>;
        return data['same_child'] == true;
      } catch (_) {
        return false;
      }
    } catch (_) {
      return false;
    }
  }

  /// Get enrollment info for a specific child.
  static Future<Map<String, dynamic>> getEnrollmentInfo(String childId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/enrollment/$childId'),
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return {'enrolled': false, 'child_id': childId};
      final body = response.body;
      if (body.trim().startsWith('<')) return {'enrolled': false, 'child_id': childId};
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return {'enrolled': false, 'child_id': childId};
    }
  }

  /// Delete a child's enrollment data.
  static Future<bool> deleteEnrollment(String childId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/delete_enrollment/$childId'),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Delete ALL enrollment data from the backend.
  static Future<bool> deleteAllEnrollments() async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/delete_all_enrollments'),
      ).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Call backend to add confirmed face data as incremental learning.
  /// Called when teacher confirms or corrects a tag.
  static Future<bool> incrementalLearn({
    required String childId,
    required String name,
    required String imageUrl,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/incremental_learn'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'child_id': childId,
          'name': name,
          'image_url': imageUrl,
        }),
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) return false;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Recognize multiple face crops in ONE batch request.
  /// [faceBytesList] — list of cropped face images (one per detected face)
  /// Returns list of results in same order.
  static Future<List<Map<String, dynamic>>> recognizeBatch(List<Uint8List> faceBytesList) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/recognize_batch'));
      for (var i = 0; i < faceBytesList.length; i++) {
        request.files.add(http.MultipartFile.fromBytes('face_$i', faceBytesList[i], filename: 'face_$i.jpg'));
      }
      final response = await request.send().timeout(const Duration(seconds: 20));
      final body = await response.stream.bytesToString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      return (data['results'] as List).map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      return List.generate(faceBytesList.length, (_) => {'matched': false, 'error': e.toString()});
    }
  }
}
