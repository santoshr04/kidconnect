import 'package:firebase_core/firebase_core.dart';

/// Firebase configuration for snappixai.
const FirebaseOptions firebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyC5xn6suVXFJltk_se62adVfLhpMC8E7bo',
  authDomain: 'snappixai.firebaseapp.com',
  projectId: 'snappixai',
  storageBucket: 'snappixai.firebasestorage.app',
  messagingSenderId: '387553660752',
  appId: '1:387553660752:android:226ed71114ab0fd654a655',
);

Future<void> initFirebase() async {
  await Firebase.initializeApp(options: firebaseOptions);
}