import 'package:flutter_test/flutter_test.dart';
import 'package:karthik_fitness/models/models.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

SmartScaleEntry _makeScale({
  double weight = 75.0,
  double bodyFat = 20.0,
  double muscle = 35.0,
  double bmr = 1800.0,
}) =>
    SmartScaleEntry(
      id: 'scale-1',
      date: DateTime(2024, 6, 1),
      weightKg: weight,
      bodyFatPercent: bodyFat,
      bodyFatKg: weight * bodyFat / 100,
      muscleMassKg: muscle,
      muscleMassPercent: muscle / weight * 100,
      leanBodyMassKg: weight * (1 - bodyFat / 100),
      biologicalAge: 22,
      visceralFatIndex: 5,
      bmr: bmr,
      bodyWaterPercent: 55.0,
      boneMassKg: 3.2,
      proteinPercent: 18.0,
      skeletalMuscleMassKg: muscle * 0.8,
    );

// ─── FoodEntry ────────────────────────────────────────────────────────────────

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
      final restored = FoodEntry.fromJson(entry.toJson());
      expect(restored.id, entry.id);
      expect(restored.name, entry.name);
      expect(restored.calories, entry.calories);
      expect(restored.protein, entry.protein);
      expect(restored.mealType, entry.mealType);
      expect(restored.servingNote, entry.servingNote);
    });

    test('preserves all MealType values', () {
      for (final type in MealType.values) {
        final entry = FoodEntry(
          id: 'x', name: 'Food', calories: 100, protein: 5,
          mealType: type, timestamp: DateTime.now(),
        );
        expect(FoodEntry.fromJson(entry.toJson()).mealType, type);
      }
    });

    test('missing servingNote defaults to empty string', () {
      final json = {
        'id': 'x', 'name': 'Rice', 'calories': 130.0, 'protein': 2.7,
        'mealType': 0, 'timestamp': DateTime.now().toIso8601String(),
        // no 'servingNote'
      };
      expect(FoodEntry.fromJson(json).servingNote, '');
    });
  });

// ─── SetData & ExerciseLog ────────────────────────────────────────────────────

  group('SetData', () {
    test('roundtrips correctly', () {
      final s = SetData(reps: 12, weight: 60.5);
      final r = SetData.fromJson(s.toJson());
      expect(r.reps, 12);
      expect(r.weight, 60.5);
    });

    test('handles integer weight from JSON', () {
      final s = SetData.fromJson({'reps': 10, 'weight': 80});
      expect(s.weight, 80.0);
    });
  });

  group('ExerciseLog', () {
    test('roundtrips with multiple sets', () {
      final log = ExerciseLog(name: 'Bench Press', sets: [
        SetData(reps: 10, weight: 60.0),
        SetData(reps: 8, weight: 65.0),
        SetData(reps: 6, weight: 70.0),
      ]);
      final r = ExerciseLog.fromJson(log.toJson());
      expect(r.name, 'Bench Press');
      expect(r.sets.length, 3);
      expect(r.sets[2].weight, 70.0);
    });

    test('handles empty sets list', () {
      final log = ExerciseLog(name: 'Plank', sets: []);
      expect(ExerciseLog.fromJson(log.toJson()).sets, isEmpty);
    });
  });

