import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A beautiful animated card with scale and fade entrance animation
class AnimatedCard extends StatefulWidget {
  final Widget child;
  final int index;
  final EdgeInsets? margin;
  final EdgeInsets? padding;
  final Color? color;
  final Gradient? gradient;
  final double borderRadius;
  final VoidCallback? onTap;
  final double? elevation;
  final Border? border;

  const AnimatedCard({
    super.key,
    required this.child,
    this.index = 0,
    this.margin,
    this.padding,
    this.color,
    this.gradient,
    this.borderRadius = 16,
    this.onTap,
    this.elevation,
    this.border,
  });

  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      ),
    );

    // Staggered animation based on index
    Future.delayed(Duration(milliseconds: 80 * widget.index), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: child,
            ),
          ),
        );
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: widget.margin ?? const EdgeInsets.symmetric(vertical: 6),
          padding: widget.padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.gradient == null
                ? (widget.color ?? AppColors.cardBackground)
                : null,
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: widget.border ??
                Border.all(color: AppColors.border, width: 0.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: widget.elevation ?? 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
