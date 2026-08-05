import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../../../data/repositories/auth_repository.dart';
import '../../../core/services/insight_face_service.dart';

/// Represents a single child entry in the registration form.
class StudentEntry {
  String name;
  String className; // Playgroup, Nursery, LKG, UKG
  String? section;
  File? photoFile;

  StudentEntry({
    this.name = '',
    this.className = 'Nursery',
    this.section,
    this.photoFile,
  });

  bool get isValid => name.trim().isNotEmpty && className.isNotEmpty && photoFile != null;
}

/// Registration form state.
class RegistrationState {
  final String parentName;
  final String mobileNumber;
  final String alternateMobile;
  final List<StudentEntry> children;
  final bool isSubmitting;
  final String? errorMessage;
  final bool isSuccess;

  const RegistrationState({
    this.parentName = '',
    this.mobileNumber = '',
    this.alternateMobile = '',
    this.children = const [],
    this.isSubmitting = false,
    this.errorMessage,
    this.isSuccess = false,
  });

  RegistrationState copyWith({
    String? parentName,
    String? mobileNumber,
    String? alternateMobile,
    List<StudentEntry>? children,
    bool? isSubmitting,
    String? errorMessage,
    bool? isSuccess,
  }) {
    return RegistrationState(
      parentName: parentName ?? this.parentName,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      alternateMobile: alternateMobile ?? this.alternateMobile,
      children: children ?? this.children,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

/// Class options for preschool.
const List<String> classOptions = ['Playgroup', 'Nursery', 'LKG', 'UKG'];
const List<String> sectionOptions = ['A', 'B', 'C', 'D'];

/// Provider that manages the student registration form and submission.
class RegistrationProvider extends StateNotifier<RegistrationState> {
  RegistrationProvider() : super(RegistrationState(children: [StudentEntry()]));

  void setParentName(String value) {
    state = state.copyWith(parentName: value.trim());
  }

  void setMobileNumber(String value) {
    state = state.copyWith(mobileNumber: value.trim());
  }

  void setAlternateMobile(String value) {
    state = state.copyWith(alternateMobile: value.trim());
  }

  void updateChild(int index, StudentEntry entry) {
    final updated = List<StudentEntry>.from(state.children);
    if (index >= 0 && index < updated.length) {
      updated[index] = entry;
      state = state.copyWith(children: updated);
    }
  }

  void setChildName(int index, String value) {
    final updated = List<StudentEntry>.from(state.children);
    if (index >= 0 && index < updated.length) {
      updated[index].name = value.trim();
      state = state.copyWith(children: updated);
    }
  }

  void setChildClass(int index, String className) {
    final updated = List<StudentEntry>.from(state.children);
    if (index >= 0 && index < updated.length) {
      updated[index].className = className;
      state = state.copyWith(children: updated);
    }
  }

  void setChildSection(int index, String? section) {
    final updated = List<StudentEntry>.from(state.children);
    if (index >= 0 && index < updated.length) {
      updated[index].section = section;
      state = state.copyWith(children: updated);
    }
  }

  void setChildPhoto(int index, File? file) {
    final updated = List<StudentEntry>.from(state.children);
    if (index >= 0 && index < updated.length) {
      updated[index].photoFile = file;
      state = state.copyWith(children: updated);
    }
  }

  void addChild() {
    final updated = List<StudentEntry>.from(state.children);
    updated.add(StudentEntry());
    state = state.copyWith(children: updated);
  }

  void removeChild(int index) {
    if (state.children.length <= 1) return;
    final updated = List<StudentEntry>.from(state.children);
    updated.removeAt(index);
    state = state.copyWith(children: updated);
  }

  void clearForm() {
    state = RegistrationState(children: [StudentEntry()]);
  }

  /// Validates the form and returns an error message or null if valid.
  String? validate() {
    if (state.parentName.trim().isEmpty) return 'Parent name is required';
    if (state.mobileNumber.trim().isEmpty) return 'Mobile number is required';
    if (state.mobileNumber.trim().length < 10) return 'Mobile number must be at least 10 digits';

    for (int i = 0; i < state.children.length; i++) {
      final c = state.children[i];
      final label = state.children.length > 1 ? 'Child ${i + 1}' : 'Child';
      if (c.name.trim().isEmpty) return '$label name is required';
      if (c.photoFile == null) return '$label photo is required';
    }

    return null;
  }

  /// Registers the parent and all children.
  /// Returns true on success, false on failure (with errorMessage set).
  Future<bool> register() async {
    final error = validate();
    if (error != null) {
      state = state.copyWith(errorMessage: error);
      return false;
    }

    state = state.copyWith(isSubmitting: true, errorMessage: null, isSuccess: false);

    try {
      // 1. Generate a secure random password for the parent account
      final phoneDigits = state.mobileNumber.replaceAll(RegExp(r'\D'), '');
      final otp = (100000 + (phoneDigits.hashCode % 900000)).toString();
      final email = '$phoneDigits@kidconnect.internal';
      final password = 'KC@$otp';

      // 2. Create Firebase Auth account
      final uid = await AuthRepository.createAccount(email, password);
      if (uid == null) throw Exception('Failed to create Firebase Auth account');

      // Also set display name on the Firebase Auth user
      try {
        final firebaseUser = fb.FirebaseAuth.instance.currentUser;
        if (firebaseUser != null) {
          await firebaseUser.updateDisplayName(state.parentName);
        }
      } catch (_) {
        // Non-critical — continue even if display name update fails
      }

      // 3. Save parent to Firestore
      await FirebaseFirestore.instance.collection('parents').doc(uid).set({
        'name': state.parentName,
        'phone': phoneDigits,
        'alternatePhone': state.alternateMobile.replaceAll(RegExp(r'\D'), ''),
        'email': email,
        'status': 'pending_completion',
        'createdBy': fb.FirebaseAuth.instance.currentUser?.uid ?? 'teacher',
        'createdAt': FieldValue.serverTimestamp(),
        'role': 'parent',
      });

      // 4. For each child: upload photo, save to Firestore, trigger face enrollment
      for (int i = 0; i < state.children.length; i++) {
        final child = state.children[i];
        await _registerChild(uid, child, i);
      }

      // 5. Log OTP to console (SMS integration placeholder)
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📱 NEW PARENT REGISTERED');
      debugPrint('   Name   : ${state.parentName}');
      debugPrint('   Phone  : $phoneDigits');
      debugPrint('   Email  : $email');
      debugPrint('   OTP    : $otp');
      debugPrint('   Children: ${state.children.length}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      state = state.copyWith(isSubmitting: false, isSuccess: true);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Registration failed: ${e.toString().replaceFirst('Exception: ', '')}',
      );
      return false;
    }
  }

  Future<void> _registerChild(String parentId, StudentEntry child, int index) async {
    final classId = child.className.toLowerCase();
    final childId = 'child_${parentId}_$index';

    // Upload photo to Firebase Storage
    String? photoUrl;
    if (child.photoFile != null) {
      try {
        final ref = FirebaseStorage.instance
            .ref()
            .child('children/$childId/enrollment/photo_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(child.photoFile!);
        photoUrl = await ref.getDownloadURL();
      } catch (e) {
        debugPrint('⚠️ Failed to upload photo for $childId: $e');
      }
    }

    // Save child to Firestore
    await FirebaseFirestore.instance.collection('children').doc(childId).set({
      'name': child.name,
      'classId': classId,
      'className': child.className,
      'section': child.section,
      'parentId': parentId,
      'photoUrl': photoUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'hasFaceProfile': false,
      'enrolledFaceCount': 0,
    });

    // Trigger face enrollment via InsightFace (non-blocking)
    if (child.photoFile != null) {
      try {
        final bytes = await child.photoFile!.readAsBytes();
        await InsightFaceService.enrollChild(
          childId: childId,
          name: child.name,
          faceBytes: bytes,
        );
        // Update face profile status
        await FirebaseFirestore.instance.collection('children').doc(childId).update({
          'hasFaceProfile': true,
          'enrolledFaceCount': 1,
        });
      } catch (e) {
        debugPrint('⚠️ Face enrollment failed for $childId (non-critical): $e');
        // Non-critical — parent can re-enroll later
      }
    }
  }
}

/// Riverpod provider for the registration state.
final registrationProvider =
    StateNotifierProvider<RegistrationProvider, RegistrationState>(
  (ref) => RegistrationProvider(),
);