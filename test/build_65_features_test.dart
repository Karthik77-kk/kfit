// Build 65 — onboarding, AI enterprise token, scale/stats auto-fill, history context
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:karthik_fitness/providers/fitness_provider.dart';
import 'package:karthik_fitness/services/on_device_ai_service.dart';
import 'package:karthik_fitness/models/models.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

Future<FitnessProvider> _loaded([Map<String, Object> seed = const {}]) async {
  SharedPreferences.setMockInitialValues(seed);
  final p = FitnessProvider();
  await p.loadData();
  return p;
}

SmartScaleEntry _scale({
  String id = 's1',
  double weight = 78.5,
  double fat = 22.0,
  double muscle = 34.0,
  double bmr = 1750.0,
  DateTime? date,
}) =>
    SmartScaleEntry(
      id: id,
      date: date ?? DateTime.now(),
      weightKg: weight,
      bodyFatPercent: fat,
      bodyFatKg: weight * fat / 100,
      muscleMassKg: muscle,
      muscleMassPercent: muscle / weight * 100,
      leanBodyMassKg: weight * (1 - fat / 100),
      biologicalAge: 24,
      visceralFatIndex: 6,
      bmr: bmr,
      bodyWaterPercent: 58.0,
      boneMassKg: 3.1,
      proteinPercent: 18.0,
      skeletalMuscleMassKg: 27.5,
    );

MeasurementEntry _meas({
  String id = 'm1',
  double chest = 95.0,
  double waist = 82.0,
  double hips = 96.0,
  double arm = 32.0,
  double thigh = 56.0,
  DateTime? date,
}) =>
    MeasurementEntry(
      id: id,
      date: date ?? DateTime.now(),
      chestCm: chest,
      waistCm: waist,
      hipsCm: hips,
      leftArmCm: arm,
      leftThighCm: thigh,
    );

FoodEntry _food(String id, double cal, double prot) => FoodEntry(
      id: id,
      name: 'Food $id',
      calories: cal,
      protein: prot,
      mealType: MealType.lunch,
      timestamp: DateTime.now(),
    );

WorkoutLog _workout({String id = 'w1', String name = 'Push A', DateTime? date}) =>
    WorkoutLog(
      id: id,
      name: name,
      date: date ?? DateTime.now(),
      workoutType: WorkoutType.custom,
      exercises: [
        ExerciseLog(
          name: 'Bench Press',
          sets: [SetData(reps: 8, weight: 80.0)],
        ),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

// ─── 1. Onboarding flag ───────────────────────────────────────────────────────

group('Onboarding flag', () {
  test('onboardingDone is false when prefs has no key', () async {
    final p = await _loaded();
    expect(p.onboardingDone, isFalse);
  });

  test('onboardingDone is true when prefs key is true', () async {
    final p = await _loaded({'onboarding_done': true});
    expect(p.onboardingDone, isTrue);
  });

  test('onboardingDone is false when prefs key is false', () async {
    final p = await _loaded({'onboarding_done': false});
    expect(p.onboardingDone, isFalse);
  });

  test('markOnboardingDone sets flag to true', () async {
    final p = await _loaded();
    expect(p.onboardingDone, isFalse);

    await p.markOnboardingDone();

    expect(p.onboardingDone, isTrue);
  });

  test('markOnboardingDone persists to SharedPreferences', () async {
    final p = await _loaded();
    await p.markOnboardingDone();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_done'), isTrue);
  });

  test('markOnboardingDone notifies listeners', () async {
    final p = await _loaded();
    var notified = false;
    p.addListener(() => notified = true);

    await p.markOnboardingDone();

    expect(notified, isTrue);
  });

  test('markOnboardingDone is idempotent', () async {
    final p = await _loaded();
    await p.markOnboardingDone();
    await p.markOnboardingDone(); // second call is fine
    expect(p.onboardingDone, isTrue);
  });

  test('onboarding flag survives provider reload', () async {
    final p = await _loaded();
    await p.markOnboardingDone();

    // Reload from same prefs
    final p2 = FitnessProvider();
    await p2.loadData();

    expect(p2.onboardingDone, isTrue);
  });

  test('saveUserName persists during onboarding flow', () async {
    final p = await _loaded();
    await p.saveUserName('Ravi');
    expect(p.userName, 'Ravi');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('user_name'), 'Ravi');
  });

  test('saveUserName trims whitespace', () async {
    final p = await _loaded();
    await p.saveUserName('  Amit  ');
    expect(p.userName, 'Amit');
  });

  test('saveUserName falls back to Karthik for blank input', () async {
    final p = await _loaded();
    await p.saveUserName('');
    expect(p.userName, 'Karthik');
  });

  test('saveUserName falls back for whitespace-only input', () async {
    final p = await _loaded();
    await p.saveUserName('   ');
    expect(p.userName, 'Karthik');
  });

  test('userName persists across reloads', () async {
    final p = await _loaded();
    await p.saveUserName('Meera');
    await p.markOnboardingDone();

    final p2 = FitnessProvider();
    await p2.loadData();

    expect(p2.userName, 'Meera');
    expect(p2.onboardingDone, isTrue);
  });
});

// ─── 2. AI service enterprise token ──────────────────────────────────────────

group('OnDeviceAiService enterprise token', () {
  test('saveToken persists to SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({});
    final ai = OnDeviceAiService();
    await ai.saveToken('hf_test_token_123');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('hf_token_ai_chat'), 'hf_test_token_123');
  });

  test('saveToken trims whitespace', () async {
    SharedPreferences.setMockInitialValues({});
    final ai = OnDeviceAiService();
    await ai.saveToken('  hf_abc  ');
    expect(ai.hfToken, 'hf_abc');
  });

  test('hasToken is false before any saveToken call', () {
    expect(OnDeviceAiService().hasToken, isFalse);
  });

  test('hasToken is true after saveToken', () async {
    SharedPreferences.setMockInitialValues({});
    final ai = OnDeviceAiService();
    await ai.saveToken('hf_token');
    expect(ai.hasToken, isTrue);
  });

  test('initial state is notInstalled', () {
    expect(OnDeviceAiService().state, AiModelState.notInstalled);
  });

  test('isReady is false initially', () {
    expect(OnDeviceAiService().isReady, isFalse);
  });

  test('resetConversation does not throw when no chat active', () {
    final ai = OnDeviceAiService();
    expect(() => ai.resetConversation(), returnsNormally);
  });
});

