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
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static NotificationProvider? _notificationProvider;

  static void init(NotificationProvider provider) {
    _notificationProvider = provider;
    
    // Request permission
    _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

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
  }

  static Future<void> sendTokenToBackend(String token) async {
    try {
      final fcmToken = await _firebaseMessaging.getToken();
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
