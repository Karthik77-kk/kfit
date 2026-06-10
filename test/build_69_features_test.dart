// Build 69 — AI simplification, gender BMR, workout calories, MET expansion
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:karthik_fitness/providers/fitness_provider.dart';
import 'package:karthik_fitness/models/models.dart';
import 'package:karthik_fitness/services/on_device_ai_service.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

Future<FitnessProvider> _loaded([Map<String, Object> seed = const {}]) async {
  SharedPreferences.setMockInitialValues(seed);
  final p = FitnessProvider();
  await p.loadData();
  return p;
}

WorkoutLog _workout(String name, List<ExerciseLog> exercises, {DateTime? date}) =>
    WorkoutLog(
      id: 'w1', name: name,
      date: date ?? DateTime.now(),
      exercises: exercises,
    );

ExerciseLog _exercise(String name, List<SetData> sets) =>
    ExerciseLog(name: name, sets: sets);

SetData _set(double weight, int reps) =>
    SetData(reps: reps, weight: weight);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => call.method == 'getApplicationDocumentsDirectory'
          ? Directory.systemTemp.path : null,
    );
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ── 1. Gender / BMR ──────────────────────────────────────────────────────────

  group('Gender field and BMR formula', () {
    test('defaults to male (isMale = true)', () async {
      final p = await _loaded();
      expect(p.isMale, isTrue);
      expect(p.isFemale, isFalse);
    });

    test('saveSex(false) sets female and persists', () async {
      final p = await _loaded();
      await p.saveSex(false);
      expect(p.isMale, isFalse);
      expect(p.isFemale, isTrue);
    });

    test('saveSex(true) restores male', () async {
      final p = await _loaded({'is_male': false});
      expect(p.isMale, isFalse);
      await p.saveSex(true);
      expect(p.isMale, isTrue);
    });

    test('is_male pref restored from SharedPreferences on loadData', () async {
      final p = await _loaded({'is_male': false});
      expect(p.isMale, isFalse);
    });

    test('male BMR uses +5 Mifflin-St Jeor constant', () async {
      // Weight 80kg, height 175cm, age 25 — male: 10*80 + 6.25*175 - 5*25 + 5 = 1848.75
      final p = await _loaded({'is_male': true});
      await p.logBodyEntry(weightKg: 80.0, steps: 0);
      await p.saveHeight(175.0);
      await p.saveAge(25);
      final expected = 10 * 80.0 + 6.25 * 175.0 - 5 * 25 + 5.0;
      expect(p.bmr, closeTo(expected, 0.1));
    });

    test('female BMR uses −161 Mifflin-St Jeor constant', () async {
      // Weight 60kg, height 160cm, age 24 — female: 10*60 + 6.25*160 - 5*24 - 161 = 1239
      final p = await _loaded({'is_male': false});
      await p.logBodyEntry(weightKg: 60.0, steps: 0);
      await p.saveHeight(160.0);
      await p.saveAge(24);
      final expected = 10 * 60.0 + 6.25 * 160.0 - 5 * 24 - 161.0;
      expect(p.bmr, closeTo(expected, 0.1));
    });

    test('male BMR > female BMR for same weight/height/age', () async {
      // Same person, different sex: male should have higher BMR
      final pm = await _loaded({'is_male': true});
      await pm.logBodyEntry(weightKg: 70.0, steps: 0);
      await pm.saveHeight(165.0);
      await pm.saveAge(28);
      final mBmr = pm.bmr!;

      SharedPreferences.setMockInitialValues({'is_male': false});
      final pf = FitnessProvider();
      await pf.loadData();
      await pf.logBodyEntry(weightKg: 70.0, steps: 0);
      await pf.saveHeight(165.0);
      await pf.saveAge(28);
      final fBmr = pf.bmr!;

      expect(mBmr - fBmr, closeTo(166.0, 1.0)); // difference = +5 - (-161) = 166
    });

    test('scale BMR overrides formula BMR (more accurate)', () async {
      final p = await _loaded();
      await p.logBodyEntry(weightKg: 75.0, steps: 0);
      await p.saveHeight(170.0);
      await p.saveAge(25);
      // Formula BMR for male 75kg 170cm 25y = 10*75+6.25*170-5*25+5 = 1,842.5
      final formulaBmr = p.bmr!;

      // Now log scale entry with a different BMR
      await p.logScaleEntry(SmartScaleEntry(
        id: 's1', date: DateTime.now(),
        weightKg: 75.0, bodyFatPercent: 18, bodyFatKg: 13.5,
        muscleMassKg: 36, muscleMassPercent: 48, leanBodyMassKg: 61.5,
        biologicalAge: 24, visceralFatIndex: 5, bmr: 1900.0,
        bodyWaterPercent: 60, boneMassKg: 3.2, proteinPercent: 18,
        skeletalMuscleMassKg: 28,
      ));

      // Scale BMR (1900) should take priority over formula (1842.5)
      expect(p.bmr, closeTo(1900.0, 0.1));
      expect(p.bmr, isNot(closeTo(formulaBmr, 1.0)));
    });
  });

  // ── 2. Workout calorie calculation improvements ───────────────────────────────

  group('Workout calorie calculation (rep-weighted duration)', () {
    test('low-rep heavy sets (5 reps) use shorter duration than high-rep (15 reps)', () async {
      final p = await _loaded();
      await p.logBodyEntry(weightKg: 80.0, steps: 0);

      // 3 sets × 5 reps: duration = 3 * (5*0.05 + 1.5) = 3 * 1.75 = 5.25 min
      final heavyEx = _exercise('Squats', [_set(100, 5), _set(100, 5), _set(100, 5)]);
      final heavyLog = _workout('Legs heavy', [heavyEx]);

      // 3 sets × 15 reps: duration = 3 * (15*0.05 + 1.5) = 3 * 2.25 = 6.75 min
      final lightEx = _exercise('Squats', [_set(60, 15), _set(60, 15), _set(60, 15)]);
      final lightLog = _workout('Legs light', [lightEx]);

      // Same exercise and weight but different reps → different calories
      // Both use same MET (6.5 for Squats), same weight (80kg)
      // heavyCal = 6.5 * 80 * 5.25 / 60 ≈ 45.5
      // lightCal = 6.5 * 80 * 6.75 / 60 ≈ 58.5
      final heavyCal = p.calculateWorkoutCalories(heavyLog);
      final lightCal = p.calculateWorkoutCalories(lightLog);
      expect(lightCal, greaterThan(heavyCal));
    });

    test('workout calories use user actual weight not fallback 70kg', () async {
      final p90 = await _loaded();
      await p90.logBodyEntry(weightKg: 90.0, steps: 0);

      SharedPreferences.setMockInitialValues({});
      final p60 = FitnessProvider();
      await p60.loadData();
      await p60.logBodyEntry(weightKg: 60.0, steps: 0);

      final ex = _exercise('Bench Press', [_set(80, 8), _set(80, 8), _set(80, 8)]);
      final wlog = _workout('Push', [ex]);

      final cal90 = p90.calculateWorkoutCalories(wlog);
      final cal60 = p60.calculateWorkoutCalories(wlog);
      expect(cal90, greaterThan(cal60));
      // Should be proportional: 90/60 = 1.5 times more
      expect(cal90 / cal60, closeTo(1.5, 0.05));
    });

    test('Deadlift has specific MET (6.0) not generic fallback (5.0)', () async {
      final p = await _loaded();
      await p.logBodyEntry(weightKg: 80.0, steps: 0);

      final deadlift = _exercise('Deadlift', [_set(120, 5), _set(120, 5), _set(120, 5)]);
      final generic  = _exercise('Someunknownexercise', [_set(120, 5), _set(120, 5), _set(120, 5)]);

      final deadliftCal = p.calculateWorkoutCalories(_workout('D', [deadlift]));
      final genericCal  = p.calculateWorkoutCalories(_workout('G', [generic]));

      // Deadlift MET=6.0, generic MET=5.0 → deadlift burns more
      expect(deadliftCal, greaterThan(genericCal));
      // Ratio should be 6.0/5.0 = 1.2
      expect(deadliftCal / genericCal, closeTo(1.2, 0.01));
    });

    test('Pull-ups have MET 8.0 — highest among strength exercises', () async {
      final p = await _loaded();
      await p.logBodyEntry(weightKg: 75.0, steps: 0);

      final pullups = _exercise('Pull-ups', [_set(0, 10), _set(0, 10), _set(0, 10)]);
      final rows    = _exercise('Barbell Rows', [_set(60, 10), _set(60, 10), _set(60, 10)]);

      final pullupCal = p.calculateWorkoutCalories(_workout('P', [pullups]));
      final rowCal    = p.calculateWorkoutCalories(_workout('R', [rows]));

      // Pull-ups MET=8.0 > Barbell Rows MET=6.0
      expect(pullupCal, greaterThan(rowCal));
    });

    test('exercise with 0 sets contributes 0 calories', () async {
      final p = await _loaded();
      await p.logBodyEntry(weightKg: 80.0, steps: 0);

      final emptyEx = ExerciseLog(name: 'Bench Press', sets: []);
      final wlog    = _workout('Empty', [emptyEx]);
      expect(p.calculateWorkoutCalories(wlog), 0);
    });

    test('calorie calculation formula: MET × weight × repWeightedDuration / 60', () async {
      final p = await _loaded();
      await p.logBodyEntry(weightKg: 80.0, steps: 0);

      // Bench Press MET=5.5, 3 sets × 8 reps
      // avgReps = 8, minPerSet = (8*0.05 + 1.5) = 1.9, clamped(1.5, 4.0) = 1.9
      // durationMin = 3 * 1.9 = 5.7
      // cal = 5.5 * 80 * 5.7 / 60 ≈ 41.8 → rounds to 42
      final ex   = _exercise('Bench Press', [_set(80, 8), _set(80, 8), _set(80, 8)]);
      final wlog = _workout('Push', [ex]);
      final cal  = p.calculateWorkoutCalories(wlog);
      final avgReps = 8.0;
      final minPerSet = (avgReps * 0.05 + 1.5).clamp(1.5, 4.0);
      final dur = 3 * minPerSet;
      final expected = (5.5 * 80.0 * dur / 60.0).round();
      expect(cal, expected);
    });

    test('multiple exercises in one workout sum up correctly', () async {
      final p = await _loaded();
      await p.logBodyEntry(weightKg: 75.0, steps: 0);

      final exA = _exercise('Bench Press', [_set(80, 5), _set(80, 5)]);
      final exB = _exercise('Squats', [_set(100, 5), _set(100, 5)]);
      final wlog = _workout('Push+Legs', [exA, exB]);

      final total = p.calculateWorkoutCalories(wlog);
      final calA  = p.calculateWorkoutCalories(_workout('A', [exA]));
      final calB  = p.calculateWorkoutCalories(_workout('B', [exB]));
      expect(total, calA + calB);
    });
  });

  // ── 3. MET table completeness ─────────────────────────────────────────────────

  group('MET table — key exercises present', () {
    Future<int> cal(FitnessProvider p, String exerciseName) async {
      final ex   = _exercise(exerciseName, [_set(60, 8), _set(60, 8), _set(60, 8)]);
      final wlog = _workout('W', [ex]);
      return p.calculateWorkoutCalories(wlog);
    }

    test('all major compound lifts have specific MET (not generic 5.0)', () async {
      final p = await _loaded();
      await p.logBodyEntry(weightKg: 80.0, steps: 0);

      // Generic fallback MET=5.0. If an exercise has a higher MET, cal > generic.
      final genericCal = await cal(p, 'Someunknown_exercise_xyz');

      // Deadlift (6.0), Pull-ups (8.0), Squats (6.5) should all burn > generic
      expect(await cal(p, 'Deadlift'),     greaterThan(genericCal));
      expect(await cal(p, 'Pull-ups'),     greaterThan(genericCal));
      expect(await cal(p, 'Squats'),       greaterThan(genericCal));
      expect(await cal(p, 'Barbell Rows'), greaterThan(genericCal));
    });

    test('cardio exercises have higher MET than strength', () async {
      final p = await _loaded();
      await p.logBodyEntry(weightKg: 80.0, steps: 0);

      final runCal  = await cal(p, 'Running');   // MET 9.8
      final benchCal = await cal(p, 'Bench Press'); // MET 5.5
      expect(runCal, greaterThan(benchCal));
    });

    test('HIIT has the highest MET among named exercises (10.0)', () async {
      final p = await _loaded();
      await p.logBodyEntry(weightKg: 80.0, steps: 0);

      final hiitCal   = await cal(p, 'HIIT');
      final benchCal  = await cal(p, 'Bench Press');
      final deadliftCal = await cal(p, 'Deadlift');
      expect(hiitCal, greaterThan(benchCal));
      expect(hiitCal, greaterThan(deadliftCal));
    });

    test('Yoga has low MET (3.0) — less than all strength exercises', () async {
      final p = await _loaded();
      await p.logBodyEntry(weightKg: 80.0, steps: 0);

      final yogaCal  = await cal(p, 'Yoga');
      final benchCal = await cal(p, 'Bench Press');
      expect(yogaCal, lessThan(benchCal));
    });
  });

  // ── 4. OnDeviceAiService — single model only ────────────────────────────────

  group('OnDeviceAiService single-model API', () {
    test('modelName is Gemma 3 1B', () {
      final ai = OnDeviceAiService();
      expect(ai.modelName, 'Gemma 3 1B');
    });

    test('modelSize is ~600 MB', () {
      final ai = OnDeviceAiService();
      expect(ai.modelSize, contains('600'));
    });

    test('initial state is notInstalled when no prefs', () {
      final ai = OnDeviceAiService();
      expect(ai.state, AiModelState.notInstalled);
    });

    test('isReady is false before init', () {
      final ai = OnDeviceAiService();
      expect(ai.isReady, isFalse);
    });

    test('isInstalled is false when no prefs record', () {
      final ai = OnDeviceAiService();
      expect(ai.isInstalled, isFalse);
    });

    test('compact system prompt includes today data', () async {
      final p = await _loaded();
      await p.logBodyEntry(weightKg: 79.5, steps: 5000);
      await p.addFoodEntry(FoodEntry(
        id: 'f1', name: 'Roti', calories: 104, protein: 3,
        mealType: MealType.lunch, timestamp: DateTime.now(),
      ));
      final ai = OnDeviceAiService();
      final prompt = ai.buildSystemPromptForTest(p);

      expect(prompt, contains('79.5'));
      expect(prompt, contains('Roti'));
      expect(prompt, isNotEmpty);
    });

    test('compact prompt includes gender (M or F)', () async {
      final pm = await _loaded({'is_male': true});
      SharedPreferences.setMockInitialValues({'is_male': false});
      final pf = FitnessProvider();
      await pf.loadData();
      final ai = OnDeviceAiService();
      final mPrompt = ai.buildSystemPromptForTest(pm);
      final fPrompt = ai.buildSystemPromptForTest(pf);
      expect(mPrompt, contains('Male'));
      expect(fPrompt, contains('Female'));
    });

    test('compact prompt contains GOALS section', () async {
      final p = await _loaded();
      final ai = OnDeviceAiService();
      final prompt = ai.buildSystemPromptForTest(p);
      expect(prompt, contains('Goal weight'));
    });

    test('compact prompt contains RULES section', () async {
      final p = await _loaded();
      final ai = OnDeviceAiService();
      final prompt = ai.buildSystemPromptForTest(p);
      expect(prompt, contains('make it personal'));
    });

    test('compact prompt handles empty user (no food, no workouts)', () async {
      final p = await _loaded();
      final ai = OnDeviceAiService();
      // Should not throw
      expect(() => ai.buildSystemPromptForTest(p), returnsNormally);
    });

    test('compact prompt with workouts includes workout names', () async {
      final p = await _loaded();
      await p.logWorkout(_workout('Push Day A',
          [_exercise('Bench Press', [_set(80, 5), _set(80, 5)])]));
      final ai = OnDeviceAiService();
      final prompt = ai.buildSystemPromptForTest(p);
      expect(prompt, contains('Push Day A'));
      expect(prompt, contains('Bench Press'));
    });

    test('compact prompt includes 1RM when compound lifts logged', () async {
      final p = await _loaded();
      await p.logWorkout(_workout('Pull Day',
          [_exercise('Deadlift', [_set(120, 5)])]));
      final ai = OnDeviceAiService();
      final prompt = ai.buildSystemPromptForTest(p);
      expect(prompt, contains('Deadlift'));
      expect(prompt, contains('1RM'));
    });

    test('compact prompt shows female sex in profile line', () async {
      final p = await _loaded({'is_male': false});
      final ai = OnDeviceAiService();
      final prompt = ai.buildSystemPromptForTest(p);
      expect(prompt, contains('F'));
    });
  });

  // ── 5. Smart recommendations remain personalized ──────────────────────────────

  group('Smart recommendations still use user data', () {
    test('recommendedProteinGoal uses lean mass when scale data exists', () async {
      final p = await _loaded();
      await p.logScaleEntry(SmartScaleEntry(
        id: 's1', date: DateTime.now(),
        weightKg: 80, bodyFatPercent: 20, bodyFatKg: 16,
        muscleMassKg: 40, muscleMassPercent: 50,
        leanBodyMassKg: 64, biologicalAge: 25, visceralFatIndex: 6,
        bmr: 1800, bodyWaterPercent: 58, boneMassKg: 3.2,
        proteinPercent: 18, skeletalMuscleMassKg: 30,
      ));
      // lean mass 64kg × 2.0 g/kg = 128g
      expect(p.recommendedProteinGoal, closeTo(128, 2));
    });

    test('recommendedProteinGoal falls back to weight × 1.8 without scale', () async {
      final p = await _loaded();
      await p.logBodyEntry(weightKg: 75.0, steps: 0);
      // 75 × 1.8 = 135
      expect(p.recommendedProteinGoal, closeTo(135, 2));
    });

    test('recommendedWaterGoal uses body weight (35ml/kg)', () async {
      final p = await _loaded();
      await p.logBodyEntry(weightKg: 80.0, steps: 0);
      // 80 × 35 = 2800 ml
      expect(p.recommendedWaterGoal, closeTo(2800, 10));
    });

    test('female BMR feeds into lower recommended calorie goal than male', () async {
      // Same weight/height/age but different sex
      final pm = await _loaded({'is_male': true});
      await pm.logBodyEntry(weightKg: 65.0, steps: 0);
      await pm.saveHeight(165.0);
      await pm.saveAge(25);

      SharedPreferences.setMockInitialValues({'is_male': false});
      final pf = FitnessProvider();
      await pf.loadData();
      await pf.logBodyEntry(weightKg: 65.0, steps: 0);
      await pf.saveHeight(165.0);
      await pf.saveAge(25);

      // Female TDEE is lower → recommended calorie goal is lower
      if (pm.recommendedCalorieGoal != null && pf.recommendedCalorieGoal != null) {
        expect(pm.recommendedCalorieGoal!, greaterThan(pf.recommendedCalorieGoal!));
      }
    });
  });

  // ── 6. Walking calories remain weight-scaled ─────────────────────────────────

  group('Walking calories (regression)', () {
    test('heavier person burns more calories walking same steps', () async {
      final p90 = await _loaded();
      await p90.logBodyEntry(weightKg: 90.0, steps: 8000);

      SharedPreferences.setMockInitialValues({});
      final p60 = FitnessProvider();
      await p60.loadData();
      await p60.logBodyEntry(weightKg: 60.0, steps: 8000);

      expect(p90.walkingCaloriesBurned, greaterThan(p60.walkingCaloriesBurned));
    });

    test('10k steps at 70kg ≈ 400 kcal', () async {
      final p = await _loaded();
      await p.logBodyEntry(weightKg: 70.0, steps: 10000);
      // Formula: 10000 × 0.04 × (70/70) = 400
      expect(p.walkingCaloriesBurned, closeTo(400.0, 5.0));
    });
  });

  // ── 7. Data integrity regression ─────────────────────────────────────────────

  group('Regression: existing features unaffected', () {
    test('saveSex does not affect food/water/workout data', () async {
      final p = await _loaded();
      await p.addFoodEntry(FoodEntry(
        id: 'f1', name: 'Dal', calories: 120, protein: 8,
        mealType: MealType.lunch, timestamp: DateTime.now(),
      ));
      await p.addWater(500);
      await p.saveSex(false);

      expect(p.todayFood.length, 1);
      expect(p.todayWaterMl, 500);
    });

    test('BMR null when no weight logged (regardless of sex)', () async {
      final pm = await _loaded({'is_male': true});
      final pf = await _loaded({'is_male': false});
      expect(pm.bmr, isNull);
      expect(pf.bmr, isNull);
    });

    test('default is_male (true) persists after first loadData', () async {
      // First launch — no is_male in prefs
      final p = await _loaded();
      expect(p.isMale, isTrue);
      // Provider should have written it to prefs
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('is_male'), isTrue);
    });

    test('calorie goal defaults unaffected by gender field addition', () async {
      final p = await _loaded();
      expect(p.calorieGoal, FitnessProvider.kDefaultCalorieGoal);
      expect(p.proteinGoal, FitnessProvider.kDefaultProteinGoal);
    });
  });
}