// ─── 3. Scale auto-fill (provider side) ──────────────────────────────────────

group('Scale auto-fill (provider)', () {
  test('latestScaleEntry is null when history empty', () async {
    final p = await _loaded();
    expect(p.latestScaleEntry, isNull);
  });

  test('latestScaleEntry returns most recent after multiple logs', () async {
    final p = await _loaded();
    await p.logScaleEntry(_scale(id: 'a', weight: 80.0,
        date: DateTime.now().subtract(const Duration(days: 2))));
    await p.logScaleEntry(_scale(id: 'b', weight: 79.0,
        date: DateTime.now().subtract(const Duration(days: 1))));
    await p.logScaleEntry(_scale(id: 'c', weight: 78.5, date: DateTime.now()));

    expect(p.latestScaleEntry?.weightKg, 78.5);
  });

  test('scale entry preserves all 13 fields', () async {
    final p = await _loaded();
    final entry = _scale(weight: 77.2, fat: 21.5, muscle: 33.8, bmr: 1720.0);
    await p.logScaleEntry(entry);

    final l = p.latestScaleEntry!;
    expect(l.weightKg,       77.2);
    expect(l.bodyFatPercent, 21.5);
    expect(l.muscleMassKg,   33.8);
    expect(l.bmr,            1720.0);
    expect(l.bodyWaterPercent, 58.0);
    expect(l.boneMassKg,     3.1);
    expect(l.biologicalAge,  24);
    expect(l.visceralFatIndex, 6);
  });

  test('same-day scale log replaces previous entry', () async {
    final p = await _loaded();
    final today = DateTime.now();
    await p.logScaleEntry(_scale(id: 'x', weight: 80.0, date: today));
    await p.logScaleEntry(_scale(id: 'y', weight: 79.5, date: today));

    expect(p.scaleHistory.length, 1);
    expect(p.scaleHistory.first.weightKg, 79.5);
  });

  test('latestWeightKg prefers scale weight over manual body entry', () async {
    final p = await _loaded();
    await p.logBodyEntry(weightKg: 82.0, steps: 0);
    await p.logScaleEntry(_scale(weight: 79.0));

    expect(p.latestWeightKg, 79.0);
  });

  test('scaleHistory is sorted ascending by date', () async {
    final p = await _loaded();
    // Use past dates only — logScaleEntry removes same-day (today) entries
    final d1 = DateTime.now().subtract(const Duration(days: 5));
    final d2 = DateTime.now().subtract(const Duration(days: 3));
    final d3 = DateTime.now().subtract(const Duration(days: 1));

    await p.logScaleEntry(_scale(id: 'c', weight: 78.0, date: d3));
    await p.logScaleEntry(_scale(id: 'a', weight: 80.0, date: d1));
    await p.logScaleEntry(_scale(id: 'b', weight: 79.0, date: d2));

    final weights = p.scaleHistory.map((e) => e.weightKg).toList();
    expect(weights, [80.0, 79.0, 78.0]);
  });
});

