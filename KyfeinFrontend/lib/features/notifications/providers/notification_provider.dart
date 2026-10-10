import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class KyfeinNotification {
  final String title;
  final String body;
  final DateTime time;
  final Map<String, dynamic> data;

  KyfeinNotification({
    required this.title,
    required this.body,
    required this.time,
    required this.data,
  });

  factory KyfeinNotification.fromJson(Map<String, dynamic> json) {
    return KyfeinNotification(
      title: json['title'],
      body: json['body'],
      time: DateTime.parse(json['time']),
      data: json['data'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'body': body,
      'time': time.toIso8601String(),
      'data': data,
    };
  }
}

class NotificationProvider with ChangeNotifier {
  List<KyfeinNotification> _notifications = [];
  bool _hasUnread = false;

  List<KyfeinNotification> get notifications => _notifications;
  bool get hasUnread => _hasUnread;

  NotificationProvider() {
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> notifs = prefs.getStringList('notifications') ?? [];
    _notifications = notifs.map((n) => KyfeinNotification.fromJson(jsonDecode(n))).toList();
    // Check if background handler added new ones since last open
    if (_notifications.isNotEmpty) {
      _hasUnread = true; 
    }
    notifyListeners();
  }

  Future<void> addNotification({required String title, required String body, required Map<String, dynamic> data}) async {
    final notif = KyfeinNotification(title: title, body: body, time: DateTime.now(), data: data);
    _notifications.insert(0, notif);
    _hasUnread = true;
    
    // Save to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final List<String> notifs = _notifications.map((n) => jsonEncode(n.toJson())).toList();
    await prefs.setStringList('notifications', notifs);
    
    notifyListeners();
  }

  void markAsRead() {
    _hasUnread = false;
    notifyListeners();
  }

  Future<void> clearNotifications() async {
    _notifications.clear();
    _hasUnread = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('notifications');
    notifyListeners();
  }
}
