import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:kfit/models/models.dart';
import 'package:kfit/providers/fitness_provider.dart';
import 'package:kfit/services/on_device_ai_service.dart';
import 'package:kfit/services/chat_intent.dart';
import 'package:kfit/services/food_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Build 110: service-layer coverage — AI prompt builders, chat-intent routing,
/// and food-API value math, all exercised against a seeded provider.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<FitnessProvider> seeded() async {
    final now = DateTime.now();
    final prefs = <String, Object>{
      'onboarding_done': true, 'user_name': 'Asha', 'height_cm': 165.0,
      'age': 30, 'is_male': false, 'goal_weight_kg': 60.0,
    };
    final body = <Map<String, dynamic>>[];
    for (var i = 0; i < 8; i++) {
      body.add(BodyEntry(
        id: 'b$i', date: now.subtract(Duration(days: 28 - i * 4)),
        weightKg: 68.0 - i * 0.3, steps: 7000,
      ).toJson());
    }
    prefs['body_history'] = jsonEncode(body);
    prefs['scale_history'] = jsonEncode([
      SmartScaleEntry(id: 's1', date: now.subtract(const Duration(days: 20)),
        weightKg: 68, bodyFatPercent: 30, bodyFatKg: 20, muscleMassKg: 44,
        muscleMassPercent: 45, leanBodyMassKg: 47, biologicalAge: 32,
        visceralFatIndex: 8, bmr: 1400, bodyWaterPercent: 50, boneMassKg: 2.5,
        proteinPercent: 17, skeletalMuscleMassKg: 26).toJson(),
      SmartScaleEntry(id: 's2', date: now.subtract(const Duration(days: 2)),
        weightKg: 66, bodyFatPercent: 27, bodyFatKg: 18, muscleMassKg: 45,
        muscleMassPercent: 47, leanBodyMassKg: 48, biologicalAge: 30,
        visceralFatIndex: 7, bmr: 1410, bodyWaterPercent: 52, boneMassKg: 2.5,
        proteinPercent: 18, skeletalMuscleMassKg: 27).toJson(),
    ]);
    prefs['measurements_history'] = jsonEncode([
      MeasurementEntry(id: 'm1', date: now.subtract(const Duration(days: 1)),
        chestCm: 90, waistCm: 74, hipsCm: 96, leftArmCm: 28, leftThighCm: 54).toJson(),
    ]);
    prefs['workouts'] = jsonEncode([
      WorkoutLog(id: 'w1', date: now, workoutType: WorkoutType.a, exercises: [
        ExerciseLog(name: 'Bench Press', sets: [SetData(reps: 5, weight: 40)]),
        ExerciseLog(name: 'Deadlift', sets: [SetData(reps: 3, weight: 70)]),
        ExerciseLog(name: 'Running', sets: [SetData(reps: 20, weight: 0)]),
      ]).toJson(),
    ]);
    for (var i = 0; i < 3; i++) {
      final d = now.subtract(Duration(days: i));
      prefs['food_${key(d)}'] = jsonEncode([
        FoodEntry(id: 'f$i', name: 'Idli', calories: 70, protein: 2, carbs: 14,
            fat: 0.4, mealType: MealType.breakfast, timestamp: d).toJson(),
        FoodEntry(id: 'g$i', name: 'Paneer', calories: 265, protein: 18,
            carbs: 3, fat: 20, mealType: MealType.dinner, timestamp: d).toJson(),
      ]);
      prefs['water_${key(d)}'] = 2000;
      prefs['supp_${key(d)}'] =
          jsonEncode(SupplementStatus(whey: true, creatine: true, multivitamin: true).toJson());
    }
    SharedPreferences.setMockInitialValues(prefs);
    final p = FitnessProvider();
    await p.loadData();
    addTearDown(p.dispose);
    return p;
  }

  group('OnDeviceAiService prompt builders', () {
    test('system prompt embeds the user\'s real numbers', () async {
      final p = await seeded();
      final ai = OnDeviceAiService();
      addTearDown(ai.dispose);
      final prompt = ai.buildSystemPromptForTest(p);
      expect(prompt, contains('Asha'));
      expect(prompt, contains('Female'));
      expect(prompt, contains('Recent food'));
      expect(prompt, contains('Weight log'));
    });

    test('query-specific context is included for each topic', () async {
      final p = await seeded();
      final ai = OnDeviceAiService();
      addTearDown(ai.dispose);
      expect(ai.buildContextForQueryTest('what is my weight trend', p),
          contains('WeightLog'));
      expect(ai.buildContextForQueryTest('how much protein did i eat', p),
          contains('FoodLog'));
      expect(ai.buildContextForQueryTest('how is my bench press', p),
          contains('Workouts'));
      expect(ai.buildContextForQueryTest('what is my waist measurement', p),
          contains('Measurements'));
      expect(ai.buildContextForQueryTest('my body fat and lean mass', p),
          contains('ScaleHistory'));
      expect(ai.buildContextForQueryTest('water and supplements', p),
          contains('Water'));
    });

    test('rich prompt merges context; keyword matcher honours word boundaries',
        () async {
      final p = await seeded();
      final ai = OnDeviceAiService();
      addTearDown(ai.dispose);
      expect(ai.buildRichPromptForTest('show my weight trend', p),
          contains('EXTRA DATA'));
      expect(OnDeviceAiService.hasKeywordTest('seafood platter', ['food']), isFalse);
      expect(OnDeviceAiService.hasKeywordTest('my food log', ['food']), isTrue);
    });
  });

  group('ChatIntent', () {
    late FitnessProvider p;
    setUp(() async {
      p = await seeded();
    });

    test('greetings are detected and answered without the LLM', () {
      expect(ChatIntent.isGreeting('hi'), isTrue);
      expect(ChatIntent.isGreeting('good morning'), isTrue);
      expect(ChatIntent.isGreeting('why am i plateauing'), isFalse);
      expect(ChatIntent.greetingReply(p), contains('Asha'));
    });

    test('factual lookups return exact deterministic answers', () {
      expect(ChatIntent.factualAnswer('what is my weight', p), contains('kg'));
      expect(ChatIntent.factualAnswer('how much protein today', p),
          contains('protein'));
      expect(ChatIntent.factualAnswer('what is my tdee', p), contains('TDEE'));
      expect(ChatIntent.factualAnswer('my calorie target', p),
          contains('target'));
      expect(ChatIntent.factualAnswer('what is my bmi', p), contains('BMI'));
      expect(ChatIntent.factualAnswer('my body fat percentage', p),
          contains('fat'));
      expect(ChatIntent.factualAnswer('my best lifts', p), isNotNull);
      expect(ChatIntent.factualAnswer('what is my streak', p), contains('treak'));
      expect(ChatIntent.factualAnswer('my habit score', p), contains('habit'));
      expect(ChatIntent.factualAnswer('my waist measurement', p),
          contains('waist'));
      expect(ChatIntent.factualAnswer('when will i reach my goal', p), isNotNull);
    });

    test('coaching questions defer to the LLM (null)', () {
      expect(ChatIntent.factualAnswer('why am i not losing weight', p), isNull);
      expect(ChatIntent.factualAnswer('suggest a meal plan', p), isNull);
      expect(ChatIntent.factualAnswer('', p), isNull);
    });
  });

  group('FoodApiResult per-gram math', () {
    test('scales per-100g values to an arbitrary serving', () {
      const r = FoodApiResult(name: 'X', calories100g: 200, protein100g: 10,
          carbs100g: 20, fat100g: 5, source: 'OpenFoodFacts');
      expect(r.caloriesForGrams(50), 100);
      expect(r.proteinForGrams(50), 5);
      expect(r.carbsForGrams(200), 40);
      expect(r.fatForGrams(0), 0);
    });

    test('search returns [] for too-short queries (no network)', () async {
      expect(await FoodApiService.search('a'), isEmpty);
    });
  });
}
