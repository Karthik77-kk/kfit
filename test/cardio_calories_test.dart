// Build 100 — cardio is logged by DURATION (minutes), not sets×reps.
// Verifies calculateWorkoutCalories uses MET × bodyweight × minutes for cardio,
// and leaves the rep-weighted model for strength exercises.
import 'package:flutter_test/flutter_test.dart';
import 'package:kfit/models/models.dart';
import 'package:kfit/providers/fitness_provider.dart';

WorkoutLog _wo(String exName, List<SetData> sets) => WorkoutLog(
      id: 'w', date: DateTime.now(), workoutType: WorkoutType.custom,
      exercises: [ExerciseLog(name: exName, sets: sets)],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ExerciseDatabase.isCardio', () {
    test('cardio exercises are cardio', () {
      for (final e in ['Running', 'Cycling', 'Swimming', 'Jump Rope', 'HIIT']) {
        expect(ExerciseDatabase.isCardio(e), isTrue, reason: e);
      }
    });
    test('strength exercises are not cardio', () {
      for (final e in ['Bench Press', 'Squats', 'Push-ups', 'Deadlift']) {
        expect(ExerciseDatabase.isCardio(e), isFalse, reason: e);
      }
    });
  });

  group('calculateWorkoutCalories — cardio uses minutes', () {
    // No weight logged -> calculateWorkoutCalories falls back to 70 kg.
    final p = FitnessProvider();

    test('30 min Running = MET 9.8 × 70kg × 0.5h = 343', () {
      final cals = p.calculateWorkoutCalories(
          _wo('Running', [SetData(reps: 30, weight: 0)]));
      expect(cals, 343);
    });

    test('60 min Cycling = MET 8.0 × 70 × 1h = 560', () {
      final cals = p.calculateWorkoutCalories(
          _wo('Cycling', [SetData(reps: 60, weight: 0)]));
      expect(cals, 560);
    });

    test('cardio with 0 minutes burns 0 (no phantom calories)', () {
      final cals = p.calculateWorkoutCalories(
          _wo('Running', [SetData(reps: 0, weight: 0)]));
      expect(cals, 0);
    });

    test('strength still uses the rep-weighted model, not minutes', () {
      // Bench Press 3×10 must NOT be read as 30 minutes of activity.
      final cals = p.calculateWorkoutCalories(_wo('Bench Press', [
        SetData(reps: 10, weight: 60),
        SetData(reps: 10, weight: 60),
        SetData(reps: 10, weight: 60),
      ]));
      expect(cals, greaterThan(0));
      expect(cals, lessThan(100)); // sanity: nowhere near a 30-min cardio burn
    });
  });
}
