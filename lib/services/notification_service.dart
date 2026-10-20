import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/capsule.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (kIsWeb || _initialized) return;

    tzdata.initializeTimeZones();

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _plugin.initialize(settings: settings);

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await android?.requestNotificationsPermission();

    _initialized = true;
  }

  static Future<void> schedule(Capsule capsule) async {
    if (kIsWeb) return;

    await initialize();

    final target = DateTime(
      capsule.openDate.year,
      capsule.openDate.month,
      capsule.openDate.day,
      9,
    );

    if (!target.isAfter(DateTime.now())) return;

    await _plugin.zonedSchedule(
      id: capsule.id.hashCode & 0x7fffffff,
      title: 'Your TimeCapsule is ready! 💜',
      body: '"${capsule.title}" is waiting for you.',
      // Absolute instant = now + remaining time, correct in any time zone.
      scheduledDate: tz.TZDateTime.now(tz.UTC)
          .add(target.difference(DateTime.now())),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'time_capsule_openings',
          'TimeCapsule openings',
          channelDescription: 'Reminders when your capsules are ready',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  static Future<void> cancel(Capsule capsule) async {
    if (kIsWeb) return;

    await _plugin.cancel(id: capsule.id.hashCode & 0x7fffffff);
  }
}