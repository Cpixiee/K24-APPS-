import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apps_k24/services/api_service.dart';
import 'dart:convert';

// Only import workmanager & local notifications on non-web platforms
import 'notification_service_mobile.dart' if (dart.library.js) 'notification_service_web.dart';

class NotificationService {
  static Future<void> init() async {
    if (kIsWeb) {
      debugPrint('[NotificationService] Running on web — skipping mobile notification init.');
      return;
    }
    await NotificationServiceImpl.init();
  }

  static Future<void> registerBackgroundTask() async {
    if (kIsWeb) return;
    await NotificationServiceImpl.registerBackgroundTask();
  }

  static Future<void> cancelBackgroundTask() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('seen_notification_ids');
      return;
    }
    await NotificationServiceImpl.cancelBackgroundTask();
  }

  // Check notifications by calling API (works on web too — just no push)
  static Future<void> checkNotificationsNow() async {
    try {
      final token = await ApiService.getToken();
      if (token == null || token.isEmpty) return;

      final notifications = await ApiService.getNotifications();
      if (notifications.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final seenIdsStr = prefs.getString('seen_notification_ids') ?? '[]';
      final List<int> seenIds = List<int>.from(jsonDecode(seenIdsStr));

      bool hasNew = false;
      for (var n in notifications) {
        final id = n['id'] as int;
        if (!seenIds.contains(id)) {
          seenIds.add(id);
          hasNew = true;
          debugPrint('[NotificationService] New notification: ${n['title']}');
        }
      }

      if (hasNew) {
        await prefs.setString('seen_notification_ids', jsonEncode(seenIds));
        if (!kIsWeb) {
          await NotificationServiceImpl.showNotifications(notifications, seenIds);
        }
      }
    } catch (e) {
      debugPrint('[NotificationService] Error checking notifications: $e');
    }
  }
}
