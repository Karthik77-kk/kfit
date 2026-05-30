import 'package:flutter_test/flutter_test.dart';
import 'package:karthik_fitness/models/models.dart';
import 'package:karthik_fitness/providers/fitness_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('FitnessProvider — calorie math', () {
    late FitnessProvider p;

    setUp(() async {
      p = FitnessProvider();
      await p.loadData();
    });

    test('starts with zero calories and protein', () {
      expect(p.todayCaloriesTotal, 0.0);
      expect(p.todayProteinTotal, 0.0);
    });

    test('calorieProgress clamps to [0,1]', () {
      expect(p.calorieProgress, 0.0);
    });

    test('addFoodEntry updates totals', () async {
      await p.addFoodEntry(FoodEntry(
        id: 'test',
        name: 'Boiled Egg',
        calories: 78,
        protein: 6,
        mealType: MealType.breakfast,
        timestamp: DateTime.now(),
      ));
      expect(p.todayCaloriesTotal, 78.0);
      expect(p.todayProteinTotal, 6.0);
    });

    test('whey supplement adds 120 kcal and 25g protein', () async {
      await p.updateSupplement('whey', true);
      expect(p.supplementCalories, 120.0);
      expect(p.supplementProtein, 25.0);
      expect(p.todayCaloriesTotal, 120.0);
      expect(p.todayProteinTotal, 25.0);
    });

    test('removeFoodEntry removes correct entry', () async {
      await p.addFoodEntry(FoodEntry(
        id: 'keep',
        name: 'Roti',
        calories: 104,
        protein: 3,
        mealType: MealType.lunch,
        timestamp: DateTime.now(),
      ));
      await p.addFoodEntry(FoodEntry(
        id: 'remove',
        name: 'Rice',
        calories: 130,
        protein: 2.7,
        mealType: MealType.lunch,
        timestamp: DateTime.now(),
      ));
      await p.removeFoodEntry('remove');
      expect(p.todayCaloriesTotal, closeTo(104, 0.01));
      expect(p.todayFood.length, 1);
      expect(p.todayFood.first.id, 'keep');
    });

    test('caloriesRemaining decreases as food is added', () async {
      final before = p.caloriesRemaining;
      await p.addFoodEntry(FoodEntry(
        id: 'x',
        name: 'Grilled Chicken',
        calories: 219,
        protein: 43,
        mealType: MealType.dinner,
        timestamp: DateTime.now(),
      ));
      expect(p.caloriesRemaining, lessThan(before));
    });

    test('carbs and fat estimates are non-negative', () async {
      await p.addFoodEntry(FoodEntry(
        id: 'f1',
        name: 'Rice',
        calories: 260,
        protein: 5,
        mealType: MealType.lunch,
        timestamp: DateTime.now(),
      ));
      expect(p.todayCarbsEstimate, greaterThanOrEqualTo(0));
      expect(p.todayFatEstimate, greaterThanOrEqualTo(0));
    });
  });

  group('FitnessProvider — user-configurable goals', () {
    late FitnessProvider p;

    setUp(() async {
      p = FitnessProvider();
      await p.loadData();
    });

    test('default goals match constants', () {
      expect(p.calorieGoal, FitnessProvider.kDefaultCalorieGoal);
      expect(p.proteinGoal, FitnessProvider.kDefaultProteinGoal);
      expect(p.waterGoalMl, FitnessProvider.kDefaultWaterGoalMl);
      expect(p.stepGoal, FitnessProvider.kDefaultStepGoal);
    });

    test('saveCalorieGoal updates calorieGoal', () async {
      await p.saveCalorieGoal(2000);
      expect(p.calorieGoal, 2000);
    });

    test('saveCalorieGoal clamps to valid range', () async {
      await p.saveCalorieGoal(100);
      expect(p.calorieGoal, 800);
      await p.saveCalorieGoal(99999);
      expect(p.calorieGoal, 5000);
    });
  });

  group('FitnessProvider — water', () {
    late FitnessProvider p;

    setUp(() async {
      p = FitnessProvider();
      await p.loadData();
    });

    test('addWater accumulates correctly', () async {
      await p.addWater(500);
      await p.addWater(300);
      expect(p.todayWaterMl, 800);
    });

    test('removeWater does not go below zero', () async {
      await p.addWater(200);
      await p.removeWater(500);
      expect(p.todayWaterMl, 0);
    });

    test('waterProgress clamps to [0,1]', () async {
      await p.addWater(99999);
      expect(p.waterProgress, 1.0);
    });
  });

  group('FitnessProvider — body / BMI', () {
    late FitnessProvider p;

    setUp(() async {
      p = FitnessProvider();
      await p.loadData();
    });

    test('BMI is null before any body entry', () {
      expect(p.bmi, isNull);
    });

    test('BMI calculates correctly after logging weight', () async {
      await p.logBodyEntry(weightKg: 78.0);
      // BMI = 78 / (1.70^2) ≈ 26.99 (height default is 170cm)
      expect(p.bmi, closeTo(78.0 / (1.70 * 1.70), 0.1));
    });

    test('bmiCategory Overweight for 78kg at 170cm', () async {
      await p.logBodyEntry(weightKg: 78.0);
      // 78 / 1.70^2 ≈ 27.0 → Overweight
      expect(p.bmiCategory, 'Overweight');
    });

    test('bmiCategory Normal for healthy weight', () async {
      await p.logBodyEntry(weightKg: 68.0);
      // 68 / 1.70^2 ≈ 23.5 → Normal
      expect(p.bmiCategory, 'Normal');
    });
  });

  group('FitnessProvider — workout', () {
    late FitnessProvider p;

    setUp(() async {
      p = FitnessProvider();
      await p.loadData();
    });

    test('no workout today initially', () {
      expect(p.todayWorkout, isNull);
      expect(p.todayWorkouts, isEmpty);
      expect(p.todayCaloriesBurned, 0);
    });

    test('logWorkout appears in todayWorkouts', () async {
      final workout = WorkoutLog(
        id: 'w1',
        date: DateTime.now(),
        name: 'Workout A — Push',
        exercises: [
          ExerciseLog(name: 'Push-ups', sets: [SetData(reps: 15, weight: 0)]),
        ],
      );
      await p.logWorkout(workout);
      expect(p.todayWorkouts.length, 1);
      expect(p.todayWorkout, isNotNull);
    });

    test('multiple workouts accumulate todayCaloriesBurned', () async {
      await p.logBodyEntry(weightKg: 75.0);
      final w1 = WorkoutLog(
        id: 'w1', date: DateTime.now(), name: 'Morning',
        exercises: [ExerciseLog(name: 'Running', sets: [SetData(reps: 1, weight: 0), SetData(reps: 1, weight: 0)])],
      );
      final w2 = WorkoutLog(
        id: 'w2', date: DateTime.now(), name: 'Evening',
        exercises: [ExerciseLog(name: 'Push-ups', sets: [SetData(reps: 15, weight: 0)])],
      );
      await p.logWorkout(w1);
      await p.logWorkout(w2);
      expect(p.todayWorkouts.length, 2);
      expect(p.todayCaloriesBurned, greaterThan(0));
    });

    test('inDeficit true when (eaten - totalBurned) < calorieGoal', () async {
      // No food logged, totalCaloriesBurned includes resting burn
      // so eaten(0) - burned(>0) < 1700 → always in deficit
      await p.logBodyEntry(weightKg: 75.0);
      expect(p.inDeficit, isTrue);
    });

    test('calorieDeficit uses totalCaloriesBurned not just workout', () async {
      await p.logBodyEntry(weightKg: 70.0);
      // With some resting calories burned, deficit should be > calorieGoal
      // (since eaten=0, deficit = goal - (0 - totalBurned) = goal + totalBurned)
      expect(p.calorieDeficit, greaterThan(p.calorieGoal));
    });
  });

  group('FitnessProvider — supplements', () {
    late FitnessProvider p;

    setUp(() async {
      p = FitnessProvider();
      await p.loadData();
    });

    test('all supplements start unchecked', () {
      expect(p.supplements.whey, false);
      expect(p.supplements.creatine, false);
      expect(p.supplements.multivitamin, false);
    });

    test('updateSupplement toggles correctly', () async {
      await p.updateSupplement('whey', true);
      expect(p.supplements.whey, true);
      await p.updateSupplement('creatine', true);
      expect(p.supplements.creatine, true);
      await p.updateSupplement('whey', false);
      expect(p.supplements.whey, false);
    });
  });

  group('FitnessProvider — streaks', () {
    late FitnessProvider p;

    setUp(() async {
      p = FitnessProvider();
      await p.loadData();
    });

    test('workoutStreak is 0 with no workouts', () {
      expect(p.workoutStreak, 0);
    });

    test('calorieStreak is 0 with no food logged', () {
      expect(p.calorieStreak, 0);
    });

    test('calorieStreak increments when food logged today', () async {
      await p.addFoodEntry(FoodEntry(
        id: 'f1', name: 'Oats', calories: 600, protein: 10,
        mealType: MealType.breakfast, timestamp: DateTime.now(),
      ));
      expect(p.calorieStreak, greaterThanOrEqualTo(1));
    });
  });

  group('FitnessProvider — weekly calorie data', () {
    late FitnessProvider p;

    setUp(() async {
      p = FitnessProvider();
      await p.loadData();
    });

    test('weeklyCalorieData returns 7 entries', () {
      expect(p.weeklyCalorieData.length, 7);
    });

    test('last entry label is Today', () {
      expect(p.weeklyCalorieData.last['label'], 'Today');
    });
  });

  group('FitnessProvider — constants', () {
    test('default daily targets are correct', () {
      expect(FitnessProvider.kDefaultCalorieGoal, 1700);
      expect(FitnessProvider.kDefaultProteinGoal, 100);
      expect(FitnessProvider.kDefaultWaterGoalMl, 2500);
      expect(FitnessProvider.kDefaultStepGoal, 8000);
    });

    test('static aliases still work', () {
      expect(FitnessProvider.kCalorieGoal, 1700);
      expect(FitnessProvider.kProteinGoal, 100);
    });
  });
}
