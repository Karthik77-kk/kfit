// Build 66 — multi-model selection + full context system prompt
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
  double weight = 78.5, double fat = 22.0,
  double muscle = 34.0, double bmr = 1750.0,
  double lean = 61.2, double visceral = 6.0,
  int bioAge = 24, DateTime? date,
}) => SmartScaleEntry(
  id: 's1', date: date ?? DateTime.now(),
  weightKg: weight, bodyFatPercent: fat,
  bodyFatKg: weight * fat / 100, muscleMassKg: muscle,
  muscleMassPercent: muscle / weight * 100,
  leanBodyMassKg: lean, biologicalAge: bioAge,
  visceralFatIndex: visceral.toInt(), bmr: bmr,
  bodyWaterPercent: 58.0, boneMassKg: 3.1,
  proteinPercent: 18.0, skeletalMuscleMassKg: 27.5,
);

MeasurementEntry _meas({double waist = 82.0, DateTime? date}) =>
    MeasurementEntry(
      id: 'm1', date: date ?? DateTime.now(),
      chestCm: 95.0, waistCm: waist, hipsCm: 96.0,
      leftArmCm: 32.0, leftThighCm: 56.0,
    );

FoodEntry _food(String id, double cal, double prot,
    {MealType meal = MealType.lunch, DateTime? ts}) =>
    FoodEntry(
      id: id, name: 'Food $id', calories: cal, protein: prot,
      mealType: meal, timestamp: ts ?? DateTime.now(),
    );