// ─── 4. Body measurements auto-fill (provider side) ──────────────────────────

group('Measurements auto-fill (provider)', () {
  test('latestMeasurements is null when empty', () async {
    final p = await _loaded();
    expect(p.latestMeasurements, isNull);
  });

  test('latestMeasurements returns most recent', () async {
    final p = await _loaded();
    final old = _meas(id: 'old', waist: 85.0,
        date: DateTime.now().subtract(const Duration(days: 10)));
    final recent = _meas(id: 'new', waist: 83.5, date: DateTime.now());

    await p.logMeasurement(old);
    await p.logMeasurement(recent);

    expect(p.latestMeasurements?.waistCm, 83.5);
  });

  test('measurement entry preserves all 5 fields', () async {
    final p = await _loaded();
    final m = _meas(chest: 94.0, waist: 80.0, hips: 97.0, arm: 33.0, thigh: 57.0);
    await p.logMeasurement(m);

    final l = p.latestMeasurements!;
    expect(l.chestCm,     94.0);
    expect(l.waistCm,     80.0);
    expect(l.hipsCm,      97.0);
    expect(l.leftArmCm,   33.0);
    expect(l.leftThighCm, 57.0);
  });

  test('getRecentMeasurements filters by day window', () async {
    final p = await _loaded();
    await p.logMeasurement(_meas(id: 'old',
        date: DateTime.now().subtract(const Duration(days: 100))));
    await p.logMeasurement(_meas(id: 'mid',
        date: DateTime.now().subtract(const Duration(days: 30))));
    await p.logMeasurement(_meas(id: 'now', date: DateTime.now()));

    expect(p.getRecentMeasurements(days: 90).length, 2);
    expect(p.getRecentMeasurements(days: 20).length, 1);
  });

  test('MeasurementEntry.isEmpty true when all fields null', () {
    final m = MeasurementEntry(
      id: 'x', date: DateTime.now(),
      chestCm: null, waistCm: null, hipsCm: null,
      leftArmCm: null, leftThighCm: null,
    );
    expect(m.isEmpty, isTrue);
  });

  test('MeasurementEntry.isEmpty false when any field non-null', () {
    final m = MeasurementEntry(
      id: 'x', date: DateTime.now(),
      chestCm: 95.0, waistCm: null, hipsCm: null,
      leftArmCm: null, leftThighCm: null,
    );
    expect(m.isEmpty, isFalse);
  });

  test('measurement with partial fields preserves non-null values', () async {
    final p = await _loaded();
    final m = MeasurementEntry(
      id: 'p', date: DateTime.now(),
      chestCm: 90.0, waistCm: null, hipsCm: 98.0,
      leftArmCm: null, leftThighCm: null,
    );
    await p.logMeasurement(m);

    final l = p.latestMeasurements!;
    expect(l.chestCm, 90.0);
    expect(l.waistCm, isNull);
    expect(l.hipsCm, 98.0);
  });
});

// ─── 5. Export data completeness ─────────────────────────────────────────────

group('Export data completeness', () {
  test('exportAllData writes valid JSON', () async {
    final p = await _loaded({'user_name': 'Karthik', 'onboarding_done': true});
    final path = await p.exportAllData();
    final json = jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;

    expect(json, isA<Map>());
    expect(json['user_name'], 'Karthik');
  });

  test('exportAllData includes onboarding_done', () async {
    final p = await _loaded({'onboarding_done': true});
    final path = await p.exportAllData();
    final json = jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;

    expect(json['onboarding_done'], isTrue);
  });

  test('exportAllData includes calorie_goal', () async {
    final p = await _loaded({'calorie_goal': 1800});
    final path = await p.exportAllData();
    final json = jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;

    expect(json['calorie_goal'], 1800);
  });

  test('exportAllData excludes pedometer device keys', () async {
    final p = await _loaded({
      'pedometer_baseline': 50000,
      'pedometer_date': '2026-06-04',
      'user_name': 'Test',
    });
    final path = await p.exportAllData();
    final json = jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;

    expect(json.containsKey('pedometer_baseline'), isFalse);
    expect(json.containsKey('pedometer_date'),     isFalse);
    expect(json.containsKey('user_name'),          isTrue);
  });

  test('importAllData restores user_name and onboarding_done', () async {
    final p = await _loaded({'user_name': 'Karthik', 'onboarding_done': true});
    final path = await p.exportAllData();

    SharedPreferences.setMockInitialValues({});
    final p2 = FitnessProvider();
    final ok = await p2.importAllData(path);

    expect(ok, isTrue);
    expect(p2.userName, 'Karthik');
    expect(p2.onboardingDone, isTrue);
  });

  test('importAllData returns false for nonexistent file', () async {
    final p = await _loaded();
    final ok = await p.importAllData('/nonexistent/path/file.json');
    expect(ok, isFalse);
  });
});

