// Accuracy fixes — regression tests.
//
// 1. Weekday averages exclude today (partial day) so projectedEodCalories can
//    no longer reference its own partial total and bias the projection low.
// 2. adaptiveTdee regresses the weight trend over the SAME 60-day window it
//    averages intake on (was: 90-day slope vs ≤60-day intake — mismatched).
// 3. weeksToGoal returns null when the measured trend is GAINING while the
//    user needs to lose (was: fell through to a fictional deficit-based ETA).
// 4. FoodEntry/FoodItem/FoodApiResult carry an explicit macrosKnown flag so a
//    genuinely zero-carb/zero-fat food (black coffee, egg whites) is not
//    re-estimated via the 65/35 split nor flags the day "estimated".
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kfit/models/models.dart';
import 'package:kfit/providers/fitness_provider.dart';
import 'package:kfit/services/food_api_service.dart';
import 'package:kfit/services/food_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _dk(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

FoodEntry _food(String id, double cal, double prot,
        {double carbs = 0, double fat = 0, bool? macrosKnown, DateTime? ts}) =>
    FoodEntry(
      id: id,
      name: 'Food $id',
      calories: cal,
      protein: prot,
      carbs: carbs,
      fat: fat,
      macrosKnown: macrosKnown,
      mealType: MealType.lunch,
      timestamp: ts ?? DateTime.now(),
    );

