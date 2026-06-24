import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../models/user_model.dart';

/// Firebase Auth repository.
///
/// Provides real Firebase authentication with mock fallback.
class AuthRepository {
  static bool get isFirebaseAvailable {
    try {
      fb.FirebaseAuth.instance;
      return true; // instance exists if no exception was thrown
    } catch (_) {
      return false;
    }
  }

  /// Sign in with email and password.
  /// Returns a [UserModel] on success, null on failure.
  static Future<UserModel?> signInWithEmail(
    String email,
    String password,
    UserRole role,
  ) async {
    if (!isFirebaseAvailable) return null;

    try {
      final credential = await fb.FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      final user = credential.user;
      if (user == null) return null;

      return UserModel(
        id: user.uid,
        name: user.displayName ?? email.split('@').first,
        email: user.email ?? email,
        role: role,
        avatarUrl: user.photoURL,
        createdAt: user.metadata.creationTime ?? DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Sign out the current user.
  static Future<void> signOut() async {
    if (!isFirebaseAvailable) return;
    await fb.FirebaseAuth.instance.signOut();
  }

  /// Get the current Firebase user (null if not signed in or unavailable).
  static fb.User? get currentUser {
    if (!isFirebaseAvailable) return null;
    return fb.FirebaseAuth.instance.currentUser;
  }
}