import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../models/user_model.dart';

/// Firebase Auth repository.
class AuthRepository {
  static bool get isFirebaseAvailable {
    try {
      fb.FirebaseAuth.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

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

  static Future<void> signOut() async {
    if (!isFirebaseAvailable) return;
    await fb.FirebaseAuth.instance.signOut();
  }

  /// Creates a new Firebase Auth account for a parent registered by a teacher.
  /// Returns the created user's UID, or null on failure.
  static Future<String?> createAccount(String email, String password) async {
    if (!isFirebaseAvailable) return null;

    try {
      final credential = await fb.FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      return credential.user?.uid;
    } catch (_) {
      return null;
    }
  }

  static fb.User? get currentUser {
    if (!isFirebaseAvailable) return null;
    return fb.FirebaseAuth.instance.currentUser;
  }
}