/// Seeds `food_YYYY-MM-DD` prefs for past days: index 0 = 1 day ago.
Map<String, Object> _seedFood(List<num> calByDay) {
  final prefs = <String, Object>{};
  final now = DateTime.now();
  for (int i = 0; i < calByDay.length; i++) {
    if (calByDay[i] == 0) continue;
    final d = now.subtract(Duration(days: i + 1));
    final ts = DateTime(d.year, d.month, d.day, 13);
    prefs['food_${_dk(d)}'] = jsonEncode([
      _food('s$i', calByDay[i].toDouble(), 50, ts: ts).toJson(),
    ]);
  }
  return prefs;
}

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

  // ── 1. Weekday averages exclude today ──────────────────────────────────────
  group('weekday averages exclude today (partial day)', () {
    test('only today logged → weekday average is null, not the partial total',
        () async {
      final p = FitnessProvider();
      await p.loadData();
      await p.addFoodEntry(_food('t', 300, 20));
      // Today's 300 kcal must NOT count as this weekday's "history".
      expect(p.caloriesAvgForWeekday(DateTime.now().weekday), isNull);
      expect(p.proteinAvgForWeekday(DateTime.now().weekday), isNull);
    });

    test('average uses prior same-weekday days only, unmoved by today\'s log',
        () async {
      // Seed the same weekday 7 and 14 days ago with 2000 / 1800 kcal.
      final seed = <String, Object>{};
      final now = DateTime.now();
      for (final (ago, cal) in [(7, 2000.0), (14, 1800.0)]) {
        final d = now.subtract(Duration(days: ago));
        final ts = DateTime(d.year, d.month, d.day, 13);
        seed['food_${_dk(d)}'] =
            jsonEncode([_food('a$ago', cal, 50, ts: ts).toJson()]);
      }
      SharedPreferences.setMockInitialValues(seed);
      final p = FitnessProvider();
      await p.loadData();
      expect(p.caloriesAvgForWeekday(now.weekday), closeTo(1900, 0.01));

      // Logging a tiny partial today must not drag the average down.
      await p.addFoodEntry(_food('t', 100, 5));
      expect(p.caloriesAvgForWeekday(now.weekday), closeTo(1900, 0.01));
    });

    test('other weekdays unaffected (still averaged from history)', () async {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final ts = DateTime(yesterday.year, yesterday.month, yesterday.day, 13);
      SharedPreferences.setMockInitialValues({
        'food_${_dk(yesterday)}':
            jsonEncode([_food('y', 1500, 60, ts: ts).toJson()]),
      });
      final p = FitnessProvider();
      await p.loadData();
      expect(p.caloriesAvgForWeekday(yesterday.weekday), closeTo(1500, 0.01));
    });
  });

  // ── 2. adaptiveTdee — slope and intake over the same 60-day window ────────
  group('adaptiveTdee window consistency', () {
    test('old weight entries beyond 60 days do not skew the trend', () async {
      // Last 15 days: dead-flat 75.0 kg (5 logs, span ≥ 7 days).
      // Days 65–85: 85 kg — a steep fake "loss" if a 90-day slope were used.
      // Intake: 2000 kcal/day over the recent window.
      SharedPreferences.setMockInitialValues(
          _seedFood(List.filled(15, 2000)));
      final p = FitnessProvider();
      await p.loadData();
      await p.saveHeight(170);
      await p.saveAge(24);
      final now = DateTime.now();
      for (final ago in [85, 75, 65]) {
        await p.logBodyEntry(
            weightKg: 85, date: now.subtract(Duration(days: ago)));
      }
      for (final ago in [15, 12, 9, 5, 1]) {
        await p.logBodyEntry(
            weightKg: 75, date: now.subtract(Duration(days: ago)));
      }
      final t = p.adaptiveTdee;
      expect(t, isNotNull);
      // Flat 60-day trend ⇒ maintenance ≈ recent average intake (2000), NOT
      // 2000 + (10 kg / ~10 wk × 7700/7 ≈ +1100) from the stale 90-day slope.
      expect(t!, closeTo(2000, 100));
    });

    test('still calibrates from a real recent trend (losing)', () async {
      // Losing ~0.35 kg/week over 28 days while eating 1800.
      SharedPreferences.setMockInitialValues(
          _seedFood(List.filled(28, 1800)));
      final p = FitnessProvider();
      await p.loadData();
      await p.saveHeight(170);
      await p.saveAge(24);
      final now = DateTime.now();
      for (int ago = 28; ago >= 0; ago -= 4) {
        final w = 77.0 - (28 - ago) * 0.05; // −0.05 kg/day = −0.35 kg/wk
        await p.logBodyEntry(
            weightKg: w, date: now.subtract(Duration(days: ago)));
      }
      final t = p.adaptiveTdee;
      expect(t, isNotNull);
      // TDEE = 1800 − (−0.35 × 7700/7) = 1800 + 385 = 2185.
      expect(t!, closeTo(2185, 120));
      expect(p.isTdeeCalibrated, isTrue);
      expect(p.bestTdee, equals(t));
    });

    test('null with fewer than 5 weight logs in the last 60 days', () async {
      SharedPreferences.setMockInitialValues(
          _seedFood(List.filled(10, 1800)));
      final p = FitnessProvider();
      await p.loadData();
      final now = DateTime.now();
      // 5+ logs overall, but only 3 within 60 days.
      for (final ago in [85, 75, 65, 10, 5, 1]) {
        await p.logBodyEntry(
            weightKg: 80, date: now.subtract(Duration(days: ago)));
      }
      expect(p.adaptiveTdee, isNull);
    });
  });

  // ── 3. weeksToGoal — no fictional ETA while gaining ────────────────────────
  group('weeksToGoal gaining-trend honesty', () {
    Future<FitnessProvider> gaining() async {
      final p = FitnessProvider();
      await p.loadData();
      await p.saveHeight(170);
      await p.saveAge(24);
      await p.saveGoalWeight(70);
      final now = DateTime.now();
      // Clear upward trend: +0.1 kg/day over 20 days, ending at 77 kg.
      for (int ago = 20; ago >= 0; ago -= 4) {
        await p.logBodyEntry(
            weightKg: 75 + (20 - ago) * 0.1,
            date: now.subtract(Duration(days: ago)));
      }
      return p;
    }

    test('gaining while needing to lose → null (no fake ETA)', () async {
      final p = await gaining();
      expect(p.kgToGoal, greaterThan(0)); // above goal weight
      expect(p.weeklyWeightChange, greaterThan(0.05)); // measurably gaining
      // bestTdee exists (weight + height), so the OLD code would have produced
      // a deficit-based ETA here. Now: no estimate while the trend contradicts.
      expect(p.bestTdee, isNotNull);
      expect(p.weeksToGoal, isNull);
    });

    test('losing trend still produces an ETA', () async {
      final p = FitnessProvider();
      await p.loadData();
      await p.saveHeight(170);
      await p.saveAge(24);
      await p.saveGoalWeight(70);
      final now = DateTime.now();
      for (int ago = 20; ago >= 0; ago -= 4) {
        await p.logBodyEntry(
            weightKg: 77 - (20 - ago) * 0.05,
            date: now.subtract(Duration(days: ago)));
      }
      expect(p.weeklyWeightChange, lessThan(-0.05));
      expect(p.weeksToGoal, isNotNull);
      expect(p.weeksToGoal!, greaterThan(0));
    });

    test('flat trend falls back to sustainable-deficit projection', () async {
      final p = FitnessProvider();
      await p.loadData();
      await p.saveHeight(170);
      await p.saveAge(24);
      await p.saveGoalWeight(70);
      final now = DateTime.now();
      for (int ago = 20; ago >= 0; ago -= 4) {
        await p.logBodyEntry(
            weightKg: 76, date: now.subtract(Duration(days: ago)));
      }
      // slope == 0 → neither branch triggers → fallback ETA from bestTdee.
      expect(p.weeksToGoal, isNotNull);
    });
  });

  // ── 4. macrosKnown — zero-macro foods are real, not "estimated" ───────────
  group('FoodEntry.macrosKnown', () {
    test('explicit true with 0 carbs / 0 fat → no 65/35 estimate', () {
      final coffee = _food('c', 5, 0.3, macrosKnown: true);
      expect(coffee.hasRealMacros, isTrue);
      expect(coffee.effectiveCarbs, 0);
      expect(coffee.effectiveFat, 0);
    });

    test('default (legacy) heuristic unchanged: 0/0 → estimated', () {
      final unknown = _food('u', 400, 10);
      expect(unknown.hasRealMacros, isFalse);
      // 65/35 split of non-protein calories: (400−40)×0.65/4 and ×0.35/9.
      expect(unknown.effectiveCarbs, closeTo((400 - 40) * 0.65 / 4, 0.01));
      expect(unknown.effectiveFat, closeTo((400 - 40) * 0.35 / 9, 0.01));
    });

    test('default heuristic: any positive macro → known', () {
      expect(_food('a', 100, 5, carbs: 12).hasRealMacros, isTrue);
      expect(_food('b', 100, 5, fat: 8).hasRealMacros, isTrue);
    });

    test('JSON round-trip preserves the flag; legacy JSON infers it', () {
      final coffee = _food('c', 5, 0.3, macrosKnown: true);
      final revived = FoodEntry.fromJson(coffee.toJson());
      expect(revived.macrosKnown, isTrue);
      expect(revived.effectiveCarbs, 0);

      // Legacy payload (no macrosKnown key) → old heuristic.
      final legacy = coffee.toJson()..remove('macrosKnown');
      expect(FoodEntry.fromJson(legacy).macrosKnown, isFalse);
      final legacyReal = _food('r', 200, 10, carbs: 30).toJson()
        ..remove('macrosKnown');
      expect(FoodEntry.fromJson(legacyReal).macrosKnown, isTrue);
    });

    test('black coffee no longer flags the whole day "estimated"', () async {
      final p = FitnessProvider();
      await p.loadData();
      await p.addFoodEntry(_food('dal', 300, 12, carbs: 45, fat: 8));
      await p.addFoodEntry(_food('coffee', 5, 0.3, macrosKnown: true));
      expect(p.todayMacrosEstimated, isFalse);
      // And the donut gets 0 extra carbs/fat from the coffee.
      expect(p.todayCarbsEstimate, closeTo(45, 0.01));
      expect(p.todayFatEstimate, closeTo(8, 0.01));
    });

    test('a genuinely unknown entry still flags the day', () async {
      final p = FitnessProvider();
      await p.loadData();
      await p.addFoodEntry(_food('dal', 300, 12, carbs: 45, fat: 8));
      await p.addFoodEntry(_food('mystery', 400, 10)); // no macro data
      expect(p.todayMacrosEstimated, isTrue);
    });
  });

  group('FoodItem / IFCT macrosKnown', () {
    test('IFCT rows are lab data — macros known even at 0/0', () {
      final items = FoodRepository.parseIfct(jsonEncode([
        {'name': 'Egg white, raw', 'kcal': 45, 'protein': 10.8, 'carb': 0, 'fat': 0},
      ]));
      expect(items, hasLength(1));
      expect(items.first.hasRealMacros, isTrue);
      expect(items.first.effectiveCarbs, 0);
      expect(items.first.effectiveFat, 0);
    });

    test('curated default keeps the legacy heuristic', () {
      const known = FoodItem(
          name: 'Rice', calories: 130, protein: 2.7, carbs: 28, fat: 0.3,
          category: 'Grains', emoji: '🍚');
      const unknown = FoodItem(
          name: 'Mystery', calories: 200, protein: 5,
          category: 'Other', emoji: '❓');
      expect(known.macrosKnown, isTrue);
      expect(unknown.macrosKnown, isFalse);
    });
  });

  group('FoodApiResult macrosKnown', () {
    test('OFF: macro fields PRESENT (even zero) → known', () {
      final results = FoodApiService.parseOffSearchBody({
        'products': [
          {
            'product_name': 'Diet Cola',
            'nutriments': {
              'energy-kcal_100g': 1,
              'proteins_100g': 0,
              'carbohydrates_100g': 0,
              'fat_100g': 0,
            },
          },
        ],
      });
      expect(results, hasLength(1));
      expect(results.first.macrosKnown, isTrue);
    });

    test('OFF: macro fields ABSENT → unknown (defaulted zeros untrusted)', () {
      final results = FoodApiService.parseOffSearchBody({
        'products': [
          {
            'product_name': 'Sparse Product',
            'nutriments': {'energy-kcal_100g': 250, 'proteins_100g': 6},
          },
        ],
      });
      expect(results, hasLength(1));
      expect(results.first.macrosKnown, isFalse);
    });

    test('USDA: nutrient rows 204/205 present (value 0) → known', () {
      final results = FoodApiService.parseUsdaSearchBody({
        'foods': [
          {
            'description': 'Egg White',
            'foodNutrients': [
              {'nutrientNumber': '208', 'value': 52},
              {'nutrientNumber': '203', 'value': 11},
              {'nutrientNumber': '204', 'value': 0},
              {'nutrientNumber': '205', 'value': 0},
            ],
          },
        ],
      });
      expect(results, hasLength(1));
      expect(results.first.macrosKnown, isTrue);
    });

    test('USDA: no macro nutrient rows → unknown', () {
      final results = FoodApiService.parseUsdaSearchBody({
        'foods': [
          {
            'description': 'Sparse',
            'foodNutrients': [
              {'nutrientNumber': '208', 'value': 100},
              {'nutrientNumber': '203', 'value': 4},
            ],
          },
        ],
      });
      expect(results, hasLength(1));
      expect(results.first.macrosKnown, isFalse);
    });

    test('cache JSON round-trip preserves the flag; legacy rows infer it', () {
      const r = FoodApiResult(
        name: 'Egg White', calories100g: 52, protein100g: 11,
        carbs100g: 0, fat100g: 0, source: 'USDA', macrosKnown: true,
      );
      expect(FoodApiResult.fromJson(r.toJson()).macrosKnown, isTrue);
      final legacy = r.toJson()..remove('mk');
      expect(FoodApiResult.fromJson(legacy).macrosKnown, isFalse);
    });
  });

  // ── Removed dead code stays removed ─────────────────────────────────────────
  test('netCalories remains the single net-energy surface', () async {
    final p = FitnessProvider();
    await p.loadData();
    await p.addFoodEntry(_food('x', 900, 40));
    expect(p.netCalories, (p.todayCaloriesTotal - p.totalCaloriesBurned).round());
  });
}
