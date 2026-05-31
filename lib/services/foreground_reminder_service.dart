import 'package:flutter/material.dart' show Color;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Foreground-service reminder engine.
///
/// Why this exists: aggressive OEM ROMs (iQOO/Vivo Funtouch, Xiaomi MIUI, etc.)
/// silently cancel AlarmManager exact alarms for apps that aren't on their
/// internal whitelist — even with every battery/auto-start permission granted.
/// A foreground service is the one thing Android legally cannot kill, so we run
/// our own 60-second wall-clock timer here and fire reminders directly, never
/// relying on AlarmManager.
///
/// The handler runs in a background isolate, so it has its own notification
/// plugin instance. The notification channels themselves are created by the main
/// app's NotificationService at HIGH importance, so showing on them here pops up.

@pragma('vm:entry-point')
void startReminderCallback() {
  FlutterForegroundTask.setTaskHandler(_ReminderTaskHandler());
}

class _ReminderTaskHandler extends TaskHandler {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // Slots already fired today (in-memory dedup). Cleared at midnight.
  final Set<String> _fired = {};
  String _firedDate = '';

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: android));
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _check(timestamp);
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {}

  Future<void> _check(DateTime now) async {
    final dateKey = '${now.year}-${now.month}-${now.day}';
    if (dateKey != _firedDate) {
      _firedDate = dateKey;
      _fired.clear();
    }

    final h = now.hour;
    final m = now.minute;
    // 2-minute window per slot — the 60s timer guarantees at least one hit.
    bool at(int hour, int minute) => h == hour && m >= minute && m < minute + 2;

    final prefs = await SharedPreferences.getInstance();
    final waterInterval = prefs.getInt('water_reminder_interval') ?? 1;
    final walkInterval = prefs.getInt('walk_reminder_interval') ?? 2;

    // Morning summary — 8:00
    if (at(8, 0)) {
      _fire('morning', 0, '🌅 Good morning, Karthik!',
          _morningBody(now), 'morning_summary');
    }
    // Multivitamin — 8:30
    if (at(8, 30)) {
      _fire('mv', 1, 'Supplement Reminder 🌿',
          'Take your MuscleBlaze Multivitamin after breakfast!', 'supp_channel');
    }
    // Creatine — 10:00
    if (at(10, 0)) {
      _fire('cr', 2, 'Creatine Time ⚡',
          "Don't forget 3–5g Creatine today — mix with water or whey!",
          'supp_channel');
    }
    // Water — every [waterInterval]h from 8 to 21, on the hour
    if (m < 2 && h >= 8 && h <= 21 && ((h - 8) % waterInterval == 0)) {
      _fire('water_$h', 10 + h, 'K Fitness 💧', _waterMsg(h), 'water_channel');
    }
    // Walk — every [walkInterval]h from 9 to 20, on the hour
    if (m < 2 && h >= 9 && h <= 20 && ((h - 9) % walkInterval == 0)) {
      _fire('walk_$h', 40 + (h % 16), 'K Fitness — Move! 🚶',
          _walkMsg(h), 'walk_channel');
    }
    // Evening checklist — 22:00
    if (at(22, 0)) {
      _fire('evening', 30, '📋 Daily Log Check — 10 PM',
          'Did you log everything? 🍽️ Food  💧 Water  💪 Workout  💊 Supplements',
          'evening_checklist');
    }
  }

  Future<void> _fire(
      String slot, int id, String title, String body, String channel) async {
    if (_fired.contains(slot)) return;
    _fired.add(slot);
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel,
          channel,
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(body),
          color: const Color(0xFF30D158),
        ),
      ),
    );
  }

  String _morningBody(DateTime now) {
    final weekday = now.weekday;
    final hint = weekday == 7
        ? '🛌 Rest day — recovery is part of the plan.'
        : (weekday == 1 || weekday == 3 || weekday == 5)
            ? '💪 Workout A today: Push-ups · Squats · Bicep Curls'
            : '🏋️ Workout B today: Shoulder Press · Rows · Lat Pulldown';
    return '$hint\n\nEvery rep counts. Stay consistent today. 💪';
  }

  static const List<String> _waterMsgs = [
    '💧 Start your day with a glass of water!',
    '💧 Hydration check! Time to drink up.',
    '💧 Keep that water goal in sight!',
    '💧 Sip some water — your body will thank you.',
    '💧 Halfway through the day. Water status?',
    '💧 Afternoon hydration reminder!',
    '💧 Water break time!',
    '💧 Don\'t forget to hydrate!',
    '💧 Evening water check.',
    '💧 Last reminder for today. Finish strong! 🎯',
  ];
  String _waterMsg(int h) => _waterMsgs[(h - 8) % _waterMsgs.length];

  static const List<String> _walkMsgs = [
    '🚶 Time to get up and take a quick walk!',
    '🦵 Your legs need a stretch. Walk for 5 minutes!',
    '🏃 Activity reminder — get up and move!',
    '⏰ Break time! A short walk boosts energy and burns calories.',
    '🌿 Step outside for a few minutes. Your body will thank you!',
  ];
  String _walkMsg(int h) => _walkMsgs[(h - 9) % _walkMsgs.length];
}

/// Public wrapper for starting/stopping the foreground reminder service.
class ForegroundReminderService {
  static const _prefKey = 'fg_service_enabled';

  /// Initialize the plugin options. Call once in main() before runApp.
  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'foreground_service',
        channelName: 'Reminder Service',
        channelDescription:
            'Keeps your daily reminders firing reliably in the background.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(60000), // 60s
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  static Future<void> _setEnabled(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, v);
  }

  static Future<bool> get isRunning => FlutterForegroundTask.isRunningService;

  /// Start the persistent reminder service.
  static Future<bool> start() async {
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await _setEnabled(true);
        return true;
      }
      final result = await FlutterForegroundTask.startService(
        serviceId: 600,
        notificationTitle: 'K Fitness reminders active',
        notificationText: 'Tap to open · keeps your reminders on time',
        callback: startReminderCallback,
      );
      final ok = result is ServiceRequestSuccess;
      if (ok) await _setEnabled(true);
      return ok;
    } catch (_) {
      return false;
    }
  }

  /// Stop the persistent reminder service.
  static Future<bool> stop() async {
    try {
      await _setEnabled(false);
      final result = await FlutterForegroundTask.stopService();
      return result is ServiceRequestSuccess;
    } catch (_) {
      return false;
    }
  }

  /// Restart the service if it was enabled (call on app launch).
  static Future<void> restoreIfEnabled() async {
    if (await isEnabled() && !await FlutterForegroundTask.isRunningService) {
      await start();
    }
  }
}
