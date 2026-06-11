import 'package:flutter_test/flutter_test.dart';
import 'package:kfit/models/models.dart';
import 'package:kfit/providers/fitness_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FoodEntry carbs/fat JSON round-trip', () {
    test('round-trips real carbs and fat through toJson/fromJson', () {
      final entry = FoodEntry(
        id: 'e1',
        name: 'Roti',
        calories: 104,
        protein: 3,
        carbs: 18,
        fat: 2.5,
        mealType: MealType.dinner,
        timestamp: DateTime(2026, 1, 1, 8, 30),
      );
      final restored = FoodEntry.fromJson(entry.toJson());
      expect(restored.carbs, 18);
      expect(restored.fat, 2.5);
      expect(restored.calories, 104);
      expect(restored.protein, 3);
      expect(restored.mealType, MealType.dinner);
    });

    test('legacy JSON without carbs/fat defaults both to 0', () {
      final legacy = <String, dynamic>{
        'id': 'old',
        'name': 'Legacy Food',
        'calories': 200,
        'protein': 10,
        'mealType': MealType.lunch.index,
        'timestamp': DateTime(2025, 5, 5).toIso8601String(),
        'servingNote': '1 plate',
      };
      final restored = FoodEntry.fromJson(legacy);
      expect(restored.carbs, 0);
      expect(restored.fat, 0);
      expect(restored.calories, 200);
      expect(restored.protein, 10);
    });

    test('negative carbs/fat in JSON are clamped to 0', () {
      final restored = FoodEntry.fromJson(<String, dynamic>{
        'id': 'neg',
        'name': 'Bad Data',
        'calories': 100,
        'protein': 5,
        'carbs': -20,
        'fat': -5,
        'mealType': 0,
        'timestamp': DateTime(2026, 1, 1).toIso8601String(),
      });
      expect(restored.carbs, 0);
      expect(restored.fat, 0);
    });

    test('default constructor leaves carbs/fat at 0', () {
      final entry = FoodEntry(
        id: 'd',
        name: 'No Macros',
        calories: 50,
        protein: 2,
        mealType: MealType.snack,
        timestamp: DateTime(2026, 1, 1),
      );
      expect(entry.carbs, 0);
      expect(entry.fat, 0);
    });
  });

  group('FoodItem effective macros', () {
    test('uses real carbs/fat when provided', () {
      const item = FoodItem(
        name: 'Paneer',
        calories: 265,
        protein: 18,
        carbs: 3.5,
        fat: 20,
        category: 'Protein',
        emoji: '🧀',
      );
      expect(item.hasRealMacros, isTrue);
      expect(item.effectiveCarbs, 3.5);
      expect(item.effectiveFat, 20);
    });

    test('falls back to 65/35 estimate when carbs/fat are 0', () {
      const item = FoodItem(
        name: 'Mystery',
        calories: 200,
        protein: 0,
        category: 'Popular',
        emoji: '🍽️',
      );
      expect(item.hasRealMacros, isFalse);
      // remaining cal = 200; carbs = 200*0.65/4 = 32.5g, fat = 200*0.35/9 ≈ 7.78g
      expect(item.effectiveCarbs, closeTo(32.5, 0.01));
      expect(item.effectiveFat, closeTo(7.78, 0.05));
    });
  });

  group('Provider todayCarbs / todayFat', () {
    late FitnessProvider p;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      p = FitnessProvider();
      await p.loadData();
    });

    test('sum real carbs and fat from logged entries', () async {
      await p.addFoodEntry(FoodEntry(
        id: 'a', name: 'Roti', calories: 104, protein: 3, carbs: 18, fat: 2.5,
        mealType: MealType.lunch, timestamp: DateTime.now(),
      ));
      await p.addFoodEntry(FoodEntry(
        id: 'b', name: 'Dal', calories: 120, protein: 8, carbs: 18, fat: 1.5,
        mealType: MealType.lunch, timestamp: DateTime.now(),
      ));
      expect(p.todayCarbs, closeTo(36, 0.001));
      expect(p.todayFat, closeTo(4.0, 0.001));
    });

    test('estimate getters prefer real summed macros when present', () async {
      await p.addFoodEntry(FoodEntry(
        id: 'a', name: 'Paneer', calories: 265, protein: 18, carbs: 3.5, fat: 20,
        mealType: MealType.lunch, timestamp: DateTime.now(),
      ));
      // Real data present → estimate getters return the real sum, not the split.
      expect(p.todayCarbsEstimate, closeTo(p.todayCarbs, 0.001));
      expect(p.todayFatEstimate, closeTo(p.todayFat, 0.001));
      expect(p.todayCarbsEstimate, closeTo(3.5, 0.001));
      expect(p.todayFatEstimate, closeTo(20, 0.001));
    });

    test('estimate falls back to 65/35 split when no real macros logged', () async {
      // Legacy-style entry: carbs/fat both 0.
      await p.addFoodEntry(FoodEntry(
        id: 'legacy', name: 'Old', calories: 500, protein: 25,
        mealType: MealType.lunch, timestamp: DateTime.now(),
      ));
      expect(p.todayCarbs, 0);
      expect(p.todayFat, 0);
      // remaining = 500 - 25*4 = 400; carbs = 400*0.65/4 = 65g, fat = 400*0.35/9 ≈ 15.56g
      expect(p.todayCarbsEstimate, closeTo(65, 0.01));
      expect(p.todayFatEstimate, closeTo(15.56, 0.05));
    });

    test('zero food logged yields zero carbs/fat and zero estimate', () {
      expect(p.todayCarbs, 0);
      expect(p.todayFat, 0);
      expect(p.todayCarbsEstimate, 0);
      expect(p.todayFatEstimate, 0);
    });
  });

  group('Food database', () {
    test('contains a healthy number of items', () {
      expect(kFoodDatabase.length, greaterThan(300));
    });

    test('every item has non-negative calories and protein', () {
      for (final item in kFoodDatabase) {
        expect(item.calories, greaterThanOrEqualTo(0), reason: item.name);
        expect(item.protein, greaterThanOrEqualTo(0), reason: item.name);
        expect(item.carbs, greaterThanOrEqualTo(0), reason: item.name);
        expect(item.fat, greaterThanOrEqualTo(0), reason: item.name);
      }
    });

    test('items with real macros roughly satisfy the 4/4/9 energy identity', () {
      for (final item in kFoodDatabase.where((f) => f.hasRealMacros)) {
        final computed = item.protein * 4 + item.carbs * 4 + item.fat * 9;
        // Allow generous tolerance: rounding, fibre, alcohol, cooking variance.
        expect(computed, closeTo(item.calories, item.calories * 0.30 + 40),
            reason: '${item.name}: computed $computed vs ${item.calories}');
      }
    });
  });
}
