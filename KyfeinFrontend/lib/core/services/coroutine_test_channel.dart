import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class CoroutineTestChannel {
  static const _method =
      MethodChannel('com.example.kyfein_frontend/coroutine_test');
  static const _events =
      EventChannel('com.example.kyfein_frontend/coroutine_progress');

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Stream<Map<String, dynamic>> get progressStream {
    return _events.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return event.map((k, v) => MapEntry(k.toString(), v));
      }
      return <String, dynamic>{};
    });
  }

  static Future<void> startStressTest() async {
    await _method.invokeMethod('startStressTest');
  }

  static Future<void> cancelStressTest() async {
    await _method.invokeMethod('cancelStressTest');
  }
}
