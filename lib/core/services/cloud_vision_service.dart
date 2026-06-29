import 'dart:convert';
import 'package:http/http.dart' as http;

class FaceData {
  final double left, top, width, height;
  final String? joyLikelihood;
  final String? headwearLikelihood;

  const FaceData({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.joyLikelihood,
    this.headwearLikelihood,
  });

  factory FaceData.fromJson(Map<String, dynamic> json) => FaceData(
    left: (json['left'] as num).toDouble(),
    top: (json['top'] as num).toDouble(),
    width: (json['width'] as num).toDouble(),
    height: (json['height'] as num).toDouble(),
    joyLikelihood: json['joy'] as String?,
    headwearLikelihood: json['headwear'] as String?,
  );
}

/// Directly calls Google Cloud Vision API for face detection.
class CloudVisionService {
  static const _apiKey = 'AIzaSyBesymav0qwryS21aNO-stucXMbIvhqwN4';
  static const _endpoint = 'https://vision.googleapis.com/v1/images:annotate?key=$_apiKey';

  /// Detect faces in an image URL.
  /// Returns list of FaceData with bounding boxes + attributes.
  static Future<List<FaceData>> detectFaces(String imageUrl) async {
    try {
      final body = jsonEncode({
        'requests': [
          {
            'image': {'source': {'imageUri': imageUrl}},
            'features': [{'type': 'FACE_DETECTION', 'maxResults': 20}],
          }
        ]
      });

      final response = await http.post(Uri.parse(_endpoint), headers: {'Content-Type': 'application/json'}, body: body);
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final annotations = data['responses']?[0]?['faceAnnotations'] as List? ?? [];

      return annotations.map((face) {
        final vertices = face['boundingPoly']['vertices'] as List;
        final left = vertices.map((v) => (v['x'] ?? 0).toDouble()).reduce((a, b) => a < b ? a : b);
        final top = vertices.map((v) => (v['y'] ?? 0).toDouble()).reduce((a, b) => a < b ? a : b);
        final right = vertices.map((v) => (v['x'] ?? 0).toDouble()).reduce((a, b) => a > b ? a : b);
        final bottom = vertices.map((v) => (v['y'] ?? 0).toDouble()).reduce((a, b) => a > b ? a : b);
        return FaceData(
          left: left, top: top, width: right - left, height: bottom - top,
          joyLikelihood: face['joyLikelihood'] as String?,
          headwearLikelihood: face['headwearLikelihood'] as String?,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }
}