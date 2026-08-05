/// Indian-standard name capitalization utility.
/// Applies proper title casing while preserving honorifics and initials.
class NameUtils {
  NameUtils._();

  /// Honorifics that should remain as-is (exact case preserved).
  static const _honorifics = {
    'sri', 'shri', 'dr', 'dr.', 'prof', 'prof.', 'smt', 'smt.',
    'mr', 'mr.', 'mrs', 'mrs.', 'ms', 'ms.',
  };

  /// Capitalizes a name with Indian-standard title casing.
  ///
  /// Rules:
  /// - Each word is capitalized (first letter uppercase, rest lowercase)
  /// - Honorifics like "Sri", "Dr.", "Prof." are preserved
  /// - Words with dots (initials like "a.b.") are fully uppercased
  /// - Multiple spaces are collapsed
  ///
  /// Examples:
  /// - "sri ram prasad" → "Sri Ram Prasad"
  /// - "a.b. kumar" → "A.B. Kumar"
  /// - "dr. smita patel" → "Dr. Smita Patel"
  static String toTitleCase(String name) {
    if (name.trim().isEmpty) return '';

    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty);

    return parts.map((word) {
      final lower = word.toLowerCase();

      // Preserve honorifics
      if (_honorifics.contains(lower)) {
        // Honorifics with dots
        if (lower.endsWith('.')) {
          return '${lower[0].toUpperCase()}${lower.substring(1)}';
        }
        // Honorifics without dots: Sri, Shri, Dr, Prof, Smt, Mr, Mrs, Ms
        return '${lower[0].toUpperCase()}${lower.substring(1)}';
      }

      // Init symbols like "a.b." or "a.b" → "A.B." or "A.B"
      if (RegExp(r'^[a-z]\.[a-z]\.?$').hasMatch(lower)) {
        return lower.toUpperCase();
      }

      // Standard title case: capitalize first letter, lowercase rest
      return '${lower[0].toUpperCase()}${lower.substring(1)}';
    }).join(' ');
  }

  /// Convenience method: trims whitespace AND applies title case.
  /// Returns the cleaned and capitalized name, or null if the input is empty after trimming.
  static String? cleanAndCapitalize(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    return toTitleCase(trimmed);
  }

  /// Validates that a name contains only valid characters for Indian names
  /// (letters, spaces, dots for initials, hyphens, apostrophes).
  static bool isValidName(String name) {
    return RegExp(r"^[a-zA-Z\s\.\-']+$").hasMatch(name.trim());
  }
}