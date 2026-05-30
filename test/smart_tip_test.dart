import 'package:flutter_test/flutter_test.dart';
import 'package:karthik_fitness/models/models.dart';
import 'package:karthik_fitness/providers/fitness_provider.dart';
import 'package:karthik_fitness/services/smart_tip_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

FoodEntry _food(String id, double cal, double protein) => FoodEntry(
      id: id, name: 'Food $id', calories: cal, protein: protein,
      mealType: MealType.lunch, timestamp: DateTime.now(),
    );

DateTime _at(int hour) => DateTime(2024, 6, 1, hour, 0);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<FitnessProvider> freshProvider() async {
    final p = FitnessProvider();
    await p.loadData();
    return p;
  }

  group('selectSmartTip — always returns a valid tip', () {
    test('fresh provider returns non-empty tip', () async {
      final p = await freshProvider();
      final tip = selectSmartTip(p, _at(14));
      expect(tip.title, isNotEmpty);
      expect(tip.body, isNotEmpty);
      expect(tip.emoji, isNotEmpty);
      expect(tip.priority, inInclusiveRange(1, 99));
    });

    test('every hour of the day returns a valid tip (no null/crash)', () async {
      final p = await freshProvider();
      for (int h = 0; h < 24; h++) {
        final tip = selectSmartTip(p, _at(h));
        expect(tip.title, isNotEmpty, reason: 'hour $h gave empty title');
        expect(tip.body, isNotEmpty, reason: 'hour $h gave empty body');
      }
    });
  });

  group('selectSmartTip — P0 critical', () {
    test('over goal by 400+ shows surplus warning', () async {
      final p = await freshProvider();
      await p.addFoodEntry(_food('big', 2200, 50)); // > 1700 + 400
      final tip = selectSmartTip(p, _at(15));
      expect(tip.emoji, '🚨');
      expect(tip.priority, 2);
      expect(tip.title, contains('over goal'));
    });
  });

  group('selectSmartTip — P1 morning', () {
    test('morning (7 AM) with no food prompts breakfast', () async {
      final p = await freshProvider();
      final tip = selectSmartTip(p, _at(7));
      expect(tip.emoji, '🌅');
      expect(tip.priority, 3);
    });

    test('9–12 window with creatine not taken nudges creatine', () async {
      final p = await freshProvider();
      // give breakfast so the no-food morning branch is skipped
      await p.addFoodEntry(_food('b', 300, 12));
      final tip = selectSmartTip(p, _at(10));
      expect(tip.emoji, '⚡');
      expect(tip.title, contains('creatine'));
    });
  });

  group('selectSmartTip — P2 protein', () {
    test('afternoon with very low protein warns', () async {
      final p = await freshProvider();
      await p.updateSupplement('creatine', true); // skip creatine nudge
      await p.addFoodEntry(_food('rice', 800, 10)); // low protein
      final tip = selectSmartTip(p, _at(13));
      expect(tip.emoji, '💪');
      expect(tip.priority, 4);
      expect(tip.title, contains('Protein'));
    });
  });

  group('selectSmartTip — P3 hydration', () {
    test('no water logged after 9 AM prompts hydration', () async {
      final p = await freshProvider();
      await p.updateSupplement('creatine', true);
      await p.addFoodEntry(_food('meal', 600, 80)); // high protein, skip P2
      final tip = selectSmartTip(p, _at(11));
      expect(tip.emoji, '💧');
      expect(tip.title, contains('No water'));
    });
  });

  group('selectSmartTip — P4 workout window', () {
    test('4–8 PM with no workout, hydrated and fed, nudges workout', () async {
      final p = await freshProvider();
      await p.addFoodEntry(_food('meal', 900, 80)); // high protein
      await p.addWater(1200); // > 1000
      final tip = selectSmartTip(p, _at(17));
      expect(tip.emoji, '🏋️');
      expect(tip.priority, 8);
    });
  });

  group('selectSmartTip — P5 deficit', () {
    test('large deficit with good protein celebrates progress', () async {
      final p = await freshProvider();
      await p.addFoodEntry(_food('chicken', 1000, 90)); // deficit 700, protein high
      await p.addWater(1200);
      // hour 14 → not morning, not workout window, not evening
      final tip = selectSmartTip(p, _at(14));
      expect(tip.emoji, '🔥');
      expect(tip.priority, 15);
    });
  });

  group('selectSmartTip — priority ordering', () {
    test('over-goal (P0) beats low-protein (P2) when both true', () async {
      final p = await freshProvider();
      // 2200 kcal but only 10g protein — both "over goal" and "low protein" true
      await p.addFoodEntry(_food('feast', 2200, 10));
      final tip = selectSmartTip(p, _at(13));
      // P0 surplus (priority 2) must win over P2 protein (priority 4)
      expect(tip.priority, 2);
      expect(tip.emoji, '🚨');
    });
  });

  group('selectSmartTip — evening', () {
    test('9 PM with whey not taken suggests pre-sleep protein', () async {
      final p = await freshProvider();
      // satisfy: not over goal, protein ok, water ok, has workout, normal deficit
      await p.addFoodEntry(_food('dinner', 1500, 90));
      await p.addWater(2200);
      await p.logWorkout(WorkoutLog(
        id: 'w', date: DateTime.now(),
        exercises: [ExerciseLog(name: 'Push-ups', sets: [SetData(reps: 10, weight: 0)])],
      ));
      final tip = selectSmartTip(p, _at(21));
      // Either evening-log or pre-sleep-whey; both are valid evening nudges
      expect(['🌙', '🥛'], contains(tip.emoji));
    });
  });
}
