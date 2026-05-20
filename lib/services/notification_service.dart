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
    try {
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const settings = InitializationSettings(android: android);
      await _plugin.initialize(settings);

      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {
      // Ignore initialization errors silently
    }
  }

  // ── Morning summary notification (8 AM daily) ──────────────────────────────
  Future<void> scheduleMorningSummary() async {
    await _plugin.cancel(50);

    const androidDetails = AndroidNotificationDetails(
      'morning_channel',
      'Morning Summary',
      channelDescription: 'Daily 8 AM fitness briefing',
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(''),
    );

    final hint = _getTodayWorkoutHint();
    final quote = _getDailyQuote();
    final body =
        '$hint\n\n"$quote"\n\nOpen the app to track today\'s progress 💪';

    try {
      final now = tz.TZDateTime.now(tz.local);
      var scheduled =
          tz.TZDateTime(tz.local, now.year, now.month, now.day, 8, 0);
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      final details = AndroidNotificationDetails(
        'morning_channel',
        'Morning Summary',
        channelDescription: 'Daily 8 AM fitness briefing',
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(body),
      );

      await _plugin.zonedSchedule(
        50,
        'Good morning, Karthik! 🌅',
        hint,
        scheduled,
        NotificationDetails(android: details),
        androidScheduleMode: AndroidScheduleMode.inexact,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      // Permission not granted — skip silently
    }
  }

  Future<void> cancelMorningSummary() async {
    await _plugin.cancel(50);
  }

  String _getTodayWorkoutHint() {
    final day = DateTime.now().weekday; // 1=Mon ... 7=Sun
    switch (day) {
      case 1:
      case 3:
      case 5:
        return '🏋️ Today is Workout A — Bench, Squat, Row. Let\'s go!';
      case 2:
      case 4:
      case 6:
        return '💪 Today is Workout B — OHP, Deadlift, Incline, RDL!';
      default:
        return '🛌 Rest day — stretch, walk, and eat clean today.';
    }
  }

  String _getDailyQuote() {
    const quotes = [
      'Every rep counts. Every meal matters.',
      'The body achieves what the mind believes.',
      'Discipline is doing it even when you don\'t feel like it.',
      'Small daily improvements lead to stunning results.',
      'You are one workout away from a better mood.',
      'Consistency beats perfection every time.',
      'Fat loss is simple — not easy. Stay the course.',
      'Progress, not perfection. Keep showing up.',
    ];
    final index = DateTime.now().difference(DateTime(2024)).inDays % quotes.length;
    return quotes[index];
  }

  // ── Water reminders ────────────────────────────────────────────────────────
  Future<void> scheduleWaterReminders() async {
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
      '💧 Evening water reminder. Don\'t get dehydrated!',
    ];

    final hours = [9, 11, 13, 15, 18];
    for (int i = 0; i < hours.length; i++) {
      try {
        final now = tz.TZDateTime.now(tz.local);
        var scheduled =
            tz.TZDateTime(tz.local, now.year, now.month, now.day, hours[i]);
        if (scheduled.isBefore(now)) {
          scheduled = scheduled.add(const Duration(days: 1));
        }
        await _plugin.zonedSchedule(
          10 + i,
          'Karthik Fitness 💪',
          messages[i],
          scheduled,
          const NotificationDetails(android: androidDetails),
          androidScheduleMode: AndroidScheduleMode.inexact,
          matchDateTimeComponents: DateTimeComponents.time,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (_) {}
    }
  }

  // ── Supplement reminders ───────────────────────────────────────────────────
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

    try {
      var mv = tz.TZDateTime(tz.local, now.year, now.month, now.day, 8, 30);
      if (mv.isBefore(now)) mv = mv.add(const Duration(days: 1));
      await _plugin.zonedSchedule(
        1,
        'Supplement Reminder 🌿',
        'Take your MuscleBlaze Multivitamin after breakfast!',
        mv,
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.inexact,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      var cr = tz.TZDateTime(tz.local, now.year, now.month, now.day, 10, 0);
      if (cr.isBefore(now)) cr = cr.add(const Duration(days: 1));
      await _plugin.zonedSchedule(
        2,
        'Creatine Time 💊',
        'Don\'t forget 3–5g Creatine — mix with water or whey!',
        cr,
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.inexact,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {}
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
