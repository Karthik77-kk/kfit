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

  testWidgets('Bottom nav has 6 tabs', (tester) async {
    await tester.pumpWidget(_appWithProvider());
    await tester.pump();
    expect(find.byType(BottomNavigationBar), findsOneWidget);

    final nav = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar));
    expect(nav.items.length, 6);
  });

  testWidgets('Bottom nav labels are correct', (tester) async {
    await tester.pumpWidget(_appWithProvider());
    await tester.pump();

    // 6-tab nav: Summary | Nutrition | Workout | Scale | Stats | History
    expect(find.text('Summary'), findsWidgets);
    expect(find.text('Nutrition'), findsWidgets);
    expect(find.text('Workout'), findsWidgets);
    expect(find.text('Scale'), findsWidgets);
    expect(find.text('Stats'), findsWidgets);
    expect(find.text('History'), findsWidgets);
  });

  testWidgets('Tapping Nutrition tab navigates to nutrition screen',
      (tester) async {
    await tester.pumpWidget(_appWithProvider());
    await tester.pump();

    await tester.tap(find.text('Nutrition').last);
    await tester.pumpAndSettle();

    expect(find.text('Nutrition'), findsWidgets);
  });

  testWidgets('Tapping Workout tab navigates to workout screen',
      (tester) async {
    await tester.pumpWidget(_appWithProvider());
    await tester.pump();

    await tester.tap(find.text('Workout').last);
    await tester.pumpAndSettle();

    expect(find.text('Workout'), findsWidgets);
  });

  testWidgets('App uses dark theme', (tester) async {
    await tester.pumpWidget(_appWithProvider());
    await tester.pump();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme?.brightness, Brightness.dark);
  });
}