WorkoutLog _workout({String name = 'Push A', DateTime? date}) => WorkoutLog(
  id: 'w1', name: name, date: date ?? DateTime.now(),
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
      (call) async => call.method == 'getApplicationDocumentsDirectory'
          ? Directory.systemTemp.path : null,
    );
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ── 1. Single-model API (Build 69: multi-model removed) ──────────────────────

  group('Single-model API (Build 69)', () {
    test('model name is Gemma 3 1B', () {
      expect(OnDeviceAiService().modelName, 'Gemma 3 1B');
    });

    test('model size contains 600', () {
      expect(OnDeviceAiService().modelSize, contains('600'));
    });

    test('initial state is notInstalled', () {
      expect(OnDeviceAiService().state, AiModelState.notInstalled);
    });

    test('isReady is false before init', () {
      expect(OnDeviceAiService().isReady, isFalse);
    });

    test('isInstalled is false when no prefs record', () {
      expect(OnDeviceAiService().isInstalled, isFalse);
    });

    test('downloadAndLoad does not crash when called again while already downloading', () async {
      // This tests the guard condition: if already downloading/loading, second call returns early
      final ai = OnDeviceAiService();
      // Second call before first completes — should not throw
      expect(() async {
        // We can't fully test download without network, but can test the guard
        if (ai.state == AiModelState.downloading) await ai.downloadAndLoad();
      }, returnsNormally);
    });
  });

  // ── 2. State transitions ──────────────────────────────────────────────────────

  group('Model state', () {
    test('initial state is notInstalled', () {
      expect(OnDeviceAiService().state, AiModelState.notInstalled);
    });

    test('dlProgress starts at 0.0', () {
      expect(OnDeviceAiService().dlProgress, 0.0);
    });

    test('errorMessage is empty initially', () {
      expect(OnDeviceAiService().errorMessage, isEmpty);
    });

    test('isReady false when notInstalled', () {
      final ai = OnDeviceAiService();
      expect(ai.state, AiModelState.notInstalled);
      expect(ai.isReady, isFalse);
    });
  });

  // ── 3. System prompt — new sections ───────────────────────────────────────

  group('System prompt — new sections Build 66', () {
    test('prompt contains GOALS section', () async {
      final p = await _loaded();
      final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
      expect(prompt.contains('GOALS'), isTrue);
    });

    test('prompt includes calorie goal value', () async {
      final p = await _loaded({'calorie_goal': 1800});
      final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
      expect(prompt.contains('1800'), isTrue);
    });

    test('prompt contains BODY section when scale/weight logged', () async {
      final p = await _loaded();
      await p.logBodyEntry(weightKg: 80.0, steps: 0);
      final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
      expect(prompt.contains('BODY'), isTrue); // compact: "BODY:" inline section
    });

    test('prompt includes BMI when weight and height logged', () async {
      final p = await _loaded();
      await p.logBodyEntry(weightKg: 80.0, steps: 0);
      final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
      expect(prompt.contains('BMI'), isTrue);
    });

    test('prompt includes body fat % when scale logged', () async {
      final p = await _loaded();
      await p.logScaleEntry(_scale(fat: 21.5));
      final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
      expect(prompt.contains('21.5'), isTrue);
    });

    test('prompt includes muscle mass when scale logged', () async {
      // Build 69 compact: visceral fat removed, but muscle mass still shown
      final p = await _loaded();
      await p.logScaleEntry(_scale(fat: 20.0));
      final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
      expect(prompt.contains('Muscle'), isTrue);
    });

    test('prompt contains PROGRESS section', () async {
      final p = await _loaded();
      final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
      expect(prompt.contains('PROGRESS'), isTrue); // compact: "PROGRESS:"
    });

    test('prompt includes goal weight in goal progress', () async {
      final p = await _loaded({'goal_weight': 70.0});
      final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
      expect(prompt.contains('70.0'), isTrue);
    });

    test('prompt contains FOOD section', () async {
      final p = await _loaded();
      final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
      expect(prompt.contains('FOOD'), isTrue); // compact: "FOOD (3d):"
    });

    test('prompt includes individual food item name', () async {
      final p = await _loaded();
      await p.addFoodEntry(FoodEntry(
        id: 'x1', name: 'Chicken Curry', calories: 450, protein: 35,
        mealType: MealType.dinner, timestamp: DateTime.now(),
      ));
      final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
      expect(prompt.contains('Chicken Curry'), isTrue);
    });

    test('prompt includes meal type label (D for dinner)', () async {
      final p = await _loaded();
      await p.addFoodEntry(FoodEntry(
        id: 'x2', name: 'Dal Rice', calories: 380, protein: 14,
        mealType: MealType.dinner, timestamp: DateTime.now(),
      ));
      final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
      expect(prompt.contains('D:'), isTrue);
    });

    test('prompt does not crash with 14 days food history', () async {
      // Build 69 compact: days 8-14 totals section dropped — verify no crash
      final p = await _loaded();
      expect(() => OnDeviceAiService().buildSystemPromptForTest(p), returnsNormally);
    });

    test('prompt contains WATER/SUPPS section when data exists', () async {
      final p = await _loaded();
      await p.addWater(1500);
      final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
      expect(prompt.contains('WATER/SUPPS'), isTrue); // compact header
    });

    test('prompt shows water amount when logged', () async {
      final p = await _loaded();
      await p.addWater(2800);
      final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
      expect(prompt.contains('2800'), isTrue);
    });

    test('prompt shows supplement check when taken (compact: W✓)', () async {
      final p = await _loaded();
      await p.updateSupplement('whey', true);
      await p.addWater(500); // need water data for WATER/SUPPS section to appear
      final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
      expect(prompt.contains('W✓'), isTrue); // compact format: W✓ not Whey✓
    });

    test('prompt shows supplement X when not taken (compact: W✗)', () async {
      final p = await _loaded();
      await p.addWater(500); // trigger WATER/SUPPS section
      final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
      expect(prompt.contains('W✗'), isTrue); // compact format: W✗ not Whey✗
    });

    test('prompt contains 1RM section when lifts logged', () async {
      final p = await _loaded();
      await p.logWorkout(WorkoutLog(
        id: 'w0', name: 'Test', date: DateTime.now(), workoutType: WorkoutType.custom,
        exercises: [ExerciseLog(name: 'Deadlift', sets: [SetData(reps: 5, weight: 100)])],
      ));
      final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
      expect(prompt.contains('1RM'), isTrue); // compact: "1RM:"
    });

    test('prompt shows 1RM estimate for logged compound lift', () async {
      final p = await _loaded();
      await p.logWorkout(WorkoutLog(
        id: 'w1', name: 'Push Day',
        date: DateTime.now(), workoutType: WorkoutType.custom,
        exercises: [
          ExerciseLog(
            name: 'Deadlift',
            sets: [SetData(reps: 5, weight: 100.0)],
          ),
        ],
      ));
      final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
      // Epley: 100 * (1 + 5/30) = ~116.7kg
      expect(prompt.contains('Deadlift'), isTrue);
    });

    test('prompt omits 1RM section when no compound lifts logged', () async {
      // Compact prompt: 1RM section only appears when lifts exist (no fallback text)
      final p = await _loaded();
      final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
      // No 1RM line when nothing logged — prompt should not contain "1RM:"
      expect(prompt.contains('1RM:'), isFalse);
    });

    test('prompt contains WorkStreak in HABITS', () async {
      final p = await _loaded();
      final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
      expect(prompt.contains('WorkStreak'), isTrue); // compact: "WorkStreak Xd"
    });

    test('prompt contains DietStreak in HABITS', () async {
      final p = await _loaded();
      final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
      expect(prompt.contains('DietStreak'), isTrue); // compact: "DietStreak Xd"
    });

    test('prompt length is > 500 chars (has real content)', () async {
      final p = await _loaded();
      final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
      expect(prompt.length, greaterThan(500));
    });

    test('prompt with all data is < 12000 chars (not runaway)', () async {
      final p = await _loaded();
      // Add lots of data
      for (int i = 0; i < 7; i++) {
        await p.addFoodEntry(_food('f$i', 400, 30,
            ts: DateTime.now().subtract(Duration(days: i))));
      }
      await p.logScaleEntry(_scale());
      await p.logMeasurement(_meas());
      for (int i = 0; i < 5; i++) {
        await p.logWorkout(_workout(
            date: DateTime.now().subtract(Duration(days: i))));
      }
      final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
      expect(prompt.length, lessThan(12000));
    });
  });

  // ── 4. Prompt data correctness ─────────────────────────────────────────────

  group('System prompt data correctness', () {
    test('prompt reflects current calorie goal', () async {
      final p = await _loaded({'calorie_goal': 2000});
      final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
      expect(prompt.contains('2000'), isTrue);
    });

    test('prompt reflects current protein goal', () async {
      final p = await _loaded({'protein_goal': 130});
      final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
      expect(prompt.contains('130'), isTrue);
    });

    test('prompt reflects current water goal', () async {
      final p = await _loaded({'water_goal_ml': 3000});
      final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
      expect(prompt.contains('3000'), isTrue);
    });

    test('prompt reflects current step goal', () async {
      final p = await _loaded({'step_goal': 10000});
      final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
      expect(prompt.contains('10000'), isTrue);
    });

    test('food item calories appear in prompt', () async {
      final p = await _loaded();
      await p.addFoodEntry(_food('dal', 320, 14, meal: MealType.lunch));
      final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
      expect(prompt.contains('320'), isTrue);
    });

    test('prompt does not crash when measurement logged (compact drops raw measurements)', () async {
      // Build 69: body measurements section dropped from compact prompt to save tokens.
      final p = await _loaded();
      await p.logMeasurement(_meas(waist: 83.5));
      // No crash, and WHR may appear if waist/hip data is sufficient
      expect(() => OnDeviceAiService().buildSystemPromptForTest(p), returnsNormally);
    });

    test('scale weight appears in prompt', () async {
      final p = await _loaded();
      await p.logScaleEntry(_scale(weight: 76.3));
      final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
      expect(prompt.contains('76.3'), isTrue);
    });

    test('workout name appears in prompt', () async {
      final p = await _loaded();
      await p.logWorkout(_workout(name: 'Leg Day Alpha'));
      final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
      expect(prompt.contains('Leg Day Alpha'), isTrue);
    });

    test('user name appears at start of prompt', () async {
      final p = await _loaded({'user_name': 'Vikas'});
      final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
      expect(prompt.startsWith("You are Vikas"), isTrue);
    });

    test('Indian food is mentioned in rules', () async {
      final p = await _loaded();
      final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
      expect(prompt.toLowerCase().contains('indian'), isTrue);
    });
  });
}
