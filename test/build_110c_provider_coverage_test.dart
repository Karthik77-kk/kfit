import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kfit/models/models.dart';
import 'package:kfit/providers/fitness_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Build 110: provider-layer coverage — export/import round-trip (with a mocked
/// path_provider) and a broad sweep of analytics getters against seeded history.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock path_provider so exportAllData()'s getApplicationDocumentsDirectory works.
  final tmp = Directory.systemTemp.createTempSync('kfit_cov');
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tmp.path,
    );
  });

  String key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<FitnessProvider> seeded() async {
    final now = DateTime.now();
    final prefs = <String, Object>{
      'onboarding_done': true, 'user_name': 'Sam', 'height_cm': 175.0,
      'age': 29, 'is_male': true, 'goal_weight_kg': 72.0,
    };
    final body = <Map<String, dynamic>>[];
    for (var i = 0; i < 9; i++) {
      body.add(BodyEntry(id: 'b$i', date: now.subtract(Duration(days: 32 - i * 4)),
          weightKg: 80.0 - i * 0.3, steps: 8000).toJson());
    }
    prefs['body_history'] = jsonEncode(body);
    prefs['scale_history'] = jsonEncode([
      SmartScaleEntry(id: 's1', date: now.subtract(const Duration(days: 24)),
        weightKg: 80, bodyFatPercent: 22, bodyFatKg: 17.6, muscleMassKg: 60,
        muscleMassPercent: 50, leanBodyMassKg: 62, biologicalAge: 30,
        visceralFatIndex: 9, bmr: 1700, bodyWaterPercent: 55, boneMassKg: 3,
        proteinPercent: 18, skeletalMuscleMassKg: 34).toJson(),
      SmartScaleEntry(id: 's2', date: now.subtract(const Duration(days: 2)),
        weightKg: 78, bodyFatPercent: 19, bodyFatKg: 14.8, muscleMassKg: 61,
        muscleMassPercent: 52, leanBodyMassKg: 63, biologicalAge: 28,
        visceralFatIndex: 8, bmr: 1710, bodyWaterPercent: 57, boneMassKg: 3,
        proteinPercent: 19, skeletalMuscleMassKg: 35).toJson(),
    ]);
    prefs['measurements_history'] = jsonEncode([
      MeasurementEntry(id: 'm1', date: now.subtract(const Duration(days: 1)),
        chestCm: 100, waistCm: 84, hipsCm: 98, leftArmCm: 36, leftThighCm: 56).toJson(),
    ]);
    prefs['workouts'] = jsonEncode([
      WorkoutLog(id: 'w1', date: now.subtract(const Duration(days: 1)),
        workoutType: WorkoutType.a, exercises: [
          ExerciseLog(name: 'Bench Press', sets: [SetData(reps: 5, weight: 70)]),
          ExerciseLog(name: 'Deadlift', sets: [SetData(reps: 3, weight: 120)]),
        ]).toJson(),
    ]);
    for (var i = 0; i < 10; i++) {
      final d = now.subtract(Duration(days: i));
      prefs['food_${key(d)}'] = jsonEncode([
        FoodEntry(id: 'f$i', name: 'Roti', calories: 104, protein: 3, carbs: 18,
            fat: 2.5, mealType: MealType.breakfast, timestamp: d.add(const Duration(hours: 9))).toJson(),
        FoodEntry(id: 'l$i', name: 'Dinner', calories: 700, protein: 40,
            mealType: MealType.dinner, timestamp: d.add(const Duration(hours: 22))).toJson(),
      ]);
      prefs['water_${key(d)}'] = 2400;
      prefs['supp_${key(d)}'] =
          jsonEncode(SupplementStatus(whey: true, creatine: true, multivitamin: true).toJson());
    }
    SharedPreferences.setMockInitialValues(prefs);
    final p = FitnessProvider();
    await p.loadData();
    addTearDown(p.dispose);
    return p;
  }

  test('export then import round-trips through the documents directory', () async {
    final p = await seeded();
    final path = await p.exportAllData();
    expect(File(path).existsSync(), isTrue);
    final ok = await p.importAllData(path);
    expect(ok, isTrue);
    // Importing a non-existent file fails gracefully.
    expect(await p.importAllData('${tmp.path}/nope.json'), isFalse);
  });

  test('analytics getters compute over seeded history without throwing',
      () async {
    final p = await seeded();
    // Weight prediction / regression family.
    expect(p.weeklyWeightChange, isNotNull);
    expect(p.predictedWeightInDays(30), isNotNull);
    expect(p.weightForecast(days: 14), isNotEmpty);
    p.estimatedGoalDate; // may be null depending on slope — just exercise it.
    expect(p.kgToGoal, isNotNull);
    p.weeksToGoal;

    // Workout analytics.
    expect(p.getPersonalRecord('Deadlift'), 120);
    expect(p.getLastExerciseWeight('Bench Press'), 70);
    expect(p.getLastExerciseReps('Bench Press'), 5);
    expect(p.daysSinceLastWorkout, lessThan(900));
    expect(p.weeklyWorkoutMap.length, 7);
    expect(p.rolling7DayWorkouts.length, 7);
    expect(p.topLiftsOneRm.isNotEmpty, isTrue);

    // Nutrition / hydration analytics.
    expect(p.weeklyAvgCalories, greaterThan(0));
    expect(p.weeklyAvgProtein, greaterThan(0));
    p.weeklyWaterGoalHitDays;
    p.weeklyProteinGoalHitDays;
    p.calorieAdherenceRate;
    p.proteinAdherenceRate;
    p.waterAdherenceRate;
    p.deficitStreak;
    p.calorieStreak;
    p.supplementStreak;
    p.overeatsOnWeekends;
    p.hasLateNightEatingPattern;
    p.habitScore;
    p.caloriesAvgForWeekday(DateTime.now().weekday);
    p.proteinAvgForWeekday(DateTime.now().weekday);
    p.waterAvgForWeekday(DateTime.now().weekday);
    p.yesterdayCal;
    p.yesterdayProtein;
    p.yesterdayWater;
    p.workedOutYesterday;

    // Body composition.
    expect(p.bodyCompTrajectory, isNotNull);
    p.bioAgeDelta;
    p.hydrationStatus;
    p.whrRisk;
    p.whtrStatus;
    p.ffmi;
    p.ffmiStatus;
    p.bodyCompositionStatus;
    p.startWeightKg;
    expect(p.goalProgress, inInclusiveRange(0.0, 1.0));

    // Smart goal recommendations.
    expect(p.recommendedCalorieGoal, isNotNull);
    expect(p.recommendedProteinGoal, greaterThan(0));
    expect(p.recommendedWaterGoal, greaterThan(0));
    p.hasGoalRecommendations;
  });

  test('mutating actions persist and update derived state', () async {
    SharedPreferences.setMockInitialValues({});
    final p = FitnessProvider();
    await p.loadData();
    addTearDown(p.dispose);

    // Goals + profile setters (each clamps + persists).
    await p.saveCalorieGoal(2100);
    await p.saveProteinGoal(140);
    await p.saveWaterGoal(3000);
    await p.saveStepGoal(11000);
    await p.saveHeight(178);
    await p.saveAge(31);
    await p.saveSex(false);
    await p.saveGoalWeight(74);
    await p.saveUserName('Riya');
    expect(p.calorieGoal, 2100);
    expect(p.userName, 'Riya');
    expect(p.isMale, isFalse);

    // Logging actions.
    await p.addFoodEntry(FoodEntry(id: 'x', name: 'Egg', calories: 78,
        protein: 6, carbs: 0.6, fat: 5.3, mealType: MealType.breakfast,
        timestamp: DateTime.now()));
    expect(p.todayFood, isNotEmpty);
    await p.removeFoodEntry('x');
    expect(p.todayFood, isEmpty);

    await p.addWater(500);
    expect(p.todayWaterMl, 500);
    await p.removeWater(200);
    expect(p.todayWaterMl, 300);

    await p.updateSupplement('whey', true);
    await p.updateSupplement('creatine', true);
    await p.updateSupplement('multivitamin', true);
    expect(p.supplements.takenCount, 3);

    await p.logBodyEntry(weightKg: 75, steps: 8500);
    expect(p.latestWeightKg, 75);

    await p.logWorkout(WorkoutLog(id: 'wk', date: DateTime.now(),
        workoutType: WorkoutType.b, exercises: [
          ExerciseLog(name: 'Squats', sets: [SetData(reps: 5, weight: 90)]),
        ]));
    expect(p.todayWorkout, isNotNull);
    expect(p.todayCaloriesBurned, greaterThan(0));

    await p.logScaleEntry(SmartScaleEntry(id: 'sc', date: DateTime.now(),
        weightKg: 75, bodyFatPercent: 20, bodyFatKg: 15, muscleMassKg: 58,
        muscleMassPercent: 50, leanBodyMassKg: 60, biologicalAge: 30,
        visceralFatIndex: 8, bmr: 1650, bodyWaterPercent: 56, boneMassKg: 3,
        proteinPercent: 18, skeletalMuscleMassKg: 33));
    expect(p.latestScaleEntry, isNotNull);

    await p.logMeasurement(MeasurementEntry(id: 'me', date: DateTime.now(),
        waistCm: 82, hipsCm: 96));
    expect(p.latestMeasurements, isNotNull);

    // Notification center actions.
    await p.markNotificationsRead();
    await p.pushNotification(AppNotification(id: 'n', emoji: '🎯',
        title: 'Test', body: 'b', accent: 0xFF30D158, category: 'milestone',
        timestamp: DateTime.now()));
    expect(p.milestoneFeed, isNotEmpty);
    await p.clearNotifications();
    await p.markOnboardingDone();
    expect(p.onboardingDone, isTrue);
  });
}
