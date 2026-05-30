import 'package:flutter_test/flutter_test.dart';
import 'package:karthik_fitness/models/models.dart';

void main() {
  group('FoodEntry', () {
    test('serialises and deserialises correctly', () {
      final entry = FoodEntry(
        id: 'test-id',
        name: 'Boiled Egg',
        calories: 78,
        protein: 6,
        mealType: MealType.breakfast,
        timestamp: DateTime(2024, 1, 15, 8, 0),
        servingNote: '1 egg',
      );

      final json = entry.toJson();
      final restored = FoodEntry.fromJson(json);

      expect(restored.id, entry.id);
      expect(restored.name, entry.name);
      expect(restored.calories, entry.calories);
      expect(restored.protein, entry.protein);
      expect(restored.mealType, entry.mealType);
      expect(restored.servingNote, entry.servingNote);
    });
  });

  group('WorkoutLog', () {
    test('serialises and deserialises correctly', () {
      final log = WorkoutLog(
        id: 'w1',
        date: DateTime(2024, 1, 15),
        workoutType: WorkoutType.a,
        exercises: [
          ExerciseLog(name: 'Push-ups', sets: [
            SetData(reps: 15, weight: 0),
            SetData(reps: 12, weight: 0),
          ]),
        ],
        durationMinutes: 45,
        caloriesBurned: 250,
      );

      final json = log.toJson();
      final restored = WorkoutLog.fromJson(json);

      expect(restored.id, log.id);
      expect(restored.workoutType, log.workoutType);
      expect(restored.durationMinutes, log.durationMinutes);
      expect(restored.caloriesBurned, log.caloriesBurned);
      expect(restored.exercises.length, 1);
      expect(restored.exercises.first.sets.length, 2);
    });
  });

  group('BodyEntry', () {
    test('serialises and deserialises correctly', () {
      final entry = BodyEntry(
        id: 'b1',
        date: DateTime(2024, 1, 15),
        weightKg: 78.5,
        steps: 6500,
      );

      final json = entry.toJson();
      final restored = BodyEntry.fromJson(json);

      expect(restored.weightKg, entry.weightKg);
      expect(restored.steps, entry.steps);
    });
  });

  group('SupplementStatus', () {
    test('serialises and deserialises', () {
      final s = SupplementStatus(whey: true, creatine: true, multivitamin: false);
      final restored = SupplementStatus.fromJson(s.toJson());
      expect(restored.whey, true);
      expect(restored.creatine, true);
      expect(restored.multivitamin, false);
      expect(restored.takenCount, 2);
    });

    test('takenCount reflects checked supplements', () {
      expect(SupplementStatus().takenCount, 0);
      expect(SupplementStatus(whey: true, creatine: true, multivitamin: true).takenCount, 3);
    });
  });

  group('estimateCaloriesBurned', () {
    test('calculates MET-based calories correctly', () {
      // MET 5 * 75kg * 60min / 60 = 375 kcal
      expect(estimateCaloriesBurned(75.0, 60), 375);
      // MET 5 * 80kg * 45min / 60 = 300 kcal
      expect(estimateCaloriesBurned(80.0, 45), 300);
    });
  });

  group('FoodDatabase', () {
    test('has entries in all required categories', () {
      final categories = kFoodDatabase.map((f) => f.category).toSet();
      for (final cat in kFoodCategories) {
        expect(categories, contains(cat), reason: 'Category "$cat" has no foods');
      }
    });

    test('all food items have positive calories', () {
      for (final food in kFoodDatabase) {
        if (food.name != 'Creatine') {
          expect(food.calories, greaterThan(0), reason: '${food.name} has zero calories');
        }
      }
    });

    test('all food items have non-empty name and emoji', () {
      for (final food in kFoodDatabase) {
        expect(food.name, isNotEmpty);
        expect(food.emoji, isNotEmpty);
      }
    });
  });
}
