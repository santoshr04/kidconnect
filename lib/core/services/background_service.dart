import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/repositories/photo_repository.dart';

class BackgroundService {
  BackgroundService._();

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // ─── INIT ────────────────────────────────────────────────
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
    try {
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
    } catch (_) {}
  }

  // ─── PHOTO NOTIFICATION ──────────────────────────────────
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
          'snappix_photos', 'Photo Updates',
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

  // ─── UPLOAD PROGRESS (persistent notification with bar) ────
  static Future<void> showUploadProgress({
    required int completed,
    required int total,
  }) async {
    final pct = total > 0 ? ((completed / total) * 100).round() : 0;
    await _notifications.show(
      id: 100,
      title: '📤 Uploading ($pct%)',
      body: '$completed of $total photos',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'snappix_upload', 'Upload Progress',
          channelDescription: 'Upload progress',
          importance: Importance.low, priority: Priority.low,
          ongoing: true, autoCancel: false, showWhen: true,
          onlyAlertOnce: true,
          showProgress: true,
          maxProgress: total,
          progress: completed,
          indeterminate: false,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: false, presentBadge: true, presentSound: false,
        ),
      ),
    );
  }

  static Future<void> cancelUploadProgress() async {
    await _notifications.cancel(id: 100);
  }

  // ─── TAGGING PROGRESS ────────────────────────────────────
  static Future<void> showTaggingProgress({
    required int completed,
    required int total,
  }) async {
    final pct = total > 0 ? ((completed / total) * 100).round() : 0;
    await _notifications.show(
      id: 200,
      title: '🏷️ AI Tagging ($pct%)',
      body: '$completed of $total photos',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'snappix_tag', 'AI Tagging',
          channelDescription: 'AI tagging progress',
          importance: Importance.low, priority: Priority.low,
          ongoing: true, autoCancel: false, showWhen: true,
          onlyAlertOnce: true,
          showProgress: true,
          maxProgress: total,
          progress: completed,
          indeterminate: false,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: false, presentBadge: true, presentSound: false,
        ),
      ),
    );
  }

  static Future<void> cancelTaggingProgress() async {
    await _notifications.cancel(id: 200);
  }

  // ─── COMPLETION ───────────────────────────────────────────
  static Future<void> showUploadComplete({required int count}) async {
    await _notifications.show(
      id: DateTime.now().millisecondsSinceEpoch % 100000 + 500,
      title: '✅ Upload Complete',
      body: '$count photo${count != 1 ? 's' : ''} uploaded',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'snappix_photos', 'Photo Updates',
          channelDescription: 'Upload completion',
          importance: Importance.high, priority: Priority.high,
          showWhen: true, enableVibration: true, playSound: true,
          autoCancel: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true, presentBadge: true, presentSound: true,
        ),
      ),
    );
  }

  // ─── BACKGROUND RETRY (WorkManager) ──────────────────────
  @pragma('vm:entry-point')
  static Future<bool> retryPendingUploads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getStringList('pending_uploads') ?? [];
      if (pending.isEmpty) return true;

      final remaining = <String>[];
      int retried = 0;
      for (final item in pending) {
        try {
          final data = jsonDecode(item) as Map<String, dynamic>;
          final path = data['path'] as String?;
          final uploadedBy = data['uploadedBy'] as String? ?? 'unknown';

          // Skip if file no longer exists on device
          if (path == null || !File(path).existsSync()) continue;

          final result = await PhotoRepository.uploadPhotoWithProgress(
            file: File(path),
            uploadedBy: uploadedBy,
            onProgress: (_, __) {},
          );
          if (result != null) {
            retried++;
          } else {
            remaining.add(item);
          }
        } catch (_) {
          remaining.add(item);
        }
      }
      await prefs.setStringList('pending_uploads', remaining);
      if (retried > 0) {
        await showUploadComplete(count: retried);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─── FIREBASE STORAGE PHOTO LISTENER ──────────────────────
  static StreamSubscription<QuerySnapshot>? _photoListener;

  static void startPhotoListener(String childId) {
    _photoListener?.cancel();
    _photoListener = FirebaseFirestore.instance
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

  static void stopPhotoListener() {
    _photoListener?.cancel();
    _photoListener = null;
  }
}