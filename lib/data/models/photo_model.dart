/// Photo resolutions for optimized delivery
class PhotoResolutions {
  final String thumbnail; // Fast loading for masonry grid (WebP)
  final String optimized; // Mobile viewing (WebP/AVIF)
  final String original;  // For download/print

  const PhotoResolutions({
    required this.thumbnail,
    required this.optimized,
    required this.original,
  });
}

/// AI Detection result for a face in a photo
class FaceDetection {
  final String childId;
  final double confidence; // 0.0 to 1.0
  final List<double> boundingBox; // [x, y, width, height]

  const FaceDetection({
    required this.childId,
    required this.confidence,
    this.boundingBox = const [0, 0, 0, 0],
  });
}

/// Photo model enhanced for AI-driven school galleries
class PhotoModel {
  final String id;
  final String url; // Default URL (optimized)
  final PhotoResolutions? resolutions;
  final String? caption;
  
  // IDs of children detected in this photo (either by AI or manual)
  final List<String> childIds;
  
  // Detailed AI metadata
  final List<FaceDetection> aiDetections;
  
  final String? activityId;
  final String uploadedBy;
  final DateTime uploadDate;
  final List<String> tags;

  const PhotoModel({
    required this.id,
    required this.url,
    this.resolutions,
    this.caption,
    this.childIds = const [],
    this.aiDetections = const [],
    this.activityId,
    required this.uploadedBy,
    required this.uploadDate,
    this.tags = const [],
  });

  /// Get child IDs with high confidence detection
  List<String> get autoTaggedChildIds => 
      aiDetections.where((d) => d.confidence > 0.85).map((d) => d.childId).toList();

  /// Combined list of all tagged children
  List<String> get allTaggedChildIds => 
      {...childIds, ...autoTaggedChildIds}.toList();

  /// Check if a specific child is in this photo
  bool containsChild(String childId) => 
      allTaggedChildIds.contains(childId);
}
