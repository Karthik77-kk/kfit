import 'package:shared_preferences/shared_preferences.dart';

/// Per-user daily quota for AI photo scans.
///
/// The Gemini free tier is a single shared pool, so regular users are capped at
/// [dailyLimit] scans per day. The primary user ("Karthik") is unlimited. The
/// counter is keyed per calendar day and resets automatically at midnight local.
class ScanQuota {
  static const int dailyLimit = 10;

  /// The app owner — never rate-limited (case/space-insensitive match).
  static bool isUnlimitedUser(String userName) =>
      userName.trim().toLowerCase() == 'karthik';

  static String _todayKey() {
    final n = DateTime.now();
    final m = n.month.toString().padLeft(2, '0');
    final d = n.day.toString().padLeft(2, '0');
    return 'ai_scan_count_${n.year}-$m-$d';
  }

  /// Scans already used today.
  static int usedToday(SharedPreferences prefs) => prefs.getInt(_todayKey()) ?? 0;

  /// Scans left today. For the primary user this returns [dailyLimit] as a
  /// sentinel (the UI shows "unlimited" for them and never blocks).
  static int remaining(SharedPreferences prefs, String userName) {
    if (isUnlimitedUser(userName)) return dailyLimit;
    return (dailyLimit - usedToday(prefs)).clamp(0, dailyLimit);
  }

  /// Whether the user may run another scan right now.
  static bool canScan(SharedPreferences prefs, String userName) {
    if (isUnlimitedUser(userName)) return true;
    return usedToday(prefs) < dailyLimit;
  }

  /// Record one successful scan against today's quota. No-op for the primary user.
  /// Call this only after a scan actually succeeds, so failed calls don't burn credits.
  static Future<void> record(SharedPreferences prefs, String userName) async {
    if (isUnlimitedUser(userName)) return;
    await prefs.setInt(_todayKey(), usedToday(prefs) + 1);
  }
}
