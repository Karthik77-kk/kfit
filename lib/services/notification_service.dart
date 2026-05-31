import 'package:flutter/material.dart' show Color;
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // ── Battery optimization method channel ──────────────────────────────────
  static const _batteryChannel = MethodChannel('com.kfitness/battery');

  // ── IDs ───────────────────────────────────────────────────────────────────
  static const int _morningId = 0;
  static const int _multivitaminId = 1;
  static const int _creatineId = 2;
  // Water reminders: IDs 10–23
  static const int _eveningChecklistId = 30;
  static const int _weeklyReminderId = 31;
  // Walk reminders: IDs 40–55
  static const int _testNotificationId = 99;

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

    // Pre-create all notification channels so they exist before scheduling.
    // Android ignores duplicate channel creation — this is idempotent.
    await _createAllChannels();
  }

  Future<void> _createAllChannels() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    // Delete old low-importance channels so Android recreates them at HIGH.
    // Android locks channel importance after first creation — deletion forces
    // the new Importance.high setting to take effect on reinstall/update.
    for (final id in ['supp_channel', 'water_channel', 'walk_channel']) {
      try { await androidPlugin.deleteNotificationChannel(id); } catch (_) {}
    }

    const channels = [
      AndroidNotificationChannel(
        'morning_summary', 'Morning Summary',
        description: 'Daily 8 AM fitness briefing',
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      ),
      AndroidNotificationChannel(
        'supp_channel', 'Supplement Reminders',
        description: 'Daily supplement reminders',
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      ),
      AndroidNotificationChannel(
        'water_channel', 'Water Reminders',
        description: 'Drink water reminders throughout the day',
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      ),
      AndroidNotificationChannel(
        'walk_channel', 'Walk Reminders',
        description: 'Get up and move reminders',
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      ),
      AndroidNotificationChannel(
        'weekly_channel', 'Weekly Check-in',
        description: 'Sunday reminder to update scale & body measurements',
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      ),
      AndroidNotificationChannel(
        'evening_checklist', 'Evening Checklist',
        description: 'Daily 10 PM reminder to complete your fitness log',
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      ),
      AndroidNotificationChannel(
        'test_channel', 'Test Notifications',
        description: 'Test that notifications are working',
        importance: Importance.max,
        enableVibration: true,
      ),
    ];

    for (final channel in channels) {
      await androidPlugin.createNotificationChannel(channel);
    }
  }

  /// Request Android 13+ notification permission.
  Future<bool> requestPermission() async {
    try {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      return granted ?? true;
    } catch (_) {
      return true; // Assume granted on older Android (< 13)
    }
  }

  /// Check if notifications are enabled for this app.
  Future<bool> areNotificationsEnabled() async {
    try {
      final enabled = await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.areNotificationsEnabled();
      return enabled ?? true;
    } catch (_) {
      return true;
    }
  }

  // ── Exact alarm permission (Android 12+) ─────────────────────────────────

  /// Returns true if the app can schedule exact alarms.
  /// On Android < 12, always returns true (not required).
  Future<bool> canScheduleExactAlarms() async {
    try {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin == null) return true;
      final result = await androidPlugin.canScheduleExactNotifications();
      return result ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Opens the exact alarm settings page (Android 12+).
  /// Routes through the native battery method channel.
  Future<void> openExactAlarmSettings() async {
    try {
      await _batteryChannel.invokeMethod('openExactAlarmSettings');
    } catch (_) {}
  }

  // ── Battery optimization (via native method channel) ──────────────────────

  /// Returns true if this app is already ignoring battery optimizations.
  Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      final result = await _batteryChannel
          .invokeMethod<bool>('isIgnoringBatteryOptimizations');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the system dialog to request battery optimization exclusion.
  Future<void> requestIgnoreBatteryOptimizations() async {
    try {
      await _batteryChannel.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (_) {}
  }

  /// Opens this app's notification settings page.
  Future<void> openNotificationSettings() async {
    try {
      await _batteryChannel.invokeMethod('openNotificationSettings');
    } catch (_) {}
  }

  // ── Test notification (fires immediately) ─────────────────────────────────

  /// Returns:
  ///   'ok'               — notification was sent
  ///   'permission_denied'— POST_NOTIFICATIONS not granted (user must enable in Settings)
  ///   'error:<msg>'      — unexpected exception
  Future<String> sendTestNotification() async {
    try {
      // Hard-check the runtime permission BEFORE calling show().
      // _plugin.show() silently drops the notification when permission is denied —
      // it does NOT throw — so without this check the caller would wrongly think it worked.
      final enabled = await areNotificationsEnabled();
      if (!enabled) return 'permission_denied';

      await _plugin.show(
        _testNotificationId,
        '🔔 Notifications are working!',
        'Great — you\'ll receive water reminders, workout alerts and your 10 PM check-in.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'test_channel',
            'Test Notifications',
            channelDescription: 'Test that notifications are working',
            importance: Importance.max,
            priority: Priority.max,
          ),
        ),
      );
      return 'ok';
    } catch (e) {
      return 'error:$e';
    }
  }

  /// Schedules a notification 60 seconds from now using the same exact-alarm
  /// mechanism as all real notifications. If this fires → scheduling works.
  /// If it doesn't fire → iQOO Auto-start or background activity is still blocked.
  Future<String> sendScheduledTestIn60s() async {
    try {
      final enabled = await areNotificationsEnabled();
      if (!enabled) return 'permission_denied';
      await _plugin.cancel(98);
      final scheduled = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 60));
      final exactOk = await canScheduleExactAlarms();
      await _plugin.zonedSchedule(
        98,
        '⏰ Scheduled test worked!',
        'Background alarms are firing correctly — all your reminders will work.',
        scheduled,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'test_channel', 'Test Notifications',
            channelDescription: 'Test that notifications are working',
            importance: Importance.max,
            priority: Priority.max,
          ),
        ),
        androidScheduleMode: exactOk
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      return 'ok';
    } catch (e) {
      return 'error:$e';
    }
  }

  // ── Morning Summary (8 AM daily) ─────────────────────────────────────────

  String _getDailyQuote() {
    final dayOfYear =
        DateTime.now().difference(DateTime(DateTime.now().year)).inDays;
    return _quotes[dayOfYear % _quotes.length];
  }

  String _getTodayWorkoutHint() {
    final weekday = DateTime.now().weekday;
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

      // Use exact alarm if available (Android 12+), fall back to inexact
      final exactOk = await canScheduleExactAlarms();
      final scheduleMode = exactOk
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

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
        androidScheduleMode: scheduleMode,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {}
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

      // Use exact alarms when available
      final exactOk = await canScheduleExactAlarms();
      final scheduleMode = exactOk
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

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
        androidScheduleMode: scheduleMode,
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
        androidScheduleMode: scheduleMode,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Water Reminders (configurable interval) ───────────────────────────────

  Future<bool> scheduleWaterReminders({int intervalHours = 1}) async {
    try {
      for (int i = 10; i <= 23; i++) {
        await _plugin.cancel(i);
      }

      const messages = [
        '💧 Start your day with a glass of water!',
        '💧 Hydration check! Time to drink up.',
        '💧 Keep that 2500ml goal in sight!',
        '💧 Sip some water — your body will thank you.',
        '💧 Halfway through the day. Water status?',
        '💧 Afternoon hydration reminder!',
        '💧 Water break time!',
        '💧 Don\'t forget to hydrate!',
        '💧 Evening water check.',
        '💧 Last reminder for today. Finish strong! 🎯',
      ];

      // Use exact alarms when available (critical for OEM phones like iQOO/Vivo
      // that batch and delay inexact alarms by hours or drop them entirely)
      final exactOk = await canScheduleExactAlarms();
      final scheduleMode = exactOk
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

      const androidDetails = AndroidNotificationDetails(
        'water_channel', 'Water Reminders',
        channelDescription: 'Reminds you to drink water throughout the day',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );

      final now = tz.TZDateTime.now(tz.local);
      int id = 10;
      int msgIdx = 0;
      for (int hour = 8; hour <= 21; hour += intervalHours) {
        var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour);
        if (scheduled.isBefore(now)) scheduled = scheduled.add(const Duration(days: 1));
        await _plugin.zonedSchedule(
          id++,
          'K Fitness 💧',
          messages[msgIdx % messages.length],
          scheduled,
          const NotificationDetails(android: androidDetails),
          androidScheduleMode: scheduleMode,
          matchDateTimeComponents: DateTimeComponents.time,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        msgIdx++;
        if (id > 23) break;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Walk / Inactivity Reminders ───────────────────────────────────────────

  Future<bool> scheduleWalkReminders({int intervalHours = 2}) async {
    try {
      // Cancel existing walk reminders (IDs 40–55)
      for (int i = 40; i <= 55; i++) {
        await _plugin.cancel(i);
      }

      const androidDetails = AndroidNotificationDetails(
        'walk_channel',
        'Walk Reminders',
        channelDescription: 'Reminds you to get up and walk if inactive',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );

      final messages = [
        '🚶 Time to get up and take a quick walk!',
        '🦵 Your legs need a stretch. Walk for 5 minutes!',
        '🏃 Activity reminder — get up and move!',
        '⏰ Break time! A short walk boosts energy and burns calories.',
        '🌿 Step outside for a few minutes. Your body will thank you!',
      ];

      // Use exact alarms when available (critical for iQOO/Vivo that drop inexact alarms)
      final exactOk = await canScheduleExactAlarms();
      final scheduleMode = exactOk
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

      final now = tz.TZDateTime.now(tz.local);
      int id = 40;
      int msgIdx = 0;
      for (int hour = 9; hour <= 20; hour += intervalHours) {
        var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour);
        if (scheduled.isBefore(now)) scheduled = scheduled.add(const Duration(days: 1));
        await _plugin.zonedSchedule(
          id++,
          'K Fitness — Move! 🚶',
          messages[msgIdx % messages.length],
          scheduled,
          const NotificationDetails(android: androidDetails),
          androidScheduleMode: scheduleMode,
          matchDateTimeComponents: DateTimeComponents.time,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        msgIdx++;
        if (id > 55) break;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Evening Checklist (10 PM daily) ──────────────────────────────────────

  Future<void> scheduleEveningChecklist() async {
    try {
      await _plugin.cancel(_eveningChecklistId);
      final now = tz.TZDateTime.now(tz.local);
      var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 22, 0);
      if (scheduled.isBefore(now)) scheduled = scheduled.add(const Duration(days: 1));

      final exactOk = await canScheduleExactAlarms();
      final scheduleMode = exactOk
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

      await _plugin.zonedSchedule(
        _eveningChecklistId,
        '📋 Daily Log Check — 10 PM',
        'Did you log everything? 🍽️ Food  💧 Water  💪 Workout  💊 Supplements',
        scheduled,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'evening_checklist', 'Evening Checklist',
            channelDescription: 'Daily 10 PM reminder to complete your fitness log',
            importance: Importance.high,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(
              '✅ Tap to open the app and fill in anything you missed today.\n\n🍽️ Food logged?\n💧 Water intake updated?\n💪 Workout logged?\n💊 Supplements checked?',
              summaryText: 'Daily Log Reminder',
            ),
            color: const Color(0xFFFF9F0A),
          ),
        ),
        androidScheduleMode: scheduleMode,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {}
  }

  // ── Weekly Check-in (Sunday 7 PM) — update scale & measurements ───────────

  Future<void> scheduleWeeklyLogReminder() async {
    try {
      await _plugin.cancel(_weeklyReminderId);
      final now = tz.TZDateTime.now(tz.local);
      // Next Sunday (weekday 7) at 19:00.
      var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 19, 0);
      while (scheduled.weekday != DateTime.sunday || scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      final exactOk = await canScheduleExactAlarms();
      final scheduleMode = exactOk
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

      await _plugin.zonedSchedule(
        _weeklyReminderId,
        '⚖️ Weekly Check-in — update your numbers',
        'It\'s Sunday! Log this week\'s smart-scale reading and body measurements so your trends stay accurate.',
        scheduled,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'weekly_channel', 'Weekly Check-in',
            channelDescription: 'Sunday reminder to update scale & body measurements',
            importance: Importance.high,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(
              '📊 Step on the smart scale and take your tape measurements (waist, hips, chest, arm, thigh).\n\nWeekly data keeps your AI Coach, body-composition trends and predictions sharp.',
              summaryText: 'Weekly Check-in',
            ),
            color: const Color(0xFF40C8E0),
          ),
        ),
        androidScheduleMode: scheduleMode,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {}
  }

  /// Re-schedule all notifications (call on every app open to ensure they're active).
  Future<void> rescheduleAll({int waterInterval = 1, int walkInterval = 2}) async {
    await scheduleMorningSummary();
    await scheduleSupplementReminders();
    await scheduleWaterReminders(intervalHours: waterInterval);
    await scheduleWalkReminders(intervalHours: walkInterval);
    await scheduleEveningChecklist();
    await scheduleWeeklyLogReminder();
  }

  // ── Cancel all ────────────────────────────────────────────────────────────

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