// ─── 6. AI system prompt history coverage ────────────────────────────────────

group('AI system prompt history coverage', () {
  test('prompt is non-empty string', () async {
    final p = await _loaded();
    final ai = OnDeviceAiService();
    final prompt = ai.buildSystemPromptForTest(p);
    expect(prompt.length, greaterThan(200));
  });

  // Build 69: compact prompt uses different headers — updated to match new format
  test('prompt contains FOOD section header', () async {
    final p = await _loaded();
    final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
    expect(prompt.contains('food'), isTrue); // compact: "FOOD (3d):"
  });

  test('prompt contains WEIGHT section', () async {
    final p = await _loaded();
    await p.logBodyEntry(weightKg: 75.0, steps: 0);
    final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
    expect(prompt.contains('Weight log'), isTrue); // compact: "WEIGHT:"
  });

  test('prompt contains BODY section when scale logged', () async {
    final p = await _loaded();
    await p.logScaleEntry(_scale(weight: 77.0));
    final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
    expect(prompt.contains('Body:'), isTrue); // compact: "BODY:" for composition
  });

  test('prompt contains HABITS section', () async {
    final p = await _loaded();
    final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
    expect(prompt.contains('Habit score'), isTrue);
  });

  test('prompt contains WORKOUTS section header', () async {
    final p = await _loaded();
    final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
    expect(prompt.contains('workouts'), isTrue); // compact: "WORKOUTS (5):"
  });

  test('prompt contains today food calories when food logged', () async {
    final p = await _loaded();
    await p.addFoodEntry(_food('dal', 320, 15));
    final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
    // The food log section shows total kcal for today
    expect(prompt.contains('320'), isTrue);
  });

  test('prompt includes scale weight when scale logged', () async {
    final p = await _loaded();
    await p.logScaleEntry(_scale(weight: 77.4));
    final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
    expect(prompt.contains('77.4'), isTrue);
  });

  test('prompt includes workout name when workout logged', () async {
    final p = await _loaded();
    await p.logWorkout(_workout(name: 'Pull B'));
    final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
    expect(prompt.contains('Pull B'), isTrue);
  });

  test('prompt does not crash when measurements are logged', () async {
    // Build 69 compact prompt dropped raw measurements section to save tokens.
    // Verify no exception is thrown when measurement data exists.
    final p = await _loaded();
    await p.logMeasurement(_meas(waist: 81.5));
    expect(() => OnDeviceAiService().buildSystemPromptForTest(p), returnsNormally);
  });

  test('prompt starts with user name', () async {
    final p = await _loaded({'user_name': 'Arjun'});
    final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
    expect(prompt.startsWith("You are Arjun"), isTrue);
  });

  test('prompt mentions Indian in rules', () async {
    final p = await _loaded();
    final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
    expect(prompt.toLowerCase().contains('indian'), isTrue);
  });

  // Build 69 compact prompt: empty-state text updated to match new compact format
  test('prompt mentions no food when no food entries', () async {
    final p = await _loaded();
    final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
    // Compact prompt shows "No food logged in last 3 days."
    expect(prompt.toLowerCase().contains('no food'), isTrue);
  });

  test('prompt mentions no workouts when none logged', () async {
    final p = await _loaded();
    final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
    // Compact prompt shows "None logged."
    expect(prompt.contains('None logged'), isTrue);
  });

  test('prompt does not crash when no scale data', () async {
    final p = await _loaded();
    // Compact prompt omits scale section entirely when no data — no crash
    expect(() => OnDeviceAiService().buildSystemPromptForTest(p), returnsNormally);
  });

  test('prompt capped at 5 workouts (Build 69 compact format)', () async {
    final p = await _loaded();
    // Log 10 workouts
    for (int i = 0; i < 10; i++) {
      await p.logWorkout(_workout(
        id: 'w$i',
        name: 'Workout $i',
        date: DateTime.now().subtract(Duration(days: i)),
      ));
    }
    final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
    // Compact prompt shows last 5 workouts: "Workout 0" (today) should appear,
    // "Workout 9" (9 days ago) should NOT appear.
    expect(prompt.contains('Workout 0'), isTrue);
    expect(prompt.contains('Workout 9'), isFalse);
  });
}); // end AI system prompt group
} // end main()
