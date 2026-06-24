/// Activity type categories
enum ActivityType {
  art,
  music,
  sports,
  learning,
  play,
  nap,
  meal,
  story,
  outdoor,
  celebration,
}

/// Activity/event model
class ActivityModel {
  final String id;
  final String title;
  final String description;
  final ActivityType type;
  final DateTime timestamp;
  final String teacherId;
  final String teacherName;
  final List<String> childIds;
  final List<String> photoUrls;
  final String? classId;

  const ActivityModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.timestamp,
    required this.teacherId,
    required this.teacherName,
    this.childIds = const [],
    this.photoUrls = const [],
    this.classId,
  });

  String get typeLabel {
    switch (type) {
      case ActivityType.art:
        return '🎨 Art & Craft';
      case ActivityType.music:
        return '🎵 Music';
      case ActivityType.sports:
        return '⚽ Sports';
      case ActivityType.learning:
        return '📚 Learning';
      case ActivityType.play:
        return '🎮 Play Time';
      case ActivityType.nap:
        return '😴 Nap Time';
      case ActivityType.meal:
        return '🍎 Meal Time';
      case ActivityType.story:
        return '📖 Story Time';
      case ActivityType.outdoor:
        return '🌳 Outdoor';
      case ActivityType.celebration:
        return '🎉 Celebration';
    }
  }

  String get typeEmoji {
    switch (type) {
      case ActivityType.art:
        return '🎨';
      case ActivityType.music:
        return '🎵';
      case ActivityType.sports:
        return '⚽';
      case ActivityType.learning:
        return '📚';
      case ActivityType.play:
        return '🎮';
      case ActivityType.nap:
        return '😴';
      case ActivityType.meal:
        return '🍎';
      case ActivityType.story:
        return '📖';
      case ActivityType.outdoor:
        return '🌳';
      case ActivityType.celebration:
        return '🎉';
    }
  }
}
