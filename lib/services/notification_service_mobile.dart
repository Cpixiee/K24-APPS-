// Mobile-only notification implementation (Android / iOS)
// This file is imported only on non-web platforms via conditional import.

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apps_k24/services/api_service.dart';
import 'dart:convert';

// Top-level function for Workmanager background task execution
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      await ApiService.init();
      final token = await ApiService.getToken();
      if (token == null || token.isEmpty) return Future.value(true);

      final notifications = await ApiService.getNotifications();
      if (notifications.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final seenIdsStr = prefs.getString('seen_notification_ids') ?? '[]';
        final List<int> seenIds = List<int>.from(jsonDecode(seenIdsStr));

        final localNotificationsPlugin = FlutterLocalNotificationsPlugin();
        const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
        const iosInit = DarwinInitializationSettings();
        await localNotificationsPlugin.initialize(
          const InitializationSettings(android: androidInit, iOS: iosInit),
        );

        bool hasNew = false;
        for (var n in notifications) {
          final id = n['id'] as int;
          if (!seenIds.contains(id)) {
            seenIds.add(id);
            hasNew = true;
            const androidDetails = AndroidNotificationDetails(
              'k24_driver_notifications',
              'K-24 Driver Notifications',
              channelDescription: 'Notifications for K-24 delivery driver tasks',
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
            );
            const iosDetails = DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            );
            await localNotificationsPlugin.show(
              id,
              n['title'] ?? 'Notifikasi Baru',
              n['message'] ?? '',
              const NotificationDetails(android: androidDetails, iOS: iosDetails),
            );
          }
        }
        if (hasNew) {
          await prefs.setString('seen_notification_ids', jsonEncode(seenIds));
        }
      }
    } catch (e) {
      debugPrint('Error in background notification task: $e');
    }
    return Future.value(true);
  });
}

class NotificationServiceImpl {
  static final _localNotificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      await _localNotificationsPlugin.initialize(
        const InitializationSettings(android: androidInit, iOS: iosInit),
      );
    } catch (e) {
      debugPrint('[NotificationService] Local notifications init error: $e');
    }

    try {
      await Workmanager().initialize(callbackDispatcher);
    } catch (e) {
      debugPrint('[NotificationService] Workmanager init error: $e');
    }
  }

  static Future<void> registerBackgroundTask() async {
    try {
      await Workmanager().registerPeriodicTask(
        'k24_driver_notification_job',
        'fetchNotificationsTask',
        frequency: const Duration(minutes: 15),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        constraints: Constraints(networkType: NetworkType.connected),
      );
    } catch (e) {
      debugPrint('Failed to register Workmanager task: $e');
    }
  }

  static Future<void> cancelBackgroundTask() async {
    try {
      await Workmanager().cancelAll();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('seen_notification_ids');
    } catch (e) {
      debugPrint('Failed to cancel Workmanager tasks: $e');
    }
  }

  static Future<void> showNotifications(
    List<dynamic> notifications,
    List<int> seenIds,
  ) async {
    for (var n in notifications) {
      final id = n['id'] as int;
      if (!seenIds.contains(id)) {
        const androidDetails = AndroidNotificationDetails(
          'k24_driver_notifications',
          'K-24 Driver Notifications',
          channelDescription: 'Notifications for K-24 delivery driver tasks',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        );
        const iosDetails = DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );
        await _localNotificationsPlugin.show(
          id,
          n['title'] ?? 'Notifikasi Baru',
          n['message'] ?? '',
          const NotificationDetails(android: androidDetails, iOS: iosDetails),
        );
      }
    }
  }
}
