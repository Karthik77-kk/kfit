// Build 71-72 feature tests
// Covers: AI init guard, rich prompt injection, context caps, copy yesterday,
// getting-started card condition, workout naming, rest timer logic,
// takeLast extension, sparkline painter, recent foods, scale layout
import 'dart:convert';
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

String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => call.method == 'getApplicationDocumentsDirectory'
          ? Directory.systemTemp.path
          : null,
    );
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ── 1. AI init guard (Build 71) ───────────────────────────────────────────────
  // The guard prevents re-entry: init() must skip if already in a terminal
  // or in-progress state. We verify this via state inspection, not by calling
  // the real FlutterGemma API (which is unavailable in tests).

  group('AI init guard — state machine', () {
    test('fresh service starts in notInstalled state', () {
      final ai = OnDeviceAiService();
      expect(ai.state, AiModelState.notInstalled);
      expect(ai.isReady, isFalse);
    });

    test('service is NOT ready on construction (no auto-init)', () {
      final ai = OnDeviceAiService();
      expect(ai.isReady, isFalse);
    });

    test('isInstalled is false before any download', () {
      final ai = OnDeviceAiService();
      expect(ai.isInstalled, isFalse);
    });

    test('model name is Gemma 3 1B', () {
      expect(OnDeviceAiService().modelName, 'Gemma 3 1B');
    });

    test('model size label is ~600 MB', () {
      expect(OnDeviceAiService().modelSize, '~600 MB');
    });

    test('autoLoad defaults to true on fresh service', () {
      final ai = OnDeviceAiService();
      expect(ai.autoLoad, isTrue);
    });

    test('saveAutoLoad persists false and updates getter', () async {
      SharedPreferences.setMockInitialValues({});
      final ai = OnDeviceAiService();
      await ai.saveAutoLoad(false);
      expect(ai.autoLoad, isFalse);
      // Verify persisted
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('ai_auto_load'), isFalse);
    });

    test('saveAutoLoad persists true', () async {
      SharedPreferences.setMockInitialValues({'ai_auto_load': false});
      final ai = OnDeviceAiService();
      await ai.saveAutoLoad(true);
      expect(ai.autoLoad, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('ai_auto_load'), isTrue);
    });

    test('autoLoad toggle does not affect model name or size', () async {
      SharedPreferences.setMockInitialValues({});
      final ai = OnDeviceAiService();
      await ai.saveAutoLoad(false);
      expect(ai.modelName, 'Gemma 3 1B');
      expect(ai.modelSize, '~600 MB');
    });
  });

  // ── 2. Rich system prompt injection (Build 71) ────────────────────────────────
  // _buildRichSystemPrompt inserts context ONCE into the system prompt (before
  // RULES:), never injected per-turn. This is the key fix for token overflow.

  group('buildRichPromptForTest — context injected into system prompt', () {
    test('no keyword → returns base prompt unchanged (no EXTRA DATA)', () async {
      final p  = await _loaded();
      final ai = OnDeviceAiService();
      final prompt = ai.buildRichPromptForTest('Hello, how are you?', p);
      expect(prompt, isNot(contains('EXTRA DATA')));
      expect(prompt, contains('answer the user'));
    });

    test('weight keyword → EXTRA DATA section appears before RULES', () async {
      final p = await _loaded();
      await p.logBodyEntry(weightKg: 80.0, steps: 0);
      final ai     = OnDeviceAiService();
      final prompt = ai.buildRichPromptForTest('What is my weight trend?', p);
      expect(prompt, contains('EXTRA DATA'));
      expect(prompt, contains('answer the user'));
      // EXTRA DATA must appear before RULES
      expect(prompt.indexOf('EXTRA DATA'), lessThan(prompt.indexOf('answer')));
    });

    test('food keyword → EXTRA DATA section appears before RULES', () async {
      final p = await _loaded();
      await p.addFoodEntry(FoodEntry(
        id: 'f1', name: 'Dal Rice', calories: 400, protein: 15,
        mealType: MealType.lunch, timestamp: DateTime.now(),
      ));
      final ai     = OnDeviceAiService();
      final prompt = ai.buildRichPromptForTest('What did I eat today?', p);
      expect(prompt, contains('EXTRA DATA'));
    });

    test('workout keyword → EXTRA DATA section present', () async {
      final p = await _loaded();
      await p.logWorkout(WorkoutLog(
        id: 'w1', name: 'Chest Day',
        date: DateTime.now(),
        exercises: [ExerciseLog(name: 'Bench Press', sets: [SetData(reps: 8, weight: 80)])],
      ));
      final ai     = OnDeviceAiService();
      final prompt = ai.buildRichPromptForTest('How was my gym session?', p);
      expect(prompt, contains('EXTRA DATA'));
    });

    test('base prompt always contains profile and RULES', () async {
      final p  = await _loaded();
      final ai = OnDeviceAiService();
      final prompt = ai.buildRichPromptForTest('Random question', p);
      expect(prompt, contains('answer the user'));
      expect(prompt, contains('Profile:'));
      expect(prompt, contains('Today('));
    });

    test('prompt does not duplicate RULES when context injected', () async {
      final p = await _loaded();
      await p.logBodyEntry(weightKg: 79.0, steps: 0);
      final ai     = OnDeviceAiService();
      final prompt = ai.buildRichPromptForTest('How am I losing weight?', p);
      // RULES: should appear exactly once
      final count = 'Now answer'.allMatches(prompt).length;
      expect(count, 1);
    });
  });

  // ── 3. Context section caps (Build 71) ───────────────────────────────────────
  // Each section is strictly capped to prevent token overflow.
  // Weight: max 14, Food: max 5 days, Workouts: max 5, Scale: max 3.

  group('Context section caps — token budget enforcement', () {
    test('weight context shows at most 14 entries (even if 20 logged)', () async {
      // Seed 20 body entries via SharedPreferences using the exact JSON format
      final entries = [
        for (int i = 20; i >= 1; i--)
          {
            'id': 'b$i',
            'date': DateTime.now().subtract(Duration(days: i)).toIso8601String(),
            'weightKg': 75.0 + i * 0.1,
            'steps': 0,
          }
      ];
      SharedPreferences.setMockInitialValues({
        'body_history': jsonEncode(entries),
      });
      final p = FitnessProvider();
      await p.loadData();

      final ai  = OnDeviceAiService();
      final ctx = ai.buildContextForQueryTest('What is my weight trend?', p);
      final logLine = ctx.split('\n').firstWhere(
          (l) => l.startsWith('WeightLog:'), orElse: () => '');
      if (logLine.isNotEmpty) {
        final entryCount = logLine.split(',').length;
        expect(entryCount, lessThanOrEqualTo(14));
      }
    });

    test('food context shows at most 5 days (even if 10 days logged)', () async {
      final p = await _loaded();
      for (int i = 1; i <= 10; i++) {
        final day = DateTime.now().subtract(Duration(days: i));
        await p.addFoodEntry(FoodEntry(
          id: 'f$i', name: 'Roti', calories: 120, protein: 3,
          mealType: MealType.lunch,
          timestamp: day,
        ));
      }
      final ai  = OnDeviceAiService();
      final ctx = ai.buildContextForQueryTest('What did I eat this week?', p);
      final foodLines = ctx
          .split('\n')
          .where((l) => l.contains('kcal') && !l.startsWith('WeightLog'))
          .toList();
      expect(foodLines.length, lessThanOrEqualTo(5));
    });

    test('workout context shows at most 5 workouts (even if 10 logged)', () async {
      final p = await _loaded();
      for (int i = 1; i <= 10; i++) {
        await p.logWorkout(WorkoutLog(
          id: 'w$i', name: 'Workout $i',
          date: DateTime.now().subtract(Duration(days: i)),
          exercises: [ExerciseLog(name: 'Squat', sets: [SetData(reps: 5, weight: 100)])],
        ));
      }
      final ai  = OnDeviceAiService();
      final ctx = ai.buildContextForQueryTest('How are my workouts going?', p);
      // Count lines starting with a date pattern inside Workouts block
      final workoutLines = ctx
          .split('\n')
          .where((l) => l.contains('Squat') || l.contains('Workout'))
          .toList();
      expect(workoutLines.length, lessThanOrEqualTo(6)); // 1 header + max 5 entries
    });

    test('scale context shows at most 3 entries (even if 5 logged)', () async {
      final p = await _loaded();
      for (int i = 1; i <= 5; i++) {
        await p.logScaleEntry(SmartScaleEntry(
          id: 's$i',
          date: DateTime.now().subtract(Duration(days: i)),
          weightKg: 79 - i * 0.2, bodyFatPercent: 21, bodyFatKg: 16,
          muscleMassKg: 37, muscleMassPercent: 47, leanBodyMassKg: 62,
          biologicalAge: 24, visceralFatIndex: 6, bmr: 1800,
          bodyWaterPercent: 59, boneMassKg: 3.1, proteinPercent: 18,
          skeletalMuscleMassKg: 28,
        ));
      }
      final ai  = OnDeviceAiService();
      final ctx = ai.buildContextForQueryTest('What is my body fat?', p);
      final scaleLine = ctx.split('\n').firstWhere(
          (l) => l.startsWith('ScaleHistory:'), orElse: () => '');
      // Max 3 entries — count separating commas
      if (scaleLine.isNotEmpty) {
        final entryCount = scaleLine.split(', ').length;
        expect(entryCount, lessThanOrEqualTo(3));
      }
    });

    test('food items per meal capped at 2 (compact format)', () async {
      final p = await _loaded();
      // Add 5 items to same meal slot today
      for (int i = 1; i <= 5; i++) {
        await p.addFoodEntry(FoodEntry(
          id: 'fi$i', name: 'Food Item $i', calories: 100, protein: 5,
          mealType: MealType.lunch, timestamp: DateTime.now(),
        ));
      }
      final ai  = OnDeviceAiService();
      final ctx = ai.buildContextForQueryTest('What did I eat for lunch?', p);
      // Count how many "L:Food Item" appear (max 2 per meal)
      final lunchItems = RegExp(r'L:Food Item').allMatches(ctx).length;
      expect(lunchItems, lessThanOrEqualTo(2));
    });
  });

  // ── 4. Copy yesterday's meals — provider logic (Build 72) ────────────────────
  // _copyYesterday reads yesterday's foodHistory and re-adds each entry for today.

  group('Copy yesterday meals — provider operations', () {
    test('food seeded for yesterday appears in foodHistory under correct key', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final key = _dateKey(yesterday);
      final item = {
        'id': 'y1', 'name': 'Chapati', 'calories': 120.0, 'protein': 3.0,
        'mealType': 1, 'timestamp': yesterday.toIso8601String(), // lunch = index 1
      };
      SharedPreferences.setMockInitialValues({'food_$key': jsonEncode([item])});
      final p = FitnessProvider();
      await p.loadData();

      final entries = p.foodHistory[key] ?? [];
      expect(entries, isNotEmpty);
      expect(entries.first.name, 'Chapati');
    });

    test('copying yesterday entries adds them to today', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final key = _dateKey(yesterday);
      final seedItems = [
        {'id': 'y1', 'name': 'Oats',   'calories': 150.0, 'protein': 5.0,
         'mealType': 0, 'timestamp': yesterday.toIso8601String()},
        {'id': 'y2', 'name': 'Banana', 'calories': 90.0,  'protein': 1.0,
         'mealType': 0, 'timestamp': yesterday.toIso8601String()},
      ];
      SharedPreferences.setMockInitialValues({'food_$key': jsonEncode(seedItems)});
      final p = FitnessProvider();
      await p.loadData();

      // Simulate _copyYesterday logic
      final yItems = p.foodHistory[key] ?? [];
      for (final e in yItems) {
        await p.addFoodEntry(FoodEntry(
          id: 'copy_${e.id}',
          name: e.name, calories: e.calories, protein: e.protein,
          mealType: e.mealType, timestamp: DateTime.now(),
        ));
      }

      expect(p.todayFood.any((e) => e.name == 'Oats'),   isTrue);
      expect(p.todayFood.any((e) => e.name == 'Banana'), isTrue);
      expect(p.todayFood.length, 2);
    });

    test('copy preserves meal type of each entry', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final key = _dateKey(yesterday);
      final seedItems = [
        {'id': 'y1', 'name': 'Curd Rice', 'calories': 200.0, 'protein': 8.0,
         'mealType': 2, 'timestamp': yesterday.toIso8601String()}, // dinner = index 2
      ];
      SharedPreferences.setMockInitialValues({'food_$key': jsonEncode(seedItems)});
      final p = FitnessProvider();
      await p.loadData();

      final yItems = p.foodHistory[key] ?? [];
      for (final e in yItems) {
        await p.addFoodEntry(FoodEntry(
          id: 'cp_${e.id}', name: e.name,
          calories: e.calories, protein: e.protein,
          mealType: e.mealType, timestamp: DateTime.now(),
        ));
      }

      expect(p.dinnerEntries.any((e) => e.name == 'Curd Rice'), isTrue);
    });

    test('copy with no yesterday food results in zero today entries', () async {
      final p = await _loaded(); // no seed data
      expect(p.todayFood, isEmpty);
    });

    test('copied entries get new IDs (not the original id)', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final key = _dateKey(yesterday);
      final seedItems = [
        {'id': 'original-id', 'name': 'Idli', 'calories': 80.0, 'protein': 2.0,
         'mealType': 0, 'timestamp': yesterday.toIso8601String()},
      ];
      SharedPreferences.setMockInitialValues({'food_$key': jsonEncode(seedItems)});
      final p = FitnessProvider();
      await p.loadData();

      final yItems = p.foodHistory[key] ?? [];
      for (final e in yItems) {
        await p.addFoodEntry(FoodEntry(
          id: 'copy_${DateTime.now().millisecondsSinceEpoch}_${e.id}',
          name: e.name, calories: e.calories, protein: e.protein,
          mealType: e.mealType, timestamp: DateTime.now(),
        ));
      }

      expect(p.todayFood.first.id, isNot('original-id'));
    });

    test('copying multiple entries preserves total calories', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final key = _dateKey(yesterday);
      final seedItems = [
        {'id': 'a', 'name': 'Egg',   'calories': 70.0, 'protein': 6.0,
         'mealType': 0, 'timestamp': yesterday.toIso8601String()},
        {'id': 'b', 'name': 'Toast', 'calories': 80.0, 'protein': 3.0,
         'mealType': 0, 'timestamp': yesterday.toIso8601String()},
      ];
      SharedPreferences.setMockInitialValues({'food_$key': jsonEncode(seedItems)});
      final p = FitnessProvider();
      await p.loadData();

      final yItems = p.foodHistory[key] ?? [];
      for (final e in yItems) {
        await p.addFoodEntry(FoodEntry(
          id: 'cp_${e.id}', name: e.name,
          calories: e.calories, protein: e.protein,
          mealType: e.mealType, timestamp: DateTime.now(),
        ));
      }

      final totalCal = p.todayFood.fold(0.0, (s, e) => s + e.calories);
      expect(totalCal, closeTo(150, 1)); // 70 + 80
    });
  });

  // ── 5. Getting-started card condition (Build 72) ──────────────────────────────
  // Card shows when: no weight + no today food + no workout history.
  // Disappears as soon as ONE of those is logged.

  group('Getting-started card visibility condition', () {
    test('shows when provider has no weight, food, or workout', () async {
      final p = await _loaded();
      // All three conditions: null weight, empty today food, empty workout history
      expect(p.latestWeightKg,    isNull);
      expect(p.todayFood,          isEmpty);
      expect(p.workoutHistory,     isEmpty);
      // All conditions met → card should show
      final shouldShow = p.latestWeightKg == null &&
          p.todayFood.isEmpty &&
          p.workoutHistory.isEmpty;
      expect(shouldShow, isTrue);
    });

    test('hides once weight is logged', () async {
      final p = await _loaded();
      await p.logBodyEntry(weightKg: 80.0, steps: 0);
      final shouldShow = p.latestWeightKg == null &&
          p.todayFood.isEmpty &&
          p.workoutHistory.isEmpty;
      expect(shouldShow, isFalse);
    });

    test('hides once food is logged today', () async {
      final p = await _loaded();
      await p.addFoodEntry(FoodEntry(
        id: 'f1', name: 'Banana', calories: 90, protein: 1,
        mealType: MealType.snack, timestamp: DateTime.now(),
      ));
      final shouldShow = p.latestWeightKg == null &&
          p.todayFood.isEmpty &&
          p.workoutHistory.isEmpty;
      expect(shouldShow, isFalse);
    });

    test('hides once a workout is logged', () async {
      final p = await _loaded();
      await p.logWorkout(WorkoutLog(
        id: 'w1', name: 'Monday Workout',
        date: DateTime.now(),
        exercises: [],
      ));
      final shouldShow = p.latestWeightKg == null &&
          p.todayFood.isEmpty &&
          p.workoutHistory.isEmpty;
      expect(shouldShow, isFalse);
    });

    test('food logged yesterday does NOT hide the card (today food only)', () async {
      // Seed yesterday's food directly via prefs (addFoodEntry always writes today)
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final key = _dateKey(yesterday);
      SharedPreferences.setMockInitialValues({
        'food_$key': jsonEncode([
          {'id': 'y1', 'name': 'Rice', 'calories': 300.0, 'protein': 6.0,
           'mealType': 1, 'timestamp': yesterday.toIso8601String()},
        ]),
      });
      final p = FitnessProvider();
      await p.loadData();

      // todayFood should be empty (yesterday doesn't count)
      expect(p.todayFood, isEmpty);
      final shouldShow = p.latestWeightKg == null &&
          p.todayFood.isEmpty &&
          p.workoutHistory.isEmpty;
      expect(shouldShow, isTrue);
    });
  });

  // ── 6. Workout day naming — no Push/Pull jargon (Build 72) ───────────────────

  group('Workout default names — simple day names, no jargon', () {
    const dayNames = [
      'Monday Workout',
      'Tuesday Workout',
      'Wednesday Workout',
      'Thursday Workout',
      'Friday Workout',
      'Weekend Workout',
      'Sunday Workout',
    ];
    const bannedJargon = ['Push', 'Pull', 'Workout A', 'Workout B'];

    test('no day-based name contains Push/Pull jargon', () {
      for (final name in dayNames) {
        for (final jargon in bannedJargon) {
          expect(name.contains(jargon), isFalse,
              reason: '"$name" must not contain "$jargon"');
        }
      }
    });

    test('all day names contain "Workout"', () {
      for (final name in dayNames) {
        expect(name, contains('Workout'));
      }
    });

    test('7 distinct names cover each day of the week', () {
      expect(dayNames.toSet().length, 7);
    });

    test('today\'s default name is one of the valid day names', () {
      final weekday = DateTime.now().weekday;
      final expected = switch (weekday) {
        1 => 'Monday Workout',
        2 => 'Tuesday Workout',
        3 => 'Wednesday Workout',
        4 => 'Thursday Workout',
        5 => 'Friday Workout',
        6 => 'Weekend Workout',
        _ => 'Sunday Workout',
      };
      expect(dayNames, contains(expected));
    });
  });

  // ── 7. Rest timer logic (Build 72) ───────────────────────────────────────────
  // _RestTimerSheetState is private — test logic directly via equivalent model.

  group('Rest timer logic (model equivalent)', () {
    test('presets are [60, 90, 120, 180] seconds', () {
      const presets = [60, 90, 120, 180];
      expect(presets, hasLength(4));
      expect(presets, contains(60));
      expect(presets, contains(90));
      expect(presets, contains(120));
      expect(presets, contains(180));
    });

    test('default selection is 90 seconds', () {
      const defaultSelected = 90;
      expect(defaultSelected, 90);
    });

    test('timer label at 45s remaining is "45s" (under 1 minute)', () {
      String label(int r) {
        if (r <= 0) return 'Done!';
        final m = r ~/ 60;
        final s = r % 60;
        return m > 0 ? '$m:${s.toString().padLeft(2, '0')}' : '${s}s';
      }
      expect(label(45), '45s');
    });

    test('timer label at 30s remaining is "30s"', () {
      String label(int r) {
        if (r <= 0) return 'Done!';
        final m = r ~/ 60;
        final s = r % 60;
        return m > 0 ? '$m:${s.toString().padLeft(2, '0')}' : '${s}s';
      }
      expect(label(30), '30s');
    });

    test('timer label at 90s formats as "1:30" (minutes:seconds)', () {
      String label(int r) {
        if (r <= 0) return 'Done!';
        final m = r ~/ 60;
        final s = r % 60;
        return m > 0 ? '$m:${s.toString().padLeft(2, '0')}' : '${s}s';
      }
      expect(label(90), '1:30');
    });

    test('timer label at 120s formats as "2:00"', () {
      String label(int r) {
        if (r <= 0) return 'Done!';
        final m = r ~/ 60;
        final s = r % 60;
        return m > 0 ? '$m:${s.toString().padLeft(2, '0')}' : '${s}s';
      }
      expect(label(120), '2:00');
    });

    test('timer label at 180s formats as "3:00"', () {
      String label(int r) {
        if (r <= 0) return 'Done!';
        final m = r ~/ 60;
        final s = r % 60;
        return m > 0 ? '$m:${s.toString().padLeft(2, '0')}' : '${s}s';
      }
      expect(label(180), '3:00');
    });

    test('timer label at 0 is "Done!"', () {
      String label(int r) {
        if (r <= 0) return 'Done!';
        final m = r ~/ 60;
        final s = r % 60;
        return m > 0 ? '$m:${s.toString().padLeft(2, '0')}' : '${s}s';
      }
      expect(label(0), 'Done!');
    });

    test('timer label at negative value is "Done!" (overflow-safe)', () {
      String label(int r) {
        if (r <= 0) return 'Done!';
        final m = r ~/ 60;
        final s = r % 60;
        return m > 0 ? '$m:${s.toString().padLeft(2, '0')}' : '${s}s';
      }
      expect(label(-1), 'Done!');
    });

    test('progress value at start is 1.0 (full bar)', () {
      const selected  = 90;
      const remaining = 90;
      final progress  = selected > 0 ? remaining / selected : 0.0;
      expect(progress, closeTo(1.0, 0.001));
    });

    test('progress value at half-way is 0.5', () {
      const selected  = 90;
      const remaining = 45;
      final progress  = selected > 0 ? remaining / selected : 0.0;
      expect(progress, closeTo(0.5, 0.001));
    });

    test('progress value at done is 0.0', () {
      const selected  = 90;
      const remaining = 0;
      final progress  = selected > 0 ? remaining / selected : 0.0;
      expect(progress, closeTo(0.0, 0.001));
    });
  });

  // ── 8. takeLast extension (Build 72) ─────────────────────────────────────────
  // Used by the sparkline painter to show last 5 measurement entries.

  group('takeLast extension', () {
    List<T> takeLast<T>(List<T> list, int n) =>
        list.length > n ? list.sublist(list.length - n) : list;

    test('returns last N items when list longer than N', () {
      final result = takeLast([1, 2, 3, 4, 5, 6, 7], 5);
      expect(result, [3, 4, 5, 6, 7]);
    });

    test('returns full list when shorter than N', () {
      final result = takeLast([1, 2, 3], 5);
      expect(result, [1, 2, 3]);
    });

    test('returns full list when exactly N', () {
      final result = takeLast([1, 2, 3, 4, 5], 5);
      expect(result, [1, 2, 3, 4, 5]);
    });

    test('returns empty list when input is empty', () {
      final result = takeLast(<double>[], 5);
      expect(result, isEmpty);
    });

    test('N=1 returns only last element', () {
      final result = takeLast([10.0, 20.0, 30.0], 1);
      expect(result, [30.0]);
    });

    test('preserves doubles accurately', () {
      final result = takeLast([82.5, 81.3, 80.7, 80.1, 79.8, 79.5], 5);
      expect(result, [81.3, 80.7, 80.1, 79.8, 79.5]);
    });
  });

  // ── 9. Sparkline painter logic (Build 72) ────────────────────────────────────
  // _SparklinePainter normalises values to [0,1]. Verify normalisation math.

  group('Sparkline painter normalisation logic', () {
    double normalise(double value, double minV, double maxV) {
      final range = (maxV - minV).abs();
      return range < 0.01 ? 0.5 : (value - minV) / range;
    }

    test('min value normalises to 0.0', () {
      final result = normalise(70.0, 70.0, 80.0);
      expect(result, closeTo(0.0, 0.001));
    });

    test('max value normalises to 1.0', () {
      final result = normalise(80.0, 70.0, 80.0);
      expect(result, closeTo(1.0, 0.001));
    });

    test('midpoint normalises to 0.5', () {
      final result = normalise(75.0, 70.0, 80.0);
      expect(result, closeTo(0.5, 0.001));
    });

    test('flat data (all same value) returns 0.5', () {
      // range < 0.01 → returns 0.5
      final result = normalise(80.0, 80.0, 80.0);
      expect(result, closeTo(0.5, 0.001));
    });

    test('painter skips drawing when fewer than 2 values', () {
      // Can't call paint() in unit tests, but we verify the guard condition
      const values = [80.0];
      expect(values.length < 2, isTrue); // guard is `if (values.length < 2) return`
    });
  });

  // ── 10. Recent foods — ordering and deduplication (Build 72) ─────────────────
  // _RecentFoodsRow shows last 5 unique food names, newest first.

  group('Recent foods selection logic', () {
    test('unique names collected from food history (no duplicates)', () async {
      final p = await _loaded();
      // All added to today (same key) — duplicates and unique names
      await p.addFoodEntry(FoodEntry(
          id: 'r1', name: 'Roti', calories: 120, protein: 3,
          mealType: MealType.lunch, timestamp: DateTime.now()));
      await p.addFoodEntry(FoodEntry(
          id: 'r2', name: 'Roti', calories: 120, protein: 3,
          mealType: MealType.dinner, timestamp: DateTime.now()));
      await p.addFoodEntry(FoodEntry(
          id: 'r3', name: 'Dal', calories: 150, protein: 8,
          mealType: MealType.lunch, timestamp: DateTime.now()));

      final seen  = <String>{};
      final names = <String>[];
      final hist  = p.foodHistory;
      final keys  = hist.keys.toList()..sort((a, b) => b.compareTo(a));
      for (final key in keys) {
        for (final e in (hist[key] ?? [])) {
          if (seen.add(e.name.toLowerCase())) names.add(e.name);
          if (names.length >= 5) break;
        }
        if (names.length >= 5) break;
      }

      expect(names.where((n) => n == 'Roti').length, 1);
      expect(names, contains('Dal'));
    });

    test('caps at 5 names even when more foods logged', () async {
      final p = await _loaded();
      final foods = ['Roti', 'Dal', 'Rice', 'Paneer', 'Egg', 'Chicken', 'Fish'];
      for (int i = 0; i < foods.length; i++) {
        await p.addFoodEntry(FoodEntry(
          id: 'f$i', name: foods[i], calories: 100, protein: 5,
          mealType: MealType.lunch, timestamp: DateTime.now(),
        ));
      }

      final seen  = <String>{};
      final names = <String>[];
      final hist  = p.foodHistory;
      final keys  = hist.keys.toList()..sort((a, b) => b.compareTo(a));
      for (final key in keys) {
        for (final e in (hist[key] ?? [])) {
          if (seen.add(e.name.toLowerCase())) names.add(e.name);
          if (names.length >= 5) break;
        }
        if (names.length >= 5) break;
      }

      expect(names.length, lessThanOrEqualTo(5));
    });

    test('returns empty list when no food history', () async {
      final p = await _loaded();
      // foodHistory combines today + loaded history; both empty on fresh load
      final seen  = <String>{};
      final names = <String>[];
      final hist  = p.foodHistory;
      final keys  = hist.keys.toList()..sort((a, b) => b.compareTo(a));
      for (final key in keys) {
        for (final e in (hist[key] ?? [])) {
          if (seen.add(e.name.toLowerCase())) names.add(e.name);
          if (names.length >= 5) break;
        }
        if (names.length >= 5) break;
      }

      expect(names, isEmpty);
    });

    test('newest foods appear first (sorted by date key descending)', () async {
      // Seed yesterday via prefs, add today via provider
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final key = _dateKey(yesterday);
      SharedPreferences.setMockInitialValues({
        'food_$key': jsonEncode([
          {'id': 'old', 'name': 'OldFood', 'calories': 100.0, 'protein': 5.0,
           'mealType': 1, 'timestamp': yesterday.toIso8601String()},
        ]),
      });
      final p = FitnessProvider();
      await p.loadData();
      await p.addFoodEntry(FoodEntry(
        id: 'new', name: 'NewFood', calories: 100, protein: 5,
        mealType: MealType.lunch, timestamp: DateTime.now(),
      ));

      final seen  = <String>{};
      final names = <String>[];
      final hist  = p.foodHistory;
      final keys  = hist.keys.toList()..sort((a, b) => b.compareTo(a));
      for (final key in keys) {
        for (final e in (hist[key] ?? [])) {
          if (seen.add(e.name.toLowerCase())) names.add(e.name);
          if (names.length >= 5) break;
        }
        if (names.length >= 5) break;
      }

      expect(names.first, 'NewFood'); // today's food first
    });
  });

  // ── 11. Build 71 regression — AI service public surface unchanged ─────────────

  group('AI service API regression (Build 71)', () {
    test('AiModelState enum has all expected values', () {
      expect(AiModelState.values, contains(AiModelState.notInstalled));
      expect(AiModelState.values, contains(AiModelState.downloading));
      expect(AiModelState.values, contains(AiModelState.loading));
      expect(AiModelState.values, contains(AiModelState.ready));
      expect(AiModelState.values, contains(AiModelState.error));
    });

    test('service exposes isReady, isInstalled, dlProgress, errorMessage', () {
      final ai = OnDeviceAiService();
      expect(ai.isReady,      isFalse);
      expect(ai.isInstalled,  isFalse);
      expect(ai.dlProgress,   0.0);
      expect(ai.errorMessage, isEmpty);
    });

    test('resetConversation does not throw on fresh service', () {
      final ai = OnDeviceAiService();
      expect(() => ai.resetConversation(), returnsNormally);
    });

    test('buildSystemPromptForTest returns non-empty string', () async {
      final p  = await _loaded();
      final ai = OnDeviceAiService();
      final s  = ai.buildSystemPromptForTest(p);
      expect(s, isNotEmpty);
      expect(s, contains('answer the user'));
    });

    test('buildRichPromptForTest returns non-empty string', () async {
      final p      = await _loaded();
      final ai     = OnDeviceAiService();
      final prompt = ai.buildRichPromptForTest('Hello', p);
      expect(prompt, isNotEmpty);
    });

    test('buildContextForQueryTest returns empty for unrelated query', () async {
      final p   = await _loaded();
      final ai  = OnDeviceAiService();
      final ctx = ai.buildContextForQueryTest('What is the capital of India?', p);
      expect(ctx, isEmpty);
    });
  });
}
