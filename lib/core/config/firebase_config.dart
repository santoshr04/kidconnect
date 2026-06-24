import 'package:firebase_core/firebase_core.dart';

/// Firebase configuration for kidconnect-be735.
///
/// Generated from Firebase Console → Project Settings → Your Apps.
const FirebaseOptions firebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyCR87BUAKrejb_cjFAMHvO_ta8o7PY2TCw',
  authDomain: 'kidconnect-be735.firebaseapp.com',
  projectId: 'kidconnect-be735',
  storageBucket: 'kidconnect-be735.firebasestorage.app',
  messagingSenderId: '191005492537',
  appId: '1:191005492537:android:207f2d810b7009e18594e8',
);

/// Initialize Firebase. Call before runApp().
Future<void> initFirebase() async {
  try {
    await Firebase.initializeApp(options: firebaseOptions);
  } catch (e) {
    // Firebase not configured — app runs in mock mode
    // ignore: avoid_print
    print('⚠️ Firebase init error: $e — running in MOCK mode');
  }
}