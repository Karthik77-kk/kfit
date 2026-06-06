import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// SharedPreferences-backed in-app notification inbox.
/// Stores the feed the bell icon shows: AI Coach insights, milestones, reminders.
/// Capped at 50 entries, 30-day retention, deduped by title within the same day.
class NotificationCenter {
  static const _key = 'app_notifications';
  static const _cap = 50;
  static const _retentionDays = 30;

  static Future<List<AppNotification>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => AppNotification.fromJson(e))
          .toList();
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    } catch (_) {
      return [];
    }
  }

  static Future<void> _save(List<AppNotification> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  /// Adds a notification. Skips if an entry with the same title already exists
  /// today (avoids spamming the same insight every app open).
  static Future<void> add(AppNotification n) async {
    final items = await all();
    final today = _dayKey(n.timestamp);
    final dupe = items.any((e) =>
        e.title == n.title && _dayKey(e.timestamp) == today);
    if (dupe) return;

    items.insert(0, n);

    // Retention + cap
    final cutoff = DateTime.now().subtract(const Duration(days: _retentionDays));
    items.removeWhere((e) => e.timestamp.isBefore(cutoff));
    if (items.length > _cap) items.removeRange(_cap, items.length);

    await _save(items);
  }

  static Future<int> unreadCount() async {
    final items = await all();
    return items.where((e) => !e.read).length;
  }

  static Future<void> markAllRead() async {
    final items = await all();
    for (final e in items) {
      e.read = true;
    }
    await _save(items);
  }

  static Future<void> markRead(String id) async {
    final items = await all();
    for (final e in items) {
      if (e.id == id) e.read = true;
    }
    await _save(items);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
