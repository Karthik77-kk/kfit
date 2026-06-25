import 'package:flutter_test/flutter_test.dart';
import 'package:kfit/services/nav_router.dart';

void main() {
  group('NavRouter.open', () {
    late NavRouter router;

    setUp(() {
      router = NavRouter();
    });

    // ── Known routes ──────────────────────────────────────────────────────

    test('"home" → tab 0, sub 0', () {
      router.open('home');
      expect(router.tabIndex, 0);
      expect(router.nutritionSubTab, 0);
    });

    test('"food" → tab 1, sub 0', () {
      router.open('food');
      expect(router.tabIndex, 1);
      expect(router.nutritionSubTab, 0);
    });

    test('"water" → tab 1, sub 1', () {
      router.open('water');
      expect(router.tabIndex, 1);
      expect(router.nutritionSubTab, 1);
    });

    test('"supplements" → tab 1, sub 2', () {
      router.open('supplements');
      expect(router.tabIndex, 1);
      expect(router.nutritionSubTab, 2);
    });

    test('"workout" → tab 2, sub 0', () {
      router.open('workout');
      expect(router.tabIndex, 2);
      expect(router.nutritionSubTab, 0);
    });

    test('"body" → tab 3, sub 0', () {
      router.open('body');
      expect(router.tabIndex, 3);
      expect(router.nutritionSubTab, 0);
    });

    test('"history" → tab 4, sub 0', () {
      router.open('history');
      expect(router.tabIndex, 4);
      expect(router.nutritionSubTab, 0);
    });

    // ── Unknown / empty routes → home ────────────────────────────────────

    test('unknown route → tab 0 (home), no throw', () {
      expect(() => router.open('bogus_route'), returnsNormally);
      expect(router.tabIndex, 0);
    });

    test('empty string → tab 0 (home), no throw', () {
      expect(() => router.open(''), returnsNormally);
      expect(router.tabIndex, 0);
    });

    // ── URI tolerance ─────────────────────────────────────────────────────

    test('"kfit://food" accepted as "food"', () {
      router.open('kfit://food');
      expect(router.tabIndex, 1);
      expect(router.nutritionSubTab, 0);
    });

    test('"kfit://water" accepted as "water"', () {
      router.open('kfit://water');
      expect(router.tabIndex, 1);
      expect(router.nutritionSubTab, 1);
    });

    test('"kfit://workout" accepted as "workout"', () {
      router.open('kfit://workout');
      expect(router.tabIndex, 2);
    });

    test('"kfit://home" accepted as "home"', () {
      router.open('kfit://home');
      expect(router.tabIndex, 0);
    });

    test('"kfit://body" accepted as "body"', () {
      router.open('kfit://body');
      expect(router.tabIndex, 3);
    });

    test('"kfit://unknown" falls back to home, no throw', () {
      expect(() => router.open('kfit://unknown'), returnsNormally);
      expect(router.tabIndex, 0);
    });

    // ── requestId increments ──────────────────────────────────────────────

    test('requestId starts at 0', () {
      expect(router.requestId, 0);
    });

    test('requestId increments on each open()', () {
      router.open('home');
      expect(router.requestId, 1);
      router.open('home'); // same route — still increments
      expect(router.requestId, 2);
      router.open('food');
      expect(router.requestId, 3);
    });

    test('notifyListeners fires on open()', () {
      int notifyCount = 0;
      router.addListener(() => notifyCount++);
      router.open('food');
      expect(notifyCount, 1);
      router.open('food');
      expect(notifyCount, 2);
    });
  });
}
