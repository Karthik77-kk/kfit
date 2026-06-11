import 'package:flutter_test/flutter_test.dart';
import 'package:kfit/models/models.dart';
import 'package:kfit/services/notification_center.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppNotification _n(String id, String title, {DateTime? ts}) => AppNotification(
      id: id, emoji: '🔔', title: title, body: 'body $id',
      accent: 0xFF30D158, category: 'test',
      timestamp: ts ?? DateTime.now(),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('add then all returns the entry', () async {
    await NotificationCenter.add(_n('1', 'Hello'));
    final all = await NotificationCenter.all();
    expect(all.length, 1);
    expect(all.first.title, 'Hello');
  });

  test('dedupes same title within the same day', () async {
    await NotificationCenter.add(_n('1', 'Same'));
    await NotificationCenter.add(_n('2', 'Same'));
    final all = await NotificationCenter.all();
    expect(all.length, 1);
  });

  test('allows same title on different days', () async {
    await NotificationCenter.add(_n('1', 'Daily', ts: DateTime.now().subtract(const Duration(days: 2))));
    await NotificationCenter.add(_n('2', 'Daily'));
    final all = await NotificationCenter.all();
    expect(all.length, 2);
  });

  test('unreadCount and markAllRead', () async {
    await NotificationCenter.add(_n('1', 'A'));
    await NotificationCenter.add(_n('2', 'B'));
    expect(await NotificationCenter.unreadCount(), 2);
    await NotificationCenter.markAllRead();
    expect(await NotificationCenter.unreadCount(), 0);
  });

  test('markRead marks a single entry', () async {
    await NotificationCenter.add(_n('1', 'A'));
    await NotificationCenter.add(_n('2', 'B'));
    await NotificationCenter.markRead('1');
    final all = await NotificationCenter.all();
    expect(all.firstWhere((e) => e.id == '1').read, isTrue);
    expect(all.firstWhere((e) => e.id == '2').read, isFalse);
  });

  test('clear empties the store', () async {
    await NotificationCenter.add(_n('1', 'A'));
    await NotificationCenter.clear();
    expect(await NotificationCenter.all(), isEmpty);
  });

  test('drops entries older than 30 days', () async {
    await NotificationCenter.add(_n('old', 'Old', ts: DateTime.now().subtract(const Duration(days: 40))));
    await NotificationCenter.add(_n('new', 'New'));
    final all = await NotificationCenter.all();
    expect(all.any((e) => e.id == 'old'), isFalse);
    expect(all.any((e) => e.id == 'new'), isTrue);
  });

  test('sorted newest first', () async {
    await NotificationCenter.add(_n('old', 'Old', ts: DateTime.now().subtract(const Duration(hours: 5))));
    await NotificationCenter.add(_n('new', 'New'));
    final all = await NotificationCenter.all();
    expect(all.first.id, 'new');
  });
}
