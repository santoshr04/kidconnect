import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/role_selection_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/parent_phone_login_screen.dart';
import '../features/parent/screens/gallery_screen.dart';
import '../features/parent/screens/parent_photo_viewer_screen.dart';
import '../features/parent/screens/face_enrollment_screen.dart';
import '../features/parent/screens/parent_child_selection_screen.dart';
import '../features/parent/screens/parent_profile_screen.dart';
import '../features/teacher/screens/upload_photos_screen.dart';
import '../features/teacher/screens/teacher_gallery_screen.dart';
import '../features/teacher/screens/photo_detail_screen.dart';
import '../features/teacher/screens/student_registration_screen.dart';
import '../features/teacher/screens/registered_students_screen.dart';
import '../features/messaging/screens/chat_screen.dart';
import '../data/models/user_model.dart';
import '../data/models/photo_model.dart';
import '../features/admin/screens/admin_shell.dart';
import '../features/admin/screens/admin_dashboard_screen.dart';
import '../features/admin/screens/admin_classes_screen.dart';
import '../features/admin/screens/admin_teachers_screen.dart';
import '../features/admin/screens/admin_students_screen.dart';
import '../features/admin/screens/admin_parents_screen.dart';
import '../features/admin/screens/admin_photos_screen.dart';
import '../features/admin/screens/admin_more_screen.dart';
import 'bottom_nav_shell.dart';

/// Listenable to notify GoRouter of auth state changes
class RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(
      authProvider,
      (_, __) => notifyListeners(),
    );
  }
}

final routerNotifierProvider = Provider((ref) => RouterNotifier(ref));

/// App router configuration using GoRouter
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    refreshListenable: notifier,
    initialLocation: '/',
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isAuthenticated = authState.isAuthenticated;
      final isLoginRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/role-select' ||
          state.matchedLocation == '/' ||
          state.matchedLocation == '/parent-login';

      if (!isAuthenticated) {
        if (!isLoginRoute) {
          return '/role-select';
        }
        return null;
      }

      // If authenticated
      if (authState.isParent) {
        if (authState.allChildren.length > 1 && authState.selectedChildId == null) {
          if (state.matchedLocation != '/parent/select-child') {
            return '/parent/select-child';
          }
          return null; // Already there
        }

        final status = authState.currentUser?.status;
        if (status == ParentStatus.pendingCompletion) {
          if (state.matchedLocation != '/parent/complete-profile') {
            return '/parent/complete-profile';
          }
          return null; // Already there
        }

        // If they are on a login route, send them to parent dashboard
        if (isLoginRoute) {
          return '/parent';
        }
      } else if (authState.isTeacher) {
        // Teacher
        if (isLoginRoute) {
          return '/teacher';
        }
      } else if (authState.isAdmin) {
        // Admin
        if (isLoginRoute) {
          return '/admin';
        }
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

      // ─── Parent Phone Login ──────────────────────────
      GoRoute(
        path: '/parent-login',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const ParentPhoneLoginScreen(),
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

      // ─── Child Selection (standalone, no bottom nav) ──
      GoRoute(
        path: '/parent/select-child',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const ParentChildSelectionScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
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
              child: GalleryScreen(),
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
              child: Scaffold(body: Center(child: Text('Messaging Coming Soon'))),
            ),
          ),
          GoRoute(
            path: '/parent/face-setup',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: FaceEnrollmentScreen(),
            ),
          ),
          GoRoute(
            path: '/parent/complete-profile',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ParentProfileScreen(),
            ),
          ),
          GoRoute(
            path: '/parent/profile',
            pageBuilder: (context, state) => CustomTransitionPage(
              child: const ParentProfileScreen(isViewMode: true),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return SlideTransition(
                  position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                      .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                  child: child,
                );
              },
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
              child: UploadPhotosScreen(),
            ),
          ),
          GoRoute(
            path: '/teacher/photos',
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
            path: '/teacher/chat',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: Scaffold(body: Center(child: Text('Messaging Coming Soon'))),
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

      // ─── Admin Shell ──────────────────────────────────
      ShellRoute(
        builder: (context, state, child) =>
            AdminShell(child: child),
        routes: [
          GoRoute(
            path: '/admin',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AdminDashboardScreen(),
            ),
          ),
          GoRoute(
            path: '/admin/classes',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AdminClassesScreen(),
            ),
          ),
          GoRoute(
            path: '/admin/teachers',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AdminTeachersScreen(),
            ),
          ),
          GoRoute(
            path: '/admin/students',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AdminStudentsScreen(),
            ),
          ),
          GoRoute(
            path: '/admin/parents',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AdminParentsScreen(),
            ),
          ),
          GoRoute(
            path: '/admin/photos',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AdminPhotosScreen(),
            ),
          ),
          GoRoute(
            path: '/admin/more',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AdminMoreScreen(),
            ),
          ),
        ],
      ),

      // ─── Shared Photo Viewer (no shell, works for teacher + parent) ───
      GoRoute(
        path: '/photo-viewer',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return CustomTransitionPage(
            child: ParentPhotoViewerScreen(
              photos: (extra['photos'] as List).cast<PhotoModel>(),
              initialIndex: extra['index'] as int,
            ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          );
        },
      ),

      // ─── Standalone Routes ────────────────────────────
      GoRoute(
        path: '/teacher/photo/:photoId',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: PhotoDetailScreen(
            photo: state.extra as PhotoModel,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
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

      GoRoute(
        path: '/chat/:userId',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: ChatScreen(
            otherUserId: state.pathParameters['userId']!,
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
    ],
  );
});