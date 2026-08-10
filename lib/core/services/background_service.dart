import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BackgroundService {
  BackgroundService._();

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
      ),
    );
  }

  static Future<void> showPhotoNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _notifications.show(
      id: DateTime.now().millisecondsSinceEpoch % 100000,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'kidconnect_photos', 'Photo Updates',
          channelDescription: 'Notifications when new photos are uploaded',
          importance: Importance.high, priority: Priority.high,
          showWhen: true, enableVibration: true, playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true, presentBadge: true, presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  static Future<void> showForegroundNotification({
    required String title,
    required String body,
  }) async {
    await _notifications.show(
      id: 1,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'kidconnect_foreground', 'KidConnect Service',
          channelDescription: 'Keeps KidConnect running in background',
          importance: Importance.low, priority: Priority.low,
          ongoing: true, autoCancel: false, showWhen: false,
        ),
      ),
    );
  }

  static Future<void> cancelForegroundNotification() async {
    await _notifications.cancel(id: 1);
  }

  static void startPhotoListener(String childId) {
    FirebaseFirestore.instance
        .collection('photos')
        .orderBy('uploadDate', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) async {
      for (final doc in snapshot.docChanges) {
        if (doc.type != DocumentChangeType.added) continue;
        final d = doc.doc.data();
        final childIds = (d?['childIds'] as List? ?? []);
        if (childIds.contains(childId)) {
          await showPhotoNotification(
            title: '📸 New Photo!',
            body: d?['caption'] as String? ?? 'New photo!',
            payload: '/parent/gallery',
          );
        }
      }
    });
  }
}