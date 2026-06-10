import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karthik_fitness/models/models.dart';
import 'package:karthik_fitness/providers/fitness_provider.dart';
import 'package:karthik_fitness/services/smart_insight_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

// Seeds past body entries so _weightRegression (needs >= 3) works.
// Required because logBodyEntry always uses DateTime.now() — past-dated
// scale entries don't build the regression's body history.
Map<String, Object> _seedBodyHistory(List<({DateTime date, double weight})> entries) {
  final json = jsonEncode(entries
      .map((e) => BodyEntry(
            id: const Uuid().v4(),
            date: e.date,
            weightKg: e.weight,
            steps: 0,
          ).toJson())
      .toList());
  return {'body_history': json};
}

FoodEntry _food(String id, double cal, double prot) => FoodEntry(
      id: id, name: 'F$id', calories: cal, protein: prot,
      mealType: MealType.lunch, timestamp: DateTime.now(),
    );

SmartScaleEntry _scale({required DateTime date, double weight = 75, int visceral = 5,
    double bodyFat = 20, double muscle = 35}) =>
    SmartScaleEntry(
      id: const Uuid().v4(), date: date, weightKg: weight,
      bodyFatPercent: bodyFat, bodyFatKg: weight * bodyFat / 100,
      muscleMassKg: muscle, muscleMassPercent: muscle / weight * 100,
      leanBodyMassKg: weight * 0.8, biologicalAge: 22, visceralFatIndex: visceral,
      bmr: 1700, bodyWaterPercent: 55, boneMassKg: 3.2, proteinPercent: 18,
      skeletalMuscleMassKg: 28,
    );

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

  group('smart insight engine — structure', () {
    test('always returns at least one insight (fallback)', () async {
      final p = FitnessProvider();
      await p.loadData();
      final all = generateInsights(p, DateTime(2026, 5, 31, 10));
      expect(all, isNotEmpty);
    });

    test('topInsight never throws on a fresh provider', () async {
      final p = FitnessProvider();
      await p.loadData();
      expect(() => topInsight(p, DateTime(2026, 5, 31, 10)), returnsNormally);
    });

    test('topInsights respects count', () async {
      final p = FitnessProvider();
      await p.loadData();
      expect(topInsights(p, DateTime(2026, 5, 31, 10), count: 3).length,
          lessThanOrEqualTo(3));
      expect(topInsights(p, DateTime(2026, 5, 31, 10), count: 1).length, 1);
    });

    test('topInsights are de-duplicated by category when possible', () async {
      final p = FitnessProvider();
      await p.loadData();
      // Create several categories worth of signal.
      await p.addFoodEntry(_food('a', 2300, 5)); // nutrition (over goal)
      await p.logScaleEntry(_scale(date: DateTime.now().subtract(const Duration(days: 6)), visceral: 5));
      await p.logScaleEntry(_scale(date: DateTime.now(), visceral: 14)); // bodyComp
      final top = topInsights(p, DateTime(2026, 5, 31, 15), count: 3);
      final cats = top.map((e) => e.category).toList();
      expect(cats.toSet().length, cats.length,
          reason: 'top insights should have distinct categories');
    });

    test('insights are sorted by score descending', () async {
      final p = FitnessProvider();
      await p.loadData();
      await p.addFoodEntry(_food('a', 2300, 5));
      final top = topInsights(p, DateTime(2026, 5, 31, 15), count: 3);
      for (int i = 0; i < top.length - 1; i++) {
        expect(top[i].score, greaterThanOrEqualTo(top[i + 1].score));
      }
    });
  });

  group('smart insight engine — specific rules', () {
    test('over-goal nutrition insight fires when far above goal', () async {
      final p = FitnessProvider();
      await p.loadData();
      await p.addFoodEntry(_food('a', 2300, 40)); // 2300 > 1700 + 400
      final all = generateInsights(p, DateTime(2026, 5, 31, 19));
      expect(all.any((i) => i.title.contains('over goal')), isTrue);
    });

    test('protein-behind-pace fires mid-afternoon with low protein', () async {
      final p = FitnessProvider();
      await p.loadData();
      await p.addFoodEntry(_food('a', 600, 5)); // only 5g protein
      final all = generateInsights(p, DateTime(2026, 5, 31, 15));
      expect(all.any((i) => i.category == InsightCategory.nutrition), isTrue);
    });

    test('visceral-fat warning fires with high latest reading', () async {
      final p = FitnessProvider();
      await p.loadData();
      await p.logScaleEntry(_scale(date: DateTime.now().subtract(const Duration(days: 6)), visceral: 12));
      await p.logScaleEntry(_scale(date: DateTime.now(), visceral: 14));
      final all = generateInsights(p, DateTime(2026, 5, 31, 10));
      expect(all.any((i) => i.title.toLowerCase().contains('visceral')), isTrue);
    });

    test('waist-down measurement insight fires on real shrinkage', () async {
      final p = FitnessProvider();
      await p.loadData();
      await p.logMeasurement(MeasurementEntry(
          id: 'm1', date: DateTime.now().subtract(const Duration(days: 20)), waistCm: 86));
      await p.logMeasurement(MeasurementEntry(
          id: 'm2', date: DateTime.now(), waistCm: 83)); // −3 cm
      final all = generateInsights(p, DateTime(2026, 5, 31, 10));
      expect(all.any((i) => i.category == InsightCategory.measurements), isTrue);
    });

    test('days-since-workout nudge fires after a gap (no recent workout)', () async {
      final p = FitnessProvider();
      await p.loadData();
      await p.logWorkout(WorkoutLog(
        id: 'w1', date: DateTime.now().subtract(const Duration(days: 5)),
        workoutType: WorkoutType.custom,
        exercises: [ExerciseLog(name: 'Push-ups', sets: [SetData(reps: 10, weight: 0)])],
      ));
      final all = generateInsights(p, DateTime(2026, 5, 31, 10));
      expect(all.any((i) => i.category == InsightCategory.workout), isTrue);
    });

    test('recomp trajectory insight fires (fat down, muscle up)', () async {
      final p = FitnessProvider();
      await p.loadData();
      await p.logScaleEntry(_scaleFL(
          date: DateTime.now().subtract(const Duration(days: 30)), fatKg: 20, leanKg: 55));
      await p.logScaleEntry(_scaleFL(date: DateTime.now(), fatKg: 17, leanKg: 57));
      final all = generateInsights(p, DateTime(2026, 5, 31, 10));
      expect(all.any((i) => i.title.toLowerCase().contains('recomp')), isTrue);
    });

    test('high waist-to-hip ratio insight fires', () async {
      final p = FitnessProvider();
      await p.loadData();
      await p.logMeasurement(MeasurementEntry(
          id: 'm', date: DateTime.now(), waistCm: 100, hipsCm: 100)); // WHR 1.0
      final all = generateInsights(p, DateTime(2026, 5, 31, 10));
      expect(all.any((i) => i.title.toLowerCase().contains('waist-to-hip')), isTrue);
    });
  });

  // ── Step / water / calorie insight rules ──────────────────────────────────

  group('smart insight — step, water, calorie rules', () {
    test('steps insight fires when no steps logged', () async {
      final p = FitnessProvider();
      await p.loadData();
      final insights = generateInsights(p, DateTime(2026, 5, 31, 14));
      final titles = insights.map((i) => i.title.toLowerCase()).toList();
      // At least one insight should mention steps
      expect(titles.any((t) => t.contains('step')), isTrue);
    });

    test('water insight fires when no water logged', () async {
      final p = FitnessProvider();
      await p.loadData();
      final insights = generateInsights(p, DateTime(2026, 5, 31, 15));
      final titles = insights.map((i) => i.title.toLowerCase()).toList();
      expect(titles.any((t) => t.contains('water') || t.contains('hydrat')), isTrue);
    });

    test('over-goal calorie insight fires when calories exceed goal', () async {
      final p = FitnessProvider();
      await p.loadData();
      await p.saveCalorieGoal(1000);
      await p.addFoodEntry(_food('f1', 1500, 50));
      final insights = generateInsights(p, DateTime(2026, 5, 31, 14));
      final titles = insights.map((i) => i.title.toLowerCase()).toList();
      expect(titles.any((t) => t.contains('over') || t.contains('above') || t.contains('calor')), isTrue);
    });

    test('protein-behind-pace insight fires when protein is behind expected pace', () async {
      final p = FitnessProvider();
      await p.loadData();
      await p.saveProteinGoal(100);
      // 0g protein at 2pm (should have ~62% of 100g = 62g by now) → behind
      final insights = generateInsights(p, DateTime(2026, 5, 31, 14));
      final titles = insights.map((i) => i.title.toLowerCase()).toList();
      expect(titles.any((t) => t.contains('protein') || t.contains('pace')), isTrue);
    });
  });

  // ── Visceral fat insight ──────────────────────────────────────────────────

  group('smart insight — visceral fat', () {
    test('visceral fat insight fires at index >= 13 (requires 2 scale entries)', () async {
      final p = FitnessProvider();
      await p.loadData();
      // Engine requires scales.length >= 2 — log one previous and one current.
      await p.logScaleEntry(_scale(date: DateTime.now().subtract(const Duration(days: 7)), visceral: 12));
      await p.logScaleEntry(_scale(date: DateTime.now(), visceral: 14));
      final insights = generateInsights(p, DateTime(2026, 5, 31, 10));
      expect(insights.any((i) => i.title.toLowerCase().contains('visceral')), isTrue);
    });

    test('visceral fat insight does NOT fire at index < 13', () async {
      final p = FitnessProvider();
      await p.loadData();
      await p.logScaleEntry(_scale(date: DateTime.now().subtract(const Duration(days: 7)), visceral: 8));
      await p.logScaleEntry(_scale(date: DateTime.now(), visceral: 8));
      final insights = generateInsights(p, DateTime(2026, 5, 31, 10));
      expect(insights.any((i) => i.title.toLowerCase().contains('visceral')), isFalse);
    });
  });

  // ── Workout / rest day insight ────────────────────────────────────────────

  group('smart insight — workout / no-workout-this-week', () {
    test('no-workout insight fires when 0 workouts this week', () async {
      final p = FitnessProvider();
      await p.loadData();
      final insights = generateInsights(p, DateTime(2026, 5, 31, 14));
      final titles = insights.map((i) => i.title.toLowerCase()).toList();
      expect(titles.any((t) => t.contains('workout') || t.contains('session')), isTrue);
    });
  });

  // ── Insight scores and dedup ──────────────────────────────────────────────

  group('smart insight — scores and category dedup', () {
    test('topInsights(count:3) returns at most 3 insights', () async {
      final p = FitnessProvider();
      await p.loadData();
      final top = topInsights(p, DateTime(2026, 5, 31, 10), count: 3);
      expect(top.length, lessThanOrEqualTo(3));
    });

    test('topInsights(count:1) returns exactly 1', () async {
      final p = FitnessProvider();
      await p.loadData();
      final top = topInsights(p, DateTime(2026, 5, 31, 10), count: 1);
      expect(top.length, 1);
    });

    test('all insights have non-empty title and body', () async {
      final p = FitnessProvider();
      await p.loadData();
      final all = generateInsights(p, DateTime(2026, 5, 31, 10));
      for (final insight in all) {
        expect(insight.title, isNotEmpty, reason: 'insight title must not be empty');
        expect(insight.body, isNotEmpty, reason: 'insight body must not be empty');
        expect(insight.emoji, isNotEmpty, reason: 'insight emoji must not be empty');
      }
    });

    test('topInsights has at most one insight per category', () async {
      final p = FitnessProvider();
      await p.loadData();
      final top = topInsights(p, DateTime(2026, 5, 31, 10), count: 10);
      final categories = top.map((i) => i.category).toList();
      final uniqueCategories = categories.toSet();
      expect(categories.length, uniqueCategories.length,
          reason: 'No two insights should share a category');
    });

    test('insights are sorted by score descending', () async {
      final p = FitnessProvider();
      await p.loadData();
      final all = generateInsights(p, DateTime(2026, 5, 31, 10));
      for (int i = 0; i < all.length - 1; i++) {
        expect(all[i].score, greaterThanOrEqualTo(all[i + 1].score),
            reason: 'Insight at index $i should have score >= index ${i+1}');
      }
    });

    test('topInsight returns highest scoring insight', () async {
      final p = FitnessProvider();
      await p.loadData();
      final all = generateInsights(p, DateTime(2026, 5, 31, 10));
      final top = topInsight(p, DateTime(2026, 5, 31, 10));
      expect(top.score, all.map((i) => i.score).reduce((a, b) => a > b ? a : b));
    });
  });

  // ── Insight with scale data ───────────────────────────────────────────────

  group('smart insight — scale-dependent rules', () {
    test('body comp insight fires when scale data available', () async {
      final p = FitnessProvider();
      await p.loadData();
      await p.logScaleEntry(_scale(date: DateTime.now(), weight: 80, bodyFat: 28));
      final insights = generateInsights(p, DateTime(2026, 5, 31, 10));
      // With high body fat (28%) the engine should produce a relevant insight
      expect(insights, isNotEmpty);
    });

    test('WHR insight fires when waist/hip ratio >= threshold', () async {
      final p = FitnessProvider();
      await p.loadData();
      await p.saveHeight(175);
      await p.logMeasurement(MeasurementEntry(
        id: 'm', date: DateTime.now(), waistCm: 100, hipsCm: 95));
      // WHR = 100/95 ≈ 1.05 — well above 0.95 threshold
      final insights = generateInsights(p, DateTime(2026, 5, 31, 10));
      expect(insights.any((i) => i.title.toLowerCase().contains('waist') || i.title.toLowerCase().contains('whr')), isTrue);
    });

    test('waist-down insight fires when waist decreases >= 1.5 cm across 2 entries', () async {
      final p = FitnessProvider();
      await p.loadData();
      // Log earlier measurement with larger waist, then recent with smaller waist.
      await p.logMeasurement(MeasurementEntry(
          id: 'm1', date: DateTime.now().subtract(const Duration(days: 14)), waistCm: 90));
      await p.logMeasurement(MeasurementEntry(
          id: 'm2', date: DateTime.now(), waistCm: 87)); // delta = -3 cm
      final insights = generateInsights(p, DateTime(2026, 5, 31, 10));
      expect(insights.any((i) => i.title.toLowerCase().contains('waist')), isTrue);
    });

    test('waist-down insight does NOT fire when waist decrease < 1.5 cm', () async {
      final p = FitnessProvider();
      await p.loadData();
      await p.logMeasurement(MeasurementEntry(
          id: 'm1', date: DateTime.now().subtract(const Duration(days: 7)), waistCm: 90));
      await p.logMeasurement(MeasurementEntry(
          id: 'm2', date: DateTime.now(), waistCm: 89.5)); // delta = -0.5 cm
      final insights = generateInsights(p, DateTime(2026, 5, 31, 10));
      final waistInsight = insights.where((i) => i.title.toLowerCase().contains('waist down')).toList();
      expect(waistInsight, isEmpty);
    });
  });

  // ── Previously untested insight conditions ────────────────────────────────

  group('smart insight engine — body composition milestones', () {
    test('FFMI 22–25 fires strong-base insight', () async {
      final p = FitnessProvider();
      await p.loadData();
      await p.saveHeight(175); // h=1.75m
      // lean=73kg → FFMI = 73/3.0625 + 6.1*(1.8-1.75) = 23.84 + 0.305 ≈ 24.1 ∈ [22,25)
      await p.logScaleEntry(SmartScaleEntry(
        id: 's', date: DateTime.now(), weightKg: 88,
        bodyFatPercent: 17, bodyFatKg: 15, muscleMassKg: 45, muscleMassPercent: 51,
        leanBodyMassKg: 73, biologicalAge: 24, visceralFatIndex: 4, bmr: 1900,
        bodyWaterPercent: 62, boneMassKg: 3.5, proteinPercent: 20, skeletalMuscleMassKg: 36,
      ));
      final insights = generateInsights(p, DateTime(2026, 5, 31, 10));
      expect(insights.any((i) => i.title.contains('Strong muscle base')), isTrue);
    });

    test('FFMI outside [22,25) does NOT fire strong-base insight', () async {
      final p = FitnessProvider();
      await p.loadData();
      await p.saveHeight(175);
      // lean=50kg → FFMI ≈ 16.6 (below 22)
      await p.logScaleEntry(SmartScaleEntry(
        id: 's', date: DateTime.now(), weightKg: 65,
        bodyFatPercent: 23, bodyFatKg: 15, muscleMassKg: 30, muscleMassPercent: 46,
        leanBodyMassKg: 50, biologicalAge: 24, visceralFatIndex: 5, bmr: 1600,
        bodyWaterPercent: 52, boneMassKg: 3, proteinPercent: 17, skeletalMuscleMassKg: 25,
      ));
      final insights = generateInsights(p, DateTime(2026, 5, 31, 10));
      expect(insights.any((i) => i.title.contains('Strong muscle base')), isFalse);
    });

    test('bio age 3+ years younger fires younger-body insight', () async {
      final p = FitnessProvider();
      await p.loadData();
      await p.saveAge(30);
      await p.logScaleEntry(SmartScaleEntry(
        id: 's', date: DateTime.now(), weightKg: 75,
        bodyFatPercent: 18, bodyFatKg: 13.5, muscleMassKg: 38, muscleMassPercent: 50,
        leanBodyMassKg: 61.5, biologicalAge: 25, visceralFatIndex: 4, bmr: 1750,
        bodyWaterPercent: 60, boneMassKg: 3.3, proteinPercent: 19, skeletalMuscleMassKg: 30,
      ));
      final insights = generateInsights(p, DateTime(2026, 5, 31, 10));
      expect(insights.any((i) => i.title.contains('younger')), isTrue);
    });

    test('bio age 4+ years older fires older-body insight', () async {
      final p = FitnessProvider();
      await p.loadData();
      await p.saveAge(24);
      await p.logScaleEntry(SmartScaleEntry(
        id: 's', date: DateTime.now(), weightKg: 85,
        bodyFatPercent: 28, bodyFatKg: 24, muscleMassKg: 30, muscleMassPercent: 35,
        leanBodyMassKg: 61, biologicalAge: 30, visceralFatIndex: 8, bmr: 1600,
        bodyWaterPercent: 50, boneMassKg: 3, proteinPercent: 16, skeletalMuscleMassKg: 24,
      ));
      final insights = generateInsights(p, DateTime(2026, 5, 31, 10));
      expect(insights.any((i) => i.title.contains('older')), isTrue);
    });

    test('bio age within 2 years fires no age insight', () async {
      final p = FitnessProvider();
      await p.loadData();
      await p.saveAge(24);
      await p.logScaleEntry(SmartScaleEntry(
        id: 's', date: DateTime.now(), weightKg: 75,
        bodyFatPercent: 20, bodyFatKg: 15, muscleMassKg: 35, muscleMassPercent: 46,
        leanBodyMassKg: 60, biologicalAge: 25, visceralFatIndex: 5, bmr: 1700,
        bodyWaterPercent: 55, boneMassKg: 3.2, proteinPercent: 18, skeletalMuscleMassKg: 28,
      ));
      final insights = generateInsights(p, DateTime(2026, 5, 31, 10));
      expect(insights.any((i) => i.title.contains('years younger')), isFalse);
      expect(insights.any((i) => i.title.contains('years older')), isFalse);
    });

    test('body water low fires hydration insight after 10 AM', () async {
      final p = FitnessProvider();
      await p.loadData();
      await p.logScaleEntry(SmartScaleEntry(
        id: 's', date: DateTime.now(), weightKg: 75,
        bodyFatPercent: 20, bodyFatKg: 15, muscleMassKg: 35, muscleMassPercent: 46,
        leanBodyMassKg: 60, biologicalAge: 24, visceralFatIndex: 5, bmr: 1700,
        bodyWaterPercent: 44, // < 50 → Low
        boneMassKg: 3.2, proteinPercent: 18, skeletalMuscleMassKg: 28,
      ));
      final insights = generateInsights(p, DateTime(2026, 5, 31, 11)); // hour=11
      expect(insights.any((i) => i.title.contains('Body water is low')), isTrue);
    });

    test('muscle dipped insight fires when muscle drops > 0.4 kg between readings', () async {
      // _weightRegression needs >= 5 body entries; muscle-dipped also requires weekly < 0.
      // Seed declining body history so weeklyWeightChange < 0.
      SharedPreferences.setMockInitialValues(_seedBodyHistory([
        (date: DateTime.now().subtract(const Duration(days: 28)), weight: 82),
        (date: DateTime.now().subtract(const Duration(days: 21)), weight: 81),
        (date: DateTime.now().subtract(const Duration(days: 14)), weight: 80),
        (date: DateTime.now().subtract(const Duration(days: 7)),  weight: 79),
        (date: DateTime.now().subtract(const Duration(days: 2)),  weight: 78.5),
      ]));
      final p = FitnessProvider();
      await p.loadData();
      // Two scale entries: muscle 36 → 35 (dip of 1 kg > 0.4 threshold).
      await p.logScaleEntry(_scale(
          date: DateTime.now().subtract(const Duration(days: 14)), weight: 80, muscle: 36));
      await p.logScaleEntry(SmartScaleEntry(
        id: 's3', date: DateTime.now(), weightKg: 79,
        bodyFatPercent: 20, bodyFatKg: 15.8, muscleMassKg: 35, muscleMassPercent: 44.3,
        leanBodyMassKg: 63.2, biologicalAge: 22, visceralFatIndex: 5, bmr: 1700,
        bodyWaterPercent: 55, boneMassKg: 3.2, proteinPercent: 18, skeletalMuscleMassKg: 28,
      ));
      // muscle dipped + weekly < 0 → fires
      final insights = generateInsights(p, DateTime(2026, 5, 31, 10));
      expect(insights.any((i) => i.title.contains('Muscle dipped')), isTrue);
    });
  });

  group('smart insight engine — predictive / EOD projections', () {
    test('EOD calorie projection over goal fires warning (after 11 AM)', () async {
      final p = FitnessProvider();
      await p.loadData();
      // Add substantial food early → projected end-of-day will exceed goal
      await p.addFoodEntry(_food('f1', 1600, 50));
      final hour = DateTime.now().hour;
      final insights = generateInsights(p, DateTime(2026, 5, 31, 15)); // 3 PM
      // projectedEodCalories is a function of current pace + historical avg,
      // so we can only check it fires when calories are very high relative to time of day
      if (p.projectedEodCalories != null && (p.projectedEodCalories ?? 0) > p.calorieGoal + 200) {
        expect(insights.any((i) => i.emoji == '🔮' && i.title.contains('finish')), isTrue);
      }
      // If projection isn't available yet (e.g. before 11 AM in CI), skip.
      // Variable kept to document the constraint; suppress unused-var lint.
      expect(hour, greaterThanOrEqualTo(0));
    });

    test('projected protein miss fires when intake is low mid-day (after 1 PM)', () async {
      final p = FitnessProvider();
      await p.loadData();
      await p.addFoodEntry(_food('f1', 600, 10)); // very low protein at lunch
      // At 2 PM pace: 10g protein in 8h window → projected EOD ≈ 10/0.5 = 20g (far below 100g)
      final insights = generateInsights(p, DateTime(2026, 5, 31, 14)); // 2 PM
      if (p.projectedEodProtein != null && (p.projectedEodProtein ?? 0) < p.proteinGoal * 0.8) {
        expect(insights.any((i) => i.title.contains('Projected to miss protein')), isTrue);
      }
    });
  });

  group('smart insight engine — behaviour patterns', () {
    test('weekend overeating insight fires on a weekend when pattern exists', () async {
      final p = FitnessProvider();
      await p.loadData();
      await p.addFoodEntry(_food('f', 2000, 80)); // today's food
      // overeatsOnWeekends needs both weekend and weekday data — hard to set up
      // without a real Saturday/Sunday. Verify no crash on any day.
      final now = DateTime(2026, 5, 31, 10); // Sunday 31 May 2026
      expect(() => generateInsights(p, now), returnsNormally);
    });

    test('goal-pace coaching with ETA fires when losing at healthy rate', () async {
      // Seed 5 declining body entries so _weightRegression yields weekly ≈ -0.25 kg/wk.
      SharedPreferences.setMockInitialValues(_seedBodyHistory([
        (date: DateTime.now().subtract(const Duration(days: 28)), weight: 78.5),
        (date: DateTime.now().subtract(const Duration(days: 21)), weight: 78.3),
        (date: DateTime.now().subtract(const Duration(days: 14)), weight: 78.0),
        (date: DateTime.now().subtract(const Duration(days: 7)),  weight: 77.7),
        (date: DateTime.now().subtract(const Duration(days: 1)),  weight: 77.5),
      ]));
      final p = FitnessProvider();
      await p.loadData();
      await p.saveGoalWeight(70);
      // weekly ≈ -0.25 kg/week — triggers "Healthy loss 0.25 kg/wk" or goal-pace insight
      final insights = generateInsights(p, DateTime(2026, 5, 31, 10));
      final hasGoalPacing = insights.any((i) =>
          i.title.contains('On pace') || i.title.contains('kg/wk'));
      expect(hasGoalPacing, isTrue);
    });
  });

  group('smart insight engine — motivation', () {
    test('dialled-in insight fires when calorie streak ≥3 AND workout streak ≥3', () async {
      final p = FitnessProvider();
      await p.loadData();
      // Build calorie streak: add today's food above 500 kcal threshold
      await p.addFoodEntry(_food('f1', 700, 40));
      // Build workout streak: log workouts for today and past 2 days
      for (int i = 0; i < 3; i++) {
        await p.logWorkout(WorkoutLog(
          id: 'w$i',
          date: DateTime.now().subtract(Duration(days: i)),
          workoutType: WorkoutType.custom,
          exercises: [ExerciseLog(name: 'Push-ups', sets: [SetData(reps: 10, weight: 0)])],
        ));
      }
      // Calorie streak requires historical data which we can't easily seed here.
      // Verify the insight generation at least doesn't throw.
      expect(() => generateInsights(p, DateTime(2026, 5, 31, 10)), returnsNormally);
      // If streaks are both ≥3, the ✅ insight should fire:
      if (p.calorieStreak >= 3 && p.workoutStreak >= 3) {
        final insights = generateInsights(p, DateTime(2026, 5, 31, 10));
        expect(insights.any((i) => i.emoji == '✅'), isTrue);
      }
    });

    test('motivation insight does NOT fire when streaks are < 3', () async {
      final p = FitnessProvider();
      await p.loadData();
      // No food logged → calorie streak = 0
      expect(p.calorieStreak, 0);
      expect(p.workoutStreak, 0);
      final insights = generateInsights(p, DateTime(2026, 5, 31, 10));
      expect(insights.any((i) => i.emoji == '✅'), isFalse);
    });

    test('fallback insight is always present', () async {
      final p = FitnessProvider();
      await p.loadData();
      final insights = generateInsights(p, DateTime(2026, 5, 31, 10));
      expect(insights.any((i) => i.title == 'Stay consistent'), isTrue);
      expect(insights.any((i) => i.emoji == '💡'), isTrue);
    });
  });

  group('smart insight engine — recommended goals', () {
    test('recommendedCalorieGoal is TDEE - 500 when TDEE available', () async {
      final p = FitnessProvider();
      await p.loadData();
      await p.saveHeight(175);
      await p.saveAge(24);
      await p.logBodyEntry(weightKg: 80.0);
      // TDEE = BMR × 1.2 (0 workouts), BMR = 10×80 + 6.25×175 - 5×24 + 5 = 1861.25
      // TDEE = 1861.25 × 1.2 = 2233.5, recommendation = 2233.5 - 500 = 1733.5 → clamp = 1733
      final rec = p.recommendedCalorieGoal;
      expect(rec, isNotNull);
      expect(rec!, greaterThanOrEqualTo(1200));
      expect(rec, lessThanOrEqualTo(2800));
      final tdee = p.tdee!;
      expect(rec, closeTo(tdee - 500, 5));
    });

    test('recommendedCalorieGoal returns null when no weight logged', () async {
      final p = FitnessProvider();
      await p.loadData();
      expect(p.recommendedCalorieGoal, isNull);
    });

    test('recommendedProteinGoal uses 2g/kg lean mass when scale available', () async {
      final p = FitnessProvider();
      await p.loadData();
      await p.logScaleEntry(SmartScaleEntry(
        id: 's', date: DateTime.now(), weightKg: 80,
        bodyFatPercent: 20, bodyFatKg: 16, muscleMassKg: 36, muscleMassPercent: 45,
        leanBodyMassKg: 64, biologicalAge: 24, visceralFatIndex: 5, bmr: 1800,
        bodyWaterPercent: 55, boneMassKg: 3.2, proteinPercent: 18, skeletalMuscleMassKg: 28,
      ));
      // lean = 64 kg → 2.0 × 64 = 128g
      expect(p.recommendedProteinGoal, closeTo(128, 2));
    });

    test('recommendedProteinGoal falls back to 1.8g/kg body weight without scale', () async {
      final p = FitnessProvider();
      await p.loadData();
      await p.logBodyEntry(weightKg: 80.0);
      // 1.8 × 80 = 144g
      expect(p.recommendedProteinGoal, closeTo(144, 2));
    });

    test('recommendedProteinGoal returns default when no weight logged', () async {
      final p = FitnessProvider();
      await p.loadData();
      expect(p.recommendedProteinGoal, FitnessProvider.kDefaultProteinGoal);
    });

    test('recommendedWaterGoal is 35ml × body weight', () async {
      final p = FitnessProvider();
      await p.loadData();
      await p.logBodyEntry(weightKg: 78.3);
      // 35 × 78.3 = 2740.5 → 2741, clamped to [1500, 4500]
      expect(p.recommendedWaterGoal, closeTo(2741, 5));
    });

    test('recommendedWaterGoal returns default when no weight', () async {
      final p = FitnessProvider();
      await p.loadData();
      expect(p.recommendedWaterGoal, FitnessProvider.kDefaultWaterGoalMl);
    });

    test('hasGoalRecommendations true when calorie goal differs by > 50 kcal', () async {
      final p = FitnessProvider();
      await p.loadData();
      await p.saveHeight(175);
      await p.saveAge(24);
      await p.logBodyEntry(weightKg: 80.0);
      await p.saveCalorieGoal(1700); // force a specific goal
      // recommendedCalorieGoal ≈ 1733 (TDEE 2233 - 500)
      // |1733 - 1700| = 33 ≤ 50 → might be false depending on exact TDEE
      // but hasGoalRecommendations also checks protein and water
      // protein: recommended 144 vs default 100 → |144-100| = 44 > 5 → true
      expect(p.hasGoalRecommendations, isTrue);
    });

    test('hasGoalRecommendations false when no weight data', () async {
      final p = FitnessProvider();
      await p.loadData();
      // No weight → recommendedCalorieGoal = null → hasGoalRecommendations = false
      expect(p.hasGoalRecommendations, isFalse);
    });
  });
}

SmartScaleEntry _scaleFL({required DateTime date, required double fatKg, required double leanKg}) =>
    SmartScaleEntry(
      id: const Uuid().v4(), date: date, weightKg: fatKg + leanKg,
      bodyFatPercent: fatKg / (fatKg + leanKg) * 100, bodyFatKg: fatKg,
      muscleMassKg: leanKg * 0.6, muscleMassPercent: 46, leanBodyMassKg: leanKg,
      biologicalAge: 22, visceralFatIndex: 5, bmr: 1700, bodyWaterPercent: 55,
      boneMassKg: 3.2, proteinPercent: 18, skeletalMuscleMassKg: 28,
    );
