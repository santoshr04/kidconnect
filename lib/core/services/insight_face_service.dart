import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

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