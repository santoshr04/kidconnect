import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class FaceSignature {
  final double normX, normY, normW, normH; // normalized 0-1 coordinates
  final String? joyLikelihood; // from Cloud Vision
  final String? headwearLikelihood;
  final int addedAt; // timestamp

  const FaceSignature({
    required this.normX,
    required this.normY,
    required this.normW,
    required this.normH,
    this.joyLikelihood,
    this.headwearLikelihood,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() => {
    'nx': normX, 'ny': normY, 'nw': normW, 'nh': normH,
    'joy': joyLikelihood, 'hw': headwearLikelihood, 'ts': addedAt,
  };

  factory FaceSignature.fromJson(Map<String, dynamic> json) => FaceSignature(
    normX: (json['nx'] as num).toDouble(),
    normY: (json['ny'] as num).toDouble(),
    normW: (json['nw'] as num).toDouble(),
    normH: (json['nh'] as num).toDouble(),
    joyLikelihood: json['joy'] as String?,
    headwearLikelihood: json['hw'] as String?,
    addedAt: json['ts'] as int,
  );

  /// Spatial hash — which 3x3 grid cell the face center falls in
  int get gridX => (normX * 3).clamp(0, 2).toInt();
  int get gridY => (normY * 3).clamp(0, 2).toInt();
  int get gridIndex => gridY * 3 + gridX;

  /// Aspect ratio of the face bounding box
  double get aspectRatio => normW / (normH > 0 ? normH : 1);
}

class ChildProfile {
  final String childId;
  final String name;
  final List<FaceSignature> signatures;

  const ChildProfile({
    required this.childId,
    required this.name,
    this.signatures = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': childId, 'name': name,
    'sigs': signatures.map((s) => s.toJson()).toList(),
  };

  factory ChildProfile.fromJson(Map<String, dynamic> json) => ChildProfile(
    childId: json['id'] as String,
    name: json['name'] as String,
    signatures: (json['sigs'] as List?)
        ?.map((s) => FaceSignature.fromJson(s as Map<String, dynamic>))
        .toList() ?? [],
  );
}

class MatchResult {
  final String childId;
  final String childName;
  final double confidence;

  const MatchResult({
    required this.childId,
    required this.childName,
    required this.confidence,
  });
}

/// Face Learning Service — stores face signatures per child
/// and auto-matches faces across photos.
class FaceLearningService {
  static const _prefsKey = 'face_profiles';
  static Map<String, ChildProfile>? _cache;

  static Future<void> _ensureLoaded() async {
    if (_cache != null) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) { _cache = {}; return; }
    final list = (jsonDecode(raw) as List).map((e) => ChildProfile.fromJson(e as Map<String, dynamic>));
    _cache = { for (final p in list) p.childId : p };
  }

  /// Save a face signature for a child after teacher tags them.
  static Future<void> addSignature({
    required String childId,
    required String childName,
    required double normX,
    required double normY,
    required double normW,
    required double normH,
    String? joyLikelihood,
    String? headwearLikelihood,
  }) async {
    await _ensureLoaded();
    final sig = FaceSignature(
      normX: normX, normY: normY, normW: normW, normH: normH,
      joyLikelihood: joyLikelihood,
      headwearLikelihood: headwearLikelihood,
      addedAt: DateTime.now().millisecondsSinceEpoch,
    );

    final existing = _cache![childId];
    if (existing != null) {
      _cache![childId] = ChildProfile(
        childId: childId, name: childName,
        signatures: [...existing.signatures, sig],
      );
    } else {
      _cache![childId] = ChildProfile(
        childId: childId, name: childName,
        signatures: [sig],
      );
    }

    await _persist();
  }

  /// Try to match a detected face from a new photo against known children.
  /// Returns best match if confidence > 0.70, null otherwise.
  static Future<MatchResult?> matchFace({
    required double normX,
    required double normY,
    required double normW,
    required double normH,
    String? joyLikelihood,
  }) async {
    await _ensureLoaded();
    if (_cache!.isEmpty) return null;

    MatchResult? best;
    double bestScore = 0;

    for (final profile in _cache!.values) {
      for (final sig in profile.signatures) {
        // Only compare faces in same or adjacent grid cells
        final newGridX = (normX * 3).clamp(0, 2).toInt();
        final newGridY = (normY * 3).clamp(0, 2).toInt();
        final sigGridX = sig.gridX;
        final sigGridY = sig.gridY;
        if ((newGridX - sigGridX).abs() > 1 || (newGridY - sigGridY).abs() > 1) continue;

        // Position similarity (faces in similar positions = same person)
        final posSim = 1 - ((normX - sig.normX).abs() + (normY - sig.normY).abs()) / 2;

        // Size similarity (similar face sizes)
        final newAspect = normW / (normH > 0 ? normH : 1);
        final sigAspect = sig.aspectRatio;
        final sizeSim = 1 - (newAspect - sigAspect).abs().clamp(0, 1);

        // Joy similarity
        final joySim = (joyLikelihood == sig.joyLikelihood) ? 1.0 : 0.0;

        // Weighted score
        final score = posSim * 0.5 + sizeSim * 0.3 + joySim * 0.2;

        if (score > bestScore) {
          bestScore = score;
          best = MatchResult(childId: profile.childId, childName: profile.name, confidence: score);
        }
      }
    }

    return bestScore > 0.70 ? best : null;
  }

  /// Get all known child profiles.
  static Future<List<ChildProfile>> getProfiles() async {
    await _ensureLoaded();
    return _cache!.values.toList();
  }

  /// Count of stored faces for a child.
  static Future<int> signatureCount(String childId) async {
    await _ensureLoaded();
    return _cache![childId]?.signatures.length ?? 0;
  }

  static Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _cache!.values.map((p) => p.toJson()).toList();
    await prefs.setString(_prefsKey, jsonEncode(list));
  }
}