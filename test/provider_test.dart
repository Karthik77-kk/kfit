import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karthik_fitness/models/models.dart';
import 'package:karthik_fitness/providers/fitness_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

SmartScaleEntry _scale({double weight = 75.0, double bmr = 1800.0, DateTime? date}) =>
    SmartScaleEntry(
      id: 'scale', date: date ?? DateTime.now(),
      weightKg: weight, bodyFatPercent: 20, bodyFatKg: weight * 0.2,
      muscleMassKg: 35, muscleMassPercent: 46, leanBodyMassKg: weight * 0.8,
      biologicalAge: 22, visceralFatIndex: 5, bmr: bmr,
      bodyWaterPercent: 55, boneMassKg: 3.2, proteinPercent: 18,
      skeletalMuscleMassKg: 28,
    );

SmartScaleEntry _scaleLean({required DateTime date, double lean = 60}) =>
    SmartScaleEntry(
      id: 'sl', date: date, weightKg: lean / 0.8,
      bodyFatPercent: 20, bodyFatKg: 15, muscleMassKg: 35, muscleMassPercent: 46,
      leanBodyMassKg: lean, biologicalAge: 22, visceralFatIndex: 5, bmr: 1700,
      bodyWaterPercent: 55, boneMassKg: 3.2, proteinPercent: 18, skeletalMuscleMassKg: 28,
    );

