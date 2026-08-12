import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';
import 'package:snappix_ai/app.dart';
import 'core/config/firebase_config.dart';
import 'core/services/background_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await initFirebase();

  // Initialize notifications
  await BackgroundService.init();

  // Start periodic background upload retry
  await Workmanager().initialize(
    bgDispatcher,
    isInDebugMode: false,
  );
  await Workmanager().registerPeriodicTask(
    'snappixUploadRetry',
    'snappixUploadRetry',
    frequency: const Duration(minutes: 15),
    constraints: Constraints(
      networkType: NetworkType.connected,
    ),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
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
      child: SnapPixAiApp(),
    ),
  );
}

@pragma('vm:entry-point')
void bgDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    await BackgroundService.retryPendingUploads();
    return Future.value(true);
  });
}