// ─── WorkoutLog ───────────────────────────────────────────────────────────────

  group('WorkoutLog', () {
    test('serialises and deserialises with name', () {
      final log = WorkoutLog(
        id: 'w1', date: DateTime(2024, 1, 15),
        name: 'Workout A — Push',
        exercises: [
          ExerciseLog(name: 'Push-ups', sets: [SetData(reps: 15, weight: 0)]),
        ],
      );
      final r = WorkoutLog.fromJson(log.toJson());
      expect(r.name, 'Workout A — Push');
      expect(r.exercises.length, 1);
    });

    test('backward compat: no name in JSON defaults to type name', () {
      final json = {
        'id': 'w2', 'date': DateTime(2024, 1, 15).toIso8601String(),
        'workoutType': 0, // WorkoutType.a
        'exercises': [], 'durationMinutes': 0, 'caloriesBurned': 0,
        // no 'name' key
      };
      final r = WorkoutLog.fromJson(json);
      expect(r.name, 'Workout A — Push');
    });

    test('backward compat: null workoutType defaults to custom', () {
      final json = {
        'id': 'w3', 'date': DateTime(2024, 1, 15).toIso8601String(),
        'workoutType': null, 'exercises': [],
        'durationMinutes': 0, 'caloriesBurned': 0,
      };
      final r = WorkoutLog.fromJson(json);
      expect(r.workoutType, WorkoutType.custom);
    });

    test('_nameForType for all WorkoutTypes', () {
      final a = WorkoutLog(id: '1', date: DateTime.now(), workoutType: WorkoutType.a, exercises: []);
      final b = WorkoutLog(id: '2', date: DateTime.now(), workoutType: WorkoutType.b, exercises: []);
      final c = WorkoutLog(id: '3', date: DateTime.now(), workoutType: WorkoutType.custom, exercises: []);
      expect(a.name, 'Workout A — Push');
      expect(b.name, 'Workout B — Pull');
      expect(c.name, 'Custom Workout');
    });

    test('explicit name overrides type name', () {
      final log = WorkoutLog(
        id: '1', date: DateTime.now(),
        workoutType: WorkoutType.a,
        name: 'My Custom Session',
        exercises: [],
      );
      expect(log.name, 'My Custom Session');
    });

    test('missing durationMinutes and caloriesBurned default to 0', () {
      final json = {
        'id': 'w4', 'date': DateTime.now().toIso8601String(),
        'workoutType': 2, 'exercises': [],
        // no durationMinutes, no caloriesBurned
      };
      final r = WorkoutLog.fromJson(json);
      expect(r.durationMinutes, 0);
      expect(r.caloriesBurned, 0);
    });
  });

// ─── BodyEntry ────────────────────────────────────────────────────────────────

  group('BodyEntry', () {
    test('roundtrips correctly', () {
      final entry = BodyEntry(id: 'b1', date: DateTime(2024, 1, 15), weightKg: 78.5, steps: 6500);
      final r = BodyEntry.fromJson(entry.toJson());
      expect(r.weightKg, 78.5);
      expect(r.steps, 6500);
    });

    test('missing steps defaults to 0', () {
      final json = {'id': 'b2', 'date': DateTime.now().toIso8601String(), 'weightKg': 70.0};
      expect(BodyEntry.fromJson(json).steps, 0);
    });
  });

// ─── SupplementStatus ─────────────────────────────────────────────────────────

  group('SupplementStatus', () {
    test('roundtrips correctly', () {
      final s = SupplementStatus(whey: true, creatine: true, multivitamin: false);
      final r = SupplementStatus.fromJson(s.toJson());
      expect(r.whey, true);
      expect(r.creatine, true);
      expect(r.multivitamin, false);
    });

    test('takenCount for all combinations', () {
      expect(SupplementStatus().takenCount, 0);
      expect(SupplementStatus(whey: true).takenCount, 1);
      expect(SupplementStatus(whey: true, creatine: true).takenCount, 2);
      expect(SupplementStatus(whey: true, creatine: true, multivitamin: true).takenCount, 3);
    });

    test('missing keys in JSON default to false', () {
      final s = SupplementStatus.fromJson({});
      expect(s.whey, false);
      expect(s.creatine, false);
      expect(s.multivitamin, false);
    });
  });

