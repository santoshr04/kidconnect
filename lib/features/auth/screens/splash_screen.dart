import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';

/// Animated splash screen with floating shapes and playful animations
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _floatingController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _textController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _floatingController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);

    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );

    _textSlide =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );

    _floatAnimation = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(parent: _floatingController, curve: Curves.easeInOut),
    );

    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _textController.forward();
    });

    Future.delayed(const Duration(milliseconds: 2800), () {
      if (mounted) context.go('/role-select');
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _floatingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53), Color(0xFFFFE66D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Floating decorative shapes
            ..._buildFloatingShapes(),

            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated Logo
                  AnimatedBuilder(
                    animation: Listenable.merge([_logoController, _floatingController]),
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _floatAnimation.value),
                        child: Opacity(
                          opacity: _logoOpacity.value,
                          child: Transform.scale(
                            scale: _logoScale.value,
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(36),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 40,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Text('👶', style: TextStyle(fontSize: 56)),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.white, width: 2),
                              ),
                              child: const Icon(Icons.check, size: 12, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // App Name with slide animation
                  SlideTransition(
                    position: _textSlide,
                    child: FadeTransition(
                      opacity: _textOpacity,
                      child: Column(
                        children: [
                          Text(
                            'KidConnect',
                            style: GoogleFonts.nunito(
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                              color: AppColors.white,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '✨ Parents & Preschool, Connected ✨',
                              style: GoogleFonts.nunito(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 50),

                  // Loading dots
                  FadeTransition(
                    opacity: _textOpacity,
                    child: _LoadingDots(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFloatingShapes() {
    return [
      // Stars and shapes floating around
      _FloatingShape(
        controller: _floatingController,
        emoji: '⭐',
        left: 30,
        top: 100,
        size: 24,
        delay: 0,
      ),
      _FloatingShape(
        controller: _floatingController,
        emoji: '🌟',
        right: 50,
        top: 150,
        size: 20,
        delay: 500,
      ),
      _FloatingShape(
        controller: _floatingController,
        emoji: '🎨',
        left: 60,
        bottom: 200,
        size: 28,
        delay: 300,
      ),
      _FloatingShape(
        controller: _floatingController,
        emoji: '📚',
        right: 40,
        bottom: 250,
        size: 26,
        delay: 700,
      ),
      _FloatingShape(
        controller: _floatingController,
        emoji: '🎵',
        left: 120,
        top: 200,
        size: 22,
        delay: 200,
      ),
      _FloatingShape(
        controller: _floatingController,
        emoji: '🦋',
        right: 100,
        top: 300,
        size: 24,
        delay: 600,
      ),
      _FloatingShape(
        controller: _floatingController,
        emoji: '🌈',
        left: 40,
        bottom: 350,
        size: 22,
        delay: 400,
      ),
      _FloatingShape(
        controller: _floatingController,
        emoji: '🎭',
        right: 80,
        bottom: 150,
        size: 20,
        delay: 100,
      ),
      // Decorative circles
      Positioned(
        left: -50,
        top: -50,
        child: Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.white.withValues(alpha: 0.08),
          ),
        ),
      ),
      Positioned(
        right: -30,
        bottom: -30,
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.white.withValues(alpha: 0.06),
          ),
        ),
      ),
      Positioned(
        right: 60,
        top: 80,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.white.withValues(alpha: 0.1),
          ),
        ),
      ),
    ];
  }
}

/// A floating shape with gentle bobbing animation
class _FloatingShape extends StatelessWidget {
  final AnimationController controller;
  final String emoji;
  final double? left;
  final double? right;
  final double? top;
  final double? bottom;
  final double size;
  final int delay;

  const _FloatingShape({
    required this.controller,
    required this.emoji,
    this.left,
    this.right,
    this.top,
    this.bottom,
    required this.size,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final value = sin((controller.value * 2 * pi) + (delay / 1000.0 * pi));
          return Transform.translate(
            offset: Offset(value * 6, value * 8),
            child: Opacity(
              opacity: 0.4 + (value.abs() * 0.2),
              child: child,
            ),
          );
        },
        child: Text(emoji, style: TextStyle(fontSize: size)),
      ),
    );
  }
}

/// Animated loading dots
class _LoadingDots extends StatefulWidget {
  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final progress = (_controller.value - index * 0.2).clamp(0.0, 1.0);
            final scale = sin(progress * pi);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.white.withValues(alpha: 0.5 + scale * 0.5),
              ),
              transform: Matrix4.translationValues(0, -scale * 8, 0),
            );
          },
        );
      }),
    );
  }
}
