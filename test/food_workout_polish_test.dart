import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:kfit/models/models.dart';
import 'package:kfit/providers/fitness_provider.dart';
import 'package:kfit/services/food_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Coverage for the food + workout polish batch: macro goals, remaining-today,
/// per-food portion memory, favorites, backup reminder, progressive-overload
/// suggestion, and recently-scanned.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<FitnessProvider> provider() async {
    final p = FitnessProvider();
    await p.loadData();
    return p;
  }

  // ── Macro goals + remaining ────────────────────────────────────────────────
  group('macro goals', () {
    test('defaults load and persist', () async {
      final p = await provider();
      expect(p.carbGoal, FitnessProvider.kDefaultCarbGoal);
      expect(p.fatGoal, FitnessProvider.kDefaultFatGoal);
    });

    test('save clamps to sane bounds', () async {
      final p = await provider();
      await p.saveCarbGoal(5);   // below min 20
      await p.saveFatGoal(9999); // above max 300
      expect(p.carbGoal, 20);
      expect(p.fatGoal, 300);
    });

    test('carb/fat progress clamp to 0..1', () async {
      final p = await provider();
      await p.saveCarbGoal(100);
      await p.addFoodEntry(FoodEntry(
        id: 'a', name: 'Rice', calories: 800, protein: 0, carbs: 200, fat: 0,
        mealType: MealType.lunch, timestamp: DateTime.now()));
      expect(p.carbProgress, 1.0); // 200/100 capped
    });
  });

  group('remaining today', () {
    test('protein remaining never goes negative', () async {
      final p = await provider();
      await p.saveProteinGoal(100);
      await p.addFoodEntry(FoodEntry(
        id: 'p', name: 'Whey', calories: 480, protein: 120,
        mealType: MealType.snack, timestamp: DateTime.now()));
      expect(p.proteinRemaining, 0); // 100 − 120 → clamped to 0
    });

    test('calories remaining reflects goal minus eaten', () async {
      final p = await provider();
      await p.saveCalorieGoal(1700);
      await p.addFoodEntry(FoodEntry(
        id: 'c', name: 'Lunch', calories: 700, protein: 10,
        mealType: MealType.lunch, timestamp: DateTime.now()));
      expect(p.caloriesRemaining, lessThanOrEqualTo(1000));
      expect(p.caloriesRemaining, greaterThan(0));
    });
  });

  // ── Per-food portion memory ────────────────────────────────────────────────
  group('portion memory', () {
    test('remembers and recalls last quantity, normalized by name', () async {
      final p = await provider();
      expect(p.lastPortion('Paneer'), isNull);
      await p.rememberPortion('Paneer', 150);
      expect(p.lastPortion('paneer'), 150);      // case-insensitive
      expect(p.lastPortion('  PANEER '), 150);   // space-insensitive
    });

    test('ignores non-positive quantities; survives reload', () async {
      final p = await provider();
      await p.rememberPortion('Dal', 0);
      expect(p.lastPortion('Dal'), isNull);
      await p.rememberPortion('Dal', 2.5);
      final p2 = await provider(); // reload from the same mock prefs
      expect(p2.lastPortion('Dal'), 2.5);
    });
  });

  // ── Favorites ──────────────────────────────────────────────────────────────
  group('favorites', () {
    test('toggle on/off and resolve to curated FoodItems', () async {
      final p = await provider();
      final sample = kFoodDatabase.first.name;
      expect(p.isFavoriteFood(sample), isFalse);
      await p.toggleFavoriteFood(sample);
      expect(p.isFavoriteFood(sample), isTrue);
      expect(p.favoriteFoodItems.any((f) => f.name == sample), isTrue);
      await p.toggleFavoriteFood(sample);
      expect(p.isFavoriteFood(sample), isFalse);
      expect(p.favoriteFoodItems, isEmpty);
    });
  });

  // ── Backup reminder ────────────────────────────────────────────────────────
  group('backup reminder', () {
    test('no data → no reminder', () async {
      final p = await provider();
      expect(p.needsBackupReminder, isFalse);
      expect(p.daysSinceBackup, isNull);
    });

    test('data but never backed up → reminder on', () async {
      final p = await provider();
      await p.addFoodEntry(FoodEntry(
        id: 'x', name: 'Egg', calories: 78, protein: 6,
        mealType: MealType.breakfast, timestamp: DateTime.now()));
      expect(p.needsBackupReminder, isTrue);
    });

    test('markBackedUp resets the clock', () async {
      final p = await provider();
      await p.addFoodEntry(FoodEntry(
        id: 'x', name: 'Egg', calories: 78, protein: 6,
        mealType: MealType.breakfast, timestamp: DateTime.now()));
      await p.markBackedUp();
      expect(p.daysSinceBackup, 0);
      expect(p.needsBackupReminder, isFalse);
    });
  });

  // ── Progressive-overload suggestion (pure) ─────────────────────────────────
  group('overloadSuggestion', () {
    test('≥8 reps on a loaded lift → +2.5 kg', () {
      expect(FitnessProvider.overloadSuggestion(40, 8), 'try 42.5kg');
      expect(FitnessProvider.overloadSuggestion(40, 12), 'try 42.5kg');
    });
    test('<8 reps → +1 rep at the same load', () {
      expect(FitnessProvider.overloadSuggestion(60, 5), 'try 6 reps');
    });
    test('bodyweight move (no load) → +1 rep', () {
      expect(FitnessProvider.overloadSuggestion(0, 15), 'try 16 reps');
    });
    test('no prior set → null', () {
      expect(FitnessProvider.overloadSuggestion(null, null), isNull);
      expect(FitnessProvider.overloadSuggestion(0, 0), isNull);
    });
    test('formats whole vs fractional kg cleanly', () {
      expect(FitnessProvider.overloadSuggestion(42.5, 10), 'try 45kg');
      expect(FitnessProvider.overloadSuggestion(41, 10), 'try 43.5kg');
    });
  });

  // ── Recently scanned ───────────────────────────────────────────────────────
  group('recently scanned', () {
    test('manual gap-fill is remembered as a recent scan', () async {
      await FoodApiService.cacheManualBarcode(
          barcode: 'RS_TEST_1', name: 'Homemade Bar', calories: 250, protein: 8);
      final recents = await FoodApiService.recentScans();
      expect(recents.any((r) => r.name == 'Homemade Bar'), isTrue);
    });

    test('recentScans honors the max and newest-first order', () async {
      // Seed three scans directly.
      final list = [
        for (final n in ['A', 'B', 'C'])
          jsonEncode(FoodApiResult(
            name: n, calories100g: 100, protein100g: 1, carbs100g: 1,
            fat100g: 1, source: 'OpenFoodFacts', barcode: 'b$n').toJson()),
      ];
      SharedPreferences.setMockInitialValues({'recent_scans': list});
      final recents = await FoodApiService.recentScans(max: 2);
      expect(recents.length, 2);
      expect(recents.first.name, 'A');
    });
  });
}