// ─── SmartScaleEntry ─────────────────────────────────────────────────────────

  group('SmartScaleEntry', () {
    test('serialises and deserialises correctly', () {
      final entry = _makeScale(weight: 78.5, bodyFat: 22.0, muscle: 36.0, bmr: 1850.0);
      final r = SmartScaleEntry.fromJson(entry.toJson());
      expect(r.weightKg, 78.5);
      expect(r.bodyFatPercent, 22.0);
      expect(r.muscleMassKg, 36.0);
      expect(r.bmr, 1850.0);
      expect(r.biologicalAge, 22);
    });

    test('missing JSON fields default to 0', () {
      final r = SmartScaleEntry.fromJson({'id': 'x', 'date': DateTime.now().toIso8601String()});
      expect(r.weightKg, 0.0);
      expect(r.bodyFatPercent, 0.0);
      expect(r.bmr, 0.0);
      expect(r.biologicalAge, 0);
    });

    test('all fields roundtrip without loss', () {
      final entry = _makeScale();
      final r = SmartScaleEntry.fromJson(entry.toJson());
      expect(r.bodyFatKg, entry.bodyFatKg);
      expect(r.muscleMassPercent, entry.muscleMassPercent);
      expect(r.leanBodyMassKg, entry.leanBodyMassKg);
      expect(r.visceralFatIndex, entry.visceralFatIndex);
      expect(r.bodyWaterPercent, entry.bodyWaterPercent);
      expect(r.boneMassKg, entry.boneMassKg);
      expect(r.proteinPercent, entry.proteinPercent);
      expect(r.skeletalMuscleMassKg, entry.skeletalMuscleMassKg);
    });
  });

// ─── ExerciseDatabase ─────────────────────────────────────────────────────────

  group('ExerciseDatabase', () {
    test('allExercises is sorted alphabetically', () {
      final all = ExerciseDatabase.allExercises;
      for (int i = 0; i < all.length - 1; i++) {
        expect(all[i].compareTo(all[i + 1]), lessThanOrEqualTo(0),
            reason: '${all[i]} should come before ${all[i + 1]}');
      }
    });

    test('allExercises contains exercises from all categories', () {
      final all = ExerciseDatabase.allExercises.toSet();
      for (final exercises in ExerciseDatabase.categories.values) {
        for (final ex in exercises) {
          expect(all, contains(ex), reason: '$ex missing from allExercises');
        }
      }
    });

    test('emojiFor known exercise returns specific emoji', () {
      expect(ExerciseDatabase.emojiFor('Push-ups'), '💪');
      expect(ExerciseDatabase.emojiFor('Deadlift'), '💀');
      expect(ExerciseDatabase.emojiFor('Running'), '🏃');
      expect(ExerciseDatabase.emojiFor('Squats'), '🦵');
    });

    test('emojiFor unknown exercise returns fallback', () {
      expect(ExerciseDatabase.emojiFor('Unknown Exercise 123'), '🏋️');
      expect(ExerciseDatabase.emojiFor(''), '🏋️');
    });

    test('categoryOf returns correct category for known exercise', () {
      expect(ExerciseDatabase.categoryOf('Push-ups'), 'Chest');
      expect(ExerciseDatabase.categoryOf('Running'), 'Cardio');
      expect(ExerciseDatabase.categoryOf('Squats'), 'Legs');
      expect(ExerciseDatabase.categoryOf('Deadlift'), 'Full Body / Compound');
    });

    test('categoryOf returns null for unknown exercise', () {
      expect(ExerciseDatabase.categoryOf('Flying Through Air'), isNull);
    });

    test('progressiveOverloadTip when reps met, weighted', () {
      final tip = ExerciseDatabase.progressiveOverloadTip('Bench Press', 3, 10, 60.0, 10);
      expect(tip, contains('62.5 kg'));
    });

    test('progressiveOverloadTip when reps met, bodyweight', () {
      final tip = ExerciseDatabase.progressiveOverloadTip('Push-ups', 3, 15, 0.0, 15);
      expect(tip, contains('Add 1 more rep'));
    });

    test('progressiveOverloadTip when 1-2 reps short', () {
      final tip = ExerciseDatabase.progressiveOverloadTip('Squats', 3, 9, 80.0, 10);
      expect(tip, contains('Stick with'));
    });

    test('progressiveOverloadTip when significantly short', () {
      final tip = ExerciseDatabase.progressiveOverloadTip('Deadlift', 3, 5, 100.0, 10);
      expect(tip, contains('form'));
    });
  });

