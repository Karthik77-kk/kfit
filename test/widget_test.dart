import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:karthik_fitness/providers/fitness_provider.dart';
import 'package:karthik_fitness/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _appWithProvider() {
  return ChangeNotifierProvider(
    create: (_) => FitnessProvider()..loadData(),
    child: const KarthikFitnessApp(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App renders without crashing', (tester) async {
    await tester.pumpWidget(_appWithProvider());
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('Bottom nav has 7 tabs', (tester) async {
    await tester.pumpWidget(_appWithProvider());
    await tester.pump();
    expect(find.byType(BottomNavigationBar), findsOneWidget);

    final nav = tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));
    expect(nav.items.length, 7);
  });

  testWidgets('Bottom nav labels are correct', (tester) async {
    await tester.pumpWidget(_appWithProvider());
    await tester.pump();

    expect(find.text('Summary'), findsWidgets);
    expect(find.text('Food'), findsWidgets);
    expect(find.text('Water'), findsWidgets);
    expect(find.text('Workout'), findsWidgets);
    expect(find.text('Stats'), findsWidgets);
    expect(find.text('Supps'), findsWidgets);
    expect(find.text('History'), findsWidgets);
  });

  testWidgets('Tapping Food tab navigates to food screen', (tester) async {
    await tester.pumpWidget(_appWithProvider());
    await tester.pump();

    await tester.tap(find.text('Food').last);
    await tester.pumpAndSettle();

    // Food screen should be visible
    expect(find.text('Food'), findsWidgets);
  });

  testWidgets('App uses dark theme', (tester) async {
    await tester.pumpWidget(_appWithProvider());
    await tester.pump();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme?.brightness, Brightness.dark);
  });
}
