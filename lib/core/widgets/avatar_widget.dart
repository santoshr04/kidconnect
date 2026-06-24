import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

/// Circular avatar widget with status indicator and fallback initials
class AvatarWidget extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double size;
  final bool showStatus;
  final bool isOnline;
  final Color? backgroundColor;
  final Color? borderColor;

  const AvatarWidget({
    super.key,
    this.imageUrl,
    required this.name,
    this.size = 44,
    this.showStatus = false,
    this.isOnline = false,
    this.backgroundColor,
    this.borderColor,
  });

  String get _initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Color get _avatarColor {
    // Generate consistent color based on name
    final colors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.accent,
      AppColors.skyBlue,
      AppColors.mint,
      AppColors.rose,
      AppColors.peach,
    ];
    final index = name.hashCode.abs() % colors.length;
    return colors[index];
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: backgroundColor ?? _avatarColor.withValues(alpha: 0.15),
            border: borderColor != null
                ? Border.all(color: borderColor!, width: 2)
                : null,
          ),
          child: imageUrl != null && imageUrl!.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    imageUrl!,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildInitials(),
                  ),
                )
              : _buildInitials(),
        ),
        if (showStatus)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: size * 0.28,
              height: size * 0.28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOnline ? AppColors.success : AppColors.textTertiary,
                border: Border.all(color: AppColors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInitials() {
    return Center(
      child: Text(
        _initials,
        style: GoogleFonts.nunito(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
          color: backgroundColor != null ? AppColors.white : _avatarColor,
        ),
      ),
    );
  }
}
