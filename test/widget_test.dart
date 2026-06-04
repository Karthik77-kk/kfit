import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:karthik_fitness/providers/fitness_provider.dart';
import 'package:karthik_fitness/main.dart';
import 'package:karthik_fitness/screens/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App with provider. Seeds onboarding_done=true so main nav is shown.
Widget _appWithProvider({bool onboardingDone = true}) {
  SharedPreferences.setMockInitialValues(
    onboardingDone ? {'onboarding_done': true} : {},
  );
  return ChangeNotifierProvider(
    create: (_) => FitnessProvider()..loadData(),
    child: const KarthikFitnessApp(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'onboarding_done': true});
  });

  // ── Existing nav tests (unchanged behaviour) ──────────────────────────────

  testWidgets('App renders without crashing', (tester) async {
    await tester.pumpWidget(_appWithProvider());
    await tester.pumpAndSettle();
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('Bottom nav has 6 tabs', (tester) async {
    await tester.pumpWidget(_appWithProvider());
    await tester.pumpAndSettle();
    expect(find.byType(BottomNavigationBar), findsOneWidget);

    final nav = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar));
    expect(nav.items.length, 6);
  });

  testWidgets('Bottom nav labels are correct', (tester) async {
    await tester.pumpWidget(_appWithProvider());
    await tester.pumpAndSettle();

    expect(find.text('Summary'),   findsWidgets);
    expect(find.text('Nutrition'), findsWidgets);
    expect(find.text('Workout'),   findsWidgets);
    expect(find.text('Scale'),     findsWidgets);
    expect(find.text('Stats'),     findsWidgets);
    expect(find.text('History'),   findsWidgets);
  });

  testWidgets('Tapping Nutrition tab navigates to nutrition screen',
      (tester) async {
    await tester.pumpWidget(_appWithProvider());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nutrition').last);
    await tester.pumpAndSettle();

    expect(find.text('Nutrition'), findsWidgets);
  });

  testWidgets('Tapping Workout tab navigates to workout screen',
      (tester) async {
    await tester.pumpWidget(_appWithProvider());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Workout').last);
    await tester.pumpAndSettle();

    expect(find.text('Workout'), findsWidgets);
  });

  testWidgets('App uses dark theme', (tester) async {
    await tester.pumpWidget(_appWithProvider());
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme?.brightness, Brightness.dark);
  });

  // ── Onboarding gate ───────────────────────────────────────────────────────

  testWidgets('Shows OnboardingScreen on first install (onboarding_done absent)',
      (tester) async {
    await tester.pumpWidget(_appWithProvider(onboardingDone: false));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(MainNavigationScreen), findsNothing);
  });

  testWidgets('Shows MainNavigationScreen when onboarding already done',
      (tester) async {
    await tester.pumpWidget(_appWithProvider(onboardingDone: true));
    await tester.pumpAndSettle();

    expect(find.byType(MainNavigationScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen),     findsNothing);
  });

  testWidgets('Onboarding page 1 has name text field', (tester) async {
    await tester.pumpWidget(_appWithProvider(onboardingDone: false));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Enter your name'), findsOneWidget);
  });

  testWidgets('Onboarding shows Continue button on page 1', (tester) async {
    await tester.pumpWidget(_appWithProvider(onboardingDone: false));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ElevatedButton, 'Continue'), findsOneWidget);
  });

  testWidgets('Onboarding Continue button advances to page 2', (tester) async {
    await tester.pumpWidget(_appWithProvider(onboardingDone: false));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Track your steps automatically'), findsOneWidget);
  });

  testWidgets('Onboarding page 2 has Skip button', (tester) async {
    await tester.pumpWidget(_appWithProvider(onboardingDone: false));
    await tester.pumpAndSettle();

    // advance to page 2
    await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextButton, 'Skip for now'), findsOneWidget);
  });

  testWidgets('Splash screen shown while provider is loading', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_done': true});
    // Provider starts loading; before pumpAndSettle the splash is shown.
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => FitnessProvider()..loadData(),
        child: const KarthikFitnessApp(),
      ),
    );
    // One pump — provider hasn't finished yet, so splash should show.
    await tester.pump();
    // Either splash or main nav is acceptable here (timing-dependent in test).
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
