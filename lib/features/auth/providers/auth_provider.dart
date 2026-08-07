import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/user_model.dart';
import '../../../data/mock/mock_data.dart';
import '../../../data/repositories/auth_repository.dart';

/// Auth state holding the current user and authentication status.
class AuthState {
  final UserModel? currentUser;
  final bool isAuthenticated;
  final bool isLoading;
  final String? selectedChildId;
  final List<Map<String, String>> allChildren; // [{id, name}] for child selection
  final bool usingMockData;

  const AuthState({
    this.currentUser,
    this.isAuthenticated = false,
    this.isLoading = false,
    this.selectedChildId,
    this.allChildren = const [],
    this.usingMockData = false,
  });

  AuthState copyWith({
    UserModel? currentUser,
    bool? isAuthenticated,
    bool? isLoading,
    String? selectedChildId,
    List<Map<String, String>>? allChildren,
    bool? usingMockData,
  }) {
    return AuthState(
      currentUser: currentUser ?? this.currentUser,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      selectedChildId: selectedChildId ?? this.selectedChildId,
      allChildren: allChildren ?? this.allChildren,
      usingMockData: usingMockData ?? this.usingMockData,
    );
  }

  bool get isParent => currentUser?.role == UserRole.parent;
  bool get isTeacher => currentUser?.role == UserRole.teacher;
}

/// Auth notifier managing authentication state.
/// Tries Firebase first, falls back to mock data.
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  Future<bool> login(String email, String password, UserRole role) async {
    state = state.copyWith(isLoading: true);

    // Try Firebase first
    final firebaseUser =
        await AuthRepository.signInWithEmail(email, password, role);

    if (firebaseUser != null) {
      String? defaultChildId;
      if (role == UserRole.parent) {
        final children = MockData.getChildrenForParent(firebaseUser.id);
        if (children.isNotEmpty) defaultChildId = children.first.id;
      }

      state = AuthState(
        currentUser: firebaseUser,
        isAuthenticated: true,
        isLoading: false,
        selectedChildId: defaultChildId,
        usingMockData: false,
      );
      return true;
    }

    // Fall back to mock data
    await Future.delayed(const Duration(milliseconds: 800));

    UserModel? user;
    if (role == UserRole.parent) {
      // Match by email if possible, otherwise use first parent
      user = MockData.parents.cast<UserModel?>().firstWhere(
        (p) => p!.email.toLowerCase() == email.toLowerCase(),
        orElse: () => MockData.parents.isNotEmpty ? MockData.parents.first : null,
      );
    } else {
      user = MockData.teachers.cast<UserModel?>().firstWhere(
        (t) => t!.email.toLowerCase() == email.toLowerCase(),
        orElse: () => MockData.teachers.isNotEmpty ? MockData.teachers.first : null,
      );
    }

    if (user != null) {
      String? defaultChildId;
      if (role == UserRole.parent) {
        final children = MockData.getChildrenForParent(user.id);
        if (children.isNotEmpty) defaultChildId = children.first.id;
      }

      state = AuthState(
        currentUser: user,
        isAuthenticated: true,
        isLoading: false,
        selectedChildId: defaultChildId,
        usingMockData: true,
      );
      return true;
    }

    state = state.copyWith(isLoading: false);
    return false;
  }

  Future<void> loginAsRole(UserRole role) async {
    await login('demo@kidconnect.com', 'password', role);
  }

  Future<bool> loginParentByPhone(String phone) async {
    state = state.copyWith(isLoading: true);

    // 1) Try Firestore — look up parent by phone (client-side filter, no index)
    try {
      final allParentsSnap = await FirebaseFirestore.instance
          .collection('parents')
          .get();
      var foundDoc = allParentsSnap.docs.cast<DocumentSnapshot?>().firstWhere(
            (d) => ((d!.data() as Map<String, dynamic>?)!['phone'] as String? ?? '') == phone,
            orElse: () => null,
          );
      if (foundDoc == null) {
        state = state.copyWith(isLoading: false);
        return false;
      }

      final data = foundDoc.data()! as Map<String, dynamic>;
      final parentDocId = foundDoc.id;

      // Use stable parent doc ID for email (phone-agnostic)
      final email = '$parentDocId@kidconnect.internal';

      // OTP from stored document, or fallback to computed from phone
      final storedOtp = data['otp'] as String?;
      final otp = storedOtp ?? (100000 + (phone.hashCode % 900000)).toString();
      final password = 'KC@$otp';

      // Try to sign in first (existing account)
      UserModel? firebaseUser;
      firebaseUser = await AuthRepository.signInWithEmail(email, password, UserRole.parent);

      if (firebaseUser == null) {
        // Account doesn't exist yet — create it (first login)
        final uid = await AuthRepository.createAccount(email, password);
        if (uid != null) {
          // Sign in with the newly created account
          firebaseUser = await AuthRepository.signInWithEmail(email, password, UserRole.parent);
        }
      }

      if (firebaseUser == null) {
        // Still failing? Try with the old-style phone-based email as fallback
        final oldEmail = '$phone@kidconnect.internal';
        firebaseUser = await AuthRepository.signInWithEmail(oldEmail, password, UserRole.parent);
        if (firebaseUser == null) {
          // Create with phone-based email as last resort
          final uid = await AuthRepository.createAccount(oldEmail, password);
          if (uid != null) {
            firebaseUser = await AuthRepository.signInWithEmail(oldEmail, password, UserRole.parent);
          }
        }
      }

      if (firebaseUser != null) {
        // Fetch ALL children — client-side filter, no index needed
        List<Map<String, String>> allChildren = [];
        String? firstChildId;
        try {
          final allChildrenSnap = await FirebaseFirestore.instance
              .collection('children')
              .get();
          debugPrint('🔍 loginParentByPhone: fetched ${allChildrenSnap.docs.length} total children docs');
          debugPrint('🔍 loginParentByPhone: looking for parentDocId=$parentDocId');
          for (final doc in allChildrenSnap.docs) {
            final childData = doc.data() as Map<String, dynamic>?;
            final childParentId = childData?['parentId'] as String? ?? '';
            debugPrint('🔍   child doc.id=${doc.id} name=${childData?['name']} parentId=$childParentId');
            if (childParentId == parentDocId) {
              final childName = childData?['name'] as String? ?? 'Child';
              allChildren.add({'id': doc.id, 'name': childName});
              firstChildId ??= doc.id;
            }
          }
          debugPrint('🔍 loginParentByPhone: matched ${allChildren.length} children for this parent');
        } catch (e) {
          debugPrint('🔍 loginParentByPhone: children fetch error: $e');
        }

        final userModel = UserModel(
          id: parentDocId,
          name: data['name'] as String? ?? 'Parent',
          email: email,
          role: UserRole.parent,
          phone: phone,
          status: data['status'] == 'active' ? ParentStatus.active : ParentStatus.pendingCompletion,
          createdAt: DateTime.now(),
        );

        state = AuthState(
          currentUser: userModel,
          isAuthenticated: true,
          isLoading: false,
          selectedChildId: firstChildId,
          allChildren: allChildren,
          usingMockData: false,
        );
        return true;
      }
    } catch (_) {
      // Firestore lookup failed
    }

    // 2) No fallback — phone not found in Firestore
    state = state.copyWith(isLoading: false);
    return false;
  }

  void selectChild(String childId) {
    state = state.copyWith(selectedChildId: childId);
  }

  Future<void> logout() async {
    await AuthRepository.signOut();
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authProvider).currentUser;
});

final selectedChildProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).selectedChildId;
});

final isMockDataProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).usingMockData;
});