// ─── Food Database ────────────────────────────────────────────────────────────

  group('FoodDatabase', () {
    test('has entries in all required categories', () {
      final categories = kFoodDatabase.map((f) => f.category).toSet();
      for (final cat in kFoodCategories) {
        expect(categories, contains(cat), reason: 'Category "$cat" has no foods');
      }
    });

    test('all food items have non-empty name and emoji', () {
      for (final food in kFoodDatabase) {
        expect(food.name, isNotEmpty, reason: 'Empty name found');
        expect(food.emoji, isNotEmpty, reason: '${food.name} has empty emoji');
      }
    });

    test('all food items except Creatine have positive calories', () {
      for (final food in kFoodDatabase) {
        if (food.name == 'Creatine') continue;
        expect(food.calories, greaterThan(0), reason: '${food.name} has zero/negative calories');
      }
    });

    test('all food items have non-negative protein', () {
      for (final food in kFoodDatabase) {
        expect(food.protein, greaterThanOrEqualTo(0),
            reason: '${food.name} has negative protein');
      }
    });

    test('has meaningful number of food entries', () {
      expect(kFoodDatabase.length, greaterThan(50));
    });

    test('Supplement category contains whey and creatine', () {
      final supps = kFoodDatabase.where((f) => f.category == 'Supplement').map((f) => f.name).toList();
      expect(supps.any((n) => n.toLowerCase().contains('whey')), isTrue);
      expect(supps.any((n) => n.toLowerCase().contains('creatine')), isTrue);
    });
  });

// ─── estimateCaloriesBurned ───────────────────────────────────────────────────

  group('estimateCaloriesBurned', () {
    test('MET=5, 60min, 75kg = 375 kcal', () {
      expect(estimateCaloriesBurned(75.0, 60), 375);
    });

    test('MET=5, 30min, 80kg = 200 kcal', () {
      expect(estimateCaloriesBurned(80.0, 30), 200);
    });

    test('zero duration = 0 kcal', () {
      expect(estimateCaloriesBurned(70.0, 0), 0);
    });
  });

  // ─── MeasurementEntry ────────────────────────────────────────────────────────
  group('MeasurementEntry', () {
    test('serialises and deserialises all fields', () {
      final e = MeasurementEntry(
        id: 'm1', date: DateTime(2026, 5, 30),
        chestCm: 95.0, waistCm: 82.0, hipsCm: 98.0,
        leftArmCm: 34.0, leftThighCm: 55.0,
      );
      final r = MeasurementEntry.fromJson(e.toJson());
      expect(r.chestCm, 95.0);
      expect(r.waistCm, 82.0);
      expect(r.hipsCm, 98.0);
      expect(r.leftArmCm, 34.0);
      expect(r.leftThighCm, 55.0);
    });

    test('nullable fields round-trip as null', () {
      final e = MeasurementEntry(id: 'm2', date: DateTime(2026, 5, 30), waistCm: 80.0);
      final r = MeasurementEntry.fromJson(e.toJson());
      expect(r.chestCm, isNull);
      expect(r.waistCm, 80.0);
      expect(r.hipsCm, isNull);
    });

    test('isEmpty true when no fields set', () {
      expect(MeasurementEntry(id: 'x', date: DateTime.now()).isEmpty, isTrue);
    });

    test('isEmpty false when at least one field set', () {
      expect(MeasurementEntry(id: 'x', date: DateTime.now(), waistCm: 80.0).isEmpty, isFalse);
    });
  });

  // ─── AppNotification ─────────────────────────────────────────────────────────
  group('AppNotification', () {
    test('serialises and deserialises all fields', () {
      final n = AppNotification(
        id: 'n1', emoji: '🎯', title: 'Goal hit', body: 'Nice work',
        accent: 0xFF30D158, category: 'milestone',
        timestamp: DateTime(2026, 5, 31, 12), read: true,
      );
      final r = AppNotification.fromJson(n.toJson());
      expect(r.id, 'n1');
      expect(r.emoji, '🎯');
      expect(r.title, 'Goal hit');
      expect(r.accent, 0xFF30D158);
      expect(r.category, 'milestone');
      expect(r.read, isTrue);
    });

    test('defaults read to false and accent fallback', () {
      final r = AppNotification.fromJson({
        'id': 'x', 'title': 't', 'body': 'b',
        'timestamp': DateTime.now().toIso8601String(),
      });
      expect(r.read, isFalse);
      expect(r.emoji, '🔔');
      expect(r.accent, 0xFF30D158);
    });
  });
}
