import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kfit/models/models.dart';
import 'package:kfit/providers/fitness_provider.dart';
import 'package:kfit/screens/food_screen.dart';

/// Branch: food-log UX — swipe-to-delete removed; tap a tile opens an editor
/// with Calories / Protein / Carbs / Fat fields, plus a delete-with-Undo.
Widget _host(FitnessProvider p) {
  return ChangeNotifierProvider<FitnessProvider>.value(
    value: p,
    child: const MaterialApp(home: FoodScreen()),
  );
}

Future<FitnessProvider> _providerWithEntry() async {
  SharedPreferences.setMockInitialValues({});
  // No loadData(): it starts a periodic day-reset timer that trips the widget
  // test's pending-timer guard. addFoodEntry works against the in-memory maps.
  final p = FitnessProvider();
  await p.addFoodEntry(FoodEntry(
    id: 'meal1',
    name: 'Paneer Curry',
    calories: 200,
    protein: 10,
    carbs: 20,
    fat: 5,
    macrosKnown: true,
    mealType: MealType.breakfast,
    timestamp: DateTime.now(),
  ));
  return p;
}

void main() {
  testWidgets('no Dismissible wraps food tiles (swipe-to-delete removed)',
      (t) async {
    final p = await _providerWithEntry();
    await t.pumpWidget(_host(p));
    await t.pumpAndSettle();

    expect(find.text('Paneer Curry'), findsOneWidget);
    expect(find.byType(Dismissible), findsNothing);
  });

  testWidgets('tapping a tile opens the editor with all four macro fields',
      (t) async {
    final p = await _providerWithEntry();
    await t.pumpWidget(_host(p));
    await t.pumpAndSettle();

    await t.tap(find.text('Paneer Curry'));
    await t.pumpAndSettle();

    // Labelled captions on the editor.
    expect(find.text('CALORIES'), findsOneWidget);
    expect(find.text('PROTEIN'), findsOneWidget);
    expect(find.text('CARBS'), findsOneWidget);
    expect(find.text('FAT'), findsOneWidget);
    // Four editable fields prefilled with the entry's macros.
    expect(find.widgetWithText(TextField, '200'), findsOneWidget); // calories
    expect(find.widgetWithText(TextField, '20'), findsOneWidget); // carbs
    expect(find.widgetWithText(TextField, '5'), findsOneWidget); // fat
  });

  testWidgets('editing carbs/fat and saving updates the stored entry',
      (t) async {
    final p = await _providerWithEntry();
    await t.pumpWidget(_host(p));
    await t.pumpAndSettle();

    await t.tap(find.text('Paneer Curry'));
    await t.pumpAndSettle();

    // Field order in the dialog: Calories, Protein, Carbs, Fat.
    final fields = find.byType(TextField);
    await t.enterText(fields.at(2), '33'); // carbs
    await t.enterText(fields.at(3), '9'); // fat
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();

    final entry = p.todayFood.firstWhere((e) => e.id == 'meal1');
    expect(entry.carbs, 33);
    expect(entry.fat, 9);
    expect(entry.macrosKnown, isTrue);
  });

  testWidgets('delete removes the entry and offers Undo', (t) async {
    final p = await _providerWithEntry();
    await t.pumpWidget(_host(p));
    await t.pumpAndSettle();

    await t.tap(find.text('Paneer Curry'));
    await t.pumpAndSettle();
    await t.tap(find.text('Delete'));
    await t.pumpAndSettle();

    expect(p.todayFood.where((e) => e.id == 'meal1'), isEmpty);
    expect(find.text('Undo'), findsOneWidget);

    await t.tap(find.text('Undo'));
    await t.pumpAndSettle();
    expect(p.todayFood.where((e) => e.name == 'Paneer Curry'), isNotEmpty);
  });
}
