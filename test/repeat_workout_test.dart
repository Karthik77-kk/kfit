import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kfit/models/models.dart';
import 'package:kfit/providers/fitness_provider.dart';
import 'package:kfit/screens/workout_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "Repeat today's workout" — re-log today's session by deep-copying its
/// exercises into the in-progress builder, then Save creates a NEW WorkoutLog
/// without ever mutating the original logged history.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  WorkoutLog log(String id, List<ExerciseLog> ex, {DateTime? date}) =>
      WorkoutLog(id: id, date: date ?? DateTime.now(), exercises: ex);

  group('repeatExercises (pure helper)', () {
    test('deep-copies sets — value-equal but distinct instances', () {
      final source = ExerciseLog(name: 'Bench Press', sets: [
        SetData(reps: 5, weight: 60),
        SetData(reps: 5, weight: 62.5),
      ]);
      final out = repeatExercises([log('w1', [source])], []);

      expect(out.length, 1);
      final copy = out.first;
      expect(copy.name, 'Bench Press');
      expect(copy.sets.map((s) => (s.reps, s.weight)).toList(),
          source.sets.map((s) => (s.reps, s.weight)).toList());
      // Distinct instances — the list AND every SetData inside it.
      expect(identical(copy.sets, source.sets), isFalse);
      for (var i = 0; i < copy.sets.length; i++) {
        expect(identical(copy.sets[i], source.sets[i]), isFalse);
      }
    });

    test('editing the copy never mutates the logged history', () {
      final source = ExerciseLog(
          name: 'Squats', sets: [SetData(reps: 8, weight: 80)]);
      final history = log('w1', [source]);
      final out = repeatExercises([history], []);
      // Grow the copied set list (mirrors the builder gaining sets).
      out.first.sets.add(SetData(reps: 8, weight: 85));
      expect(out.first.sets.length, 2);
      expect(history.exercises.first.sets.length, 1); // untouched
      expect(source.sets.length, 1);
    });

    test('de-dupes by name across sessions — first occurrence wins', () {
      final out = repeatExercises([
        log('w1', [
          ExerciseLog(name: 'Push-ups', sets: [SetData(reps: 10, weight: 0)])
        ]),
        log('w2', [
          ExerciseLog(name: 'Push-ups', sets: [SetData(reps: 12, weight: 0)]),
          ExerciseLog(name: 'Pull-ups', sets: [SetData(reps: 8, weight: 0)]),
        ]),
      ], []);
      expect(out.map((e) => e.name).toList(), ['Push-ups', 'Pull-ups']);
      expect(out.first.sets.first.reps, 10); // kept first session's value
    });

    test('skips names already present in the builder', () {
      final existing = [
        ExerciseLog(name: 'Squats', sets: [SetData(reps: 5, weight: 100)])
      ];
      final out = repeatExercises([
        log('w1', [
          ExerciseLog(name: 'Squats', sets: [SetData(reps: 8, weight: 80)]),
          ExerciseLog(name: 'Lunges', sets: [SetData(reps: 10, weight: 20)]),
        ]),
      ], existing);
      expect(out.map((e) => e.name).toList(), ['Lunges']);
    });

    test('cardio minutes (stored in reps) copy through unchanged', () {
      final out = repeatExercises([
        log('w1', [
          ExerciseLog(name: 'Running', sets: [SetData(reps: 25, weight: 0)])
        ]),
      ], []);
      expect(out.first.sets.first.reps, 25);
      expect(out.first.sets.first.weight, 0);
    });

    test('empty when there is nothing new to add', () {
      expect(repeatExercises([], []), isEmpty);
      final existing = [
        ExerciseLog(name: 'Plank', sets: [SetData(reps: 60, weight: 0)])
      ];
      expect(repeatExercises([log('w1', [existing.first])], existing), isEmpty);
    });
  });

  group('Repeat button (WorkoutScreen)', () {
    Future<FitnessProvider> makeProvider({bool withWorkout = false}) async {
      SharedPreferences.setMockInitialValues({'onboarding_done': true});
      final p = FitnessProvider();
      await p.loadData();
      if (withWorkout) {
        await p.logWorkout(log('seed', [
          ExerciseLog(name: 'Bench Press', sets: [SetData(reps: 5, weight: 60)]),
          ExerciseLog(name: 'Squats', sets: [SetData(reps: 8, weight: 80)]),
        ]));
      }
      return p;
    }

    Future<void> pump(WidgetTester tester, FitnessProvider p) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      // Unmount at teardown so the provider day-reset timer + any snackbar
      // dismissal timer are cancelled before the pending-timer check.
      addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
      await tester.pumpWidget(ChangeNotifierProvider<FitnessProvider>(
        create: (_) => p,
        lazy: false,
        child: const MaterialApp(home: WorkoutScreen()),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('hidden when no workout was logged today', (tester) async {
      await pump(tester, await makeProvider());
      expect(find.text('Repeat'), findsNothing);
    });

    testWidgets('fills the builder; Save logs a NEW session, original intact',
        (tester) async {
      final p = await makeProvider(withWorkout: true);
      await pump(tester, p);

      expect(find.text('Repeat'), findsOneWidget);
      expect(p.todayWorkouts.length, 1);

      await tester.tap(find.text('Repeat'));
      await tester.pumpAndSettle();

      // Builder is now populated.
      expect(find.text('Current Session'), findsOneWidget);
      final save = find.widgetWithText(ElevatedButton, 'Save Workout');
      expect(save, findsOneWidget);

      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      // Second WorkoutLog now exists; the seeded original is unchanged.
      expect(p.todayWorkouts.length, 2);
      final original = p.todayWorkouts.firstWhere((w) => w.id == 'seed');
      expect(original.exercises.length, 2);
      expect(original.exercises.first.sets.first.weight, 60);
    });

    testWidgets('appends only exercises not already in the builder',
        (tester) async {
      final p = await makeProvider(withWorkout: true);
      await pump(tester, p);

      // Two taps — the second adds nothing (all names already in the builder).
      await tester.tap(find.text('Repeat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Repeat'));
      await tester.pumpAndSettle();

      final save = find.widgetWithText(ElevatedButton, 'Save Workout');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      final newLog = p.todayWorkouts.firstWhere((w) => w.id != 'seed');
      expect(newLog.exercises.length, 2); // de-duped, not 4
    });
  });
}
