import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'api_service.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final notificationService = NotificationService();
      await notificationService.init();

      final sysTemp = Directory.systemTemp;
      final sessionFile = File('${sysTemp.path}/library_app_user_session.json');
      if (await sessionFile.exists()) {
        final content = await sessionFile.readAsString();
        if (content.isNotEmpty) {
          final userMap = jsonDecode(content);
          final int userId = userMap['id'] is int ? userMap['id'] : int.tryParse(userMap['id'].toString()) ?? 0;
          if (userId > 0) {
            final data = await ApiService.getStudentDashboard(userId);
            if (data['success'] == true && data['notifications'] != null) {
              await notificationService.processNotifications(data['notifications'] as List<dynamic>);
            }
          }
        }
      }
    } catch (e) {
      print("Workmanager background notification error: $e");
    }
    return Future.value(true);
  });
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  File get _shownNotifsFile {
    final sysTemp = Directory.systemTemp;
    return File('${sysTemp.path}/library_shown_notif_ids.json');
  }

  Future<Set<int>> _loadShownNotifIds() async {
    try {
      final file = _shownNotifsFile;
      if (await file.exists()) {
        final text = await file.readAsString();
        if (text.isNotEmpty) {
          final List<dynamic> list = jsonDecode(text);
          return list.map((e) => int.tryParse(e.toString()) ?? 0).where((id) => id > 0).toSet();
        }
      }
    } catch (e) {
      print("Load shown notif ids error: $e");
    }
    return {};
  }

  Future<void> _saveShownNotifIds(Set<int> ids) async {
    try {
      final file = _shownNotifsFile;
      await file.writeAsString(jsonEncode(ids.toList()));
    } catch (e) {
      print("Save shown notif ids error: $e");
    }
  }

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(initializationSettings);

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> processNotifications(List<dynamic> notifs) async {
    final shownIds = await _loadShownNotifIds();
    bool updated = false;

    for (var n in notifs) {
      final int notifId = n['id'] is int ? n['id'] : int.tryParse(n['id'].toString()) ?? 0;
      final String rawTitle = n['title'] ?? 'New Notice';
      final String rawMsg = n['message'] ?? n['content'] ?? '';
      final String title = rawTitle.isNotEmpty ? rawTitle : 'New Notice';
      final String body = rawMsg.isNotEmpty ? rawMsg : title;
      final bool isRead = n['is_read'] == 1 || n['is_read'] == true;

      if (!isRead && notifId > 0 && !shownIds.contains(notifId)) {
        shownIds.add(notifId);
        updated = true;

        await showNotification(
          id: notifId,
          title: title,
          body: body,
        );
      }
    }

    if (updated) {
      await _saveShownNotifIds(shownIds);
    }
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'library_notifs_channel',
      'Library Announcements',
      channelDescription: 'Notifications for library notices and seat allotments',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
      enableVibration: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
    );
  }
}
