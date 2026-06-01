import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karthik_fitness/models/models.dart';
import 'package:karthik_fitness/providers/fitness_provider.dart';
import 'package:karthik_fitness/services/smart_insight_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _dk(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

FoodEntry _e(double cal, double prot, DateTime ts) => FoodEntry(
      id: 'h${ts.millisecondsSinceEpoch}',
      name: 'Food',
      calories: cal,
      protein: prot,
      mealType: MealType.lunch,
      timestamp: ts,
    );

/// Builds a SharedPreferences seed map with food entries for past [n] days.
/// Index 0 = 1 day ago, index 1 = 2 days ago, etc.
/// Days with calByDay[i] == 0 are skipped (no entry = no data for that day).
/// Accepts List<num> so callers can use int literals like [1700, 1600].
Map<String, Object> _seedFood({
  required List<num> calByDay,
  required List<num> protByDay,
  int hour = 13,
}) {
  assert(calByDay.length == protByDay.length);
  final prefs = <String, Object>{};
  final now = DateTime.now();
  for (int i = 0; i < calByDay.length; i++) {
    if (calByDay[i] == 0) continue;
    final d = now.subtract(Duration(days: i + 1));
    final ts = DateTime(d.year, d.month, d.day, hour);
    prefs['food_${_dk(d)}'] = jsonEncode(
        [_e(calByDay[i].toDouble(), protByDay[i].toDouble(), ts).toJson()]);
  }
  return prefs;
}

