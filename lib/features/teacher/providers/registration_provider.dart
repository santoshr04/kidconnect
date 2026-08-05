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

  /// If set, we're updating an existing parent/child instead of creating new ones.
  String? _editingParentId;
  List<String> _editingChildIds = [];

  bool get isEditMode => _editingParentId != null;

  /// Switches to edit mode for an existing family.
  void setEditMode(String parentId, List<String> childIds) {
    _editingParentId = parentId;
    _editingChildIds = childIds;
  }

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
    _editingParentId = null;
    _editingChildIds = [];
    state = RegistrationState(children: [StudentEntry()]);
  }

  /// Validates the form and returns an error message or null if valid.
  String? validate() {
    if (state.parentName.trim().isEmpty) return 'Parent name is required';
    if (state.mobileNumber.trim().isEmpty) return 'Mobile number is required';
    if (state.mobileNumber.trim().length < 10) return 'Mobile number must be at least 10 digits';
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
      final phoneDigits = state.mobileNumber.replaceAll(RegExp(r'\D'), '');

      if (_editingParentId != null) {
        // ── EDIT MODE: Update existing records ──
        final parentId = _editingParentId!;

        await FirebaseFirestore.instance.collection('parents').doc(parentId).update({
          'name': state.parentName,
          'phone': phoneDigits,
          'alternatePhone': state.alternateMobile.replaceAll(RegExp(r'\D'), ''),
        });

        for (int i = 0; i < state.children.length; i++) {
          final child = state.children[i];
          final childId = i < _editingChildIds.length
              ? _editingChildIds[i]
              : 'child_${parentId}_$i';
          await _updateChild(childId, child);
        }

        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        debugPrint('✏️ FAMILY UPDATED');
        debugPrint('   Parent : ${state.parentName}');
        debugPrint('   Phone  : $phoneDigits');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

        _editingParentId = null;
        _editingChildIds = [];
      } else {
        // ── CREATE MODE: New family ──
        final otp = (100000 + (phoneDigits.hashCode % 900000)).toString();
        final email = '$phoneDigits@kidconnect.internal';
        final password = 'KC@$otp';

        final uid = await AuthRepository.createAccount(email, password);
        if (uid == null) throw Exception('Failed to create Firebase Auth account');

        try {
          final firebaseUser = fb.FirebaseAuth.instance.currentUser;
          if (firebaseUser != null) {
            await firebaseUser.updateDisplayName(state.parentName);
          }
        } catch (_) {}

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

        for (int i = 0; i < state.children.length; i++) {
          final child = state.children[i];
          await _registerChild(uid, child, i);
        }

        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        debugPrint('📱 NEW PARENT REGISTERED');
        debugPrint('   Name   : ${state.parentName}');
        debugPrint('   Phone  : $phoneDigits');
        debugPrint('   Email  : $email');
        debugPrint('   OTP    : $otp');
        debugPrint('   Children: ${state.children.length}');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      }

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

    if (child.photoFile != null) {
      try {
        final bytes = await child.photoFile!.readAsBytes();
        await InsightFaceService.enrollChild(childId: childId, name: child.name, faceBytes: bytes);
        await FirebaseFirestore.instance.collection('children').doc(childId).update({
          'hasFaceProfile': true,
          'enrolledFaceCount': 1,
        });
      } catch (e) {
        debugPrint('⚠️ Face enrollment failed for $childId (non-critical): $e');
      }
    }
  }

  /// Updates an existing child document in Firestore (edit mode).
  Future<void> _updateChild(String childId, StudentEntry child) async {
    final updates = <String, dynamic>{
      'name': child.name,
      'classId': child.className.toLowerCase(),
      'className': child.className,
      'section': child.section,
    };

    if (child.photoFile != null) {
      try {
        final ref = FirebaseStorage.instance
            .ref()
            .child('children/$childId/enrollment/photo_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(child.photoFile!);
        updates['photoUrl'] = await ref.getDownloadURL();
      } catch (e) {
        debugPrint('⚠️ Failed to upload photo for $childId: $e');
      }
    }

    await FirebaseFirestore.instance.collection('children').doc(childId).update(updates);

    if (child.photoFile != null) {
      try {
        final bytes = await child.photoFile!.readAsBytes();
        await InsightFaceService.enrollChild(childId: childId, name: child.name, faceBytes: bytes);
        await FirebaseFirestore.instance.collection('children').doc(childId).update({
          'hasFaceProfile': true,
          'enrolledFaceCount': 1,
        });
      } catch (e) {
        debugPrint('⚠️ Face re-enrollment failed for $childId (non-critical): $e');
      }
    }
  }

  /// Populates the form with existing data for editing.
  void loadExisting({
    required String parentName,
    required String mobileNumber,
    required String alternateMobile,
    required List<Map<String, dynamic>> children,
  }) {
    final studentEntries = children.map((c) => StudentEntry(
      name: c['name'] as String? ?? '',
      className: c['className'] as String? ?? 'Nursery',
      section: c['section'] as String?,
    )).toList();

    if (studentEntries.isEmpty) {
      studentEntries.add(StudentEntry());
    }

    state = RegistrationState(
      parentName: parentName,
      mobileNumber: mobileNumber,
      alternateMobile: alternateMobile,
      children: studentEntries,
    );
  }
}

/// Riverpod provider for the registration state.
final registrationProvider =
    StateNotifierProvider<RegistrationProvider, RegistrationState>(
  (ref) => RegistrationProvider(),
);