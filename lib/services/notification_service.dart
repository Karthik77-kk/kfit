import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // ── IDs ───────────────────────────────────────────────────────────────────
  static const int _morningId = 0;
  static const int _multivitaminId = 1;
  static const int _creatineId = 2;
  // Water reminders: IDs 10–14

  // ── Motivational quotes ───────────────────────────────────────────────────
  static const List<String> _quotes = [
    'Every rep counts. Every meal matters. Stay consistent. 💪',
    'Fat loss is a marathon, not a sprint. Trust the process. 🏃',
    'You are one workout away from a better mood. 🎯',
    'Progress, not perfection. Log your meals today. 📊',
    'Creatine taken? Protein hit? Let\'s make today count! ⚡',
    'Your future self will thank you for today\'s choices. 🙌',
    'Small daily improvements lead to massive results. 🔥',
    'The only bad workout is the one that didn\'t happen. 🏋️',
  ];

  // ── Initialization ────────────────────────────────────────────────────────

  Future<void> initialize() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);
  }

  /// Request Android 13+ notification permission.
  /// Returns true if granted (or already granted on older Android).
  Future<bool> requestPermission() async {
    try {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      return granted ?? true;
    } catch (_) {
      return false;
    }
  }

  // ── Morning Summary (8 AM daily) ─────────────────────────────────────────

  String _getDailyQuote() {
    final dayOfYear =
        DateTime.now().difference(DateTime(DateTime.now().year)).inDays;
    return _quotes[dayOfYear % _quotes.length];
  }

  String _getTodayWorkoutHint() {
    final weekday = DateTime.now().weekday; // 1=Mon … 7=Sun
    if (weekday == 7) return '🛌 Rest day — recovery is part of the plan.';
    if (weekday == 1 || weekday == 3 || weekday == 5) {
      return '💪 Workout A today: Push-ups · Squats · Bicep Curls';
    }
    return '🏋️ Workout B today: Shoulder Press · Rows · Lat Pulldown';
  }

  Future<void> scheduleMorningSummary() async {
    try {
      await _plugin.cancel(_morningId);

      final now = tz.TZDateTime.now(tz.local);
      var scheduled = tz.TZDateTime(
          tz.local, now.year, now.month, now.day, 8, 0);
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      final quote = _getDailyQuote();
      final workout = _getTodayWorkoutHint();
      final body = '$workout\n\n$quote';

      await _plugin.zonedSchedule(
        _morningId,
        '🌅 Good morning, Karthik!',
        body,
        scheduled,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'morning_summary',
            'Morning Summary',
            channelDescription: 'Daily 8 AM fitness briefing',
            importance: Importance.high,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(
              '$body\n\n📊 Open app to see today\'s progress →',
              summaryText: 'Daily Fitness Briefing',
            ),
            color: const Color(0xFF30D158),
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexact,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      // Silently skip if permission not granted
    }
  }

  Future<void> cancelMorningSummary() async {
    await _plugin.cancel(_morningId);
  }

  // ── Supplement Reminders ──────────────────────────────────────────────────

  Future<bool> scheduleSupplementReminders() async {
    try {
      await _plugin.cancel(_multivitaminId);
      await _plugin.cancel(_creatineId);

      const androidDetails = AndroidNotificationDetails(
        'supp_channel',
        'Supplement Reminders',
        channelDescription: 'Daily supplement reminders',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );

      final now = tz.TZDateTime.now(tz.local);

      // Multivitamin — 8:30 AM
      var mv = tz.TZDateTime(
          tz.local, now.year, now.month, now.day, 8, 30);
      if (mv.isBefore(now)) mv = mv.add(const Duration(days: 1));
      await _plugin.zonedSchedule(
        _multivitaminId,
        'Supplement Reminder 🌿',
        'Take your MuscleBlaze Multivitamin after breakfast!',
        mv,
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.inexact,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      // Creatine — 10:00 AM
      var cr = tz.TZDateTime(
          tz.local, now.year, now.month, now.day, 10, 0);
      if (cr.isBefore(now)) cr = cr.add(const Duration(days: 1));
      await _plugin.zonedSchedule(
        _creatineId,
        'Creatine Time ⚡',
        'Don\'t forget 3–5g Creatine today — mix with water or whey!',
        cr,
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.inexact,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Water Reminders ───────────────────────────────────────────────────────

  Future<bool> scheduleWaterReminders() async {
    try {
      for (int i = 10; i <= 14; i++) {
        await _plugin.cancel(i);
      }

      const androidDetails = AndroidNotificationDetails(
        'water_channel',
        'Water Reminders',
        channelDescription: 'Reminds you to drink water throughout the day',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );

      const messages = [
        '💧 Good morning! Start your day with a glass of water.',
        '💧 Hydration check! Have you had your 2nd glass yet?',
        '💧 Afternoon reminder — keep that 2.5L goal in sight!',
        '💧 Evening water check. Don\'t forget to hydrate!',
        '💧 Last reminder for today. Finish strong! 🎯',
      ];
      const hours = [9, 11, 13, 15, 18];

      final now = tz.TZDateTime.now(tz.local);
      for (int i = 0; i < hours.length; i++) {
        var scheduled = tz.TZDateTime(
            tz.local, now.year, now.month, now.day, hours[i]);
        if (scheduled.isBefore(now)) {
          scheduled = scheduled.add(const Duration(days: 1));
        }
        await _plugin.zonedSchedule(
          10 + i,
          'Karthik Fitness 💧',
          messages[i],
          scheduled,
          const NotificationDetails(android: androidDetails),
          androidScheduleMode: AndroidScheduleMode.inexact,
          matchDateTimeComponents: DateTimeComponents.time,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Cancel all ────────────────────────────────────────────────────────────

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
