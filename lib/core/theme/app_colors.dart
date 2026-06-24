import 'package:flutter/material.dart';

/// KidConnect Color Palette
/// A warm, playful yet professional color system designed
/// for a preschool app that appeals to both children and parents.
class AppColors {
  AppColors._();

  // ─── Primary Colors ───────────────────────────────────────
  /// Coral — warm, engaging, main brand color
  static const Color primary = Color(0xFFFF6B6B);
  static const Color primaryLight = Color(0xFFFF9A9A);
  static const Color primaryDark = Color(0xFFE84545);

  // ─── Secondary Colors ─────────────────────────────────────
  /// Teal — trust, calm, secondary brand color
  static const Color secondary = Color(0xFF4ECDC4);
  static const Color secondaryLight = Color(0xFF7EDDD7);
  static const Color secondaryDark = Color(0xFF36B5AC);

  // ─── Tertiary Colors ──────────────────────────────────────
  /// Warm Yellow — joy, energy
  static const Color tertiary = Color(0xFFFFE66D);
  static const Color tertiaryLight = Color(0xFFFFF0A3);
  static const Color tertiaryDark = Color(0xFFE6CC3D);

  // ─── Accent Colors ────────────────────────────────────────
  /// Lavender — creativity, imagination
  static const Color accent = Color(0xFFA78BFA);
  static const Color accentLight = Color(0xFFC4B5FD);
  static const Color accentDark = Color(0xFF8B5CF6);

  /// Sky Blue — learning, exploration
  static const Color skyBlue = Color(0xFF60A5FA);
  static const Color skyBlueLight = Color(0xFF93C5FD);

  /// Peach — warmth, nurturing
  static const Color peach = Color(0xFFFBBF24);
  static const Color peachLight = Color(0xFFFDE68A);

  /// Mint — fresh, growth
  static const Color mint = Color(0xFF34D399);
  static const Color mintLight = Color(0xFF6EE7B7);

  /// Rose Pink — gentle, caring
  static const Color rose = Color(0xFFF472B6);
  static const Color roseLight = Color(0xFFF9A8D4);

  // ─── Neutral Colors ───────────────────────────────────────
  static const Color white = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF8F9FE);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F3F8);
  static const Color cardBackground = Color(0xFFFFFFFF);

  static const Color textPrimary = Color(0xFF1A1D26);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFF3F4F6);
  static const Color shadow = Color(0x1A000000);

  // ─── Semantic Colors ──────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);

  // ─── Attendance Status Colors ─────────────────────────────
  static const Color present = Color(0xFF10B981);
  static const Color absent = Color(0xFFEF4444);
  static const Color late = Color(0xFFF59E0B);
  static const Color holiday = Color(0xFF8B5CF6);

  // ─── Gradient Definitions ─────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [Color(0xFF4ECDC4), Color(0xFF7EDDD7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warmGradient = LinearGradient(
    colors: [Color(0xFFFF6B6B), Color(0xFFFFE66D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient coolGradient = LinearGradient(
    colors: [Color(0xFF4ECDC4), Color(0xFF60A5FA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient purpleGradient = LinearGradient(
    colors: [Color(0xFFA78BFA), Color(0xFFF472B6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient sunsetGradient = LinearGradient(
    colors: [Color(0xFFFF6B6B), Color(0xFFA78BFA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient teacherGradient = LinearGradient(
    colors: [Color(0xFF4ECDC4), Color(0xFF36B5AC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient parentGradient = LinearGradient(
    colors: [Color(0xFFFF6B6B), Color(0xFFFF9A9A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Activity Type Colors ─────────────────────────────────
  static const Color activityArt = Color(0xFFA78BFA);
  static const Color activityMusic = Color(0xFFF472B6);
  static const Color activitySports = Color(0xFF10B981);
  static const Color activityLearning = Color(0xFF60A5FA);
  static const Color activityPlay = Color(0xFFFFE66D);
  static const Color activityNap = Color(0xFF8B5CF6);
  static const Color activityMeal = Color(0xFFFBBF24);
  static const Color activityStory = Color(0xFF4ECDC4);

  // ─── Progress Category Colors ─────────────────────────────
  static const Color progressSocial = Color(0xFFFF6B6B);
  static const Color progressMotor = Color(0xFF4ECDC4);
  static const Color progressCognitive = Color(0xFF60A5FA);
  static const Color progressLanguage = Color(0xFFA78BFA);
  static const Color progressCreative = Color(0xFFFFE66D);
  static const Color progressEmotional = Color(0xFFF472B6);
}
