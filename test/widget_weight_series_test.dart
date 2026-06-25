import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kfit/providers/fitness_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

/// Builds the SharedPreferences initial values map with [n] body entries
/// whose weights start at [startKg] and increase by 1.0 each day,
/// beginning [n] days ago so that today is the last entry.
Map<String, Object> _seedBodyN(int n, {double startKg = 70.0}) {
  final now = DateTime.now();
  final list = List.generate(n, (i) {
    final date = now.subtract(Duration(days: n - 1 - i));
    final kg   = startKg + i;
    return {
      'id':       'b$i',
      'date':     date.toIso8601String(),
      'weightKg': kg,
      'steps':    0,
    };
  });
  return {'body_history': jsonEncode(list)};
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Mock path_provider so FitnessProvider's constructor doesn't crash on
    // getApplicationDocumentsDirectory.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return '/tmp';
        }
        return null;
      },
    );
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('widgetWeightSeries', () {
    // ── Empty history ─────────────────────────────────────────────────────

    test('returns [] when no body or scale history', () async {
      SharedPreferences.setMockInitialValues({});
      final p = FitnessProvider();
      await p.loadData();
      expect(p.widgetWeightSeries(), isEmpty);
    });

    // ── Single entry ──────────────────────────────────────────────────────

    test('returns 1 entry when only one body weight exists', () async {
      SharedPreferences.setMockInitialValues(_seedBodyN(1, startKg: 73.5));
      final p = FitnessProvider();
      await p.loadData();
      final s = p.widgetWeightSeries();
      expect(s.length, 1);
      expect(s.first, closeTo(73.5, 0.01));
    });

    // ── Exactly 7 entries ─────────────────────────────────────────────────

    test('returns all 7 when exactly 7 body entries', () async {
      SharedPreferences.setMockInitialValues(_seedBodyN(7, startKg: 70.0));
      final p = FitnessProvider();
      await p.loadData();
      final s = p.widgetWeightSeries();
      expect(s.length, 7);
      // Should be sorted oldest→newest: 70, 71, … 76
      for (int i = 0; i < 7; i++) {
        expect(s[i], closeTo(70.0 + i, 0.01));
      }
    });

    // ── More than 7 entries → last 7 ─────────────────────────────────────

    test('returns last 7 when 10 body entries exist', () async {
      SharedPreferences.setMockInitialValues(_seedBodyN(10, startKg: 60.0));
      final p = FitnessProvider();
      await p.loadData();
      final s = p.widgetWeightSeries();
      expect(s.length, 7);
      // The last 7 of [60…69] are [63, 64, 65, 66, 67, 68, 69].
      for (int i = 0; i < 7; i++) {
        expect(s[i], closeTo(63.0 + i, 0.01));
      }
    });

    test('respects custom maxPoints param', () async {
      SharedPreferences.setMockInitialValues(_seedBodyN(10, startKg: 60.0));
      final p = FitnessProvider();
      await p.loadData();
      expect(p.widgetWeightSeries(maxPoints: 3).length, 3);
      expect(p.widgetWeightSeries(maxPoints: 1).length, 1);
    });

    // ── Mixed body + scale history ────────────────────────────────────────

    test('merges body and scale histories, sorted chronologically', () async {
      // 3 body entries on odd days ago + 3 scale entries on even days ago.
      final now   = DateTime.now();
      final bodyList = [1, 3, 5].map((d) => {
        'id': 'b$d',
        'date': now.subtract(Duration(days: d)).toIso8601String(),
        'weightKg': 70.0 + d,
        'steps': 0,
      }).toList();
      final scaleList = [2, 4, 6].map((d) => {
        'id': 's$d',
        'date': now.subtract(Duration(days: d)).toIso8601String(),
        'weightKg': 70.0 + d,
        'bodyFatPercent': 20.0, 'bodyFatKg': 14.0,
        'muscleMassKg': 35.0, 'muscleMassPercent': 46.0,
        'leanBodyMassKg': 56.0, 'biologicalAge': 22, 'visceralFatIndex': 5,
        'bmr': 1700.0, 'bodyWaterPercent': 55.0, 'boneMassKg': 3.2,
        'proteinPercent': 18.0, 'skeletalMuscleMassKg': 28.0,
      }).toList();

      SharedPreferences.setMockInitialValues({
        'body_history':  jsonEncode(bodyList),
        'scale_history': jsonEncode(scaleList),
      });

      final p = FitnessProvider();
      await p.loadData();
      final s = p.widgetWeightSeries();

      // 6 entries total (3 body + 3 scale), all ≤ 7 → all returned
      expect(s.length, 6);

      // Values must be ascending in time: oldest first (6 days ago → 1 day ago)
      // Days ago: 6, 5, 4, 3, 2, 1 → weights: 76, 75, 74, 73, 72, 71
      expect(s.first, greaterThan(s.last)); // oldest weight > newest weight
      // Confirm sorted (each entry should be ≤ previous in this seeded scenario
      // since weight decreases as days_ago decreases... actually weight = 70+d so
      // oldest (d=6) = 76, newest (d=1) = 71 → sorted DESC in value but sorted
      // ASC by date which is what we want).
      for (int i = 1; i < s.length; i++) {
        // Date-ordered means oldest has higher weight here (day 6 → 76 kg), so
        // the series should be strictly decreasing as we go forward in time.
        expect(s[i], lessThan(s[i - 1]));
      }
    });

    // ── Zero / negative weights filtered ─────────────────────────────────

    test('filters out zero-weight entries', () async {
      final now = DateTime.now();
      final list = [
        {'id': 'b0', 'date': now.subtract(const Duration(days: 2)).toIso8601String(), 'weightKg': 0.0, 'steps': 0},
        {'id': 'b1', 'date': now.subtract(const Duration(days: 1)).toIso8601String(), 'weightKg': 72.0, 'steps': 0},
      ];
      SharedPreferences.setMockInitialValues({'body_history': jsonEncode(list)});
      final p = FitnessProvider();
      await p.loadData();
      final s = p.widgetWeightSeries();
      expect(s.length, 1);
      expect(s.first, closeTo(72.0, 0.01));
    });
  });
}
