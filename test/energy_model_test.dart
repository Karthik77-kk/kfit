// Build 106 — unified dynamic energy model (componentTdee).
// Maintenance = resting BMR + logged walking + logged workouts, floored at the
// sedentary BMR×1.2 so idle users match the old formula (no competing number),
// and rising dynamically with real activity.
import 'package:flutter_test/flutter_test.dart';
import 'package:kfit/models/models.dart';
import 'package:kfit/providers/fitness_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<FitnessProvider> seeded({int steps = 0}) async {
    final p = FitnessProvider();
    await p.loadData();
    await p.saveHeight(170);
    await p.saveAge(24);
    await p.logBodyEntry(weightKg: 75, steps: steps);
    return p;
  }

  group('componentTdee', () {
    test('null until body metrics exist', () async {
      final p = FitnessProvider();
      await p.loadData();
      expect(p.componentTdee, isNull);
    });

    test('idle → floors at BMR×1.2 and matches the formula TDEE (no double-count)',
        () async {
      final p = await seeded();
      expect(p.componentTdee, closeTo(p.bmr! * 1.2, 1.0));
      expect(p.bestTdee, closeTo(p.tdee!, 1.0));
    });

    test('lots of steps raises maintenance above the sedentary floor', () async {
      final p = await seeded(steps: 12000);
      final floor = p.bmr! * 1.2;
      expect(p.componentTdee, greaterThan(floor));
    });

    test('logging a workout adds to maintenance vs an identical idle profile',
        () async {
      final idle = await seeded(steps: 12000);
      final active = await seeded(steps: 12000);
      await active.logWorkout(WorkoutLog(
        id: 'w', date: DateTime.now(), workoutType: WorkoutType.custom,
        exercises: [
          ExerciseLog(name: 'Squats', sets: [
            SetData(reps: 8, weight: 80),
            SetData(reps: 8, weight: 80),
            SetData(reps: 8, weight: 80),
          ]),
        ],
      ));
      expect(active.componentTdee!, greaterThan(idle.componentTdee!));
    });

    test('bestTdee uses componentTdee when no calibrated trend yet', () async {
      final p = await seeded();
      expect(p.bestTdee, equals(p.componentTdee));
      expect(p.isTdeeCalibrated, isFalse);
    });
  });
}
