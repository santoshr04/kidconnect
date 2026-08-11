import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:workmanager/workmanager.dart';
import 'package:kidconnect/app.dart';
import 'core/config/firebase_config.dart';
import 'core/services/background_service.dart';

import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kidconnect/data/repositories/photo_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (real backend)
  await initFirebase();

  // Initialize background service (notifications + foreground service)
  await BackgroundService.init();

  // Start periodic background sync via Workmanager
  await Workmanager().initialize(
    callbackDispatcher,
  );
  await Workmanager().registerPeriodicTask(
    'kidconnect-sync',
    'kidconnectBackgroundSync',
    frequency: const Duration(minutes: 15),
    constraints: Constraints(
      networkType: NetworkType.connected,
    ),
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    const ProviderScope(
      child: KidConnectApp(),
    ),
  );
}

/// Background task entry point for Workmanager
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // Re-initialize Firebase for background isolate
      await Firebase.initializeApp();

      if (task == 'uploadPendingPhotos') {
        final prefs = await SharedPreferences.getInstance();
        final pending = prefs.getStringList('pending_uploads') ?? [];
        if (pending.isEmpty) return true;

        for (int i = 0; i < pending.length; i++) {
          try {
            final data = jsonDecode(pending[i]);
            final String path = data['path'];
            final String uploadedBy = data['uploadedBy'];
            final String localId = data['localId'];

            final file = File(path);
            if (file.existsSync()) {
              final result = await PhotoRepository.uploadPhotoWithProgress(
                file: file,
                uploadedBy: uploadedBy,
                onProgress: (a, b) {},
              );
              if (result != null) {
                // Success, remove from queue
                final currentPending = prefs.getStringList('pending_uploads') ?? [];
                currentPending.removeWhere((item) {
                  final parsed = jsonDecode(item);
                  return parsed['localId'] == localId;
                });
                await prefs.setStringList('pending_uploads', currentPending);
              }
            }
          } catch (e) {
            print('Background upload error for file: $e');
          }
        }
        return true;
      }

      // Periodic photo check — fetches latest photo and notifies
      if (task == 'kidconnectBackgroundSync') {
        final snapshot = await FirebaseFirestore.instance
            .collection('photos')
            .orderBy('uploadDate', descending: true)
            .limit(1)
            .get();
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final caption = data['caption'] as String? ?? 'New activity photo!';
          final childIds = (data['childIds'] as List<dynamic>? ?? []);
          if (childIds.isNotEmpty) {
            await BackgroundService.showPhotoNotification(
              title: '📸 New Photo for Your Child!',
              body: caption,
              payload: '/parent/gallery',
            );
          }
        }
      }
    } catch (_) {}
    return true;
  });
}
