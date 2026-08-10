import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import 'admin_dashboard_screen.dart';
import 'admin_classes_screen.dart';
import 'admin_teachers_screen.dart';
import 'admin_students_screen.dart';
import 'admin_parents_screen.dart';
import 'admin_photos_screen.dart';
import 'admin_more_screen.dart';

/// Admin shell with bottom navigation bar
class AdminShell extends ConsumerStatefulWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  int _currentIndex = 0;

  static const _tabs = [
    ('Dashboard', Icons.dashboard_rounded, '/admin'),
    ('Classes', Icons.school_rounded, '/admin/classes'),
    ('Teachers', Icons.people_rounded, '/admin/teachers'),
    ('Students', Icons.child_care_rounded, '/admin/students'),
    ('Parents', Icons.family_restroom_rounded, '/admin/parents'),
  ];

  @override
  void initState() {
    super.initState();
    // Set initial tab from current location
    final loc = GoRouterState.of(context).uri.toString();
    for (var i = 0; i < _tabs.length; i++) {
      if (loc.startsWith(_tabs[i].$3)) {
        _currentIndex = i;
        break;
      }
    }
  }

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    context.go(_tabs[index].$3);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: widget.child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
                color: AppColors.shadow.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, -2)),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textTertiary,
          selectedLabelStyle:
              GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700),
          unselectedLabelStyle:
              GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w600),
          items: _tabs
              .map((t) => BottomNavigationBarItem(
                    icon: Icon(t.$2),
                    activeIcon: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(t.$2, size: 22),
                    ),
                    label: t.$1,
                  ))
              .toList(),
        ),
      ),
    );
  }
}