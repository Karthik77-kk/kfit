import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);

    // Request permission (Android 13+)
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> scheduleWaterReminders() async {
    // Cancel existing water reminders
    for (int i = 10; i <= 20; i++) {
      await _plugin.cancel(i);
    }

    const androidDetails = AndroidNotificationDetails(
      'water_channel',
      'Water Reminders',
      channelDescription: 'Reminds you to drink water',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    final messages = [
      '💧 Time to drink water! You got this.',
      '💧 Stay hydrated! 2.5L is the goal today.',
      '💧 Water check! Have you had your glass?',
      '💧 Hydration reminder — keep that water flowing!',
      '💧 Evening water reminder. Don\'t let yourself get dehydrated!',
    ];

    // 9am, 11am, 1pm, 3pm, 6pm
    final hours = [9, 11, 13, 15, 18];
    for (int i = 0; i < hours.length; i++) {
      final now = tz.TZDateTime.now(tz.local);
      var scheduled = tz.TZDateTime(
          tz.local, now.year, now.month, now.day, hours[i]);
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
      await _plugin.zonedSchedule(
        10 + i,
        'Karthik Fitness 💪',
        messages[i],
        scheduled,
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> scheduleSupplementReminders() async {
    await _plugin.cancel(1);
    await _plugin.cancel(2);

    const androidDetails = AndroidNotificationDetails(
      'supp_channel',
      'Supplement Reminders',
      channelDescription: 'Daily supplement reminders',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    final now = tz.TZDateTime.now(tz.local);

    // Multivitamin — 8:30 AM
    var mv = tz.TZDateTime(tz.local, now.year, now.month, now.day, 8, 30);
    if (mv.isBefore(now)) mv = mv.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      1,
      'Supplement Reminder 🌿',
      'Take your MuscleBlaze Multivitamin after breakfast!',
      mv,
      const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    // Creatine — 10 AM (anytime daily)
    var cr = tz.TZDateTime(tz.local, now.year, now.month, now.day, 10, 0);
    if (cr.isBefore(now)) cr = cr.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      2,
      'Creatine Time 💊',
      'Don\'t forget 3–5g Creatine today — can mix with water or whey!',
      cr,
      const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> showWorkoutReminder() async {
    const androidDetails = AndroidNotificationDetails(
      'workout_channel',
      'Workout Reminders',
      channelDescription: 'Workout day reminders',
      importance: Importance.high,
      priority: Priority.high,
    );
    await _plugin.show(
      99,
      'Workout time! 🏋️',
      'You haven\'t logged a workout today. Let\'s get it done!',
      const NotificationDetails(android: androidDetails),
    );
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
