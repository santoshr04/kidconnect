import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/user_model.dart';
import '../../../data/mock/mock_data.dart';
import '../../../data/repositories/auth_repository.dart';

/// Auth state holding the current user and authentication status.
class AuthState {
  final UserModel? currentUser;
  final bool isAuthenticated;
  final bool isLoading;
  final String? selectedChildId;
  final bool usingMockData;

  const AuthState({
    this.currentUser,
    this.isAuthenticated = false,
    this.isLoading = false,
    this.selectedChildId,
    this.usingMockData = false,
  });

  AuthState copyWith({
    UserModel? currentUser,
    bool? isAuthenticated,
    bool? isLoading,
    String? selectedChildId,
    bool? usingMockData,
  }) {
    return AuthState(
      currentUser: currentUser ?? this.currentUser,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      selectedChildId: selectedChildId ?? this.selectedChildId,
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

    // First try to match the phone, get the parent email, then Firebase Auth
    final parent = MockData.getParentByPhone(phone);

    if (parent == null) {
      state = state.copyWith(isLoading: false);
      return false;
    }

    // Try Firebase Auth with parent credentials
    final firebaseUser = await AuthRepository.signInWithEmail(
      parent.email,
      'password123',
      UserRole.parent,
    );

    // Look up children using mock parent ID (Firebase UID won't match mock IDs)
    final children = MockData.getChildrenForParent(parent.id);
    final defaultChildId = children.isNotEmpty ? children.first.id : null;

    if (firebaseUser != null) {
      state = AuthState(
        currentUser: firebaseUser,
        isAuthenticated: true,
        isLoading: false,
        selectedChildId: defaultChildId,
        usingMockData: false,
      );
      return true;
    }

    // Firebase Auth failed, fall back to mock (Firestore won't work)
    await Future.delayed(const Duration(milliseconds: 800));

    state = AuthState(
      currentUser: parent,
      isAuthenticated: true,
      isLoading: false,
      selectedChildId: defaultChildId,
      usingMockData: true,
    );
    return true;
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