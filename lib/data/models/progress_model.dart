/// Progress category for skill assessment
enum ProgressCategory {
  social,
  motor,
  cognitive,
  language,
  creative,
  emotional,
}

/// Progress report data for a child
class ProgressModel {
  final String id;
  final String childId;
  final ProgressCategory category;
  final double score; // 0.0 to 5.0
  final String period; // e.g., "June 2026", "Q2 2026"
  final String? teacherNotes;
  final DateTime assessmentDate;
  final String assessedBy;

  const ProgressModel({
    required this.id,
    required this.childId,
    required this.category,
    required this.score,
    required this.period,
    this.teacherNotes,
    required this.assessmentDate,
    required this.assessedBy,
  });

  String get categoryLabel {
    switch (category) {
      case ProgressCategory.social:
        return 'Social Skills';
      case ProgressCategory.motor:
        return 'Motor Skills';
      case ProgressCategory.cognitive:
        return 'Cognitive';
      case ProgressCategory.language:
        return 'Language';
      case ProgressCategory.creative:
        return 'Creativity';
      case ProgressCategory.emotional:
        return 'Emotional';
    }
  }

  String get categoryEmoji {
    switch (category) {
      case ProgressCategory.social:
        return '🤝';
      case ProgressCategory.motor:
        return '🏃';
      case ProgressCategory.cognitive:
        return '🧠';
      case ProgressCategory.language:
        return '💬';
      case ProgressCategory.creative:
        return '🎨';
      case ProgressCategory.emotional:
        return '❤️';
    }
  }

  double get percentage => (score / 5.0) * 100;
}
