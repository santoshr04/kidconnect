import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';

/// Playful role selection with big animated cards and floating decorations
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late AnimationController _floatController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _floatController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
    );
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Constrain width for web/tablet
    final contentWidth = screenWidth > 500 ? 420.0 : screenWidth;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background decorative shapes
          _buildBackgroundDecorations(),

          // Main content
          SafeArea(
            child: Center(
              child: SizedBox(
                width: contentWidth,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            const SizedBox(height: 40),

                          // Animated logo
                          AnimatedBuilder(
                            animation: _floatController,
                            builder: (context, child) {
                              final y = sin(_floatController.value * 2 * pi) * 6;
                              return Transform.translate(
                                offset: Offset(0, y),
                                child: child,
                              );
                            },
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                gradient: AppColors.warmGradient,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Text('👶', style: TextStyle(fontSize: 38)),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Header
                          Text(
                            'Welcome to',
                            style: GoogleFonts.nunito(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            'KidConnect',
                            style: GoogleFonts.nunito(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.tertiary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Who are you? 🤔',
                              style: GoogleFonts.nunito(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.tertiaryDark,
                              ),
                            ),
                          ),
                          const SizedBox(height: 36),

                          // ─── Parent Card ─────────────────────
                          _BigRoleCard(
                            emoji: '👨‍👩‍👧‍👦',
                            title: "I'm a Parent",
                            features: [
                              '📊 Track attendance & progress',
                              '📸 View photos & activities',
                              '💬 Chat with teachers',
                            ],
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            delay: 200,
                            floatController: _floatController,
                            onTap: () => context.push('/parent-login'),
                          ),

                          const SizedBox(height: 16),

                          // ─── Teacher Card ────────────────────
                          _BigRoleCard(
                            emoji: '👩‍🏫',
                            title: "I'm a Teacher",
                            features: [
                              '📋 Mark attendance & post activities',
                              '📸 Upload photos & send reports',
                              '👥 Manage classes & students',
                            ],
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4ECDC4), Color(0xFF44B09E)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            delay: 400,
                            floatController: _floatController,
                            onTap: () => context.push('/login', extra: 'teacher'),
                          ),

                          const SizedBox(height: 36),

                          // Footer
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppColors.secondary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppColors.tertiary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'KidConnect v1.0',
                                  style: GoogleFonts.nunito(
                                    fontSize: 12,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundDecorations() {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, _) {
        final val = _floatController.value;
        return Stack(
          children: [
            // Top-left blob
            Positioned(
              left: -80,
              top: -60,
              child: Transform.rotate(
                angle: val * 0.3,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.08),
                        AppColors.primary.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Bottom-right blob
            Positioned(
              right: -60,
              bottom: -40,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.secondary.withValues(alpha: 0.08),
                      AppColors.secondary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            // Floating mini elements
            Positioned(
              right: 30,
              top: 100 + sin(val * 2 * pi) * 10,
              child: const Opacity(
                opacity: 0.3,
                child: Text('⭐', style: TextStyle(fontSize: 18)),
              ),
            ),
            Positioned(
              left: 25,
              bottom: 120 + sin(val * 2 * pi + 1) * 8,
              child: const Opacity(
                opacity: 0.25,
                child: Text('🌈', style: TextStyle(fontSize: 16)),
              ),
            ),
            Positioned(
              right: 60,
              bottom: 200 + sin(val * 2 * pi + 2) * 12,
              child: const Opacity(
                opacity: 0.2,
                child: Text('🎨', style: TextStyle(fontSize: 14)),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Big role selection card with feature list
class _BigRoleCard extends StatefulWidget {
  final String emoji;
  final String title;
  final List<String> features;
  final Gradient gradient;
  final int delay;
  final AnimationController floatController;
  final VoidCallback onTap;

  const _BigRoleCard({
    required this.emoji,
    required this.title,
    required this.features,
    required this.gradient,
    required this.delay,
    required this.floatController,
    required this.onTap,
  });

  @override
  State<_BigRoleCard> createState() => _BigRoleCardState();
}

class _BigRoleCardState extends State<_BigRoleCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _animController.forward();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnim,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: widget.gradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: (widget.gradient as LinearGradient)
                      .colors
                      .first
                      .withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(widget.emoji,
                            style: const TextStyle(fontSize: 30)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: GoogleFonts.nunito(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: AppColors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ...widget.features.map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        f,
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
