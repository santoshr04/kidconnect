import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_colors.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/teacher/screens/upload_photos_screen.dart';
import '../features/teacher/screens/teacher_gallery_screen.dart';
import '../features/teacher/screens/photo_detail_screen.dart';
import '../features/teacher/screens/student_registration_screen.dart';
import '../features/teacher/screens/registered_students_screen.dart';
import '../data/models/photo_model.dart';
import 'bottom_nav_shell.dart';

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
  }
}

final routerNotifierProvider = Provider((ref) => RouterNotifier(ref));

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    refreshListenable: notifier,
    initialLocation: '/login',
    routes: [
      // ─── Login ──────────────────────────────────
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const LoginScreen(role: 'teacher'),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                  .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            );
          },
        ),
      ),

      // ─── Teacher Shell ──────────────────────────
      ShellRoute(
        builder: (context, state, child) =>
            BottomNavShell(isParent: false, child: child),
        routes: [
          GoRoute(
            path: '/teacher',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: UploadPhotosScreen(),
            ),
          ),
          GoRoute(
            path: '/teacher/gallery',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: TeacherGalleryScreen(),
            ),
          ),
          GoRoute(
            path: '/teacher/students',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: RegisteredStudentsScreen(),
            ),
          ),
          GoRoute(
            path: '/teacher/register',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: StudentRegistrationScreen(),
            ),
          ),
        ],
      ),

      // ─── Photo Detail ───────────────────────────
      GoRoute(
        path: '/teacher/photo/:photoId',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: PhotoDetailScreen(photo: state.extra as PhotoModel),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                  .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            );
          },
        ),
      ),
    ],
  );
});