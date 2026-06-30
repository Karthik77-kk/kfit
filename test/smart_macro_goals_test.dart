import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:kfit/models/models.dart';
import 'package:kfit/providers/fitness_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Auto-calculated carb + fat goals (Smart Goals), derived from the user's TDEE
/// the same way calories/protein are: protein first, fat ~25% of calories, carbs
/// fill the remaining energy.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Provider seeded with enough body history to produce a TDEE estimate.
  Future<FitnessProvider> seeded() async {
    final now = DateTime.now();
    final body = <Map<String, dynamic>>[
      for (var i = 0; i < 10; i++)
        BodyEntry(
          id: 'b$i',
          date: now.subtract(Duration(days: 27 - i * 3)),
          weightKg: 80.0 - i * 0.2,
          steps: 8000,
        ).toJson(),
    ];
    SharedPreferences.setMockInitialValues({
      'onboarding_done': true,
      'height_cm': 175.0,
      'age': 30,
      'is_male': true,
      'body_history': jsonEncode(body),
    });
    final p = FitnessProvider();
    await p.loadData();
    return p;
  }

  group('recommended carb/fat goals', () {
    test('null until a TDEE estimate exists', () async {
      SharedPreferences.setMockInitialValues({}); // no body data
      final p = FitnessProvider();
      await p.loadData();
      expect(p.recommendedCalorieGoal, isNull);
      expect(p.recommendedCarbGoal, isNull);
      expect(p.recommendedFatGoal, isNull);
    });

    test('fat ≈ 25% of recommended calories ÷ 9', () async {
      final p = await seeded();
      final cals = p.recommendedCalorieGoal;
      expect(cals, isNotNull);
      final expected = (cals! * 0.25 / 9.0).round().clamp(30, 130);
      expect(p.recommendedFatGoal, expected);
    });

    test('carbs fill the energy left after protein + fat', () async {
      final p = await seeded();
      final cals = p.recommendedCalorieGoal!;
      final expected = ((cals -
                  p.recommendedProteinGoal * 4 -
                  p.recommendedFatGoal! * 9) /
              4.0)
          .round()
          .clamp(50, 500);
      expect(p.recommendedCarbGoal, expected);
    });

    test('the three macros roughly reconstruct the calorie target', () async {
      final p = await seeded();
      final cals = p.recommendedCalorieGoal!;
      final kcalFromMacros = p.recommendedProteinGoal * 4 +
          p.recommendedCarbGoal! * 4 +
          p.recommendedFatGoal! * 9;
      expect((kcalFromMacros - cals).abs(), lessThan(60)); // rounding/clamp slack
    });

    test('Apply saves carb + fat goals onto the provider', () async {
      final p = await seeded();
      final rCarb = p.recommendedCarbGoal!;
      final rFat = p.recommendedFatGoal!;
      await p.saveCarbGoal(rCarb);
      await p.saveFatGoal(rFat);
      expect(p.carbGoal, rCarb);
      expect(p.fatGoal, rFat);
    });
  });
}
