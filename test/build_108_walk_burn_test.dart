import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kfit/models/models.dart';
import 'package:kfit/providers/fitness_provider.dart';
import 'package:kfit/services/smart_insight_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Build 108: the walk-burn calorie figure was computed in two places with
/// DIFFERENT METs — smart_insight_engine (3.5) and notification_panel (5.0) — so
/// the same "20-min walk" tip showed ~82 kcal on the Home coach card and ~117
/// kcal in the notification center. These tests lock in the single shared
/// helper (walkCaloriesForMinutes, MET 3.5) and prove both consumers use it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('walkCaloriesForMinutes — MET 3.5 single source of truth', () {
    test('MET constant is 3.5 (matches the provider exercise table)', () {
      expect(kWalkingMet, 3.5);
    });

    test('70 kg reference: 20 and 30 minutes', () {
      // 3.5 * 70 * 20/60 = 81.67 -> 82 ; 3.5 * 70 * 30/60 = 122.5 -> 123
      expect(walkCaloriesForMinutes(70, minutes: 20), 82);
      expect(walkCaloriesForMinutes(70, minutes: 30), 123);
      expect(walkCaloriesForMinutes(70), 123); // default is 30 min
    });

    test('scales linearly with body weight', () {
      expect(walkCaloriesForMinutes(60, minutes: 20), 70); // 3.5*60*20/60
      expect(walkCaloriesForMinutes(80, minutes: 30), 140); // 3.5*80*30/60
      expect(walkCaloriesForMinutes(100, minutes: 60), 350); // 3.5*100*60/60
    });

    test('null weight falls back to the 70 kg reference', () {
      expect(walkCaloriesForMinutes(null, minutes: 20),
          walkCaloriesForMinutes(70, minutes: 20));
    });

    test('zero / edge inputs do not throw and stay sane', () {
      expect(walkCaloriesForMinutes(70, minutes: 0), 0);
      expect(walkCaloriesForMinutes(0, minutes: 30), 0);
      expect(walkCaloriesForMinutes(70, minutes: 120), 490); // 3.5*70*120/60
    });

    test('is strictly lower than the old MET-5.0 figure (regression guard)', () {
      // The bug used MET 5.0; the correct walking MET (3.5) must be ~30% lower.
      final correct = walkCaloriesForMinutes(70, minutes: 20); // 82
      final oldBug = (5.0 * 70 * 20 / 60).round(); // 117
      expect(correct, lessThan(oldBug));
      expect(correct, 82);
    });
  });

  group('estimateCaloriesBurned (resistance) is unchanged + single-defined', () {
    test('still uses MET 5.0 for weight training', () {
      expect(estimateCaloriesBurned(75, 60), 375); // 5*75*60/60
      expect(estimateCaloriesBurned(80, 30), 200);
      expect(estimateCaloriesBurned(70, 0), 0);
    });
  });

  group('both consumers delegate to the shared helper', () {
    test('insight engine + notification center reference walkCaloriesForMinutes',
        () {
      final insight =
          File('lib/services/smart_insight_engine.dart').readAsStringSync();
      final notif =
          File('lib/screens/notification_panel.dart').readAsStringSync();
      expect(insight.contains('walkCaloriesForMinutes'), isTrue,
          reason: 'insight engine must use the shared helper');
      expect(notif.contains('walkCaloriesForMinutes'), isTrue,
          reason: 'notification center must use the shared helper');
      // No stray hardcoded "5.0 * <weight> * <minutes>" walk formula remains.
      expect(RegExp(r'5\.0 \* \(?weightKg').hasMatch(notif), isFalse,
          reason: 'old MET-5.0 walk formula should be gone');
    });

    test('home_screen no longer redefines estimateCaloriesBurned', () {
      final home = File('lib/screens/home_screen.dart').readAsStringSync();
      expect(home.contains('int estimateCaloriesBurned('), isFalse,
          reason: 'duplicate definition should be removed; use models.dart');
    });
  });

  group('end-to-end: insight copy uses the shared walk-burn value', () {
    test('"over goal" insight quotes the MET-3.5 walk-burn number', () async {
      SharedPreferences.setMockInitialValues({});
      final p = FitnessProvider();
      await p.loadData();
      await p.logBodyEntry(weightKg: 70);
      // Exceed the calorie goal (1700) by > 400 so the "over goal" insight fires.
      await p.addFoodEntry(FoodEntry(
        id: 'feast', name: 'Feast', calories: 2200, protein: 50,
        mealType: MealType.dinner, timestamp: DateTime.now(),
      ));
      final insights = generateInsights(p, DateTime.now());
      final overGoal =
          insights.where((i) => i.title.contains('over goal')).toList();
      expect(overGoal, isNotEmpty, reason: '2200 kcal should trip the over-goal insight');
      // Body must quote the shared-helper figure (123 kcal for a 30-min walk @70kg),
      // NOT the old MET-5.0 figure (175).
      expect(overGoal.first.body,
          contains('${walkCaloriesForMinutes(70)} kcal'));
      expect(overGoal.first.body.contains('175 kcal'), isFalse);
    });
  });
}
