import 'package:flutter_test/flutter_test.dart';
import 'package:kfit/models/models.dart';
import 'package:kfit/providers/fitness_provider.dart';

AppNotification _n(String title, {String emoji = '🔔'}) => AppNotification(
      id: title,
      emoji: emoji,
      title: title,
      body: '',
      accent: 0,
      category: 'test',
      timestamp: DateTime(2026),
    );

void main() {
  group('FitnessProvider.mergeWidgetNotifications', () {
    test('empty feeds → []', () {
      expect(FitnessProvider.mergeWidgetNotifications([], []), isEmpty);
    });

    test('milestones come before insights', () {
      final out = FitnessProvider.mergeWidgetNotifications(
          [_n('Streak!')], [_n('Eat protein')]);
      expect(out.map((e) => e.title).toList(), ['Streak!', 'Eat protein']);
    });

    test('dedupes by title, keeping the first (milestone) occurrence', () {
      final out = FitnessProvider.mergeWidgetNotifications(
          [_n('Same', emoji: '🏆')], [_n('Same', emoji: '💡'), _n('Other')]);
      expect(out.map((e) => e.title).toList(), ['Same', 'Other']);
      expect(out.first.emoji, '🏆'); // the milestone copy is kept
    });

    test('skips blank / whitespace titles', () {
      final out =
          FitnessProvider.mergeWidgetNotifications([_n('   ')], [_n('Real')]);
      expect(out.map((e) => e.title).toList(), ['Real']);
    });

    test('takes at most n', () {
      final out = FitnessProvider.mergeWidgetNotifications(
          [], [_n('a'), _n('b'), _n('c'), _n('d')],
          n: 3);
      expect(out.map((e) => e.title).toList(), ['a', 'b', 'c']);
    });

    test('n larger than available returns all', () {
      final out =
          FitnessProvider.mergeWidgetNotifications([_n('a')], [_n('b')], n: 5);
      expect(out.length, 2);
    });
  });
}
