import 'package:flutter/services.dart';
import '../config/api_config.dart';

class NativeNotificationService {
  static const MethodChannel _channel = MethodChannel('com.example.flutter_app/notifications');

  static Future<void> startNativeService(int userId) async {
    if (userId <= 0) return;
    try {
      await _channel.invokeMethod('startService', {
        'userId': userId,
        'baseUrl': ApiConfig.baseUrl,
      });
      print("Native notification service started for user $userId");
    } catch (e) {
      print("Error starting native notification service: $e");
    }
  }

  static Future<void> stopNativeService() async {
    try {
      await _channel.invokeMethod('stopService');
      print("Native notification service stopped");
    } catch (e) {
      print("Error stopping native notification service: $e");
    }
  }
}
