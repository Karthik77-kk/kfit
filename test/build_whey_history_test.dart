import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:kfit/models/models.dart';
import 'package:kfit/providers/fitness_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whey double-count regression (history paths).
///
/// Today already suppresses the whey supplement's 120 kcal / 25 g when a whey
/// shake is also logged as food (one scoop, counted once). Before this fix the
/// HISTORY aggregations (weeklyCalorieData, caloriesForDate, proteinForDate,
/// weeklyAvgProtein, the calorie-streak walk, weeklyProteinGoalHitDays) added
/// the supplement unconditionally for past days — so a past day with both a
/// logged shake and the whey toggle read ~120 kcal / ~25 g too high. These
/// tests pin today and history to the same suppression rule.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // Seeds a single PAST day (2 days ago) with one food entry and the whey
  // supplement toggled on, then returns a loaded provider.
  Future<FitnessProvider> seedPastDay({
    required FoodEntry food,
    required bool whey,
  }) async {
    final day = DateTime.now().subtract(const Duration(days: 2));
    final prefs = <String, Object>{
      'onboarding_done': true,
      'user_name': 'Sam',
      'food_${key(day)}': jsonEncode([food.toJson()]),
      'supp_${key(day)}': jsonEncode(SupplementStatus(whey: whey).toJson()),
    };
    SharedPreferences.setMockInitialValues(prefs);
    final p = FitnessProvider();
    await p.loadData();
    addTearDown(p.dispose);
    return p;
  }

  final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));

  group('whey supplement is suppressed on a past day with a logged shake', () {
    test('caloriesForDate / proteinForDate exclude the extra scoop', () async {
      final p = await seedPastDay(
        food: FoodEntry(
          id: 'w', name: 'Whey Protein Shake', calories: 150, protein: 30,
          mealType: MealType.snack, timestamp: twoDaysAgo,
        ),
        whey: true,
      );
      // Food only — NOT 150 + 120 / 30 + 25.
      expect(p.caloriesForDate(twoDaysAgo), 150);
      expect(p.proteinForDate(twoDaysAgo), 30);
    });

    test('weeklyCalorieData entry for that day excludes the extra scoop',
        () async {
      final p = await seedPastDay(
        food: FoodEntry(
          id: 'w', name: 'Whey Protein Shake', calories: 150, protein: 30,
          mealType: MealType.snack, timestamp: twoDaysAgo,
        ),
        whey: true,
      );
      final entry = p.weeklyCalorieData
          .firstWhere((m) => m['date'] == key(twoDaysAgo));
      expect(entry['calories'], 150);
    });

    test('weeklyAvgProtein does not include the phantom 25 g', () async {
      final p = await seedPastDay(
        food: FoodEntry(
          id: 'w', name: 'Whey Protein Shake', calories: 150, protein: 30,
          mealType: MealType.snack, timestamp: twoDaysAgo,
        ),
        whey: true,
      );
      // Only that one day has protein (30 g), spread over the 7-day window.
      expect(p.weeklyAvgProtein, closeTo(30 / 7, 0.001));
    });
  });

  group('whey supplement still counts on a past day without a shake', () {
    test('caloriesForDate / proteinForDate add the scoop', () async {
      final p = await seedPastDay(
        food: FoodEntry(
          id: 'r', name: 'Roti', calories: 100, protein: 4,
          mealType: MealType.breakfast, timestamp: twoDaysAgo,
        ),
        whey: true,
      );
      expect(p.caloriesForDate(twoDaysAgo), 100 + 120);
      expect(p.proteinForDate(twoDaysAgo), 4 + 25);
    });

    test('weeklyCalorieData entry adds the scoop', () async {
      final p = await seedPastDay(
        food: FoodEntry(
          id: 'r', name: 'Roti', calories: 100, protein: 4,
          mealType: MealType.breakfast, timestamp: twoDaysAgo,
        ),
        whey: true,
      );
      final entry = p.weeklyCalorieData
          .firstWhere((m) => m['date'] == key(twoDaysAgo));
      expect(entry['calories'], 100 + 120);
    });
  });
}
