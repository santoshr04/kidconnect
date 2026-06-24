import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/role_selection_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/parent/screens/gallery_screen.dart';
import '../features/teacher/screens/upload_photos_screen.dart';
import 'bottom_nav_shell.dart';

/// App router configuration using GoRouter
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isAuthenticated = authState.isAuthenticated;
      final isLoginRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/role-select' ||
          state.matchedLocation == '/';

      if (!isAuthenticated && !isLoginRoute) {
        return '/role-select';
      }

      if (isAuthenticated && isLoginRoute) {
        return authState.isParent ? '/parent' : '/teacher';
      }

      return null;
    },
    routes: [
      // Splash
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),

      // Role Selection
      GoRoute(
        path: '/role-select',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const RoleSelectionScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),

      // Login
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: LoginScreen(
            role: state.extra as String? ?? 'parent',
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            );
          },
        ),
      ),

      // ─── Parent Shell ─────────────────────────────────
      ShellRoute(
        builder: (context, state, child) =>
            BottomNavShell(isParent: true, child: child),
        routes: [
          GoRoute(
            path: '/parent',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: GalleryScreen(), // Set Gallery as Home
            ),
          ),
          GoRoute(
            path: '/parent/gallery',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: GalleryScreen(),
            ),
          ),
          GoRoute(
            path: '/parent/chat',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: Scaffold(body: Center(child: Text('Messaging Disabled'))),
            ),
          ),
        ],
      ),

      // ─── Teacher Shell ────────────────────────────────
      ShellRoute(
        builder: (context, state, child) =>
            BottomNavShell(isParent: false, child: child),
        routes: [
          GoRoute(
            path: '/teacher',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: UploadPhotosScreen(), // Set Upload as Home
            ),
          ),
          GoRoute(
            path: '/teacher/photos',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: UploadPhotosScreen(),
            ),
          ),
          GoRoute(
            path: '/teacher/chat',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: Scaffold(body: Center(child: Text('Messaging Disabled'))),
            ),
          ),
        ],
      ),

      // ─── Standalone Routes ────────────────────────────
      // (Progress and standalone chat disabled for photo-centric focus)
    ],
  );
});
