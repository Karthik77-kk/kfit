// UX polish — accessibility (Semantics) regression tests.
//
// Screen-reader users get nothing from a CustomPainter ring or a PieChart
// donut on their own. These verify the descriptive Semantics labels wrapping
// the Home activity rings, macro donut, and streak badge are present and carry
// the live values, so TalkBack/VoiceOver can announce progress.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kfit/models/models.dart';
import 'package:kfit/providers/fitness_provider.dart';
import 'package:kfit/services/on_device_ai_service.dart';
import 'package:kfit/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Seeds a provider with today's food + a workout streak so the rings, macro
  /// donut, and streak badge all render with real values.
  Future<FitnessProvider> seeded() async {
    final now = DateTime.now();
    final prefs = <String, Object>{
      'onboarding_done': true,
      'user_name': 'Test',
      'ai_coach_enabled': false, // keep the tree small
      'calorie_goal': 2000,
      'protein_goal': 120,
      'water_goal_ml': 2500,
      'water_${key(now)}': 1000,
      'food_${key(now)}': jsonEncode([
        FoodEntry(
          id: 'f1', name: 'Dal', calories: 600, protein: 30, carbs: 60, fat: 15,
          mealType: MealType.lunch, timestamp: now,
        ).toJson(),
      ]),
    };
    // A 3-day workout streak (today + yesterday + 2 days ago).
    final workouts = <Map<String, dynamic>>[];
    for (var i = 0; i < 3; i++) {
      workouts.add(WorkoutLog(
        id: 'w$i', date: now.subtract(Duration(days: i)),
        workoutType: WorkoutType.a,
        exercises: [
          ExerciseLog(name: 'Squats', sets: [SetData(reps: 8, weight: 80)]),
        ],
      ).toJson());
    }
    prefs['workouts'] = jsonEncode(workouts);
    SharedPreferences.setMockInitialValues(prefs);
    final p = FitnessProvider();
    await p.loadData();
    return p;
  }

  Future<void> pump(WidgetTester tester, FitnessProvider p) async {
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));

    final ai = OnDeviceAiService();
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<FitnessProvider>(create: (_) => p, lazy: false),
        ChangeNotifierProvider<OnDeviceAiService>(create: (_) => ai, lazy: false),
      ],
      child: const MaterialApp(home: HomeScreen()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('activity rings expose a labelled Semantics node', (tester) async {
    final p = await seeded();
    await pump(tester, p);
    // calorie 600/2000 = 30%, protein 30/120 = 25%, water 1000/2500 = 40%.
    final label = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .map((s) => s.properties.label ?? '')
        .firstWhere((l) => l.contains('Activity rings'), orElse: () => '');
    expect(label, contains('calories 30 percent'));
    expect(label, contains('protein 25 percent'));
    expect(label, contains('water 40 percent'));
  });

  testWidgets('macro donut exposes a labelled Semantics node', (tester) async {
    final p = await seeded();
    await pump(tester, p);
    final label = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .map((s) => s.properties.label ?? '')
        .firstWhere((l) => l.startsWith('Macros'), orElse: () => '');
    expect(label, isNotEmpty);
    expect(label, contains('protein 30 grams'));
    expect(label, contains('carbs 60 grams'));
    expect(label, contains('fat 15 grams'));
  });

  testWidgets('streak badge announces the streak length', (tester) async {
    final p = await seeded();
    await pump(tester, p);
    expect(p.workoutStreak, greaterThanOrEqualTo(3));
    final labels = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .map((s) => s.properties.label ?? '');
    expect(labels.any((l) => l.contains('workout streak')), isTrue);
  });
}
