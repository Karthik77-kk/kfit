import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karthik_fitness/models/models.dart';
import 'package:karthik_fitness/providers/fitness_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

SmartScaleEntry _scale({double weight = 75.0, double bmr = 1800.0}) =>
    SmartScaleEntry(
      id: 'scale', date: DateTime.now(),
      weightKg: weight, bodyFatPercent: 20, bodyFatKg: weight * 0.2,
      muscleMassKg: 35, muscleMassPercent: 46, leanBodyMassKg: weight * 0.8,
      biologicalAge: 22, visceralFatIndex: 5, bmr: bmr,
      bodyWaterPercent: 55, boneMassKg: 3.2, proteinPercent: 18,
      skeletalMuscleMassKg: 28,
    );

FoodEntry _food(String id, double calories, double protein,
    {MealType meal = MealType.lunch}) =>
    FoodEntry(
      id: id, name: 'Food $id', calories: calories, protein: protein,
      mealType: meal, timestamp: DateTime.now(),
    );

WorkoutLog _workout(String id, {
  List<ExerciseLog>? exercises,
  DateTime? date,
  WorkoutType type = WorkoutType.custom,
}) =>
    WorkoutLog(
      id: id,
      date: date ?? DateTime.now(),
      workoutType: type,
      exercises: exercises ?? [ExerciseLog(name: 'Push-ups', sets: [SetData(reps: 10, weight: 0)])],
    );

