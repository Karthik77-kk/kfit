import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kfit/models/models.dart';
import 'package:kfit/providers/fitness_provider.dart';
import 'package:kfit/widgets/date_picker_chip.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Build 111: backdate + edit logged entries across food, water, weight, scale,
/// measurements. The provider previously hardcoded "today"; these verify entries
/// can be written to (and edited on) any date and that history reflects it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FitnessProvider p;
  final today = DateTime.now();
  final d3 = today.subtract(const Duration(days: 3));
  final d5 = today.subtract(const Duration(days: 5));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    p = FitnessProvider();
    await p.loadData();
    addTearDown(p.dispose);
  });

  FoodEntry food(String id, double cal, {double prot = 5}) => FoodEntry(
        id: id, name: 'Meal $id', calories: cal, protein: prot,
        mealType: MealType.lunch, timestamp: today);

  group('food backdate + edit', () {
    test('backdated food lands on the past day, not today', () async {
      await p.addFoodEntry(food('a', 300), date: d3);
      expect(p.todayFood, isEmpty);
      expect(p.caloriesForDate(d3), closeTo(300, 0.001));
      expect(p.foodHistory[
          '${d3.year}-${d3.month.toString().padLeft(2, '0')}-${d3.day.toString().padLeft(2, '0')}'],
          isNotNull);
    });

    test('today food still works with no date', () async {
      await p.addFoodEntry(food('t', 250));
      expect(p.todayFood.length, 1);
      expect(p.todayCalories, closeTo(250, 0.001));
    });

    test('edit a past entry replaces it', () async {
      await p.addFoodEntry(food('e', 300), date: d3);
      await p.updateFoodEntry('e', food('e', 500), date: d3);
      expect(p.caloriesForDate(d3), closeTo(500, 0.001));
    });

    test('edit a today entry replaces it', () async {
      await p.addFoodEntry(food('te', 300));
      await p.updateFoodEntry('te', food('te', 120));
      expect(p.todayCalories, closeTo(120, 0.001));
    });

    test('remove a past entry', () async {
      await p.addFoodEntry(food('r', 300), date: d3);
      await p.removeFoodEntry('r', date: d3);
      expect(p.caloriesForDate(d3), 0);
    });

    test('backdated food persists across reload', () async {
      await p.addFoodEntry(food('p', 400), date: d3);
      final p2 = FitnessProvider();
      await p2.loadData();
      addTearDown(p2.dispose);
      expect(p2.caloriesForDate(d3), closeTo(400, 0.001));
    });
  });

  group('water / weight / scale / measurement backdate', () {
    test('backdated water adds to the past day', () async {
      await p.addWater(600, date: d3);
      expect(p.waterForDate(d3), 600);
      await p.removeWater(200, date: d3);
      expect(p.waterForDate(d3), 400);
      // today untouched
      expect(p.todayWaterMl, 0);
    });

    test('backdated weight fills the trend on the right date', () async {
      await p.logBodyEntry(weightKg: 77, date: d5);
      final entries = p.getRecentBodyEntries(days: 30);
      expect(entries.any((e) =>
          e.date.year == d5.year && e.date.month == d5.month &&
          e.date.day == d5.day && e.weightKg == 77), isTrue);
    });

    test('re-logging weight for a past day replaces it (one per day)', () async {
      await p.logBodyEntry(weightKg: 77, date: d5);
      await p.logBodyEntry(weightKg: 76, date: d5);
      final onD5 = p.getRecentBodyEntries(days: 30).where((e) =>
          e.date.year == d5.year && e.date.month == d5.month && e.date.day == d5.day);
      expect(onD5.length, 1);
      expect(onD5.first.weightKg, 76);
    });

    test('backdated scale reading lands on its own date', () async {
      final entry = SmartScaleEntry(
        id: 'sc', date: d5, weightKg: 75, bodyFatPercent: 20, bodyFatKg: 15,
        muscleMassKg: 58, muscleMassPercent: 50, leanBodyMassKg: 60,
        biologicalAge: 30, visceralFatIndex: 8, bmr: 1650, bodyWaterPercent: 55,
        boneMassKg: 3, proteinPercent: 18, skeletalMuscleMassKg: 33);
      await p.logScaleEntry(entry);
      expect(p.scaleHistory.any((e) =>
          e.date.day == d5.day && e.weightKg == 75), isTrue);
      // It also seeds a weight entry on that day.
      expect(p.getRecentBodyEntries(days: 30).any((e) =>
          e.date.day == d5.day && e.weightKg == 75), isTrue);
    });

    test('backdated measurement honours its entry date', () async {
      await p.logMeasurement(MeasurementEntry(id: 'm', date: d5, waistCm: 82));
      expect(p.measurementHistory.any((e) =>
          e.date.day == d5.day && e.waistCm == 82), isTrue);
    });
  });

  group('DatePickerChip', () {
    testWidgets('labels Today/Yesterday and opens a date picker', (tester) async {
      DateTime? changed;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DatePickerChip(
            date: DateTime.now(),
            onChanged: (d) => changed = d,
          ),
        ),
      ));
      expect(find.text('Today'), findsOneWidget);
      await tester.tap(find.byType(DatePickerChip));
      await tester.pumpAndSettle();
      // showDatePicker opened — pick the OK action to confirm the wiring.
      expect(find.text('OK'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(changed, isNotNull);
    });

    testWidgets('shows the absolute date for older days', (tester) async {
      final old = DateTime.now().subtract(const Duration(days: 10));
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DatePickerChip(date: old, onChanged: (_) {}),
        ),
      ));
      expect(find.text('Today'), findsNothing);
      expect(find.text('Yesterday'), findsNothing);
    });
  });
}
