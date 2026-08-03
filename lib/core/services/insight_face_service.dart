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

  const DetectedFace({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.matched = false,
    this.childId,
    this.name,
    this.confidence,
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

  /// Unified detection + recognition: sends image URL, gets back
  /// all face bounding boxes + matching child info in one response.
  static Future<DetectResult> detectAndRecognize(String imageUrl) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/detect_and_recognize'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'image_url': imageUrl}),
      ).timeout(const Duration(seconds: 30));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return DetectResult.fromJson(data);
    } catch (e) {
      return DetectResult(faces: [], imageWidth: 1, imageHeight: 1, error: e.toString());
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