// ─── Test suite ───────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock path_provider for export/import tests
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return Directory.systemTemp.path;
        }
        return null;
      },
    );
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ── Constants ───────────────────────────────────────────────────────────────

  group('Constants', () {
    test('default daily targets', () {
      expect(FitnessProvider.kDefaultCalorieGoal, 1700);
      expect(FitnessProvider.kDefaultProteinGoal, 100);
      expect(FitnessProvider.kDefaultWaterGoalMl, 2500);
      expect(FitnessProvider.kDefaultStepGoal, 8000);
    });

    test('static aliases for backward compat', () {
      expect(FitnessProvider.kCalorieGoal, FitnessProvider.kDefaultCalorieGoal);
      expect(FitnessProvider.kProteinGoal, FitnessProvider.kDefaultProteinGoal);
    });
  });

  // ── Initial state ──────────────────────────────────────────────────────────

  group('Initial state after loadData', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('food is empty', () => expect(p.todayFood, isEmpty));
    test('water is 0', () => expect(p.todayWaterMl, 0));
    test('supplements all false', () {
      expect(p.supplements.whey, false);
      expect(p.supplements.creatine, false);
      expect(p.supplements.multivitamin, false);
    });
    test('no body entries', () => expect(p.bodyHistory, isEmpty));
    test('no scale entries', () => expect(p.scaleHistory, isEmpty));
    test('no workout history', () => expect(p.workoutHistory, isEmpty));
    test('calories are zero', () {
      expect(p.todayCaloriesTotal, 0.0);
      expect(p.todayProteinTotal, 0.0);
    });
    test('isLoaded is true after loadData', () => expect(p.isLoaded, isTrue));
    test('userName defaults to Karthik', () => expect(p.userName, 'Karthik'));
    test('height defaults to 170cm', () => expect(p.heightCm, 170.0));
    test('age defaults to 24', () => expect(p.age, 24));
    test('goalWeight defaults to 70kg', () => expect(p.goalWeightKg, 70.0));
  });

  // ── User profile setters ───────────────────────────────────────────────────

  group('User profile — save and persist', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('saveUserName persists across reload', () async {
      await p.saveUserName('Raj');
      final p2 = FitnessProvider();
      await p2.loadData();
      expect(p2.userName, 'Raj');
    });

    test('saveUserName trims whitespace', () async {
      await p.saveUserName('  Karthik  ');
      expect(p.userName, 'Karthik');
    });

    test('saveUserName empty string resets to Karthik', () async {
      await p.saveUserName('');
      expect(p.userName, 'Karthik');
    });

    test('saveHeight persists', () async {
      await p.saveHeight(175.0);
      final p2 = FitnessProvider();
      await p2.loadData();
      expect(p2.heightCm, 175.0);
    });

    test('saveAge clamps to [10, 100]', () async {
      await p.saveAge(5);
      expect(p.age, 10);
      await p.saveAge(150);
      expect(p.age, 100);
    });

    test('saveGoalWeight clamps to [30, 300]', () async {
      await p.saveGoalWeight(10.0);
      expect(p.goalWeightKg, 30.0);
      await p.saveGoalWeight(500.0);
      expect(p.goalWeightKg, 300.0);
    });

    test('saveGoalWeight persists', () async {
      await p.saveGoalWeight(65.0);
      final p2 = FitnessProvider();
      await p2.loadData();
      expect(p2.goalWeightKg, 65.0);
    });
  });

  // ── User-configurable goals ────────────────────────────────────────────────

  group('Configurable goals', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('saveCalorieGoal updates and persists', () async {
      await p.saveCalorieGoal(2000);
      expect(p.calorieGoal, 2000);
      final p2 = FitnessProvider();
      await p2.loadData();
      expect(p2.calorieGoal, 2000);
    });

    test('saveCalorieGoal clamps [800, 5000]', () async {
      await p.saveCalorieGoal(100); expect(p.calorieGoal, 800);
      await p.saveCalorieGoal(9999); expect(p.calorieGoal, 5000);
    });

    test('saveProteinGoal clamps [20, 300]', () async {
      await p.saveProteinGoal(5); expect(p.proteinGoal, 20);
      await p.saveProteinGoal(500); expect(p.proteinGoal, 300);
    });

    test('saveWaterGoal clamps [500, 8000]', () async {
      await p.saveWaterGoal(100); expect(p.waterGoalMl, 500);
      await p.saveWaterGoal(20000); expect(p.waterGoalMl, 8000);
    });

    test('saveStepGoal clamps [1000, 30000]', () async {
      await p.saveStepGoal(0); expect(p.stepGoal, 1000);
      await p.saveStepGoal(100000); expect(p.stepGoal, 30000);
    });

    test('calorieProgress uses configurable goal', () async {
      await p.saveCalorieGoal(800);
      await p.addFoodEntry(_food('f1', 800, 30));
      expect(p.calorieProgress, closeTo(1.0, 0.01));
    });

    test('reminder intervals persist', () async {
      await p.setWaterReminderInterval(3);
      await p.setWalkReminderInterval(2);
      final p2 = FitnessProvider();
      await p2.loadData();
      expect(p2.waterReminderIntervalHours, 3);
      expect(p2.walkReminderIntervalHours, 2);
    });

    test('setWaterReminderInterval clamps [1, 6]', () async {
      await p.setWaterReminderInterval(0); expect(p.waterReminderIntervalHours, 1);
      await p.setWaterReminderInterval(10); expect(p.waterReminderIntervalHours, 6);
    });
  });

  // ── Food ──────────────────────────────────────────────────────────────────

  group('Food logging', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('addFoodEntry increases totals', () async {
      await p.addFoodEntry(_food('f1', 300, 25));
      expect(p.todayCaloriesTotal, closeTo(300, 0.01));
      expect(p.todayProteinTotal, closeTo(25, 0.01));
    });

    test('multiple entries accumulate', () async {
      await p.addFoodEntry(_food('f1', 200, 10, meal: MealType.breakfast));
      await p.addFoodEntry(_food('f2', 400, 30, meal: MealType.lunch));
      await p.addFoodEntry(_food('f3', 300, 20, meal: MealType.dinner));
      expect(p.todayCaloriesTotal, closeTo(900, 0.01));
      expect(p.todayProteinTotal, closeTo(60, 0.01));
    });

    test('removeFoodEntry removes correct item', () async {
      await p.addFoodEntry(_food('keep', 200, 10));
      await p.addFoodEntry(_food('remove', 400, 30));
      await p.removeFoodEntry('remove');
      expect(p.todayFood.length, 1);
      expect(p.todayFood.first.id, 'keep');
      expect(p.todayCaloriesTotal, closeTo(200, 0.01));
    });

    test('meal type grouping works', () async {
      await p.addFoodEntry(_food('b', 200, 10, meal: MealType.breakfast));
      await p.addFoodEntry(_food('l', 300, 20, meal: MealType.lunch));
      await p.addFoodEntry(_food('d', 400, 30, meal: MealType.dinner));
      await p.addFoodEntry(_food('s', 100, 5, meal: MealType.snack));
      expect(p.breakfastEntries.length, 1);
      expect(p.lunchEntries.length, 1);
      expect(p.dinnerEntries.length, 1);
      expect(p.snackEntries.length, 1);
    });

    test('calorieProgress clamps to [0, 1]', () async {
      await p.addFoodEntry(_food('f1', 99999, 100));
      expect(p.calorieProgress, 1.0);
    });

    test('proteinProgress clamps to [0, 1]', () async {
      await p.addFoodEntry(_food('f1', 100, 9999));
      expect(p.proteinProgress, 1.0);
    });

    test('caloriesRemaining negative when over goal', () async {
      await p.addFoodEntry(_food('f1', 2000, 10));
      expect(p.caloriesRemaining, isNegative);
    });

    test('food persists across provider reload', () async {
      await p.addFoodEntry(_food('f1', 300, 25));
      final p2 = FitnessProvider();
      await p2.loadData();
      expect(p2.todayFood.length, 1);
      expect(p2.todayCaloriesTotal, closeTo(300, 0.01));
    });
  });

  // ── Supplements ───────────────────────────────────────────────────────────

  group('Supplements', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('whey adds 120 kcal to todayCaloriesTotal', () async {
      await p.updateSupplement('whey', true);
      expect(p.supplementCalories, 120.0);
      expect(p.todayCaloriesTotal, 120.0);
    });

    test('whey adds 25g to todayProteinTotal', () async {
      await p.updateSupplement('whey', true);
      expect(p.supplementProtein, 25.0);
      expect(p.todayProteinTotal, 25.0);
    });

    test('creatine and multivitamin add no calories', () async {
      await p.updateSupplement('creatine', true);
      await p.updateSupplement('multivitamin', true);
      expect(p.supplementCalories, 0.0);
      expect(p.supplementProtein, 0.0);
    });

    test('supplement calories included in weekly calorie data', () async {
      await p.updateSupplement('whey', true);
      final today = p.weeklyCalorieData.last;
      expect(today['calories'], closeTo(120, 0.01));
    });

    test('all supplements toggle correctly', () async {
      for (final key in ['whey', 'creatine', 'multivitamin']) {
        await p.updateSupplement(key, true);
        await p.updateSupplement(key, false);
      }
      expect(p.supplements.takenCount, 0);
    });

    test('supplements persist across reload', () async {
      await p.updateSupplement('whey', true);
      final p2 = FitnessProvider();
      await p2.loadData();
      expect(p2.supplements.whey, true);
    });
  });

  // ── Water ─────────────────────────────────────────────────────────────────

  group('Water', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('addWater accumulates', () async {
      await p.addWater(250); await p.addWater(500);
      expect(p.todayWaterMl, 750);
    });

    test('removeWater never goes below 0', () async {
      await p.addWater(200);
      await p.removeWater(500);
      expect(p.todayWaterMl, 0);
    });

    test('waterProgress clamps to [0, 1]', () async {
      await p.addWater(99999);
      expect(p.waterProgress, 1.0);
    });

    test('water persists across reload', () async {
      await p.addWater(1500);
      final p2 = FitnessProvider();
      await p2.loadData();
      expect(p2.todayWaterMl, 1500);
    });
  });

  // ── Body entries ──────────────────────────────────────────────────────────

  group('Body entries', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('logBodyEntry saves weight and steps', () async {
      await p.logBodyEntry(weightKg: 78.5, steps: 5000);
      expect(p.latestWeightKg, 78.5);
      expect(p.todaySteps, 5000);
    });

    test('logBodyEntry same-day overwrites (no duplicates)', () async {
      await p.logBodyEntry(weightKg: 80.0, steps: 3000);
      await p.logBodyEntry(weightKg: 79.5, steps: 7000);
      expect(p.bodyHistory.length, 1);
      expect(p.latestWeightKg, 79.5);
      expect(p.todaySteps, 7000);
    });

    test('updateTodaySteps updates existing entry', () async {
      await p.logBodyEntry(weightKg: 78.0, steps: 3000);
      await p.updateTodaySteps(8000);
      expect(p.bodyHistory.length, 1);
      expect(p.todaySteps, 8000);
      expect(p.latestWeightKg, 78.0);
    });

    test('updateTodaySteps creates entry with last known weight if none today', () async {
      await p.updateTodaySteps(5000);
      expect(p.bodyHistory.length, 1);
      expect(p.todaySteps, 5000);
    });

    test('stepProgress clamps to [0, 1]', () async {
      await p.logBodyEntry(weightKg: 70.0, steps: 99999);
      expect(p.stepProgress, 1.0);
    });

    test('getRecentBodyEntries filters by days', () async {
      await p.logBodyEntry(weightKg: 78.0);
      final recent = p.getRecentBodyEntries(days: 30);
      expect(recent.length, 1);
    });

    test('weightChangeKg null with fewer than 2 entries', () async {
      await p.logBodyEntry(weightKg: 78.0);
      expect(p.weightChangeKg, isNull);
    });

    test('body history persists', () async {
      await p.logBodyEntry(weightKg: 76.5);
      final p2 = FitnessProvider();
      await p2.loadData();
      expect(p2.latestWeightKg, 76.5);
    });
  });

  // ── Smart Scale ───────────────────────────────────────────────────────────

  group('Smart Scale', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('logScaleEntry saves to scaleHistory', () async {
      await p.logScaleEntry(_scale(weight: 78.5));
      expect(p.scaleHistory.length, 1);
      expect(p.latestScaleEntry!.weightKg, 78.5);
    });

    test('latestWeightKg prefers scale over body entry', () async {
      await p.logBodyEntry(weightKg: 80.0);
      await p.logScaleEntry(_scale(weight: 78.5));
      expect(p.latestWeightKg, 78.5);
    });

    test('latestWeightKg falls back to body entry when no scale', () async {
      await p.logBodyEntry(weightKg: 80.0);
      expect(p.latestWeightKg, 80.0);
      expect(p.latestScaleEntry, isNull);
    });

    test('logScaleEntry also creates bodyHistory entry', () async {
      await p.logScaleEntry(_scale(weight: 78.0));
      expect(p.bodyHistory, isNotEmpty);
      expect(p.latestBodyEntry!.weightKg, 78.0);
    });

    test('same-day scale entry overwrites', () async {
      await p.logScaleEntry(_scale(weight: 80.0));
      await p.logScaleEntry(_scale(weight: 79.0));
      expect(p.scaleHistory.length, 1);
      expect(p.latestScaleEntry!.weightKg, 79.0);
    });

    test('scale BMR overrides Mifflin-St Jeor', () async {
      await p.saveHeight(170.0);
      await p.saveAge(24);
      await p.logScaleEntry(_scale(weight: 78.0, bmr: 2000.0));
      expect(p.bmr, 2000.0);
    });

    test('scale BMR=0 falls back to Mifflin', () async {
      await p.saveHeight(170.0);
      await p.saveAge(24);
      await p.logScaleEntry(_scale(weight: 78.0, bmr: 0.0));
      expect(p.bmr, closeTo(1727.5, 0.5));
    });

    test('scale history persists', () async {
      await p.logScaleEntry(_scale(weight: 77.0, bmr: 1900.0));
      final p2 = FitnessProvider();
      await p2.loadData();
      expect(p2.scaleHistory.length, 1);
      expect(p2.latestScaleEntry!.bmr, 1900.0);
    });
  });

  // ── Body Measurements ─────────────────────────────────────────────────────

  group('Body Measurements', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('logMeasurement saves entry', () async {
      await p.logMeasurement(MeasurementEntry(
        id: 'm1', date: DateTime.now(), chestCm: 95.0, waistCm: 82.0,
      ));
      expect(p.latestMeasurements, isNotNull);
      expect(p.latestMeasurements!.chestCm, 95.0);
      expect(p.latestMeasurements!.waistCm, 82.0);
    });

    test('same-day measurement overwrites', () async {
      await p.logMeasurement(MeasurementEntry(id: 'm1', date: DateTime.now(), waistCm: 84.0));
      await p.logMeasurement(MeasurementEntry(id: 'm2', date: DateTime.now(), waistCm: 82.0));
      expect(p.measurementHistory.length, 1);
      expect(p.latestMeasurements!.waistCm, 82.0);
    });

    test('isEmpty entries are rejected', () async {
      await p.logMeasurement(MeasurementEntry(id: 'empty', date: DateTime.now()));
      expect(p.measurementHistory.isEmpty, isTrue);
    });

    test('measurements persist across reload', () async {
      await p.logMeasurement(MeasurementEntry(
        id: 'm1', date: DateTime.now(), hipsCm: 98.0, leftArmCm: 34.0,
      ));
      final p2 = FitnessProvider();
      await p2.loadData();
      expect(p2.measurementHistory.length, 1);
      expect(p2.latestMeasurements!.hipsCm, 98.0);
      expect(p2.latestMeasurements!.leftArmCm, 34.0);
    });

    test('getRecentMeasurements filters by days', () async {
      await p.logMeasurement(MeasurementEntry(id: 'm1', date: DateTime.now(), waistCm: 82.0));
      expect(p.getRecentMeasurements(days: 30).length, 1);
      expect(p.getRecentMeasurements(days: 0).length, 0);
    });
  });

  // ── Workout logging ───────────────────────────────────────────────────────

  group('Workout logging', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('no workout today initially', () {
      expect(p.todayWorkout, isNull);
      expect(p.todayWorkouts, isEmpty);
    });

    test('logWorkout appears in todayWorkouts', () async {
      await p.logWorkout(_workout('w1'));
      expect(p.todayWorkouts.length, 1);
      expect(p.todayWorkout, isNotNull);
    });

    test('multiple workouts same day accumulate in todayWorkouts', () async {
      await p.logWorkout(_workout('w1'));
      await p.logWorkout(_workout('w2'));
      await p.logWorkout(_workout('w3'));
      expect(p.todayWorkouts.length, 3);
    });

    test('workouts on different days not in todayWorkouts', () async {
      await p.logWorkout(_workout('yesterday', date: DateTime.now().subtract(const Duration(days: 1))));
      await p.logWorkout(_workout('today'));
      expect(p.todayWorkouts.length, 1);
    });

    test('todayCaloriesBurned sums all today workouts MET calories', () async {
      await p.logBodyEntry(weightKg: 70.0);
      await p.logWorkout(_workout('w1', exercises: [
        ExerciseLog(name: 'Running', sets: [SetData(reps: 1, weight: 0), SetData(reps: 1, weight: 0)]),
      ]));
      await p.logWorkout(_workout('w2', exercises: [
        ExerciseLog(name: 'Push-ups', sets: [SetData(reps: 10, weight: 0)]),
      ]));
      expect(p.todayCaloriesBurned, greaterThan(0));
    });

    test('workouts persist across reload', () async {
      await p.logWorkout(_workout('w1'));
      final p2 = FitnessProvider();
      await p2.loadData();
      expect(p2.workoutHistory.length, 1);
    });
  });

  // ── Workout retention (90-day trim) ───────────────────────────────────────

  group('Workout 90-day retention', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('workouts older than 90 days are trimmed on next log', () async {
      // Log an old workout (91 days ago)
      await p.logWorkout(_workout('old', date: DateTime.now().subtract(const Duration(days: 91))));
      // Log a new workout — this triggers trimming
      await p.logWorkout(_workout('new'));
      // Old should be gone
      expect(p.workoutHistory.any((w) => w.id == 'old'), isFalse);
      expect(p.workoutHistory.any((w) => w.id == 'new'), isTrue);
    });

    test('workouts within 90 days are kept', () async {
      await p.logWorkout(_workout('recent', date: DateTime.now().subtract(const Duration(days: 89))));
      await p.logWorkout(_workout('today'));
      expect(p.workoutHistory.length, 2);
    });
  });

  // ── Exercise history lookups ───────────────────────────────────────────────

  group('Exercise history — last weight/reps/PR', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('getLastExerciseWeight returns most recent non-zero weight', () async {
      await p.logWorkout(_workout('w1', exercises: [
        ExerciseLog(name: 'Bench Press', sets: [SetData(reps: 10, weight: 60.0)]),
      ]));
      await p.logWorkout(_workout('w2', exercises: [
        ExerciseLog(name: 'Bench Press', sets: [SetData(reps: 8, weight: 65.0)]),
      ]));
      expect(p.getLastExerciseWeight('Bench Press'), 65.0);
    });

    test('getLastExerciseWeight null for never-logged exercise', () {
      expect(p.getLastExerciseWeight('Bench Press'), isNull);
    });

    test('getLastExerciseWeight skips zero-weight sets', () async {
      await p.logWorkout(_workout('w1', exercises: [
        ExerciseLog(name: 'Push-ups', sets: [SetData(reps: 15, weight: 0)]),
      ]));
      expect(p.getLastExerciseWeight('Push-ups'), isNull);
    });

    test('getLastExerciseReps returns most recent reps', () async {
      await p.logWorkout(_workout('w1', exercises: [
        ExerciseLog(name: 'Squats', sets: [SetData(reps: 12, weight: 80)]),
      ]));
      expect(p.getLastExerciseReps('Squats'), 12);
    });

    test('getPersonalRecord returns highest weight ever', () async {
      await p.logWorkout(_workout('w1', exercises: [
        ExerciseLog(name: 'Deadlift', sets: [SetData(reps: 5, weight: 100), SetData(reps: 3, weight: 120)]),
      ]));
      await p.logWorkout(_workout('w2', exercises: [
        ExerciseLog(name: 'Deadlift', sets: [SetData(reps: 5, weight: 110)]),
      ]));
      expect(p.getPersonalRecord('Deadlift'), 120.0);
    });

    test('getPersonalRecord null for never-logged exercise', () {
      expect(p.getPersonalRecord('Deadlift'), isNull);
    });

    test('getPersonalRecord null when all weights are zero', () async {
      await p.logWorkout(_workout('w1', exercises: [
        ExerciseLog(name: 'Pull-ups', sets: [SetData(reps: 10, weight: 0)]),
      ]));
      expect(p.getPersonalRecord('Pull-ups'), isNull);
    });
  });

  // ── Workout streak ────────────────────────────────────────────────────────

  group('workoutStreak', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('0 with no workouts', () {
      expect(p.workoutStreak, 0);
    });

    test('1 when only today has workout', () async {
      await p.logWorkout(_workout('today'));
      expect(p.workoutStreak, 1);
    });

    test('consecutive days count correctly', () async {
      for (int i = 0; i < 3; i++) {
        await p.logWorkout(_workout('w$i',
            date: DateTime.now().subtract(Duration(days: i))));
      }
      expect(p.workoutStreak, 3);
    });

    test('gap breaks streak (skipped day resets)', () async {
      await p.logWorkout(_workout('today'));
      // yesterday skipped, log 2 days ago
      await p.logWorkout(_workout('w2',
          date: DateTime.now().subtract(const Duration(days: 2))));
      // Streak counts today only (yesterday gap breaks it)
      expect(p.workoutStreak, 1);
    });

    test('no workout today: looks from yesterday', () async {
      await p.logWorkout(_workout('yesterday',
          date: DateTime.now().subtract(const Duration(days: 1))));
      // No workout today, but yesterday had one
      expect(p.workoutStreak, 1);
    });
  });

  // ── Weekly workout data ────────────────────────────────────────────────────

  group('weeklyWorkoutMap & weeklyWorkoutDays', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('weeklyWorkoutMap has 7 entries', () {
      expect(p.weeklyWorkoutMap.length, 7);
    });

    test('weeklyWorkoutMap all false with no workouts', () {
      expect(p.weeklyWorkoutMap.every((v) => v == false), isTrue);
    });

    test('weeklyWorkoutDays 0 with no workouts', () {
      expect(p.weeklyWorkoutDays, 0);
    });

    test('weeklyWorkoutDays counts distinct days only', () async {
      // Log 3 workouts today (same day)
      await p.logWorkout(_workout('w1'));
      await p.logWorkout(_workout('w2'));
      await p.logWorkout(_workout('w3'));
      expect(p.weeklyWorkoutDays, 1); // Still just 1 unique day
    });
  });

  // ── Calorie streak ────────────────────────────────────────────────────────

  group('calorieStreak', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('0 with no food logged', () {
      expect(p.calorieStreak, 0);
    });

    test('1 when today exceeds 500 kcal threshold', () async {
      await p.addFoodEntry(_food('f1', 600, 30));
      expect(p.calorieStreak, greaterThanOrEqualTo(1));
    });

    test('0 when today is below 500 kcal threshold', () async {
      await p.addFoodEntry(_food('f1', 200, 10));
      expect(p.calorieStreak, 0);
    });

    test('whey supplement counts toward 500 kcal threshold', () async {
      await p.updateSupplement('whey', true);
      await p.addFoodEntry(_food('f1', 400, 20));
      // 400 + 120 (whey) = 520 > 500
      expect(p.calorieStreak, greaterThanOrEqualTo(1));
    });
  });

  // ── Weekly calorie data ───────────────────────────────────────────────────

  group('weeklyCalorieData', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('always returns 7 entries', () {
      expect(p.weeklyCalorieData.length, 7);
    });

    test('last entry labeled Today', () {
      expect(p.weeklyCalorieData.last['label'], 'Today');
    });

    test('today entry reflects current food', () async {
      await p.addFoodEntry(_food('f1', 500, 20));
      expect(p.weeklyCalorieData.last['calories'], closeTo(500, 0.01));
    });

    test('today entry includes supplement calories', () async {
      await p.updateSupplement('whey', true);
      expect(p.weeklyCalorieData.last['calories'], closeTo(120, 0.01));
    });

    test('past days default to 0 when no data', () {
      for (int i = 0; i < 6; i++) {
        expect(p.weeklyCalorieData[i]['calories'], 0.0);
      }
    });
  });

  // ── Calorie burn breakdown ────────────────────────────────────────────────

  group('Calorie burn breakdown', () {
    late FitnessProvider p;
    setUp(() async {
      p = FitnessProvider();
      await p.loadData();
      await p.saveHeight(170.0);
      await p.saveAge(24);
      await p.logBodyEntry(weightKg: 70.0, steps: 5000);
    });

    test('restingCaloriesBurned > 0 when BMR available', () {
      expect(p.restingCaloriesBurned, greaterThan(0));
    });

    test('walkingCaloriesBurned > 0 when steps > 0', () {
      expect(p.walkingCaloriesBurned, greaterThan(0));
      expect(p.walkingCaloriesBurned, closeTo(5000 * 0.04 * (70.0 / 70.0), 0.1));
    });

    test('totalCaloriesBurned = resting + walking + workout', () async {
      final r = p.restingCaloriesBurned;
      final w = p.walkingCaloriesBurned;
      final wo = p.todayCaloriesBurned.toDouble();
      expect(p.totalCaloriesBurned, closeTo(r + w + wo, 0.1));
    });

    test('walkingCaloriesBurned 0 with 0 steps', () async {
      await p.logBodyEntry(weightKg: 70.0, steps: 0);
      expect(p.walkingCaloriesBurned, 0.0);
    });

    test('restingCaloriesBurned 0 when no weight (no BMR)', () {
      final fresh = FitnessProvider();
      expect(fresh.restingCaloriesBurned, 0.0);
    });

    test('weeklyCaloriesBurned sums workout burns from past 7 days', () async {
      await p.logWorkout(_workout('w1', exercises: [
        ExerciseLog(name: 'Running', sets: [SetData(reps: 1, weight: 0)]),
      ]));
      expect(p.weeklyCaloriesBurned, greaterThan(0));
    });
  });

  // ── calorieDeficit & inDeficit ────────────────────────────────────────────

  group('calorieDeficit uses totalCaloriesBurned', () {
    late FitnessProvider p;
    setUp(() async {
      p = FitnessProvider();
      await p.loadData();
      await p.saveHeight(170.0);
      await p.saveAge(24);
      await p.logBodyEntry(weightKg: 70.0, steps: 0);
    });

    test('deficit = goal - (eaten - totalBurned)', () async {
      await p.addFoodEntry(_food('f1', 800, 30));
      final expected = p.calorieGoal - (800 - p.totalCaloriesBurned).round();
      expect(p.calorieDeficit, expected);
    });

    test('inDeficit true when eaten < goal + totalBurned', () {
      // No food, some resting burn → definitely in deficit
      expect(p.inDeficit, isTrue);
    });

    test('inDeficit false when big surplus', () async {
      await p.addFoodEntry(_food('f1', 5000, 50));
      // 5000 eaten, total burn << 5000 → net > 1700 → not in deficit
      expect(p.inDeficit, isFalse);
    });

    test('caloriesRemaining is food-only (does not include burn)', () async {
      await p.addFoodEntry(_food('f1', 500, 20));
      expect(p.caloriesRemaining, 1200); // 1700 - 500, ignores burn
    });
  });

  // ── Export / Import ───────────────────────────────────────────────────────

  group('exportAllData / importAllData', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('exportAllData excludes pedometer_baseline and pedometer_date', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('pedometer_baseline', 12345);
      await prefs.setString('pedometer_date', '2024-01-01');
      await prefs.setInt('calorie_goal', 2000);

      final path = await p.exportAllData();
      final content = await File(path).readAsString();

      expect(content, isNot(contains('pedometer_baseline')));
      expect(content, isNot(contains('pedometer_date')));
      expect(content, contains('calorie_goal'));
    });

    test('importAllData returns false for non-existent file', () async {
      final ok = await p.importAllData('/non/existent/path.json');
      expect(ok, isFalse);
    });

    test('importAllData returns false for invalid JSON', () async {
      final f = File('${Directory.systemTemp.path}/bad.json');
      await f.writeAsString('not valid json!!!');
      final ok = await p.importAllData(f.path);
      expect(ok, isFalse);
      await f.delete();
    });

    test('export then import restores data correctly', () async {
      await p.saveCalorieGoal(2200);
      await p.addFoodEntry(_food('f1', 500, 25));
      final path = await p.exportAllData();

      // Fresh provider imports the data
      SharedPreferences.setMockInitialValues({});
      final p2 = FitnessProvider();
      await p2.loadData();
      final ok = await p2.importAllData(path);

      expect(ok, isTrue);
      expect(p2.calorieGoal, 2200);
      expect(p2.todayFood.length, 1);
    });
  });

  // ── getRecentWorkouts ──────────────────────────────────────────────────────

  group('getRecentWorkouts', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('filters by days window', () async {
      await p.logWorkout(_workout('w1')); // today
      await p.logWorkout(_workout('w2',
          date: DateTime.now().subtract(const Duration(days: 20))));
      await p.logWorkout(_workout('w3',
          date: DateTime.now().subtract(const Duration(days: 16))));

      final recent = p.getRecentWorkouts(days: 14);
      expect(recent.length, 1);
      expect(recent.first.id, 'w1');
    });

    test('sorted newest first', () async {
      await p.logWorkout(_workout('older',
          date: DateTime.now().subtract(const Duration(days: 2))));
      await p.logWorkout(_workout('newer'));

      final recent = p.getRecentWorkouts();
      expect(recent.first.id, 'newer');
    });
  });

  // ── kgToGoal / weeksToGoal ────────────────────────────────────────────────

  group('kgToGoal / weeksToGoal', () {
    late FitnessProvider p;
    setUp(() async {
      p = FitnessProvider();
      await p.loadData();
      await p.saveGoalWeight(70.0);
    });

    test('kgToGoal positive when above goal', () async {
      await p.logBodyEntry(weightKg: 80.0);
      expect(p.kgToGoal, closeTo(10.0, 0.01));
    });

    test('kgToGoal negative when below goal', () async {
      await p.logBodyEntry(weightKg: 65.0);
      expect(p.kgToGoal, isNegative);
    });

    test('kgToGoal null when no weight', () {
      expect(p.kgToGoal, isNull);
    });

    test('weeksToGoal null when below goal', () async {
      await p.logBodyEntry(weightKg: 65.0);
      expect(p.weeksToGoal, isNull);
    });

    test('weeksToGoal null when no weight', () {
      expect(p.weeksToGoal, isNull);
    });
  });

  // ── hasPedometerData ──────────────────────────────────────────────────────

  group('hasPedometerData', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('false when baseline not set', () {
      expect(p.hasPedometerData, isFalse);
    });

    test('todaySteps falls back to manual entry when no pedometer', () async {
      await p.logBodyEntry(weightKg: 70.0, steps: 5000);
      expect(p.todaySteps, 5000);
    });
  });

  // ── fatLossCalorieTarget ──────────────────────────────────────────────────

  group('fatLossCalorieTarget', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('null when no weight', () {
      expect(p.fatLossCalorieTarget, isNull);
    });

    test('= TDEE - 500, clamped [1200, 3500]', () async {
      await p.saveHeight(170.0);
      await p.saveAge(24);
      await p.logBodyEntry(weightKg: 78.0);
      final t = p.tdee!;
      expect(p.fatLossCalorieTarget, closeTo((t - 500).clamp(1200.0, 3500.0), 1.0));
    });
  });

  // ── supplementCalories edge cases ─────────────────────────────────────────

  group('supplement calorie edge cases', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('todayCaloriesTotal = food + whey supplement', () async {
      await p.addFoodEntry(_food('f1', 500, 20));
      await p.updateSupplement('whey', true);
      expect(p.todayCaloriesTotal, closeTo(620, 0.01)); // 500 + 120
    });

    test('toggling whey off removes supplement calories', () async {
      await p.updateSupplement('whey', true);
      await p.updateSupplement('whey', false);
      expect(p.supplementCalories, 0.0);
    });
  });

  // ── foodHistory includes today ────────────────────────────────────────────

  group('foodHistory / waterHistory / supplementHistory maps', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('foodHistory includes today key', () async {
      await p.addFoodEntry(_food('f1', 300, 20));
      final today = _todayKey();
      expect(p.foodHistory.containsKey(today), isTrue);
      expect(p.foodHistory[today]!.length, 1);
    });

    test('waterHistory includes today', () async {
      await p.addWater(1000);
      expect(p.waterHistory[_todayKey()], 1000);
    });

    test('supplementHistory includes today', () async {
      await p.updateSupplement('whey', true);
      expect(p.supplementHistory[_todayKey()]!.whey, isTrue);
    });
  });
}

// ─── Utilities ────────────────────────────────────────────────────────────────

String _todayKey() {
  final n = DateTime.now();
  return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}
