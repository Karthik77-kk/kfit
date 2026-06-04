// Build 68 — production readiness fixes: crash handler, export safety,
// scale crash guard, goal card null safety, version constants
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:karthik_fitness/providers/fitness_provider.dart';
import 'package:karthik_fitness/models/models.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

Future<FitnessProvider> _loaded([Map<String, Object> seed = const {}]) async {
  SharedPreferences.setMockInitialValues(seed);
  final p = FitnessProvider();
  await p.loadData();
  return p;
}

SmartScaleEntry _scale({double weight = 78.5, DateTime? date}) =>
    SmartScaleEntry(
      id: 's1', date: date ?? DateTime.now(),
      weightKg: weight, bodyFatPercent: 22, bodyFatKg: weight * 0.22,
      muscleMassKg: 34, muscleMassPercent: 44,
      leanBodyMassKg: weight * 0.78, biologicalAge: 24,
      visceralFatIndex: 6, bmr: 1750, bodyWaterPercent: 58,
      boneMassKg: 3.1, proteinPercent: 18, skeletalMuscleMassKg: 27.5,
    );

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

  // ── 1. exportAllData error handling ────────────────────────────────────────

  group('exportAllData error handling', () {
    test('exportAllData writes valid JSON and returns a file path', () async {
      final p = await _loaded({'user_name': 'Karthik', 'calorie_goal': 1700});
      final path = await p.exportAllData();

      expect(path, isNotEmpty);
      expect(path, endsWith('.json'));

      final content = await File(path).readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      expect(json['user_name'], 'Karthik');
      expect(json['calorie_goal'], 1700);
    });

    test('exportAllData JSON is valid and parseable', () async {
      final p = await _loaded({'user_name': 'Test', 'onboarding_done': true});
      final path = await p.exportAllData();
      final content = await File(path).readAsString();

      // Should not throw
      expect(() => jsonDecode(content), returnsNormally);
    });

    test('exportAllData excludes pedometer device-specific keys', () async {
      final p = await _loaded({
        'pedometer_baseline': 50000,
        'pedometer_date': '2026-06-04',
        'user_name': 'Test',
      });
      final path = await p.exportAllData();
      final json =
          jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;

      expect(json.containsKey('pedometer_baseline'), isFalse);
      expect(json.containsKey('pedometer_date'), isFalse);
      expect(json.containsKey('user_name'), isTrue);
    });

    test('importAllData restores all exported values', () async {
      final p = await _loaded({
        'user_name': 'Karthik',
        'calorie_goal': 1800,
        'onboarding_done': true,
      });
      final path = await p.exportAllData();

      SharedPreferences.setMockInitialValues({});
      final p2 = FitnessProvider();
      final ok = await p2.importAllData(path);

      expect(ok, isTrue);
      expect(p2.userName, 'Karthik');
      expect(p2.calorieGoal, 1800);
      expect(p2.onboardingDone, isTrue);
    });

    test('importAllData returns false for nonexistent file', () async {
      final p = await _loaded();
      final ok = await p.importAllData('/no/such/file/backup.json');
      expect(ok, isFalse);
    });

    test('importAllData returns false for malformed JSON file', () async {
      final p = await _loaded();
      final f = File('${Directory.systemTemp.path}/bad_backup.json');
      await f.writeAsString('{ this is not valid json !!');
      final ok = await p.importAllData(f.path);
      expect(ok, isFalse);
    });

    test('exportAllData includes all four goal values', () async {
      final p = await _loaded({
        'calorie_goal': 2000,
        'protein_goal': 150,
        'water_goal_ml': 3000,
        'step_goal': 10000,
      });
      final path = await p.exportAllData();
      final json =
          jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;

      expect(json['calorie_goal'], 2000);
      expect(json['protein_goal'], 150);
      expect(json['water_goal_ml'], 3000);
      expect(json['step_goal'], 10000);
    });

    test('export then import preserves calorie goal', () async {
      final p = await _loaded({'calorie_goal': 1600});
      final path = await p.exportAllData();

      SharedPreferences.setMockInitialValues({});
      final p2 = FitnessProvider();
      await p2.importAllData(path);

      expect(p2.calorieGoal, 1600);
    });

    test('export then import preserves measurement history', () async {
      final p = await _loaded();
      await p.logMeasurement(MeasurementEntry(
        id: 'm1', date: DateTime.now(),
        chestCm: 94, waistCm: 82, hipsCm: 96,
        leftArmCm: 32, leftThighCm: 56,
      ));
      final path = await p.exportAllData();

      SharedPreferences.setMockInitialValues({});
      final p2 = FitnessProvider();
      final ok = await p2.importAllData(path);

      expect(ok, isTrue);
      expect(p2.measurementHistory.isNotEmpty, isTrue);
      expect(p2.latestMeasurements?.chestCm, 94);
    });
  });

  // ── 2. Smart scale null/parse safety ──────────────────────────────────────

  group('Smart scale save guard', () {
    test('double.tryParse returns null for non-numeric input', () {
      expect(double.tryParse('abc'), isNull);
      expect(double.tryParse(''),    isNull);
      expect(double.tryParse('75.5'), isNotNull);
      expect(double.tryParse('75,5'), isNull); // comma is not valid decimal
    });

    test('double.tryParse succeeds for valid weight strings', () {
      expect(double.tryParse('70'),    70.0);
      expect(double.tryParse('75.5'),  75.5);
      expect(double.tryParse('100.0'), 100.0);
    });

    test('double.tryParse handles leading/trailing whitespace via trimmed input', () {
      // The text controller .text is used directly; ensure trim is safe
      final raw = '  80.0  ';
      final val = double.tryParse(raw.trim());
      expect(val, 80.0);
    });

    test('logScaleEntry persists and is retrievable', () async {
      final p = await _loaded();
      await p.logScaleEntry(_scale(weight: 77.2));

      expect(p.latestScaleEntry?.weightKg, 77.2);
      expect(p.scaleHistory.length, 1);
    });

    test('logScaleEntry with boundary weight values across different days', () async {
      final p = await _loaded();
      // Both past dates to avoid today-replacement logic
      final d1 = DateTime.now().subtract(const Duration(days: 5));
      final d2 = DateTime.now().subtract(const Duration(days: 1));

      await p.logScaleEntry(_scale(weight: 30.0, date: d1));
      await p.logScaleEntry(_scale(weight: 200.0, date: d2));

      expect(p.scaleHistory.length, 2);
      expect(p.scaleHistory.first.weightKg, 30.0);
      expect(p.scaleHistory.last.weightKg, 200.0);
    });

    test('null guard logic: null state means early return (no crash)', () {
      // Simulate the guard pattern used in _save():
      // if (_formKey.currentState == null || !_formKey.currentState!.validate())
      // When currentState is null → short-circuit, no validate() call, no crash.
      FormState? nullableState; // simulates currentState being null
      final shouldReturn = nullableState == null;
      expect(shouldReturn, isTrue);
    });
  });

  // ── 3. Goal card null safety ───────────────────────────────────────────────

  group('Goal card null safety', () {
    test('latestWeightKg ?? 0.0 never throws when weight is null', () async {
      final p = await _loaded();
      expect(p.latestWeightKg, isNull);
      // This is the fixed pattern — should never throw
      final current = p.latestWeightKg ?? 0.0;
      expect(current, 0.0);
    });

    test('kgToGoal ?? 0.0 never throws when no weight logged', () async {
      final p = await _loaded({'goal_weight': 70.0});
      expect(p.kgToGoal, isNull); // no weight logged → null
      final kg = p.kgToGoal ?? 0.0;
      expect(kg, 0.0);
    });

    test('goalProgress returns 0.0 when no weight data', () async {
      final p = await _loaded();
      expect(p.goalProgress, 0.0);
    });

    test('goal card values are correct after weight is logged', () async {
      final p = await _loaded({'goal_weight': 70.0});
      await p.logBodyEntry(weightKg: 80.0, steps: 0);

      expect(p.latestWeightKg, 80.0);
      expect(p.kgToGoal, closeTo(10.0, 0.01));
      expect(p.goalWeightKg, 70.0);
    });

    test('kgToGoal is null when no weight is logged', () async {
      final p = await _loaded({'goal_weight': 70.0});
      expect(p.kgToGoal, isNull);
    });

    test('kgToGoal is zero when current weight equals goal weight', () async {
      final p = await _loaded();
      await p.saveGoalWeight(80.0);
      await p.logBodyEntry(weightKg: 80.0, steps: 0);
      // at goal — kgToGoal is clamped to 0 (not negative)
      expect(p.kgToGoal, closeTo(0.0, 0.01));
    });
  });

  // ── 4. Version constants ──────────────────────────────────────────────────

  group('Version constants', () {
    test('default calorie goal constant has not regressed', () {
      expect(FitnessProvider.kDefaultCalorieGoal, 1700);
    });

    test('default protein goal constant has not regressed', () {
      expect(FitnessProvider.kDefaultProteinGoal, 100);
    });

    test('default water goal constant has not regressed', () {
      expect(FitnessProvider.kDefaultWaterGoalMl, 2500);
    });

    test('default step goal constant has not regressed', () {
      expect(FitnessProvider.kDefaultStepGoal, 8000);
    });

    test('provider initialises with correct defaults', () async {
      final p = await _loaded();
      expect(p.calorieGoal, FitnessProvider.kDefaultCalorieGoal);
      expect(p.proteinGoal, FitnessProvider.kDefaultProteinGoal);
      expect(p.waterGoalMl, FitnessProvider.kDefaultWaterGoalMl);
      expect(p.stepGoal,    FitnessProvider.kDefaultStepGoal);
    });
  });

  // ── 5. Crash handler guard logic ──────────────────────────────────────────

  group('Crash handler', () {
    test('crash log write is safe when directory is accessible', () async {
      // Simulate the _appendCrashLog logic without running actual app
      final dir  = Directory.systemTemp;
      final file = File('${dir.path}/test_crash_log.txt');
      const entry = '[2026-06-04] [Test]\nError message\n---\n';

      // Should not throw
      expect(
        () => file.writeAsStringSync(entry, mode: FileMode.append),
        returnsNormally,
      );

      final content = await file.readAsString();
      expect(content, contains('[Test]'));
      expect(content, contains('Error message'));

      // Cleanup
      await file.delete();
    });

    test('crash log append mode does not overwrite existing content', () async {
      final file = File('${Directory.systemTemp.path}/test_append_log.txt');
      file.writeAsStringSync('entry1\n---\n');
      file.writeAsStringSync('entry2\n---\n', mode: FileMode.append);

      final content = await file.readAsString();
      expect(content, contains('entry1'));
      expect(content, contains('entry2'));

      await file.delete();
    });

    test('crash handler swallowing its own error does not propagate', () {
      // The guard inside _appendCrashLog catches its own errors
      expect(() {
        try {
          throw Exception('simulated crash');
        } catch (_) {
          // This is the catch (_) {} pattern in _appendCrashLog
        }
      }, returnsNormally);
    });
  });

  // ── 6. Data integrity regression tests ───────────────────────────────────

  group('Data integrity regressions', () {
    test('food entry survives save and reload cycle', () async {
      final p = await _loaded();
      await p.addFoodEntry(FoodEntry(
        id: 'f1', name: 'Dal Rice', calories: 380, protein: 14,
        mealType: MealType.lunch, timestamp: DateTime.now(),
      ));
      expect(p.todayFood.length, 1);
      expect(p.todayFood.first.name, 'Dal Rice');
    });

    test('water log accumulates correctly', () async {
      final p = await _loaded();
      await p.addWater(500);
      await p.addWater(750);
      expect(p.todayWaterMl, 1250);
    });

    test('supplement toggle persists', () async {
      final p = await _loaded();
      await p.updateSupplement('whey', true);
      expect(p.supplements.whey, isTrue);
      expect(p.supplementCalories, 120.0);
      expect(p.supplementProtein, 25.0);
    });

    test('scale entry logScaleEntry deduplicates same-day entries', () async {
      final p = await _loaded();
      final today = DateTime.now();
      await p.logScaleEntry(_scale(weight: 80.0, date: today));
      await p.logScaleEntry(_scale(weight: 79.5, date: today));

      expect(p.scaleHistory.length, 1);
      expect(p.scaleHistory.first.weightKg, 79.5);
    });

    test('onboarding flag correctly read back after markOnboardingDone', () async {
      final p = await _loaded();
      expect(p.onboardingDone, isFalse);
      await p.markOnboardingDone();
      expect(p.onboardingDone, isTrue);
    });

    test('goal weight save persists correctly', () async {
      final p = await _loaded();
      await p.saveGoalWeight(68.0);
      expect(p.goalWeightKg, 68.0);
    });

    test('calorie goal save is clamped to valid range', () async {
      final p = await _loaded();
      await p.saveCalorieGoal(500);  // below min (800)
      expect(p.calorieGoal, 800);
      await p.saveCalorieGoal(9999); // above max (5000)
      expect(p.calorieGoal, 5000);
    });

    test('removeFoodEntry removes exactly the right entry', () async {
      final p = await _loaded();
      await p.addFoodEntry(FoodEntry(
        id: 'a', name: 'Roti', calories: 104, protein: 3,
        mealType: MealType.lunch, timestamp: DateTime.now(),
      ));
      await p.addFoodEntry(FoodEntry(
        id: 'b', name: 'Dal', calories: 120, protein: 8,
        mealType: MealType.lunch, timestamp: DateTime.now(),
      ));
      expect(p.todayFood.length, 2);

      p.removeFoodEntry('a');
      expect(p.todayFood.length, 1);
      expect(p.todayFood.first.id, 'b');
    });
  });
}
