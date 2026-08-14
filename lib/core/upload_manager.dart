import 'dart:async';
import 'package:flutter/services.dart';

class UploadManager {
  static const MethodChannel _channel = MethodChannel('com.example.kidconnect/upload');
  static const EventChannel _events = EventChannel('com.example.kidconnect/upload_events');

  static Future<bool> enqueueFiles(List<String> files, {String? batchId, String? remoteUrl}) async {
    final args = {'files': files, 'batchId': batchId, 'remoteUrl': remoteUrl};
    return await _channel.invokeMethod('enqueueFiles', args);
  }

  static Future<bool> startForegroundService() async {
    return await _channel.invokeMethod('startForegroundService');
  }

  static Future<List<Map<dynamic, dynamic>>> getJobs() async {
    final res = await _channel.invokeMethod('getJobs');
    return List<Map<dynamic, dynamic>>.from(res ?? []);
  }

  static Stream<Map<dynamic, dynamic>> get events => _events.receiveBroadcastStream().map((e) => Map<dynamic, dynamic>.from(e as Map));

  static Future<void> pauseJob(int id) async {
    await _channel.invokeMethod('pauseJob', {'id': id});
  }

  static Future<void> resumeJob(int id) async {
    await _channel.invokeMethod('resumeJob', {'id': id});
  }

  static Future<void> cancelJob(int id) async {
    await _channel.invokeMethod('cancelJob', {'id': id});
  }

  // Tagging notifications (start/update/stop)
  static Future<void> startTaggingNotification({String? title, String? text}) async {
    await _channel.invokeMethod('startTaggingNotification', {'title': title, 'text': text});
  }

  static Future<void> updateTaggingNotification({required int progress, String? title, String? text}) async {
    await _channel.invokeMethod('updateTaggingNotification', {'progress': progress, 'title': title, 'text': text});
  }

  static Future<void> stopTaggingNotification() async {
    await _channel.invokeMethod('stopTaggingNotification');
  }
}
