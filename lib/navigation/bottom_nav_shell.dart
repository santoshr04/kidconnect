import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';

/// Bottom navigation shell with role-specific tabs
class BottomNavShell extends StatelessWidget {
  final bool isParent;
  final Widget child;

  const BottomNavShell({
    super.key,
    required this.isParent,
    required this.child,
  });

  int _getCurrentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (isParent) {
      if (location.contains('/parent/gallery') || location == '/parent') return 0;
      if (location.contains('/parent/chat')) return 1;
    } else {
      if (location.contains('/teacher/photos') || location == '/teacher') return 0;
      if (location.contains('/teacher/chat')) return 1;
    }
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    if (isParent) {
      switch (index) {
        case 0:
          context.go('/parent/gallery');
          break;
        case 1:
          context.go('/parent/chat');
          break;
      }
    } else {
      switch (index) {
        case 0:
          context.go('/teacher/photos');
          break;
        case 1:
          context.go('/teacher/chat');
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _getCurrentIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(
                2, // Reduced to 2 tabs
                (index) => _NavItem(
                  icon: _getIcon(index),
                  activeIcon: _getActiveIcon(index),
                  label: _getLabel(index),
                  isSelected: currentIndex == index,
                  color: isParent ? AppColors.primary : AppColors.secondary,
                  onTap: () => _onTap(context, index),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIcon(int index) {
    if (isParent) {
      switch (index) {
        case 0:
          return Icons.photo_library_outlined;
        case 1:
          return Icons.chat_bubble_outline_rounded;
        default:
          return Icons.home_outlined;
      }
    } else {
      switch (index) {
        case 0:
          return Icons.add_photo_alternate_outlined;
        case 1:
          return Icons.chat_bubble_outline_rounded;
        default:
          return Icons.dashboard_outlined;
      }
    }
  }

  IconData _getActiveIcon(int index) {
    if (isParent) {
      switch (index) {
        case 0:
          return Icons.photo_library_rounded;
        case 1:
          return Icons.chat_bubble_rounded;
        default:
          return Icons.home_rounded;
      }
    } else {
      switch (index) {
        case 0:
          return Icons.add_photo_alternate_rounded;
        case 1:
          return Icons.chat_bubble_rounded;
        default:
          return Icons.dashboard_rounded;
      }
    }
  }

  String _getLabel(int index) {
    if (isParent) {
      switch (index) {
        case 0:
          return 'Gallery';
        case 1:
          return 'Messages';
        default:
          return '';
      }
    } else {
      switch (index) {
        case 0:
          return 'Upload';
        case 1:
          return 'Messages';
        default:
          return '';
      }
    }
  }
}

/// Individual navigation item with animated indicator
class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isSelected ? activeIcon : icon,
                key: ValueKey(isSelected),
                color: isSelected ? color : AppColors.textTertiary,
                size: 24,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? color : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
