import 'dart:convert';
import 'package:http/http.dart' as http;

/// Directly calls Google Cloud Vision API for face detection.
class CloudVisionService {
  static const _apiKey = 'AIzaSyBesymav0qwryS21aNO-stucXMbIvhqwN4';
  static const _endpoint = 'https://vision.googleapis.com/v1/images:annotate?key=$_apiKey';

  /// Detect faces in an image URL.
  /// Returns [faces]: [{left, top, width, height}, ...] and [imageSize]: {width, height}
  static Future<Map<String, dynamic>> detectFaces(String imageUrl) async {
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
      if (response.statusCode != 200) return {'faces': [], 'imageSize': null};

      final data = jsonDecode(response.body);
      final annotations = data['responses']?[0]?['faceAnnotations'] as List? ?? [];

      final faces = annotations.map((face) {
        final vertices = face['boundingPoly']['vertices'] as List;
        final left = vertices.map((v) => (v['x'] ?? 0).toDouble()).reduce((a, b) => a < b ? a : b);
        final top = vertices.map((v) => (v['y'] ?? 0).toDouble()).reduce((a, b) => a < b ? a : b);
        final right = vertices.map((v) => (v['x'] ?? 0).toDouble()).reduce((a, b) => a > b ? a : b);
        final bottom = vertices.map((v) => (v['y'] ?? 0).toDouble()).reduce((a, b) => a > b ? a : b);
        return {'left': left, 'top': top, 'width': right - left, 'height': bottom - top};
      }).toList();

      return {'faces': faces};
    } catch (e) {
      return {'faces': [], 'imageSize': null};
    }
  }
}