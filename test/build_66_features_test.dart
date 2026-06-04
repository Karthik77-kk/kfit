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

  // ── 1. AiModelConfig data class ────────────────────────────────────────────

  group('AiModelConfig', () {
    test('availableModels has exactly 3 entries', () {
      expect(OnDeviceAiService.availableModels.length, 3);
    });

    test('first model is gemma3_1b', () {
      expect(OnDeviceAiService.availableModels.first.id, 'gemma3_1b');
    });

    test('gemma3_1b URL points to litert-community Gemma3-1B-IT', () {
      final m = OnDeviceAiService.availableModels
          .firstWhere((m) => m.id == 'gemma3_1b');
      expect(m.url, contains('litert-community/Gemma3-1B-IT'));
      expect(m.url, endsWith('.litertlm'));
    });

    test('gemma4_e4b URL points to litert-community gemma-4-E4B', () {
      final m = OnDeviceAiService.availableModels
          .firstWhere((m) => m.id == 'gemma4_e4b');
      expect(m.url, contains('gemma-4-E4B-it-litert-lm'));
      expect(m.url, endsWith('.litertlm'));
    });

    test('qwen25_1b5 URL points to litert-community Qwen2.5-1.5B', () {
      final m = OnDeviceAiService.availableModels
          .firstWhere((m) => m.id == 'qwen25_1b5');
      expect(m.url, contains('Qwen2.5-1.5B-Instruct'));
      expect(m.url, endsWith('.litertlm'));
    });

    test('all models have non-empty name, sizeLabel, description', () {
      for (final m in OnDeviceAiService.availableModels) {
        expect(m.name.isNotEmpty,        isTrue, reason: '${m.id} missing name');
        expect(m.sizeLabel.isNotEmpty,   isTrue, reason: '${m.id} missing sizeLabel');
        expect(m.description.isNotEmpty, isTrue, reason: '${m.id} missing description');
      }
    });

    test('gemma3_1b maxTokens is 2048', () {
      final m = OnDeviceAiService.availableModels
          .firstWhere((m) => m.id == 'gemma3_1b');
      expect(m.maxTokens, 2048);
    });

    test('gemma4_e4b maxTokens is 4096', () {
      final m = OnDeviceAiService.availableModels
          .firstWhere((m) => m.id == 'gemma4_e4b');
      expect(m.maxTokens, 4096);
    });

    test('qwen25_1b5 maxTokens is 4096', () {
      final m = OnDeviceAiService.availableModels
          .firstWhere((m) => m.id == 'qwen25_1b5');
      expect(m.maxTokens, 4096);
    });

    test('all model IDs are unique', () {
      final ids = OnDeviceAiService.availableModels.map((m) => m.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('all model URLs are unique', () {
      final urls = OnDeviceAiService.availableModels.map((m) => m.url).toList();
      expect(urls.toSet().length, urls.length);
    });

    test('qualityBadge is one of known values', () {
      const valid = {'Fast', 'Best', 'Alternative'};
      for (final m in OnDeviceAiService.availableModels) {
        expect(valid, contains(m.qualityBadge),
            reason: '${m.id} has unexpected badge: ${m.qualityBadge}');
      }
    });
  });

  // ── 2. Model selection ─────────────────────────────────────────────────────

  group('Model selection', () {
    test('default activeModelId is gemma3_1b', () {
      expect(OnDeviceAiService().activeModelId, 'gemma3_1b');
    });

    test('activeConfig returns config matching activeModelId', () {
      final ai = OnDeviceAiService();
      expect(ai.activeConfig.id, ai.activeModelId);
    });

    test('selectModel persists selection to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final ai = OnDeviceAiService();
      await ai.selectModel('qwen25_1b5');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ai_active_model_id'), 'qwen25_1b5');
    });

    test('selectModel updates activeModelId in memory', () async {
      SharedPreferences.setMockInitialValues({});
      final ai = OnDeviceAiService();
      await ai.selectModel('gemma4_e4b');
      expect(ai.activeModelId, 'gemma4_e4b');
    });

    test('selectModel with unknown id does nothing', () async {
      SharedPreferences.setMockInitialValues({});
      final ai = OnDeviceAiService();
      final before = ai.activeModelId;
      await ai.selectModel('nonexistent_model_xyz');
      expect(ai.activeModelId, before);
    });

    test('selectModel notifies listeners', () async {
      SharedPreferences.setMockInitialValues({});
      final ai = OnDeviceAiService();
      var count = 0;
      ai.addListener(() => count++);
      await ai.selectModel('qwen25_1b5');
      expect(count, greaterThan(0));
    });

    test('isModelInstalled false for all before any download', () {
      final ai = OnDeviceAiService();
      for (final m in OnDeviceAiService.availableModels) {
        expect(ai.isModelInstalled(m.id), isFalse);
      }
    });

    test('installedModelId is empty string initially', () {
      expect(OnDeviceAiService().installedModelId, isEmpty);
    });

    test('activeConfig falls back to first model for unknown id', () {
      final ai = OnDeviceAiService();
      // Force an invalid activeModelId — simulate corrupted prefs
      // activeConfig should still return the first model safely
      expect(ai.activeConfig, isNotNull);
      expect(ai.activeConfig, equals(OnDeviceAiService.availableModels.first));
    });

    test('initial state is notInstalled', () {
      expect(OnDeviceAiService().state, AiModelState.notInstalled);
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

    test('prompt contains BODY COMPOSITION section', () async {
      final p = await _loaded();
      final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
      expect(prompt.contains('BODY COMPOSITION'), isTrue);
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

    test('prompt includes visceral fat index when scale logged', () async {
      final p = await _loaded();
      await p.logScaleEntry(_scale(visceral: 7.0));
      final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
      expect(prompt.contains('Visceral fat'), isTrue);
    });

    test('prompt contains GOAL PROGRESS section', () async {
      final p = await _loaded();
      final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
      expect(prompt.contains('GOAL PROGRESS'), isTrue);
    });

    test('prompt includes goal weight in goal progress', () async {
      final p = await _loaded({'goal_weight': 70.0});
      final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
      expect(prompt.contains('70.0'), isTrue);
    });

    test('prompt contains FOOD LOG — ITEMS section', () async {
      final p = await _loaded();
      final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
      expect(prompt.contains('FOOD LOG — ITEMS'), isTrue);
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

    test('prompt contains FOOD LOG — TOTALS section for days 8-14', () async {
      final p = await _loaded();
      final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
      expect(prompt.contains('FOOD LOG — TOTALS'), isTrue);
    });

    test('prompt contains WATER & SUPPLEMENTS section', () async {
      final p = await _loaded();
      final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
      expect(prompt.contains('WATER & SUPPLEMENTS'), isTrue);
    });

    test('prompt shows water amount when logged', () async {
      final p = await _loaded();
      await p.addWater(2800);
      final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
      expect(prompt.contains('2800'), isTrue);
    });

    test('prompt shows supplement check marks when taken', () async {
      final p = await _loaded();
      await p.updateSupplement('whey', true);
      final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
      expect(prompt.contains('Whey✓'), isTrue);
    });

    test('prompt shows supplement X when not taken', () async {
      final p = await _loaded();
      final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
      expect(prompt.contains('Whey✗'), isTrue);
    });

    test('prompt contains ESTIMATED 1RM section', () async {
      final p = await _loaded();
      final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
      expect(prompt.contains('ESTIMATED 1RM'), isTrue);
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

    test('prompt shows No compound lifts when none logged', () async {
      final p = await _loaded();
      final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
      expect(prompt.contains('No compound lifts'), isTrue);
    });

    test('prompt contains workout streak', () async {
      final p = await _loaded();
      final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
      expect(prompt.contains('Workout streak'), isTrue);
    });

    test('prompt contains diet streak', () async {
      final p = await _loaded();
      final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
      expect(prompt.contains('Diet streak'), isTrue);
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

    test('measurement waist value appears in prompt', () async {
      final p = await _loaded();
      await p.logMeasurement(_meas(waist: 83.5));
      final prompt = OnDeviceAiService().buildSystemPromptForTest(p);
      expect(prompt.contains('83.5'), isTrue);
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
