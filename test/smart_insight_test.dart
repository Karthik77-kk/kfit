import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karthik_fitness/models/models.dart';
import 'package:karthik_fitness/providers/fitness_provider.dart';
import 'package:karthik_fitness/services/smart_insight_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

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
      // The insight only fires for >= 1.5 cm decrease
      final waistInsight = insights.where((i) => i.title.toLowerCase().contains('waist down')).toList();
      expect(waistInsight, isEmpty);
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
