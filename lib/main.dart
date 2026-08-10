import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:workmanager/workmanager.dart';
import 'package:kidconnect/app.dart';
import 'core/config/firebase_config.dart';
import 'core/services/background_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (real backend)
  await initFirebase();

  // Initialize background service (notifications + foreground service)
  await BackgroundService.init();

  // Show persistent foreground notification to keep app alive
  await BackgroundService.showForegroundNotification(
    title: 'KidConnect',
    body: 'Running in background — staying connected to your child\'s school',
  );

  // Start periodic background sync via Workmanager
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: false,
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
    // Periodic photo check — fetches latest photo and notifies
    try {
      // Re-initialize Firebase for background isolate
      await Firebase.initializeApp();
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
    } catch (_) {}
    return true;
  });
}
