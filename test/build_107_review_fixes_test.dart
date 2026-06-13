import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:kfit/models/models.dart';
import 'package:kfit/providers/fitness_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tests for the Build 107 review fixes:
///  • net-calorie / deficit verdict made time-of-day stable (projectedDayBurn /
///    projectedInDeficit)
///  • whey supplement no longer double-counts a logged whey shake
///  • adaptiveTdee excludes today's partial day
///  • per-entry effective macros + honest "estimated" flag
///  • food database macro-completeness consistency across duplicate names
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ── Time-of-day-stable energy balance ──────────────────────────────────────
  group('projectedDayBurn / projectedInDeficit', () {
    late FitnessProvider p;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      p = FitnessProvider();
      await p.loadData();
    });

    test('projectedDayBurn is null-equivalent (0) with no weight logged', () {
      expect(p.bmr, isNull);
      expect(p.projectedDayBurn, 0);
      expect(p.projectedInDeficit, isNull); // no signal → neutral
    });

    test('projectedDayBurn uses FULL-day BMR, not the prorated resting burn',
        () async {
      await p.logBodyEntry(weightKg: 80);
      final bmr = p.bmr!;
      // No steps, no workout → projected day burn equals the full-day BMR.
      expect(p.projectedDayBurn, closeTo(bmr, 0.001));
      // ...and is always >= the time-prorated resting burn (the old, volatile basis).
      expect(p.projectedDayBurn, greaterThanOrEqualTo(p.restingCaloriesBurned));
    });

    test('projectedInDeficit is null with weight but no intake projection',
        () async {
      await p.logBodyEntry(weightKg: 80);
      // No food logged → projectedEodCalories is null → verdict stays neutral.
      expect(p.projectedEodCalories, isNull);
      expect(p.projectedInDeficit, isNull);
    });

    test('projectedInDeficit agrees with eod-intake vs full-day-burn', () async {
      await p.logBodyEntry(weightKg: 80);
      await p.addFoodEntry(FoodEntry(
        id: 'a', name: 'Lunch', calories: 700, protein: 40,
        mealType: MealType.lunch, timestamp: DateTime.now(),
      ));
      // Relationship holds regardless of the wall-clock hour the test runs at:
      final eod = p.projectedEodCalories;
      if (eod != null) {
        expect(p.projectedInDeficit, eod < p.projectedDayBurn);
      } else {
        expect(p.projectedInDeficit, isNull);
      }
    });
  });

  // ── Whey double-count reconciliation ───────────────────────────────────────
  group('whey supplement vs logged shake', () {
    late FitnessProvider p;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      p = FitnessProvider();
      await p.loadData();
    });

    test('whey toggle alone adds 120 kcal / 25 g', () async {
      await p.updateSupplement('whey', true);
      expect(p.supplementCalories, 120);
      expect(p.supplementProtein, 25);
    });

    test('a logged whey shake suppresses the supplement contribution', () async {
      await p.updateSupplement('whey', true);
      await p.addFoodEntry(FoodEntry(
        id: 'w', name: 'Whey Protein Shake', calories: 130, protein: 25,
        carbs: 3, fat: 1.5, mealType: MealType.snack, timestamp: DateTime.now(),
      ));
      // No double count: the scoop is already in the food log.
      expect(p.supplementCalories, 0);
      expect(p.supplementProtein, 0);
      // Total reflects the shake once (130), not 130 + 120.
      expect(p.todayCaloriesTotal, closeTo(130, 0.001));
      expect(p.todayProteinTotal, closeTo(25, 0.001));
    });

    test('non-whey food does not suppress the supplement', () async {
      await p.updateSupplement('whey', true);
      await p.addFoodEntry(FoodEntry(
        id: 'r', name: 'Roti', calories: 104, protein: 3,
        mealType: MealType.dinner, timestamp: DateTime.now(),
      ));
      expect(p.supplementCalories, 120);
      expect(p.supplementProtein, 25);
    });
  });

  // ── Per-entry effective macros + honest estimated flag ──────────────────────
  group('effective macros & todayMacrosEstimated', () {
    test('FoodEntry.effectiveCarbs/Fat use real values when present', () {
      final e = FoodEntry(
        id: 'p', name: 'Paneer', calories: 265, protein: 18, carbs: 3.5, fat: 20,
        mealType: MealType.lunch, timestamp: DateTime(2026, 1, 1),
      );
      expect(e.hasRealMacros, isTrue);
      expect(e.effectiveCarbs, 3.5);
      expect(e.effectiveFat, 20);
    });

    test('FoodEntry.effectiveCarbs/Fat fall back to 65/35 when absent', () {
      final e = FoodEntry(
        id: 'x', name: 'Mystery', calories: 200, protein: 0,
        mealType: MealType.snack, timestamp: DateTime(2026, 1, 1),
      );
      expect(e.hasRealMacros, isFalse);
      expect(e.effectiveCarbs, closeTo(32.5, 0.01)); // 200*0.65/4
      expect(e.effectiveFat, closeTo(7.78, 0.05)); // 200*0.35/9
    });

    late FitnessProvider p;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      p = FitnessProvider();
      await p.loadData();
    });

    test('all-real-macro day is NOT flagged estimated', () async {
      await p.addFoodEntry(FoodEntry(
        id: 'a', name: 'Roti', calories: 104, protein: 3, carbs: 18, fat: 2.5,
        mealType: MealType.lunch, timestamp: DateTime.now(),
      ));
      expect(p.todayMacrosEstimated, isFalse);
      expect(p.todayCarbsEstimate, closeTo(18, 0.001));
      expect(p.todayFatEstimate, closeTo(2.5, 0.001));
    });

    test('a macro-less entry flags the day estimated and is summed per-entry',
        () async {
      await p.addFoodEntry(FoodEntry(
        id: 'a', name: 'Paneer', calories: 265, protein: 18, carbs: 3.5, fat: 20,
        mealType: MealType.lunch, timestamp: DateTime.now(),
      ));
      await p.addFoodEntry(FoodEntry(
        id: 'b', name: 'Custom', calories: 500, protein: 25, // no macros
        mealType: MealType.dinner, timestamp: DateTime.now(),
      ));
      expect(p.todayMacrosEstimated, isTrue);
      // Per-entry: 3.5 (real) + (500-100)*0.65/4 = 3.5 + 65 = 68.5
      expect(p.todayCarbsEstimate, closeTo(68.5, 0.01));
      // 20 (real) + (500-100)*0.35/9 = 20 + 15.56 = 35.56
      expect(p.todayFatEstimate, closeTo(35.56, 0.05));
    });

    test('empty day is not flagged estimated', () {
      expect(p.todayMacrosEstimated, isFalse);
      expect(p.todayCarbsEstimate, 0);
      expect(p.todayFatEstimate, 0);
    });
  });

  // ── adaptiveTdee excludes today's partial day ──────────────────────────────
  group('adaptiveTdee', () {
    test('is computed from history and is unaffected by today\'s partial intake',
        () async {
      final now = DateTime.now();
      final prefs = <String, Object>{};

      // 8 weight logs over the last 14 days, gently trending down (~0.5 kg/wk).
      final body = <Map<String, dynamic>>[];
      for (final ago in [14, 12, 10, 8, 6, 4, 2, 0]) {
        final d = now.subtract(Duration(days: ago));
        body.add(BodyEntry(
          id: 'b$ago', date: d, weightKg: 80.0 - (14 - ago) * 0.07, steps: 0,
        ).toJson());
      }
      prefs['body_history'] = jsonEncode(body);

      // 1500 kcal logged on each of the past 14 days (not today).
      for (var ago = 1; ago <= 14; ago++) {
        final d = now.subtract(Duration(days: ago));
        prefs['food_${dayKey(d)}'] = jsonEncode([
          FoodEntry(
            id: 'f$ago', name: 'Meal', calories: 1500, protein: 80,
            mealType: MealType.lunch, timestamp: d,
          ).toJson(),
        ]);
      }

      SharedPreferences.setMockInitialValues(prefs);
      final p = FitnessProvider();
      await p.loadData();

      final before = p.adaptiveTdee;
      expect(before, isNotNull);
      expect(before, inInclusiveRange(1200.0, 4500.0));
      expect(p.isTdeeCalibrated, isTrue);

      // Logging a small partial intake TODAY must not move the calibrated TDEE
      // (today is excluded from the energy-balance average).
      await p.addFoodEntry(FoodEntry(
        id: 'today', name: 'Snack', calories: 200, protein: 5,
        mealType: MealType.snack, timestamp: DateTime.now(),
      ));
      expect(p.adaptiveTdee, closeTo(before!, 0.001));
    });
  });

  // ── Food database macro-completeness consistency ───────────────────────────
  group('food database', () {
    test('all copies of a food name agree on macro completeness', () {
      final byName = <String, List<FoodItem>>{};
      for (final f in kFoodDatabase) {
        byName.putIfAbsent(f.name, () => []).add(f);
      }
      final offenders = <String>[];
      for (final e in byName.entries) {
        final hasReal = e.value.map((f) => f.hasRealMacros).toSet();
        if (hasReal.length > 1) offenders.add(e.key);
      }
      expect(offenders, isEmpty,
          reason: 'These foods have copies that disagree on real-vs-estimated '
              'macros (donut would change by which copy is tapped): $offenders');
    });

    test('entries sharing name + calories + protein have identical macros', () {
      final byKey = <String, FoodItem>{};
      final offenders = <String>[];
      for (final f in kFoodDatabase) {
        final k = '${f.name}|${f.calories}|${f.protein}';
        final prev = byKey[k];
        if (prev == null) {
          byKey[k] = f;
        } else if (prev.carbs != f.carbs || prev.fat != f.fat) {
          offenders.add(k);
        }
      }
      expect(offenders, isEmpty, reason: 'Inconsistent macros: $offenders');
    });
  });
}