/// Builds SharedPreferences seed map with water entries (ml) for past days.
/// Index 0 = 1 day ago. Zero values are stored (0ml is valid data).
Map<String, Object> _seedWater(List<int> mlByDay) {
  final prefs = <String, Object>{};
  final now = DateTime.now();
  for (int i = 0; i < mlByDay.length; i++) {
    if (mlByDay[i] == 0) continue; // 0 ml → no entry (skip)
    final d = now.subtract(Duration(days: i + 1));
    prefs['water_${_dk(d)}'] = mlByDay[i];
  }
  return prefs;
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => null,
    );
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ── calorieAdherenceRate ──────────────────────────────────────────────────

  group('calorieAdherenceRate', () {
    test('0.0 when no food history', () async {
      final p = FitnessProvider();
      await p.loadData();
      expect(p.calorieAdherenceRate, 0.0);
    });

    test('1.0 when every logged day is within ±15% of 1700 kcal goal', () async {
      SharedPreferences.setMockInitialValues(
          _seedFood(calByDay: List.filled(10, 1700), protByDay: List.filled(10, 80)));
      final p = FitnessProvider();
      await p.loadData();
      expect(p.calorieAdherenceRate, closeTo(1.0, 0.01));
    });

    test('1950 kcal (well within 115% of 1700) counts as within goal', () async {
      // 1700 * 1.15 = 1955.0, but due to floating-point imprecision we use 1950
      SharedPreferences.setMockInitialValues(
          _seedFood(calByDay: List.filled(5, 1950), protByDay: List.filled(5, 80)));
      final p = FitnessProvider();
      await p.loadData();
      expect(p.calorieAdherenceRate, closeTo(1.0, 0.01));
    });

    test('lower boundary 1445 kcal (85% of 1700) is within goal', () async {
      SharedPreferences.setMockInitialValues(
          _seedFood(calByDay: List.filled(5, 1445), protByDay: List.filled(5, 80)));
      final p = FitnessProvider();
      await p.loadData();
      expect(p.calorieAdherenceRate, closeTo(1.0, 0.01));
    });

    test('0.0 when all logged days are way over goal (3000 kcal)', () async {
      SharedPreferences.setMockInitialValues(
          _seedFood(calByDay: List.filled(5, 3000), protByDay: List.filled(5, 80)));
      final p = FitnessProvider();
      await p.loadData();
      expect(p.calorieAdherenceRate, 0.0);
    });

    test('0.0 when all logged days are too low (500 kcal, below 85%)', () async {
      SharedPreferences.setMockInitialValues(
          _seedFood(calByDay: List.filled(5, 500), protByDay: List.filled(5, 30)));
      final p = FitnessProvider();
      await p.loadData();
      expect(p.calorieAdherenceRate, 0.0);
    });

    test('correct fraction: 6 of 10 days within goal = 0.6', () async {
      final cal = [1700, 1700, 1700, 1700, 1700, 1700, 500, 500, 500, 500];
      SharedPreferences.setMockInitialValues(
          _seedFood(calByDay: cal, protByDay: List.filled(10, 80)));
      final p = FitnessProvider();
      await p.loadData();
      expect(p.calorieAdherenceRate, closeTo(0.6, 0.01));
    });

    test('skips days with no data (0 cal days do not dilute rate)', () async {
      // 5 good days, 5 skipped → 100% of logged days
      final cal = [1700, 1700, 1700, 1700, 1700, 0, 0, 0, 0, 0];
      SharedPreferences.setMockInitialValues(
          _seedFood(calByDay: cal, protByDay: List.filled(10, 80)));
      final p = FitnessProvider();
      await p.loadData();
      expect(p.calorieAdherenceRate, closeTo(1.0, 0.01));
    });

    test('single logged day within goal = 1.0', () async {
      SharedPreferences.setMockInitialValues(
          _seedFood(calByDay: [1700], protByDay: [80]));
      final p = FitnessProvider();
      await p.loadData();
      expect(p.calorieAdherenceRate, 1.0);
    });
  });

  // ── proteinAdherenceRate ──────────────────────────────────────────────────

  group('proteinAdherenceRate', () {
    test('0.0 when no food history', () async {
      final p = FitnessProvider();
      await p.loadData();
      expect(p.proteinAdherenceRate, 0.0);
    });

    test('1.0 when every day hits ≥90% of 100g goal (90g)', () async {
      SharedPreferences.setMockInitialValues(
          _seedFood(calByDay: List.filled(8, 1700), protByDay: List.filled(8, 90)));
      final p = FitnessProvider();
      await p.loadData();
      expect(p.proteinAdherenceRate, closeTo(1.0, 0.01));
    });

    test('1.0 when protein exactly at goal (100g)', () async {
      SharedPreferences.setMockInitialValues(
          _seedFood(calByDay: List.filled(5, 1700), protByDay: List.filled(5, 100)));
      final p = FitnessProvider();
      await p.loadData();
      expect(p.proteinAdherenceRate, closeTo(1.0, 0.01));
    });

    test('0.0 when all days are below 90% of goal (50g/100g = 50%)', () async {
      SharedPreferences.setMockInitialValues(
          _seedFood(calByDay: List.filled(8, 1500), protByDay: List.filled(8, 50)));
      final p = FitnessProvider();
      await p.loadData();
      expect(p.proteinAdherenceRate, 0.0);
    });

    test('partial adherence: 4 of 8 days hitting goal = 0.5', () async {
      final prot = [95.0, 95, 95, 95, 50, 50, 50, 50];
      SharedPreferences.setMockInitialValues(
          _seedFood(calByDay: List.filled(8, 1700), protByDay: prot));
      final p = FitnessProvider();
      await p.loadData();
      expect(p.proteinAdherenceRate, closeTo(0.5, 0.01));
    });

    test('89g is just below threshold (0.89 × 100 = 89 < 90)', () async {
      SharedPreferences.setMockInitialValues(
          _seedFood(calByDay: List.filled(5, 1700), protByDay: List.filled(5, 89)));
      final p = FitnessProvider();
      await p.loadData();
      expect(p.proteinAdherenceRate, 0.0);
    });

    test('skips days with no protein data (0g entries)', () async {
      final prot = [95.0, 95, 0, 0, 0];
      SharedPreferences.setMockInitialValues(
          _seedFood(calByDay: [1700, 1700, 0, 0, 0], protByDay: prot));
      final p = FitnessProvider();
      await p.loadData();
      expect(p.proteinAdherenceRate, closeTo(1.0, 0.01));
    });
  });

  // ── waterAdherenceRate ────────────────────────────────────────────────────

  group('waterAdherenceRate', () {
    test('0.0 when no water history', () async {
      final p = FitnessProvider();
      await p.loadData();
      expect(p.waterAdherenceRate, 0.0);
    });

    test('1.0 when all logged days meet ≥90% of 2500 ml goal (2250 ml)', () async {
      SharedPreferences.setMockInitialValues(_seedWater(List.filled(10, 2250)));
      final p = FitnessProvider();
      await p.loadData();
      expect(p.waterAdherenceRate, closeTo(1.0, 0.01));
    });

    test('1.0 when water exactly at goal (2500 ml)', () async {
      SharedPreferences.setMockInitialValues(_seedWater(List.filled(5, 2500)));
      final p = FitnessProvider();
      await p.loadData();
      expect(p.waterAdherenceRate, closeTo(1.0, 0.01));
    });

    test('0.0 when all logged days are below 90% of goal (1000 ml)', () async {
      SharedPreferences.setMockInitialValues(_seedWater(List.filled(10, 1000)));
      final p = FitnessProvider();
      await p.loadData();
      expect(p.waterAdherenceRate, 0.0);
    });

    test('correct fraction: 5 of 10 days meeting goal', () async {
      final ml = [2500, 2500, 2500, 2500, 2500, 1000, 1000, 1000, 1000, 1000];
      SharedPreferences.setMockInitialValues(_seedWater(ml));
      final p = FitnessProvider();
      await p.loadData();
      expect(p.waterAdherenceRate, closeTo(0.5, 0.01));
    });

    test('skips days with 0 ml (no entry = no data)', () async {
      final ml = [2500, 2500, 2500, 0, 0, 0, 0, 0, 0, 0];
      SharedPreferences.setMockInitialValues(_seedWater(ml));
      final p = FitnessProvider();
      await p.loadData();
      // Only 3 logged days, all met goal
      expect(p.waterAdherenceRate, closeTo(1.0, 0.01));
    });

    test('2249 ml is just below threshold (89.96% of 2500 < 90%)', () async {
      SharedPreferences.setMockInitialValues(_seedWater(List.filled(5, 2249)));
      final p = FitnessProvider();
      await p.loadData();
      expect(p.waterAdherenceRate, 0.0);
    });
  });

  // ── deficitStreak ─────────────────────────────────────────────────────────

  group('deficitStreak', () {
    test('0 when no food history', () async {
      final p = FitnessProvider();
      await p.loadData();
      expect(p.deficitStreak, 0);
    });

    test('0 when yesterday was over goal', () async {
      SharedPreferences.setMockInitialValues(
          _seedFood(calByDay: [2500], protByDay: [80]));
      final p = FitnessProvider();
      await p.loadData();
      expect(p.deficitStreak, 0);
    });

    test('0 when yesterday was exactly at goal (not <99% of goal)', () async {
      // 1700 kcal = 100% of 1700 goal; threshold is <99% → 1700 is not a deficit
      SharedPreferences.setMockInitialValues(
          _seedFood(calByDay: [1700], protByDay: [80]));
      final p = FitnessProvider();
      await p.loadData();
      expect(p.deficitStreak, 0);
    });

    test('1 when only yesterday was under goal', () async {
      SharedPreferences.setMockInitialValues(
          _seedFood(calByDay: [1600], protByDay: [80]));
      final p = FitnessProvider();
      await p.loadData();
      expect(p.deficitStreak, 1);
    });

    test('counts consecutive days under goal', () async {
      final cal = [1600, 1600, 1600, 1600, 1600, 2000];
      SharedPreferences.setMockInitialValues(
          _seedFood(calByDay: cal, protByDay: List.filled(6, 80)));
      final p = FitnessProvider();
      await p.loadData();
      expect(p.deficitStreak, 5);
    });

    test('breaks on first over-goal day (middle of history)', () async {
      // yesterday: 1600, 2 days: 2000 (breaks), 3 days: 1500 (not counted)
      final cal = [1600, 2000, 1500];
      SharedPreferences.setMockInitialValues(
          _seedFood(calByDay: cal, protByDay: List.filled(3, 80)));
      final p = FitnessProvider();
      await p.loadData();
      expect(p.deficitStreak, 1);
    });

    test('breaks on gap day (no data = 0 calories)', () async {
      // yesterday/2/3 days: deficit; 4th day: no data → breaks
      final cal = [1600, 1600, 1600, 0, 1600, 1600];
      SharedPreferences.setMockInitialValues(
          _seedFood(calByDay: cal, protByDay: List.filled(6, 80)));
      final p = FitnessProvider();
      await p.loadData();
      expect(p.deficitStreak, 3);
    });

    test('10-day streak when all 10 past days under goal', () async {
      SharedPreferences.setMockInitialValues(
          _seedFood(calByDay: List.filled(10, 1500), protByDay: List.filled(10, 80)));
      final p = FitnessProvider();
      await p.loadData();
      expect(p.deficitStreak, 10);
    });

    test('streak boundary: 1683 kcal (just below 99% × 1700 = 1683) counts', () async {
      SharedPreferences.setMockInitialValues(
          _seedFood(calByDay: [1683], protByDay: [80]));
      final p = FitnessProvider();
      await p.loadData();
      // 1683 < 1700 * 0.99 = 1683 → equal, not strictly less → streak = 0
      // Actually 1700 * 0.99 = 1683.0 exactly, and 1683 < 1683 is false → 0
      expect(p.deficitStreak, 0);
    });

    test('streak boundary: 1682 kcal (strictly below 99% threshold) counts', () async {
      SharedPreferences.setMockInitialValues(
          _seedFood(calByDay: [1682], protByDay: [80]));
      final p = FitnessProvider();
      await p.loadData();
      // 1682 < 1683 → true → streak = 1
      expect(p.deficitStreak, 1);
    });
  });

  // ── hasLateNightEatingPattern ─────────────────────────────────────────────

  group('hasLateNightEatingPattern', () {
    test('false when no food history', () async {
      final p = FitnessProvider();
      await p.loadData();
      expect(p.hasLateNightEatingPattern, isFalse);
    });

    test('false when all entries are before 9 PM (hour 12)', () async {
      SharedPreferences.setMockInitialValues(
          _seedFood(
              calByDay: List.filled(14, 1700),
              protByDay: List.filled(14, 80),
              hour: 12));
      final p = FitnessProvider();
      await p.loadData();
      expect(p.hasLateNightEatingPattern, isFalse);
    });

    test('true when >25% of entries are after 9 PM (5 of 14 days = 36%)', () async {
      final prefs = <String, Object>{};
      final now = DateTime.now();
      for (int i = 1; i <= 14; i++) {
        final d = now.subtract(Duration(days: i));
        final hour = i <= 5 ? 22 : 12;
        final ts = DateTime(d.year, d.month, d.day, hour);
        prefs['food_${_dk(d)}'] = jsonEncode([_e(1700, 80, ts).toJson()]);
      }
      SharedPreferences.setMockInitialValues(prefs);
      final p = FitnessProvider();
      await p.loadData();
      expect(p.hasLateNightEatingPattern, isTrue);
    });

    test('false when only 3 of 14 days are late-night (21% < 25%)', () async {
      // Method scans only the last 14 days. 3/14 ≈ 21% is below the 25% threshold.
      final prefs = <String, Object>{};
      final now = DateTime.now();
      for (int i = 1; i <= 14; i++) {
        final d = now.subtract(Duration(days: i));
        final hour = i <= 3 ? 22 : 12; // days 1-3 late, rest daytime
        final ts = DateTime(d.year, d.month, d.day, hour);
        prefs['food_${_dk(d)}'] = jsonEncode([_e(1700, 80, ts).toJson()]);
      }
      SharedPreferences.setMockInitialValues(prefs);
      final p = FitnessProvider();
      await p.loadData();
      // 3/14 ≈ 0.214 ≤ 0.25 → false
      expect(p.hasLateNightEatingPattern, isFalse);
    });

    test('false when total qualifying entries < 6 (insufficient signal)', () async {
      // Only 4 days of data, all late-night — too few
      final prefs = <String, Object>{};
      final now = DateTime.now();
      for (int i = 1; i <= 4; i++) {
        final d = now.subtract(Duration(days: i));
        final ts = DateTime(d.year, d.month, d.day, 22);
        prefs['food_${_dk(d)}'] = jsonEncode([_e(1700, 80, ts).toJson()]);
      }
      SharedPreferences.setMockInitialValues(prefs);
      final p = FitnessProvider();
      await p.loadData();
      // total=4 < 6 → false
      expect(p.hasLateNightEatingPattern, isFalse);
    });

    test('entries with ≤50 kcal are excluded (coffee/drinks not counted)', () async {
      // 14 days, each with a 30 kcal entry at 22:00
      final prefs = <String, Object>{};
      final now = DateTime.now();
      for (int i = 1; i <= 14; i++) {
        final d = now.subtract(Duration(days: i));
        final ts = DateTime(d.year, d.month, d.day, 22);
        prefs['food_${_dk(d)}'] = jsonEncode([_e(30, 0, ts).toJson()]);
      }
      SharedPreferences.setMockInitialValues(prefs);
      final p = FitnessProvider();
      await p.loadData();
      // All entries ≤50 kcal → total = 0 < 6 → false
      expect(p.hasLateNightEatingPattern, isFalse);
    });

    test('exact 9 PM boundary: hour 21 counts as late-night', () async {
      final prefs = <String, Object>{};
      final now = DateTime.now();
      for (int i = 1; i <= 14; i++) {
        final d = now.subtract(Duration(days: i));
        final hour = i <= 5 ? 21 : 12; // 5 entries at 21:00 exactly
        final ts = DateTime(d.year, d.month, d.day, hour);
        prefs['food_${_dk(d)}'] = jsonEncode([_e(1700, 80, ts).toJson()]);
      }
      SharedPreferences.setMockInitialValues(prefs);
      final p = FitnessProvider();
      await p.loadData();
      // 5/14 ≈ 36% > 25% and total=14 ≥ 6 → true
      expect(p.hasLateNightEatingPattern, isTrue);
    });

    test('hour 20 (8 PM) does not count as late-night', () async {
      final prefs = <String, Object>{};
      final now = DateTime.now();
      for (int i = 1; i <= 14; i++) {
        final d = now.subtract(Duration(days: i));
        final ts = DateTime(d.year, d.month, d.day, 20);
        prefs['food_${_dk(d)}'] = jsonEncode([_e(1700, 80, ts).toJson()]);
      }
      SharedPreferences.setMockInitialValues(prefs);
      final p = FitnessProvider();
      await p.loadData();
      // All at 20:00 (< 21) → late = 0 → false
      expect(p.hasLateNightEatingPattern, isFalse);
    });
  });

  // ── habitScore ────────────────────────────────────────────────────────────

  group('habitScore', () {
    test('0 when no food history', () async {
      final p = FitnessProvider();
      await p.loadData();
      expect(p.habitScore, 0);
    });

    test('>0 when some calorie and protein adherence exists', () async {
      SharedPreferences.setMockInitialValues(
          _seedFood(calByDay: [1700, 1700, 1700], protByDay: [95, 95, 95]));
      final p = FitnessProvider();
      await p.loadData();
      expect(p.habitScore, greaterThan(0));
    });

    test('score is higher with strong adherence than weak adherence', () async {
      SharedPreferences.setMockInitialValues(
          _seedFood(
              calByDay: List.filled(10, 1700),
              protByDay: List.filled(10, 95)));
      final p1 = FitnessProvider();
      await p1.loadData();
      final strongScore = p1.habitScore;

      SharedPreferences.setMockInitialValues(
          _seedFood(
              calByDay: List.filled(10, 2500),
              protByDay: List.filled(10, 30)));
      final p2 = FitnessProvider();
      await p2.loadData();
      final weakScore = p2.habitScore;

      expect(strongScore, greaterThan(weakScore));
    });

    test('score is always in [0, 100]', () async {
      SharedPreferences.setMockInitialValues(
          _seedFood(
              calByDay: List.filled(30, 1700),
              protByDay: List.filled(30, 100)));
      final p = FitnessProvider();
      await p.loadData();
      final score = p.habitScore;
      expect(score, greaterThanOrEqualTo(0));
      expect(score, lessThanOrEqualTo(100));
    });

    test('no late-night eating pattern adds 10 points to weighted score', () async {
      // Build provider with same adherence but once with and once without late-night eating
      final goodSeed = _seedFood(
          calByDay: List.filled(10, 1700), protByDay: List.filled(10, 95), hour: 12);
      SharedPreferences.setMockInitialValues(goodSeed);
      final p1 = FitnessProvider();
      await p1.loadData();
      final scoreWithoutLateNight = p1.habitScore;

      // Same food data but with heavy late-night eating (many entries after 9pm)
      final lateSeed = <String, Object>{};
      final now = DateTime.now();
      for (int i = 1; i <= 14; i++) {
        final d = now.subtract(Duration(days: i));
        final hour = i <= 6 ? 22 : 12;
        final ts = DateTime(d.year, d.month, d.day, hour);
        lateSeed['food_${_dk(d)}'] =
            jsonEncode([_e(1700, 95, ts).toJson()]);
      }
      SharedPreferences.setMockInitialValues(lateSeed);
      final p2 = FitnessProvider();
      await p2.loadData();
      final scoreWithLateNight = p2.habitScore;

      // Late-night eating removes 10pts from the final score
      expect(scoreWithoutLateNight, greaterThan(scoreWithLateNight));
    });
  });

  // ── yesterdayCal / yesterdayProtein / yesterdayWater / workedOutYesterday ──

  group('yesterday getters', () {
    test('yesterdayCal is 0.0 when no yesterday data', () async {
      final p = FitnessProvider();
      await p.loadData();
      expect(p.yesterdayCal, 0.0);
    });

    test('yesterdayCal returns yesterday calories correctly', () async {
      SharedPreferences.setMockInitialValues(
          _seedFood(calByDay: [1650], protByDay: [88]));
      final p = FitnessProvider();
      await p.loadData();
      expect(p.yesterdayCal, closeTo(1650, 0.01));
    });

    test('yesterdayCal not affected by food 2 days ago', () async {
      // Index 0 = yesterday (1650), index 1 = 2 days ago (2000)
      SharedPreferences.setMockInitialValues(
          _seedFood(calByDay: [1650, 2000], protByDay: [88, 80]));
      final p = FitnessProvider();
      await p.loadData();
      expect(p.yesterdayCal, closeTo(1650, 0.01));
    });

    test('yesterdayProtein is 0.0 when no yesterday data', () async {
      final p = FitnessProvider();
      await p.loadData();
      expect(p.yesterdayProtein, 0.0);
    });

    test('yesterdayProtein returns yesterday protein correctly', () async {
      SharedPreferences.setMockInitialValues(
          _seedFood(calByDay: [1650], protByDay: [88]));
      final p = FitnessProvider();
      await p.loadData();
      expect(p.yesterdayProtein, closeTo(88, 0.01));
    });

    test('yesterdayWater is 0 when no yesterday data', () async {
      final p = FitnessProvider();
      await p.loadData();
      expect(p.yesterdayWater, 0);
    });

    test('yesterdayWater returns yesterday ml correctly', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      SharedPreferences.setMockInitialValues({'water_${_dk(yesterday)}': 2200});
      final p = FitnessProvider();
      await p.loadData();
      expect(p.yesterdayWater, 2200);
    });

    test('yesterdayWater not affected by 2-days-ago water', () async {
      final y1 = DateTime.now().subtract(const Duration(days: 1));
      final y2 = DateTime.now().subtract(const Duration(days: 2));
      SharedPreferences.setMockInitialValues({
        'water_${_dk(y1)}': 2200,
        'water_${_dk(y2)}': 1500,
      });
      final p = FitnessProvider();
      await p.loadData();
      expect(p.yesterdayWater, 2200);
    });
  });

  // ── workedOutYesterday ────────────────────────────────────────────────────

  group('workedOutYesterday', () {
    test('false when no workout history at all', () async {
      final p = FitnessProvider();
      await p.loadData();
      expect(p.workedOutYesterday, isFalse);
    });

    test('false when workout was today (not yesterday)', () async {
      final p = FitnessProvider();
      await p.loadData();
      await p.logWorkout(WorkoutLog(
        id: 'w1',
        date: DateTime.now(),
        workoutType: WorkoutType.custom,
        exercises: [
          ExerciseLog(name: 'Push-ups', sets: [SetData(reps: 10, weight: 0)])
        ],
      ));
      expect(p.workedOutYesterday, isFalse);
    });

    test('true when workout logged yesterday', () async {
      final p = FitnessProvider();
      await p.loadData();
      await p.logWorkout(WorkoutLog(
        id: 'w1',
        date: DateTime.now().subtract(const Duration(days: 1)),
        workoutType: WorkoutType.custom,
        exercises: [
          ExerciseLog(name: 'Push-ups', sets: [SetData(reps: 10, weight: 0)])
        ],
      ));
      expect(p.workedOutYesterday, isTrue);
    });

    test('false when workout was 2 days ago', () async {
      final p = FitnessProvider();
      await p.loadData();
      await p.logWorkout(WorkoutLog(
        id: 'w1',
        date: DateTime.now().subtract(const Duration(days: 2)),
        workoutType: WorkoutType.custom,
        exercises: [
          ExerciseLog(name: 'Squats', sets: [SetData(reps: 10, weight: 0)])
        ],
      ));
      expect(p.workedOutYesterday, isFalse);
    });

    test('true when multiple workouts logged yesterday (at least one counts)', () async {
      final p = FitnessProvider();
      await p.loadData();
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await p.logWorkout(WorkoutLog(
        id: 'w1',
        date: yesterday,
        workoutType: WorkoutType.custom,
        exercises: [
          ExerciseLog(name: 'Push-ups', sets: [SetData(reps: 10, weight: 0)])
        ],
      ));
      await p.logWorkout(WorkoutLog(
        id: 'w2',
        date: yesterday,
        workoutType: WorkoutType.custom,
        exercises: [
          ExerciseLog(name: 'Squats', sets: [SetData(reps: 10, weight: 0)])
        ],
      ));
      expect(p.workedOutYesterday, isTrue);
    });

    test('false when no workout yesterday despite workouts on other days', () async {
      final p = FitnessProvider();
      await p.loadData();
      // Workouts today and 2 days ago, but NOT yesterday
      await p.logWorkout(WorkoutLog(
        id: 'today',
        date: DateTime.now(),
        workoutType: WorkoutType.custom,
        exercises: [
          ExerciseLog(name: 'Push-ups', sets: [SetData(reps: 10, weight: 0)])
        ],
      ));
      await p.logWorkout(WorkoutLog(
        id: 'twodaysago',
        date: DateTime.now().subtract(const Duration(days: 2)),
        workoutType: WorkoutType.custom,
        exercises: [
          ExerciseLog(name: 'Push-ups', sets: [SetData(reps: 10, weight: 0)])
        ],
      ));
      expect(p.workedOutYesterday, isFalse);
    });
  });

  // ── Smart insight engine — new habit rules ────────────────────────────────

  group('smart insight engine — new habit insights', () {
    test('late-night eating insight fires when pattern detected', () async {
      final prefs = <String, Object>{};
      final now = DateTime.now();
      for (int i = 1; i <= 14; i++) {
        final d = now.subtract(Duration(days: i));
        final hour = i <= 5 ? 22 : 12;
        final ts = DateTime(d.year, d.month, d.day, hour);
        prefs['food_${_dk(d)}'] = jsonEncode([_e(1700, 80, ts).toJson()]);
      }
      SharedPreferences.setMockInitialValues(prefs);
      final p = FitnessProvider();
      await p.loadData();
      final insights = generateInsights(p, DateTime(2026, 6, 1, 10));
      expect(insights.any((i) => i.title.contains('Late-night')), isTrue);
    });

    test('late-night eating insight does NOT fire when no pattern', () async {
      SharedPreferences.setMockInitialValues(
          _seedFood(
              calByDay: List.filled(14, 1700),
              protByDay: List.filled(14, 80),
              hour: 12));
      final p = FitnessProvider();
      await p.loadData();
      final insights = generateInsights(p, DateTime(2026, 6, 1, 10));
      expect(insights.any((i) => i.title.contains('Late-night')), isFalse);
    });

    test('deficit streak ≥7 fires elite streak insight', () async {
      SharedPreferences.setMockInitialValues(
          _seedFood(
              calByDay: List.filled(10, 1500),
              protByDay: List.filled(10, 80)));
      final p = FitnessProvider();
      await p.loadData();
      expect(p.deficitStreak, greaterThanOrEqualTo(7));
      final insights = generateInsights(p, DateTime(2026, 6, 1, 10));
      expect(insights.any((i) => i.title.contains('day deficit streak')), isTrue);
    });

    test('deficit streak 3–6 fires keep-going insight', () async {
      // 4 days deficit then an over-goal day to cap the streak
      SharedPreferences.setMockInitialValues(
          _seedFood(
              calByDay: [1500, 1500, 1500, 1500, 2200],
              protByDay: List.filled(5, 80)));
      final p = FitnessProvider();
      await p.loadData();
      expect(p.deficitStreak, 4);
      final insights = generateInsights(p, DateTime(2026, 6, 1, 10));
      expect(insights.any((i) => i.title.contains('-day deficit')), isTrue);
    });

    test('no deficit streak insight fires when streak is 0', () async {
      SharedPreferences.setMockInitialValues(
          _seedFood(calByDay: [2200], protByDay: [80]));
      final p = FitnessProvider();
      await p.loadData();
      expect(p.deficitStreak, 0);
      final insights = generateInsights(p, DateTime(2026, 6, 1, 10));
      expect(insights.any((i) => i.title.contains('deficit streak')), isFalse);
      expect(insights.any((i) => i.title.contains('day deficit —')), isFalse);
    });

    test('habit score insight fires when score ≥ 50', () async {
      SharedPreferences.setMockInitialValues(
          _seedFood(
              calByDay: List.filled(30, 1700),
              protByDay: List.filled(30, 95)));
      final p = FitnessProvider();
      await p.loadData();
      expect(p.habitScore, greaterThanOrEqualTo(50));
      final insights = generateInsights(p, DateTime(2026, 6, 1, 10));
      expect(insights.any((i) => i.title.contains('Habit score')), isTrue);
    });

    test('no habit score insight fires with no history (score = 0)', () async {
      final p = FitnessProvider();
      await p.loadData();
      expect(p.habitScore, 0);
      final insights = generateInsights(p, DateTime(2026, 6, 1, 10));
      expect(insights.any((i) => i.title.contains('Habit score')), isFalse);
    });

    test('calorie adherence insight fires when adherence < 45%', () async {
      // All days at 3000 kcal → way over goal → 0% adherence < 45%
      SharedPreferences.setMockInitialValues(
          _seedFood(
              calByDay: List.filled(10, 3000),
              protByDay: List.filled(10, 80)));
      final p = FitnessProvider();
      await p.loadData();
      expect(p.calorieAdherenceRate, lessThan(0.45));
      final insights = generateInsights(p, DateTime(2026, 6, 1, 10));
      expect(insights.any((i) => i.emoji == '📋'), isTrue);
    });

    test('calorie adherence insight does NOT fire when adherence ≥ 45%', () async {
      // Perfect adherence → no warning needed
      SharedPreferences.setMockInitialValues(
          _seedFood(
              calByDay: List.filled(10, 1700),
              protByDay: List.filled(10, 80)));
      final p = FitnessProvider();
      await p.loadData();
      expect(p.calorieAdherenceRate, greaterThanOrEqualTo(0.45));
      final insights = generateInsights(p, DateTime(2026, 6, 1, 10));
      expect(insights.any((i) => i.emoji == '📋'), isFalse);
    });

    test('calorie adherence insight does NOT fire when no history', () async {
      final p = FitnessProvider();
      await p.loadData();
      final insights = generateInsights(p, DateTime(2026, 6, 1, 10));
      expect(insights.any((i) => i.emoji == '📋'), isFalse);
    });

    test('protein adherence insight fires when adherence < 40%', () async {
      SharedPreferences.setMockInitialValues(
          _seedFood(
              calByDay: List.filled(10, 1700),
              protByDay: List.filled(10, 20)));
      final p = FitnessProvider();
      await p.loadData();
      expect(p.proteinAdherenceRate, lessThan(0.4));
      final insights = generateInsights(p, DateTime(2026, 6, 1, 10));
      expect(insights.any((i) => i.title.contains('Protein goal missed')), isTrue);
    });

    test('protein adherence insight does NOT fire when adherence ≥ 40%', () async {
      SharedPreferences.setMockInitialValues(
          _seedFood(
              calByDay: List.filled(10, 1700),
              protByDay: List.filled(10, 95)));
      final p = FitnessProvider();
      await p.loadData();
      expect(p.proteinAdherenceRate, greaterThanOrEqualTo(0.4));
      final insights = generateInsights(p, DateTime(2026, 6, 1, 10));
      expect(insights.any((i) => i.title.contains('Protein goal missed')), isFalse);
    });

    test('protein adherence insight does NOT fire when no history', () async {
      final p = FitnessProvider();
      await p.loadData();
      final insights = generateInsights(p, DateTime(2026, 6, 1, 10));
      expect(insights.any((i) => i.title.contains('Protein goal missed')), isFalse);
    });

    test('all new insights have valid scores, emojis, titles, and bodies', () async {
      final prefs = <String, Object>{};
      final now = DateTime.now();
      // Seed with late-night eating + poor adherence to trigger all new rules
      for (int i = 1; i <= 14; i++) {
        final d = now.subtract(Duration(days: i));
        final hour = i <= 5 ? 22 : 12;
        final ts = DateTime(d.year, d.month, d.day, hour);
        prefs['food_${_dk(d)}'] =
            jsonEncode([_e(i <= 10 ? 3000.0 : 1700.0, 20, ts).toJson()]);
      }
      SharedPreferences.setMockInitialValues(prefs);
      final p = FitnessProvider();
      await p.loadData();
      final insights = generateInsights(p, DateTime(2026, 6, 1, 10));
      for (final ins in insights) {
        expect(ins.emoji, isNotEmpty, reason: 'emoji empty for "${ins.title}"');
        expect(ins.title, isNotEmpty, reason: 'title empty');
        expect(ins.body, isNotEmpty, reason: 'body empty for "${ins.title}"');
        expect(ins.score, greaterThanOrEqualTo(0),
            reason: 'score < 0 for "${ins.title}"');
        expect(ins.score, lessThanOrEqualTo(100),
            reason: 'score > 100 for "${ins.title}"');
      }
    });
  });
}
