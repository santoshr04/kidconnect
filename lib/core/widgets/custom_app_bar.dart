import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Custom app bar with optional gradient background
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showGradient;
  final Gradient? gradient;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBackButton;
  final Color? titleColor;
  final double elevation;

  const CustomAppBar({
    super.key,
    required this.title,
    this.showGradient = false,
    this.gradient,
    this.actions,
    this.leading,
    this.showBackButton = false,
    this.titleColor,
    this.elevation = 0,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    if (showGradient) {
      return Container(
        decoration: BoxDecoration(
          gradient: gradient ?? AppColors.primaryGradient,
        ),
        child: AppBar(
          title: Text(
            title,
            style: TextStyle(
              color: titleColor ?? AppColors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: showBackButton
              ? IconButton(
                  icon: Icon(Icons.arrow_back_ios_rounded,
                      color: titleColor ?? AppColors.white),
                  onPressed: () => Navigator.of(context).pop(),
                )
              : leading,
          actions: actions,
          iconTheme:
              IconThemeData(color: titleColor ?? AppColors.white),
        ),
      );
    }

    return AppBar(
      title: Text(title),
      elevation: elevation,
      leading: showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded),
              onPressed: () => Navigator.of(context).pop(),
            )
          : leading,
      actions: actions,
    );
  }
}