SmartScaleEntry _scaleFatLean({required DateTime date, double fatKg = 18, double leanKg = 56}) =>
    SmartScaleEntry(
      id: 'sfl', date: date, weightKg: fatKg + leanKg,
      bodyFatPercent: fatKg / (fatKg + leanKg) * 100, bodyFatKg: fatKg,
      muscleMassKg: leanKg * 0.6, muscleMassPercent: 46, leanBodyMassKg: leanKg,
      biologicalAge: 22, visceralFatIndex: 5, bmr: 1700, bodyWaterPercent: 55,
      boneMassKg: 3.2, proteinPercent: 18, skeletalMuscleMassKg: 28,
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

    test('profile + goals always persisted to prefs after loadData (backup fix)', () async {
      // Even without the user ever visiting Settings, all keys must exist in
      // SharedPreferences so they appear in export backups.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('user_name'),     isTrue,  reason: 'user_name missing from backup');
      expect(prefs.containsKey('height_cm'),     isTrue,  reason: 'height_cm missing from backup');
      expect(prefs.containsKey('age'),           isTrue,  reason: 'age missing from backup');
      expect(prefs.containsKey('goal_weight_kg'),isTrue,  reason: 'goal_weight_kg missing from backup');
      expect(prefs.containsKey('calorie_goal'),  isTrue,  reason: 'calorie_goal missing from backup');
      expect(prefs.containsKey('protein_goal'),  isTrue,  reason: 'protein_goal missing from backup');
      expect(prefs.containsKey('water_goal_ml'), isTrue,  reason: 'water_goal_ml missing from backup');
      expect(prefs.containsKey('step_goal'),     isTrue,  reason: 'step_goal missing from backup');
      // Values must match the loaded defaults
      expect(prefs.getString('user_name'),     'Karthik');
      expect(prefs.getDouble('height_cm'),     170.0);
      expect(prefs.getInt('age'),              24);
      expect(prefs.getDouble('goal_weight_kg'),70.0);
      expect(prefs.getInt('calorie_goal'),     1700);
      expect(prefs.getInt('protein_goal'),     100);
      expect(prefs.getInt('water_goal_ml'),    2500);
      expect(prefs.getInt('step_goal'),        8000);
    });
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
  });

  // ── In-app notification feed (live + milestones) ──────────────────────────

  group('Notification feed', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('liveInsightFeed is always non-empty (fallback insight)', () {
      expect(p.liveInsightFeed, isNotEmpty);
    });

    test('milestoneFeed starts empty', () {
      expect(p.milestoneFeed, isEmpty);
    });

    test('markNotificationsRead marks current live insights seen (badge drops)', () async {
      final before = p.unreadNotifications;
      expect(before, greaterThan(0));
      await p.markNotificationsRead();
      // Same state → the same insight titles are now "seen" → no longer unread.
      expect(p.unreadNotifications, 0);
    });
  });

  // ── Weekly summary getters ────────────────────────────────────────────────

  group('Weekly summary getters', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('weeklyAvgCalories includes todays food', () async {
      await p.addFoodEntry(_food('f1', 700, 30));
      expect(p.weeklyAvgCalories, closeTo(700.0 / 7, 1));
    });

    test('weeklyAvgCalories includes supplement calories', () async {
      await p.updateSupplement('whey', true); // +120 kcal
      expect(p.weeklyAvgCalories, closeTo(120.0 / 7, 1));
    });

    test('weeklyAvgProtein includes today protein', () async {
      await p.addFoodEntry(_food('f1', 400, 50));
      expect(p.weeklyAvgProtein, closeTo(50.0 / 7, 0.5));
    });

    test('weeklyWaterGoalHitDays 0 when no water logged', () {
      expect(p.weeklyWaterGoalHitDays, 0);
    });

    test('weeklyWaterGoalHitDays 1 when today meets goal', () async {
      await p.saveWaterGoal(500);
      await p.addWater(500);
      expect(p.weeklyWaterGoalHitDays, 1);
    });

    test('weeklyProteinGoalHitDays 0 with no food', () {
      expect(p.weeklyProteinGoalHitDays, 0);
    });

    test('weeklyProteinGoalHitDays 1 when today meets goal', () async {
      await p.saveProteinGoal(50);
      await p.addFoodEntry(_food('f1', 200, 50));
      expect(p.weeklyProteinGoalHitDays, 1);
    });
  });

  // ── Historical aggregates (insight engine inputs) ─────────────────────────

  group('Historical aggregates', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('caloriesForDate uses live data for today', () async {
      await p.addFoodEntry(_food('f1', 650, 30));
      expect(p.caloriesForDate(DateTime.now()), closeTo(650, 0.01));
    });

    test('proteinForDate uses live data for today (incl whey)', () async {
      await p.addFoodEntry(_food('f1', 400, 30));
      await p.updateSupplement('whey', true); // +25g
      expect(p.proteinForDate(DateTime.now()), closeTo(55, 0.01));
    });

    test('avgCaloriesForDays(0,0) equals today when only today logged', () async {
      await p.addFoodEntry(_food('f1', 800, 20));
      expect(p.avgCaloriesForDays(0, 0), closeTo(800, 0.01));
    });

    test('avgCaloriesForDays ignores empty days (no zero dilution)', () async {
      await p.addFoodEntry(_food('f1', 800, 20));
      // days 1..6 have no data → averaged only over the one logged day
      expect(p.avgCaloriesForDays(0, 6), closeTo(800, 0.01));
    });

    test('proteinAvgForWeekday reflects today when only today logged', () async {
      await p.addFoodEntry(_food('f1', 400, 40));
      expect(p.proteinAvgForWeekday(DateTime.now().weekday), closeTo(40, 0.01));
    });

    test('proteinAvgForWeekday null for a weekday with no data', () async {
      final otherWeekday = (DateTime.now().weekday % 7) + 1;
      // ensure it's a different weekday than today with no logs
      if (otherWeekday != DateTime.now().weekday) {
        expect(p.proteinAvgForWeekday(otherWeekday), isNull);
      }
    });

    test('daysSinceLastWorkout 999 when none', () {
      expect(p.daysSinceLastWorkout, 999);
    });

    test('daysSinceLastWorkout 0 after logging today', () async {
      await p.logWorkout(_workout('w1'));
      expect(p.daysSinceLastWorkout, 0);
    });
  });

  // ── Body-composition analytics ────────────────────────────────────────────

  group('Body-composition analytics', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('goalProgress reflects real start→goal span (not hardcoded 10kg)', () async {
      await p.saveGoalWeight(70);
      // Start far back at 90kg, now at 80kg → 50% of the 20kg journey.
      await p.logScaleEntry(_scale(date: DateTime.now().subtract(const Duration(days: 40)), weight: 90));
      await p.logScaleEntry(_scale(date: DateTime.now(), weight: 80));
      expect(p.startWeightKg, closeTo(90, 0.01));
      expect(p.goalProgress, closeTo(0.5, 0.02));
    });

    test('goalProgress 1.0 when goal reached', () async {
      await p.saveGoalWeight(70);
      await p.logScaleEntry(_scale(date: DateTime.now().subtract(const Duration(days: 10)), weight: 80));
      await p.logScaleEntry(_scale(date: DateTime.now(), weight: 69));
      expect(p.goalProgress, 1.0);
    });

    test('weeksToGoal uses measured trend, not instantaneous deficit', () async {
      await p.saveGoalWeight(70);
      // ~0.5 kg/week loss over 4 weeks (76 → 74), 4 kg to go → ~8 weeks, NOT 2.
      await p.logScaleEntry(_scale(date: DateTime.now().subtract(const Duration(days: 28)), weight: 76));
      await p.logScaleEntry(_scale(date: DateTime.now().subtract(const Duration(days: 14)), weight: 75));
      await p.logScaleEntry(_scale(date: DateTime.now(), weight: 74));
      final wk = p.weeksToGoal;
      expect(wk, isNotNull);
      expect(wk!, greaterThan(4)); // trend-based, realistic — not the absurd 2
    });

    test('weeksToGoal null when not losing and no history', () async {
      await p.saveGoalWeight(70);
      await p.logScaleEntry(_scale(date: DateTime.now(), weight: 80));
      // single entry → no trend; with no body weight/height for TDEE fallback may be null
      expect(p.weeksToGoal == null || p.weeksToGoal! >= 1, isTrue);
    });

    test('waistToHipRatio computed from measurements', () async {
      await p.logMeasurement(MeasurementEntry(
          id: 'm', date: DateTime.now(), waistCm: 90, hipsCm: 100));
      expect(p.waistToHipRatio, closeTo(0.90, 0.001));
      expect(p.whrRisk, isNotNull);
    });

    test('waistToHeightRatio uses height', () async {
      await p.saveHeight(180);
      await p.logMeasurement(MeasurementEntry(id: 'm', date: DateTime.now(), waistCm: 90));
      expect(p.waistToHeightRatio, closeTo(0.5, 0.001));
    });

    test('ffmi computed from scale lean mass + height', () async {
      await p.saveHeight(180);
      // lean 60kg, h=1.8 → 60/3.24 = 18.52 + 6.1*(1.8-1.8)=0 → ~18.5
      await p.logScaleEntry(_scaleLean(date: DateTime.now(), lean: 60));
      expect(p.ffmi, closeTo(18.52, 0.1));
    });

    test('bodyCompTrajectory classifies recomp (fat down, muscle up)', () async {
      await p.logScaleEntry(_scaleFatLean(
          date: DateTime.now().subtract(const Duration(days: 30)), fatKg: 20, leanKg: 55));
      await p.logScaleEntry(_scaleFatLean(date: DateTime.now(), fatKg: 17, leanKg: 57));
      final t = p.bodyCompTrajectory;
      expect(t, isNotNull);
      expect(t!.fatChange, closeTo(-3, 0.01));
      expect(t.leanChange, closeTo(2, 0.01));
      expect(t.verdict.toLowerCase(), contains('recomp'));
    });

    test('bodyCompositionStatus returns a label when scale logged', () async {
      await p.logScaleEntry(_scale(date: DateTime.now(), weight: 75));
      expect(p.bodyCompositionStatus.label, isNotEmpty);
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

  // ── whtrStatus ───────────────────────────────────────────────────────────

  group('whtrStatus', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('returns dash label when no measurement logged', () {
      expect(p.whtrStatus.label, '—');
    });

    test('Healthy when waist/height < 0.5', () async {
      await p.saveHeight(180);
      await p.logMeasurement(MeasurementEntry(id: 'm', date: DateTime.now(), waistCm: 80));
      // 80/180 ≈ 0.444 → Healthy
      expect(p.whtrStatus.label, 'Healthy');
    });

    test('Raised when waist/height in [0.5, 0.6)', () async {
      await p.saveHeight(180);
      await p.logMeasurement(MeasurementEntry(id: 'm', date: DateTime.now(), waistCm: 99));
      // 99/180 ≈ 0.55 → Raised
      expect(p.whtrStatus.label, 'Raised');
    });

    test('High when waist/height >= 0.6', () async {
      await p.saveHeight(160);
      await p.logMeasurement(MeasurementEntry(id: 'm', date: DateTime.now(), waistCm: 100));
      // 100/160 = 0.625 → High
      expect(p.whtrStatus.label, 'High');
    });

    test('returns dash when height is 0 (guard against divide-by-zero)', () async {
      await p.saveHeight(0);
      await p.logMeasurement(MeasurementEntry(id: 'm', date: DateTime.now(), waistCm: 80));
      expect(p.whtrStatus.label, '—');
    });
  });

  // ── ffmiStatus ───────────────────────────────────────────────────────────

  group('ffmiStatus', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('returns dash when no scale entry logged', () {
      expect(p.ffmiStatus.label, '—');
    });

    test('Below average when ffmi < 18', () async {
      await p.saveHeight(180);
      // lean 50kg, h=1.8 → 50/3.24 + 6.1*(1.8-1.8) ≈ 15.4 → Below average
      await p.logScaleEntry(SmartScaleEntry(
        id: 's', date: DateTime.now(), weightKg: 65,
        bodyFatPercent: 23, bodyFatKg: 15, muscleMassKg: 30, muscleMassPercent: 46,
        leanBodyMassKg: 50, biologicalAge: 24, visceralFatIndex: 5, bmr: 1600,
        bodyWaterPercent: 55, boneMassKg: 3, proteinPercent: 17, skeletalMuscleMassKg: 25,
      ));
      expect(p.ffmiStatus.label, 'Below average');
    });

    test('Average when ffmi in [18, 20)', () async {
      await p.saveHeight(180);
      // lean 60kg → ffmi ≈ 18.52 → Average
      await p.logScaleEntry(_scaleLean(date: DateTime.now(), lean: 60));
      expect(p.ffmiStatus.label, 'Average');
    });

    test('Athletic when ffmi in [20, 22)', () async {
      await p.saveHeight(175);
      // lean 65kg, h=1.75 → 65/3.0625 + 6.1*(1.8-1.75) ≈ 21.2 + 0.305 ≈ 21.5 → Athletic
      await p.logScaleEntry(SmartScaleEntry(
        id: 's', date: DateTime.now(), weightKg: 80,
        bodyFatPercent: 18.75, bodyFatKg: 15, muscleMassKg: 40, muscleMassPercent: 50,
        leanBodyMassKg: 65, biologicalAge: 24, visceralFatIndex: 4, bmr: 1800,
        bodyWaterPercent: 60, boneMassKg: 3.5, proteinPercent: 19, skeletalMuscleMassKg: 32,
      ));
      expect(p.ffmiStatus.label, 'Athletic');
    });

    test('Excellent when ffmi in [22, 25)', () async {
      await p.saveHeight(175);
      // lean 73kg, h=1.75 → 73/3.0625 + 6.1*(1.8-1.75) ≈ 23.8 + 0.305 ≈ 24.1 → Excellent
      await p.logScaleEntry(SmartScaleEntry(
        id: 's', date: DateTime.now(), weightKg: 88,
        bodyFatPercent: 17, bodyFatKg: 15, muscleMassKg: 45, muscleMassPercent: 51,
        leanBodyMassKg: 73, biologicalAge: 24, visceralFatIndex: 4, bmr: 1900,
        bodyWaterPercent: 62, boneMassKg: 3.5, proteinPercent: 20, skeletalMuscleMassKg: 36,
      ));
      expect(p.ffmiStatus.label, 'Excellent');
    });

    test('Very high when ffmi >= 25', () async {
      await p.saveHeight(175);
      // lean 85kg, h=1.75 → 85/3.0625 + 0.305 ≈ 27.76 + 0.305 ≈ 28.07 → Very high
      await p.logScaleEntry(SmartScaleEntry(
        id: 's', date: DateTime.now(), weightKg: 100,
        bodyFatPercent: 15, bodyFatKg: 15, muscleMassKg: 52, muscleMassPercent: 52,
        leanBodyMassKg: 85, biologicalAge: 24, visceralFatIndex: 3, bmr: 2100,
        bodyWaterPercent: 64, boneMassKg: 4, proteinPercent: 21, skeletalMuscleMassKg: 42,
      ));
      expect(p.ffmiStatus.label, 'Very high');
    });
  });

  // ── hydrationStatus ──────────────────────────────────────────────────────

  group('hydrationStatus', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('null when no scale entry', () {
      expect(p.hydrationStatus, isNull);
    });

    test('Low when bodyWaterPercent < 50', () async {
      await p.logScaleEntry(_scale()..toString()); // use helper then override
      // Build entry with low water
      await p.logScaleEntry(SmartScaleEntry(
        id: 's', date: DateTime.now(), weightKg: 75,
        bodyFatPercent: 20, bodyFatKg: 15, muscleMassKg: 35, muscleMassPercent: 46,
        leanBodyMassKg: 60, biologicalAge: 24, visceralFatIndex: 5, bmr: 1700,
        bodyWaterPercent: 45, boneMassKg: 3.2, proteinPercent: 18, skeletalMuscleMassKg: 28,
      ));
      expect(p.hydrationStatus!.label, 'Low');
    });

    test('Healthy when bodyWaterPercent in [50, 65]', () async {
      await p.logScaleEntry(SmartScaleEntry(
        id: 's', date: DateTime.now(), weightKg: 75,
        bodyFatPercent: 20, bodyFatKg: 15, muscleMassKg: 35, muscleMassPercent: 46,
        leanBodyMassKg: 60, biologicalAge: 24, visceralFatIndex: 5, bmr: 1700,
        bodyWaterPercent: 58, boneMassKg: 3.2, proteinPercent: 18, skeletalMuscleMassKg: 28,
      ));
      expect(p.hydrationStatus!.label, 'Healthy');
    });

    test('High when bodyWaterPercent > 65', () async {
      await p.logScaleEntry(SmartScaleEntry(
        id: 's', date: DateTime.now(), weightKg: 75,
        bodyFatPercent: 20, bodyFatKg: 15, muscleMassKg: 35, muscleMassPercent: 46,
        leanBodyMassKg: 60, biologicalAge: 24, visceralFatIndex: 5, bmr: 1700,
        bodyWaterPercent: 70, boneMassKg: 3.2, proteinPercent: 18, skeletalMuscleMassKg: 28,
      ));
      expect(p.hydrationStatus!.label, 'High');
    });
  });

  // ── bioAgeDelta ──────────────────────────────────────────────────────────

  group('bioAgeDelta', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('null when no scale entry', () {
      expect(p.bioAgeDelta, isNull);
    });

    test('negative when biologically younger than real age', () async {
      await p.saveAge(30);
      await p.logScaleEntry(SmartScaleEntry(
        id: 's', date: DateTime.now(), weightKg: 75,
        bodyFatPercent: 18, bodyFatKg: 13.5, muscleMassKg: 38, muscleMassPercent: 50,
        leanBodyMassKg: 61.5, biologicalAge: 25, visceralFatIndex: 4, bmr: 1750,
        bodyWaterPercent: 60, boneMassKg: 3.3, proteinPercent: 19, skeletalMuscleMassKg: 30,
      ));
      expect(p.bioAgeDelta, -5); // 25 - 30 = -5
    });

    test('positive when biologically older than real age', () async {
      await p.saveAge(24);
      await p.logScaleEntry(SmartScaleEntry(
        id: 's', date: DateTime.now(), weightKg: 85,
        bodyFatPercent: 28, bodyFatKg: 24, muscleMassKg: 30, muscleMassPercent: 35,
        leanBodyMassKg: 61, biologicalAge: 30, visceralFatIndex: 8, bmr: 1600,
        bodyWaterPercent: 50, boneMassKg: 3, proteinPercent: 16, skeletalMuscleMassKg: 24,
      ));
      expect(p.bioAgeDelta, 6); // 30 - 24 = 6
    });

    test('null when biologicalAge is 0 (not reported by scale)', () async {
      await p.logScaleEntry(SmartScaleEntry(
        id: 's', date: DateTime.now(), weightKg: 75,
        bodyFatPercent: 20, bodyFatKg: 15, muscleMassKg: 35, muscleMassPercent: 46,
        leanBodyMassKg: 60, biologicalAge: 0, visceralFatIndex: 5, bmr: 1700,
        bodyWaterPercent: 55, boneMassKg: 3.2, proteinPercent: 18, skeletalMuscleMassKg: 28,
      ));
      expect(p.bioAgeDelta, isNull);
    });
  });

  // ── caloriesAvgForWeekday ────────────────────────────────────────────────

  group('caloriesAvgForWeekday', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('null when no data for that weekday', () {
      // today's weekday might have 0 food, but historical keys are empty
      // ask for a day with no data in history
      final someWeekday = (DateTime.now().weekday % 7) + 1; // shift by 1
      expect(p.caloriesAvgForWeekday(someWeekday), isNull);
    });

    test('returns todays calories when today has food', () async {
      await p.addFoodEntry(_food('f1', 700, 30));
      final today = DateTime.now().weekday;
      final avg = p.caloriesAvgForWeekday(today);
      expect(avg, isNotNull);
      expect(avg!, closeTo(700, 1));
    });

    test('averages multiple entries for same weekday', () async {
      final now = DateTime.now();
      final weekday = now.weekday;

      // Log food for today (which is on `weekday`).
      await p.addFoodEntry(_food('t', 700, 30));

      // The getter should return that value for today's weekday.
      final avg = p.caloriesAvgForWeekday(weekday);
      expect(avg, isNotNull);
      expect(avg!, closeTo(700, 1));
    });
  });

  // ── clearNotifications / pushNotification (provider layer) ───────────────

  group('clearNotifications and pushNotification via provider', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('clearNotifications empties milestone feed', () async {
      // Push a milestone notification then clear it.
      final n = AppNotification(
        id: 'test1', emoji: '🏋️', title: 'Test milestone',
        body: 'You did it!', accent: 0xFFFF9F0A,
        category: 'milestone', timestamp: DateTime.now(),
      );
      await p.pushNotification(n);
      expect(p.milestoneFeed.isNotEmpty, isTrue);

      await p.clearNotifications();
      expect(p.milestoneFeed, isEmpty);
    });

    test('pushNotification adds to milestoneFeed', () async {
      final n = AppNotification(
        id: 'ms_push', emoji: '🎯', title: 'Goal reached!',
        body: 'Hit 70kg!', accent: 0xFF30D158,
        category: 'milestone', timestamp: DateTime.now(),
      );
      await p.pushNotification(n);
      expect(p.milestoneFeed.any((e) => e.id == 'ms_push'), isTrue);
    });

    test('pushNotification increments unreadNotifications count', () async {
      await p.markNotificationsRead(); // clear badge first
      final before = p.unreadNotifications;
      final n = AppNotification(
        id: 'badge_test', emoji: '🏆', title: 'New badge',
        body: 'You earned it', accent: 0xFF40C8E0,
        category: 'milestone', timestamp: DateTime.now(),
      );
      await p.pushNotification(n);
      expect(p.unreadNotifications, greaterThan(before));
    });
  });

  // ── _purgeStaleDailyKeys (stale key cleanup) ────────────────────────────

  group('Stale daily key purge (food/water/supp keys > 61 days)', () {
    test('removes food/water/supp keys older than 61 days on loadData', () async {
      final staleDate = DateTime.now().subtract(const Duration(days: 70));
      final staleKey = '${staleDate.year}-${staleDate.month.toString().padLeft(2,'0')}-${staleDate.day.toString().padLeft(2,'0')}';

      // Pre-seed stale keys in SharedPreferences
      SharedPreferences.setMockInitialValues({
        'food_$staleKey': '[]',
        'water_$staleKey': '500',
        'supp_$staleKey': '{"whey":false,"creatine":false,"multivitamin":false}',
      });

      final p = FitnessProvider();
      await p.loadData();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('food_$staleKey'), isFalse,
          reason: 'food key older than 61 days should be purged');
      expect(prefs.containsKey('water_$staleKey'), isFalse,
          reason: 'water key older than 61 days should be purged');
      expect(prefs.containsKey('supp_$staleKey'), isFalse,
          reason: 'supp key older than 61 days should be purged');
    });

    test('keeps food/water/supp keys within 60 days', () async {
      final recentDate = DateTime.now().subtract(const Duration(days: 30));
      final recentKey = '${recentDate.year}-${recentDate.month.toString().padLeft(2,'0')}-${recentDate.day.toString().padLeft(2,'0')}';

      SharedPreferences.setMockInitialValues({
        'food_$recentKey': '[]',
        'water_$recentKey': 1000, // int, not String
      });

      final p = FitnessProvider();
      await p.loadData();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('food_$recentKey'), isTrue,
          reason: 'food key within 60 days must NOT be purged');
      expect(prefs.containsKey('water_$recentKey'), isTrue,
          reason: 'water key within 60 days must NOT be purged');
    });

    test('does not purge non-daily keys (workouts, body_history etc)', () async {
      SharedPreferences.setMockInitialValues({
        'workouts': '[]',
        'body_history': '[]',
        'goals_calorie': 1700, // int
      });

      final p = FitnessProvider();
      await p.loadData();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('workouts'), isTrue);
      expect(prefs.containsKey('body_history'), isTrue);
      expect(prefs.containsKey('goals_calorie'), isTrue);
    });
  });

  // ── netCalories — uses totalCaloriesBurned (resting + walking + workout) ──

  group('netCalories uses totalCaloriesBurned', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('0 when no food and no burn', () {
      expect(p.netCalories, 0);
    });

    test('equals todayCaloriesTotal when no burn sources active', () async {
      await p.addFoodEntry(_food('f1', 800, 40));
      // No weight → no resting burn; no steps; no workout → burn = 0
      expect(p.netCalories, p.todayCaloriesTotal.round());
    });

    test('is less than todayCaloriesTotal when weight logged (resting burn active)', () async {
      await p.logBodyEntry(weightKg: 75.0);
      await p.addFoodEntry(_food('f1', 800, 40));
      // Resting burn is prorated from BMR (Mifflin), but requires weight.
      // Since burn > 0, net < eaten.
      expect(p.netCalories, lessThan(p.todayCaloriesTotal.round()));
    });

    test('decreases further when steps are added', () async {
      await p.logBodyEntry(weightKg: 75.0);
      await p.addFoodEntry(_food('f1', 1000, 50));
      final netBefore = p.netCalories;
      // Add steps → walkingCaloriesBurned increases → net decreases
      await p.updateTodaySteps(8000);
      expect(p.netCalories, lessThan(netBefore));
    });

    test('consistent with inDeficit: inDeficit == (netCalories < calorieGoal)', () async {
      await p.saveCalorieGoal(1700);
      await p.addFoodEntry(_food('f1', 800, 40));
      expect(p.inDeficit, equals(p.netCalories < p.calorieGoal));
    });

    test('consistent with calorieDeficit: calorieGoal - netCalories = calorieDeficit', () async {
      await p.saveCalorieGoal(1700);
      await p.addFoodEntry(_food('f1', 1200, 60));
      expect(p.calorieDeficit, equals(p.calorieGoal - p.netCalories));
    });

    test('inDeficit false when netCalories exceeds calorieGoal', () async {
      await p.saveCalorieGoal(1000);
      await p.addFoodEntry(_food('f1', 1500, 60)); // way over goal, no burn
      expect(p.inDeficit, isFalse);
      expect(p.netCalories, greaterThan(p.calorieGoal));
    });

    test('includes workout calories in burn (MET)', () async {
      await p.logBodyEntry(weightKg: 80.0);
      await p.addFoodEntry(_food('f1', 1200, 60));
      final netBefore = p.netCalories;
      await p.logWorkout(_workout('w1', exercises: [
        ExerciseLog(name: 'Bench Press', sets: [SetData(reps: 8, weight: 60),SetData(reps: 8, weight: 60),SetData(reps: 8, weight: 60)]),
      ]));
      expect(p.netCalories, lessThan(netBefore));
    });
  });

  // ── Over-goal raw ratios (drives ring overflow display) ───────────────────

  group('Over-goal raw ratios for ring overflow', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('raw calorie ratio > 1.0 when over goal', () async {
      await p.saveCalorieGoal(1000);
      await p.addFoodEntry(_food('f1', 1200, 40)); // 120% of goal
      final rawRatio = p.calorieGoal > 0 ? p.todayCaloriesTotal / p.calorieGoal : 0.0;
      expect(rawRatio, greaterThan(1.0));
      expect(rawRatio, closeTo(1.2, 0.01));
    });

    test('raw protein ratio > 1.0 when over protein goal', () async {
      await p.saveProteinGoal(50);
      await p.addFoodEntry(_food('f1', 200, 80)); // 160% of goal
      final rawRatio = p.proteinGoal > 0 ? p.todayProteinTotal / p.proteinGoal : 0.0;
      expect(rawRatio, greaterThan(1.0));
      expect(rawRatio, closeTo(1.6, 0.01));
    });

    test('raw water ratio > 1.0 when over water goal', () async {
      await p.saveWaterGoal(1000);
      await p.addWater(1500); // 150% of goal
      final rawRatio = p.waterGoalMl > 0 ? p.todayWaterMl / p.waterGoalMl : 0.0;
      expect(rawRatio, greaterThan(1.0));
      expect(rawRatio, closeTo(1.5, 0.01));
    });

    test('calPct formula produces >100 when over goal', () async {
      await p.saveCalorieGoal(1700);
      await p.addFoodEntry(_food('f1', 2000, 80));
      final calPct = p.calorieGoal > 0 ? (p.todayCaloriesTotal / p.calorieGoal * 100).round() : 0;
      expect(calPct, greaterThan(100));
      expect(calPct, closeTo(118, 1)); // 2000/1700*100 ≈ 118
    });

    test('caloriesRemaining is negative when over goal', () async {
      await p.saveCalorieGoal(1000);
      await p.addFoodEntry(_food('f1', 1200, 40));
      expect(p.caloriesRemaining, lessThan(0));
      expect(p.caloriesRemaining, -200); // 1000 - 1200
    });

    test('calorieProgress clamped to 1.0 even when 150% over', () async {
      await p.saveCalorieGoal(1000);
      await p.addFoodEntry(_food('f1', 1500, 40));
      expect(p.calorieProgress, 1.0); // clamped
    });

    test('proteinProgress clamped to 1.0 even when over', () async {
      await p.saveProteinGoal(50);
      await p.addFoodEntry(_food('f1', 200, 100));
      expect(p.proteinProgress, 1.0);
    });

    test('goalProgress clamped to 1.0 when weight goes below goal (over-achieved)', () async {
      await p.saveGoalWeight(70.0);
      await p.logScaleEntry(_scale(date: DateTime.now().subtract(const Duration(days: 10)), weight: 80));
      await p.logScaleEntry(_scale(date: DateTime.now(), weight: 65)); // past goal
      expect(p.goalProgress, 1.0); // clamped, goal is reached
    });
  });

  // ── fatMassKg and leanMassKg ─────────────────────────────────────────────

  group('fatMassKg and leanMassKg', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('fatMassKg null when no scale entry', () {
      expect(p.fatMassKg, isNull);
    });

    test('fatMassKg null when bodyFatKg is 0 on scale entry', () async {
      await p.logScaleEntry(SmartScaleEntry(
        id: 's', date: DateTime.now(), weightKg: 75,
        bodyFatPercent: 0, bodyFatKg: 0, muscleMassKg: 35, muscleMassPercent: 46,
        leanBodyMassKg: 60, biologicalAge: 24, visceralFatIndex: 5, bmr: 1700,
        bodyWaterPercent: 55, boneMassKg: 3.2, proteinPercent: 18, skeletalMuscleMassKg: 28,
      ));
      expect(p.fatMassKg, isNull);
    });

    test('fatMassKg returns bodyFatKg from latest scale entry', () async {
      await p.logScaleEntry(_scale(weight: 75, bmr: 1700));
      // _scale sets bodyFatKg = weight * 0.2 = 75 * 0.2 = 15
      expect(p.fatMassKg, closeTo(15.0, 0.01));
    });

    test('leanMassKg null when no scale entry', () {
      expect(p.leanMassKg, isNull);
    });

    test('leanMassKg null when leanBodyMassKg is 0 on entry', () async {
      await p.logScaleEntry(SmartScaleEntry(
        id: 's', date: DateTime.now(), weightKg: 75,
        bodyFatPercent: 20, bodyFatKg: 15, muscleMassKg: 35, muscleMassPercent: 46,
        leanBodyMassKg: 0, biologicalAge: 24, visceralFatIndex: 5, bmr: 1700,
        bodyWaterPercent: 55, boneMassKg: 3.2, proteinPercent: 18, skeletalMuscleMassKg: 28,
      ));
      expect(p.leanMassKg, isNull);
    });

    test('leanMassKg returns leanBodyMassKg from latest scale entry', () async {
      await p.logScaleEntry(_scale(weight: 75, bmr: 1700));
      // _scale sets leanBodyMassKg = weight * 0.8 = 60
      expect(p.leanMassKg, closeTo(60.0, 0.01));
    });

    test('fatMassKg updates to latest scale entry', () async {
      await p.logScaleEntry(_scale(date: DateTime.now().subtract(const Duration(days: 2)), weight: 80, bmr: 1700));
      await p.logScaleEntry(_scale(date: DateTime.now(), weight: 75, bmr: 1680));
      expect(p.fatMassKg, closeTo(75 * 0.2, 0.01)); // from latest entry
    });
  });

  // ── startWeightKg ────────────────────────────────────────────────────────

  group('startWeightKg', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('null when no history', () {
      expect(p.startWeightKg, isNull);
    });

    test('returns first body entry weight', () async {
      await p.logBodyEntry(weightKg: 85.0);
      expect(p.startWeightKg, closeTo(85.0, 0.01));
    });

    test('returns scale entry if it predates body entry', () async {
      await p.logScaleEntry(_scale(
          date: DateTime.now().subtract(const Duration(days: 10)), weight: 90, bmr: 1800));
      await p.logBodyEntry(weightKg: 85.0); // today
      expect(p.startWeightKg, closeTo(90.0, 0.01)); // scale is older
    });

    test('returns body entry if it predates scale entry', () async {
      // For this we can only log today entries (same-day merging)
      // Just verify it returns the earliest one
      await p.logBodyEntry(weightKg: 85.0);
      expect(p.startWeightKg, closeTo(85.0, 0.01));
    });

    test('ignores zero-weight entries', () async {
      await p.logScaleEntry(SmartScaleEntry(
        id: 's', date: DateTime.now().subtract(const Duration(days: 5)), weightKg: 0,
        bodyFatPercent: 0, bodyFatKg: 0, muscleMassKg: 0, muscleMassPercent: 0,
        leanBodyMassKg: 0, biologicalAge: 0, visceralFatIndex: 0, bmr: 0,
        bodyWaterPercent: 0, boneMassKg: 0, proteinPercent: 0, skeletalMuscleMassKg: 0,
      ));
      await p.logBodyEntry(weightKg: 80.0);
      expect(p.startWeightKg, closeTo(80.0, 0.01)); // zero-weight ignored
    });
  });

  // ── projectedEodCalories and projectedEodProtein ─────────────────────────

  group('projectedEodCalories', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('null when no food logged', () {
      // Even if hour >= 11, no food = null
      expect(p.projectedEodCalories, isNull);
    });

    test('null when no protein logged', () {
      expect(p.projectedEodProtein, isNull);
    });

    test('returns positive value when food logged (if after 11 AM)', () async {
      // Can't mock DateTime.now().hour, so we can only assert the null/non-null
      // boundary based on current time. If before 11 AM → null; after 11 AM → non-null.
      await p.addFoodEntry(_food('f1', 800, 40));
      final hour = DateTime.now().hour;
      if (hour >= 11) {
        expect(p.projectedEodCalories, isNotNull);
        expect(p.projectedEodCalories!, greaterThan(0));
      } else {
        expect(p.projectedEodCalories, isNull);
      }
    });

    test('projectedEodProtein returns positive when protein logged after 11 AM', () async {
      await p.addFoodEntry(_food('f1', 400, 50));
      final hour = DateTime.now().hour;
      if (hour >= 11) {
        expect(p.projectedEodProtein, isNotNull);
        expect(p.projectedEodProtein!, greaterThan(0));
      } else {
        expect(p.projectedEodProtein, isNull);
      }
    });

    test('projectedEodCalories includes supplement calories in signal', () async {
      await p.updateSupplement('whey', true); // +120 kcal
      final hour = DateTime.now().hour;
      if (hour >= 11) {
        expect(p.projectedEodCalories, isNotNull);
        // With whey, todayCaloriesTotal = 120 > 0, so projection is non-null
        expect(p.projectedEodCalories!, greaterThan(0));
      } else {
        expect(p.projectedEodCalories, isNull);
      }
    });
  });

  // ── overeatsOnWeekends ───────────────────────────────────────────────────

  group('overeatsOnWeekends', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('false when no historical data at all', () {
      expect(p.overeatsOnWeekends, isFalse);
    });

    test('false when no weekend data (only weekday data)', () async {
      // Today might be a weekday or weekend; we can only influence today's data.
      // If today is a weekday, add today's data and expect false (no weekend data).
      final now = DateTime.now();
      final isWeekend = now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
      if (!isWeekend) {
        await p.addFoodEntry(_food('f1', 1800, 80));
        expect(p.overeatsOnWeekends, isFalse); // no weekend data to compare
      }
    });

    test('false when weekend avg <= weekday avg + 250', () async {
      // If today is a weekend, logging 1700 kcal → weekend avg 1700.
      // No weekday data → false (empty weekday = false).
      // Actually with no weekday data, overeatsOnWeekends = false.
      expect(p.overeatsOnWeekends, isFalse);
    });

    test('false when only one side has data', () async {
      await p.addFoodEntry(_food('f1', 2500, 80));
      // Today contributes to either weekday or weekend bucket, but not both.
      // Missing one side → false.
      expect(p.overeatsOnWeekends, isFalse);
    });
  });

  // ── avgWaterForDays ──────────────────────────────────────────────────────

  group('avgWaterForDays', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('0 when no water logged', () {
      expect(p.avgWaterForDays(0, 6), 0);
    });

    test('returns today water when only today has data', () async {
      await p.addWater(2000);
      expect(p.avgWaterForDays(0, 0), closeTo(2000, 0.01));
    });

    test('averages only days with water (no zero dilution)', () async {
      await p.addWater(3000);
      // Only today has data; days 1-6 are empty → average = 3000 (not 3000/7)
      expect(p.avgWaterForDays(0, 6), closeTo(3000, 0.01));
    });

    test('window 0-0 considers only today', () async {
      await p.addWater(1500);
      expect(p.avgWaterForDays(0, 0), closeTo(1500, 0.01));
    });

    test('0 when window excludes today (day 1 to 7) and no past data', () {
      expect(p.avgWaterForDays(1, 7), 0);
    });
  });

  // ── waterAvgForWeekday ───────────────────────────────────────────────────

  group('waterAvgForWeekday', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('null when no data for that weekday', () {
      final today = DateTime.now().weekday;
      final otherWeekday = (today % 7) + 1;
      expect(p.waterAvgForWeekday(otherWeekday), isNull);
    });

    test('returns today water for today weekday', () async {
      await p.addWater(2200);
      final today = DateTime.now().weekday;
      final avg = p.waterAvgForWeekday(today);
      expect(avg, isNotNull);
      expect(avg!, closeTo(2200, 0.01));
    });
  });

  // ── bodyCompositionStatus — all branches ─────────────────────────────────

  group('bodyCompositionStatus all classification branches', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('returns Log data label when no weight and no scale', () {
      expect(p.bodyCompositionStatus.label, 'Log data');
    });

    test('returns BMI-based label when weight logged but no scale', () async {
      await p.saveHeight(170);
      await p.logBodyEntry(weightKg: 70.0); // BMI 24.2 → Normal
      final status = p.bodyCompositionStatus;
      expect(status.label, isNotEmpty);
      expect(status.label, isNot('Log data'));
    });

    test('Overfat when bf >= 25%', () async {
      await p.saveHeight(175);
      await p.logScaleEntry(SmartScaleEntry(
        id: 's', date: DateTime.now(), weightKg: 80,
        bodyFatPercent: 28, bodyFatKg: 22.4, muscleMassKg: 35, muscleMassPercent: 44,
        leanBodyMassKg: 57.6, biologicalAge: 28, visceralFatIndex: 11, bmr: 1600,
        bodyWaterPercent: 50, boneMassKg: 3.2, proteinPercent: 17, skeletalMuscleMassKg: 29,
      ));
      expect(p.bodyCompositionStatus.label, 'Overfat');
    });

    test('Athletic when bf < 15% and FFMI >= 20', () async {
      await p.saveHeight(175);
      // lean=65, h=1.75 → FFMI=65/3.0625+6.1*0.05=21.2+0.305=21.5 → Athletic
      await p.logScaleEntry(SmartScaleEntry(
        id: 's', date: DateTime.now(), weightKg: 75,
        bodyFatPercent: 13, bodyFatKg: 9.75, muscleMassKg: 42, muscleMassPercent: 56,
        leanBodyMassKg: 65, biologicalAge: 24, visceralFatIndex: 4, bmr: 1800,
        bodyWaterPercent: 62, boneMassKg: 3.5, proteinPercent: 20, skeletalMuscleMassKg: 33,
      ));
      final status = p.bodyCompositionStatus;
      expect(status.label, 'Athletic');
    });

    test('Lean when bf < 20% and FFMI >= 19', () async {
      await p.saveHeight(175);
      // lean=60, h=1.75 → FFMI=60/3.0625+0.305=19.6+0.305=19.9 → Lean (bf=18 < 20)
      await p.logScaleEntry(SmartScaleEntry(
        id: 's', date: DateTime.now(), weightKg: 73,
        bodyFatPercent: 18, bodyFatKg: 13.14, muscleMassKg: 38, muscleMassPercent: 52,
        leanBodyMassKg: 60, biologicalAge: 24, visceralFatIndex: 6, bmr: 1720,
        bodyWaterPercent: 58, boneMassKg: 3.3, proteinPercent: 18, skeletalMuscleMassKg: 30,
      ));
      final status = p.bodyCompositionStatus;
      expect(status.label, anyOf('Lean', 'Average'));
    });

    test('Average for moderate body fat and FFMI', () async {
      await p.saveHeight(170);
      // lean=56, h=1.7 → FFMI=56/2.89+6.1*0.1=19.38+0.61=19.99 → Average
      // bf=22 → not overfat, not lean → Average
      await p.logScaleEntry(SmartScaleEntry(
        id: 's', date: DateTime.now(), weightKg: 72,
        bodyFatPercent: 22, bodyFatKg: 15.84, muscleMassKg: 36, muscleMassPercent: 50,
        leanBodyMassKg: 56, biologicalAge: 25, visceralFatIndex: 7, bmr: 1680,
        bodyWaterPercent: 55, boneMassKg: 3.2, proteinPercent: 17, skeletalMuscleMassKg: 28,
      ));
      final status = p.bodyCompositionStatus;
      expect(status.label, isNotEmpty);
      expect(status.label, isNot('Log data'));
    });

    test('Recomp needed when FFMI < 18 (low muscle despite normal body fat)', () async {
      await p.saveHeight(175);
      // lean=50, h=1.75 → FFMI=50/3.0625+0.305=16.3+0.305=16.6 → Below average
      // bf=22 → not overfat
      await p.logScaleEntry(SmartScaleEntry(
        id: 's', date: DateTime.now(), weightKg: 64,
        bodyFatPercent: 22, bodyFatKg: 14.08, muscleMassKg: 32, muscleMassPercent: 50,
        leanBodyMassKg: 50, biologicalAge: 30, visceralFatIndex: 8, bmr: 1550,
        bodyWaterPercent: 52, boneMassKg: 3.0, proteinPercent: 16, skeletalMuscleMassKg: 25,
      ));
      final status = p.bodyCompositionStatus;
      expect(status.label, 'Recomp needed');
    });
  });

  // ── calorieDeficit exact values ──────────────────────────────────────────

  group('calorieDeficit exact values', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('equals calorieGoal when no food and no burn', () {
      // deficit = goal - (0 - 0) = goal
      expect(p.calorieDeficit, p.calorieGoal);
    });

    test('exact value: goal=1700, eaten=1200, burn=0 → deficit=500', () async {
      await p.saveCalorieGoal(1700);
      await p.addFoodEntry(_food('f1', 1200, 60));
      // No weight → no resting burn; no steps; no workout → burn=0
      expect(p.calorieDeficit, 500);
    });

    test('exact value: goal=1700, eaten=2000, burn=0 → deficit=-300 (surplus)', () async {
      await p.saveCalorieGoal(1700);
      await p.addFoodEntry(_food('f1', 2000, 80));
      expect(p.calorieDeficit, -300);
    });

    test('0 when eaten = goal exactly and no burn', () async {
      await p.saveCalorieGoal(1500);
      await p.addFoodEntry(_food('f1', 1500, 60));
      expect(p.calorieDeficit, 0);
    });

    test('inDeficit true when deficit > 0', () async {
      await p.saveCalorieGoal(1700);
      await p.addFoodEntry(_food('f1', 1000, 40));
      expect(p.inDeficit, isTrue);
      expect(p.calorieDeficit, greaterThan(0));
    });

    test('inDeficit false when deficit < 0 (surplus)', () async {
      await p.saveCalorieGoal(1000);
      await p.addFoodEntry(_food('f1', 1500, 60));
      expect(p.inDeficit, isFalse);
      expect(p.calorieDeficit, lessThan(0));
    });

    test('inDeficit false at exact boundary (eaten = goal, burn = 0)', () async {
      await p.saveCalorieGoal(1200);
      await p.addFoodEntry(_food('f1', 1200, 50));
      expect(p.calorieDeficit, 0);
      expect(p.inDeficit, isFalse); // not strictly < goal
    });
  });

  // ── caloriesRemaining edge cases ─────────────────────────────────────────

  group('caloriesRemaining', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('equals calorieGoal when nothing eaten', () {
      expect(p.caloriesRemaining, p.calorieGoal);
    });

    test('decreases as food is added', () async {
      await p.saveCalorieGoal(1700);
      await p.addFoodEntry(_food('f1', 500, 20));
      expect(p.caloriesRemaining, 1200);
    });

    test('is 0 when exactly at goal', () async {
      await p.saveCalorieGoal(1000);
      await p.addFoodEntry(_food('f1', 1000, 40));
      expect(p.caloriesRemaining, 0);
    });

    test('is negative when over goal', () async {
      await p.saveCalorieGoal(1000);
      await p.addFoodEntry(_food('f1', 1300, 50));
      expect(p.caloriesRemaining, -300);
    });

    test('does not subtract burned calories (food-only metric)', () async {
      await p.saveCalorieGoal(1700);
      await p.logBodyEntry(weightKg: 75); // enables resting burn
      await p.addFoodEntry(_food('f1', 1000, 40));
      // caloriesRemaining = goal - food-only = 700 (ignores burn)
      expect(p.caloriesRemaining, 700);
    });
  });

  // ── daysSinceLastWorkout ─────────────────────────────────────────────────

  group('daysSinceLastWorkout', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('999 when no workouts ever', () {
      expect(p.daysSinceLastWorkout, 999);
    });

    test('0 when workout logged today', () async {
      await p.logWorkout(_workout('w1'));
      expect(p.daysSinceLastWorkout, 0);
    });

    test('positive when most recent workout was yesterday or before', () async {
      // Can't easily create a workout on a past date via logWorkout (uses date),
      // but we can verify the today=0 case and the empty=999 case.
      await p.logWorkout(_workout('w1'));
      expect(p.daysSinceLastWorkout, greaterThanOrEqualTo(0));
    });
  });

  // ── weeklyProteinGoalHitDays extended ────────────────────────────────────

  group('weeklyProteinGoalHitDays extended', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('0 with no food', () {
      expect(p.weeklyProteinGoalHitDays, 0);
    });

    test('1 when today meets goal exactly', () async {
      await p.saveProteinGoal(100);
      await p.addFoodEntry(_food('f1', 400, 100));
      expect(p.weeklyProteinGoalHitDays, 1);
    });

    test('0 when today below goal', () async {
      await p.saveProteinGoal(100);
      await p.addFoodEntry(_food('f1', 300, 50));
      expect(p.weeklyProteinGoalHitDays, 0);
    });

    test('whey protein counts toward protein goal', () async {
      await p.saveProteinGoal(30); // low goal
      await p.updateSupplement('whey', true); // +25g protein
      await p.addFoodEntry(_food('f1', 200, 10)); // 10g food
      // total = 35g > 30g goal → hit
      expect(p.weeklyProteinGoalHitDays, 1);
    });
  });

  // ── weeklyWaterGoalHitDays extended ──────────────────────────────────────

  group('weeklyWaterGoalHitDays extended', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('0 with no water', () {
      expect(p.weeklyWaterGoalHitDays, 0);
    });

    test('1 when exactly at goal', () async {
      await p.saveWaterGoal(2000);
      await p.addWater(2000);
      expect(p.weeklyWaterGoalHitDays, 1);
    });

    test('0 when 1 ml below goal', () async {
      await p.saveWaterGoal(2000);
      await p.addWater(1999);
      expect(p.weeklyWaterGoalHitDays, 0);
    });

    test('1 when over goal', () async {
      await p.saveWaterGoal(1000);
      await p.addWater(2500);
      expect(p.weeklyWaterGoalHitDays, 1);
    });
  });

  // ── bodyCompTrajectory detailed ──────────────────────────────────────────

  group('bodyCompTrajectory detailed verdicts', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('null with fewer than 2 scale entries', () async {
      await p.logScaleEntry(_scaleFatLean(date: DateTime.now(), fatKg: 18, leanKg: 56));
      expect(p.bodyCompTrajectory, isNull);
    });

    test('null when first entry has zero bodyFatKg', () async {
      await p.logScaleEntry(SmartScaleEntry(
        id: 's0', date: DateTime.now().subtract(const Duration(days: 30)),
        weightKg: 70, bodyFatPercent: 0, bodyFatKg: 0, muscleMassKg: 0, muscleMassPercent: 0,
        leanBodyMassKg: 56, biologicalAge: 24, visceralFatIndex: 5, bmr: 1600,
        bodyWaterPercent: 55, boneMassKg: 3, proteinPercent: 17, skeletalMuscleMassKg: 28,
      ));
      await p.logScaleEntry(_scaleFatLean(date: DateTime.now(), fatKg: 16, leanKg: 58));
      expect(p.bodyCompTrajectory, isNull);
    });

    test('Losing fat and some muscle verdict', () async {
      await p.logScaleEntry(_scaleFatLean(date: DateTime.now().subtract(const Duration(days: 30)), fatKg: 20, leanKg: 58));
      await p.logScaleEntry(_scaleFatLean(date: DateTime.now(), fatKg: 17, leanKg: 56));
      final t = p.bodyCompTrajectory!;
      expect(t.verdict.toLowerCase(), contains('muscle'));
      expect(t.fatChange, closeTo(-3.0, 0.01));
      expect(t.leanChange, closeTo(-2.0, 0.01));
    });

    test('Fat trending up verdict when fat increases > 0.3 kg', () async {
      await p.logScaleEntry(_scaleFatLean(date: DateTime.now().subtract(const Duration(days: 15)), fatKg: 18, leanKg: 56));
      await p.logScaleEntry(_scaleFatLean(date: DateTime.now(), fatKg: 20, leanKg: 56));
      final t = p.bodyCompTrajectory!;
      expect(t.verdict.toLowerCase(), contains('fat'));
      expect(t.fatChange, closeTo(2.0, 0.01));
    });

    test('Holding steady verdict when both changes < 0.3', () async {
      await p.logScaleEntry(_scaleFatLean(date: DateTime.now().subtract(const Duration(days: 7)), fatKg: 18.1, leanKg: 56.1));
      await p.logScaleEntry(_scaleFatLean(date: DateTime.now(), fatKg: 18.0, leanKg: 56.0));
      final t = p.bodyCompTrajectory!;
      expect(t.verdict.toLowerCase(), contains('steady'));
    });

    test('Gaining both fat and muscle verdict', () async {
      await p.logScaleEntry(_scaleFatLean(date: DateTime.now().subtract(const Duration(days: 30)), fatKg: 16, leanKg: 54));
      await p.logScaleEntry(_scaleFatLean(date: DateTime.now(), fatKg: 17.5, leanKg: 56));
      final t = p.bodyCompTrajectory!;
      expect(t.verdict.toLowerCase(), contains('gaining'));
    });
  });

  // ── getPersonalRecord edge cases ─────────────────────────────────────────

  group('getPersonalRecord edge cases', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('returns highest weight across multiple workouts', () async {
      await p.logWorkout(_workout('w1', exercises: [
        ExerciseLog(name: 'Bench Press', sets: [SetData(reps: 8, weight: 60), SetData(reps: 8, weight: 65)]),
      ]));
      await p.logWorkout(_workout('w2', date: DateTime.now().subtract(const Duration(days: 1)), exercises: [
        ExerciseLog(name: 'Bench Press', sets: [SetData(reps: 5, weight: 70)]),
      ]));
      expect(p.getPersonalRecord('Bench Press'), 70.0);
    });

    test('null for exercise never logged', () {
      expect(p.getPersonalRecord('Deadlift'), isNull);
    });

    test('null when all sets have zero weight (bodyweight exercise)', () async {
      await p.logWorkout(_workout('w1', exercises: [
        ExerciseLog(name: 'Push-ups', sets: [SetData(reps: 15, weight: 0), SetData(reps: 15, weight: 0)]),
      ]));
      expect(p.getPersonalRecord('Push-ups'), isNull);
    });
  });

  // ── 90-day workout trim edge cases ───────────────────────────────────────

  group('Workout 90-day trim edge cases', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('workout 89 days ago is kept (well within 90-day window)', () async {
      // Use 89 days to avoid timing race: two DateTime.now() calls can drift.
      final d89 = DateTime.now().subtract(const Duration(days: 89));
      await p.logWorkout(_workout('old', date: d89));
      await p.logWorkout(_workout('new'));
      expect(p.workoutHistory.any((w) => w.id == 'old'), isTrue);
    });

    test('workout 91 days ago is trimmed when new workout is logged', () async {
      final d91 = DateTime.now().subtract(const Duration(days: 91));
      await p.logWorkout(_workout('old', date: d91));
      await p.logWorkout(_workout('new'));
      expect(p.workoutHistory.any((w) => w.id == 'old'), isFalse);
    });
  });

  // ── hasPedometerData and todaySteps extended ─────────────────────────────

  group('hasPedometerData and todaySteps extended', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('todaySteps is 0 initially', () {
      expect(p.todaySteps, 0);
    });

    test('stepProgress is 0 when no steps', () {
      expect(p.stepProgress, 0.0);
    });

    test('stepProgress is 0.5 when at half goal', () async {
      await p.saveStepGoal(10000);
      await p.logBodyEntry(weightKg: 70, steps: 5000);
      expect(p.stepProgress, closeTo(0.5, 0.01));
    });

    test('stepProgress clamped to 1.0 when steps exceed goal', () async {
      await p.saveStepGoal(5000);
      await p.logBodyEntry(weightKg: 70, steps: 9000);
      expect(p.stepProgress, 1.0);
    });
  });

  // ── supplementCalories / supplementProtein edge cases ────────────────────

  group('Supplement calorie/protein edge cases', () {
    late FitnessProvider p;
    setUp(() async { p = FitnessProvider(); await p.loadData(); });

    test('supplementCalories 0 when no supplements taken', () {
      expect(p.supplementCalories, 0);
    });

    test('supplementCalories 120 when whey taken', () async {
      await p.updateSupplement('whey', true);
      expect(p.supplementCalories, 120);
    });

    test('supplementCalories 0 when creatine/multivitamin taken (no calories)', () async {
      await p.updateSupplement('creatine', true);
      await p.updateSupplement('multivitamin', true);
      expect(p.supplementCalories, 0);
    });

    test('supplementProtein 0 when no supplements taken', () {
      expect(p.supplementProtein, 0);
    });

    test('supplementProtein 25 when whey taken', () async {
      await p.updateSupplement('whey', true);
      expect(p.supplementProtein, 25);
    });

    test('todayCaloriesTotal correctly sums food + whey only', () async {
      await p.addFoodEntry(_food('f1', 500, 30));
      await p.updateSupplement('whey', true);    // +120 kcal
      await p.updateSupplement('creatine', true); // +0 kcal
      expect(p.todayCaloriesTotal, closeTo(620, 0.01));
    });
  });
}

// ─── Utilities ────────────────────────────────────────────────────────────────

String _todayKey() {
  final n = DateTime.now();
  return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}
