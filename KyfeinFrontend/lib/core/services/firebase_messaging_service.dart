import 'package:flutter/foundation.dart'; // Ditambahkan untuk pengecekan kIsWeb
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_endpoints.dart';
import '../../features/notifications/providers/notification_provider.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background message
  developer.log("Handling a background message: ${message.messageId}", name: 'FCM');
  // We cannot use providers here easily as it's an isolate, but we can save to SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final List<String> notifications = prefs.getStringList('notifications') ?? [];
  notifications.insert(0, jsonEncode({
    'title': message.notification?.title ?? 'Notification',
    'body': message.notification?.body ?? '',
    'time': DateTime.now().toIso8601String(),
    'data': message.data,
  }));
  await prefs.setStringList('notifications', notifications);
}

class FirebaseMessagingService {
  static NotificationProvider? _notificationProvider;

  static void init(NotificationProvider provider) {
    _notificationProvider = provider;

    // Jika berjalan di platform Web dan Firebase belum terkonfigurasi, lewati aman tanpa crash
    try {
      final FirebaseMessaging firebaseMessaging = FirebaseMessaging.instance;

      // Request permission
      firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // Register background handler (Hanya untuk non-web)
      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      }

      // Foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (message.notification != null) {
          _notificationProvider?.addNotification(
            title: message.notification!.title ?? 'Notification',
            body: message.notification!.body ?? '',
            data: message.data,
          );
        }
      });
    } catch (e) {
      developer.log('Firebase Messaging di-bypass (Web/Belum terkonfigurasi): $e', name: 'FCM');
    }
  }

  static Future<void> sendTokenToBackend(String token) async {
    try {
      final FirebaseMessaging firebaseMessaging = FirebaseMessaging.instance;
      final fcmToken = await firebaseMessaging.getToken();
      if (fcmToken != null) {
        final response = await http.post(
          Uri.parse(ApiEndpoints.fcmToken),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token'
          },
          body: jsonEncode({'fcm_token': fcmToken}),
        );
        developer.log('FCM Token sent to backend: ${response.statusCode}', name: 'FCM');
      }
    } catch (e) {
      developer.log('Failed to send FCM token: $e', name: 'FCM');
    }
  }
}