import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/user_model.dart';
import '../../../data/mock/mock_data.dart';

/// Auth state holding the current user and authentication status
class AuthState {
  final UserModel? currentUser;
  final bool isAuthenticated;
  final bool isLoading;
  final String? selectedChildId;

  const AuthState({
    this.currentUser,
    this.isAuthenticated = false,
    this.isLoading = false,
    this.selectedChildId,
  });

  AuthState copyWith({
    UserModel? currentUser,
    bool? isAuthenticated,
    bool? isLoading,
    String? selectedChildId,
  }) {
    return AuthState(
      currentUser: currentUser ?? this.currentUser,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      selectedChildId: selectedChildId ?? this.selectedChildId,
    );
  }

  bool get isParent => currentUser?.role == UserRole.parent;
  bool get isTeacher => currentUser?.role == UserRole.teacher;
}

/// Auth notifier managing authentication state
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  /// Login with email and password (mock)
  Future<bool> login(String email, String password, UserRole role) async {
    state = state.copyWith(isLoading: true);

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));

    // Mock authentication — find user by role
    UserModel? user;
    if (role == UserRole.parent) {
      user = MockData.parents.isNotEmpty ? MockData.parents.first : null;
    } else {
      user = MockData.teachers.isNotEmpty ? MockData.teachers.first : null;
    }

    if (user != null) {
      // Set default selected child for parents
      String? defaultChildId;
      if (role == UserRole.parent) {
        final children = MockData.getChildrenForParent(user.id);
        if (children.isNotEmpty) {
          defaultChildId = children.first.id;
        }
      }

      state = AuthState(
        currentUser: user,
        isAuthenticated: true,
        isLoading: false,
        selectedChildId: defaultChildId,
      );
      return true;
    }

    state = state.copyWith(isLoading: false);
    return false;
  }

  /// Quick login as a specific role (for demo)
  Future<void> loginAsRole(UserRole role) async {
    await login('demo@kidconnect.com', 'password', role);
  }

  /// Select a different child (parent mode)
  void selectChild(String childId) {
    state = state.copyWith(selectedChildId: childId);
  }

  /// Logout
  void logout() {
    state = const AuthState();
  }
}

/// Auth state provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

/// Convenience provider for current user
final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authProvider).currentUser;
});

/// Convenience provider for selected child
final selectedChildProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).selectedChildId;
});
