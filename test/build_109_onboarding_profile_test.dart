import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kfit/models/models.dart';
import 'package:kfit/providers/fitness_provider.dart';
import 'package:kfit/screens/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Build 109: onboarding now captures weight/height/age/sex/goal (so the app
/// lights up day one and there's no silent male default), and body-composition
/// thresholds (body-fat %, FFMI) are sex-specific (a lean woman is no longer
/// labelled "Overfat").
SmartScaleEntry _scale({required double bf, double lean = 0}) => SmartScaleEntry(
      id: 's', date: DateTime.now(), weightKg: 70, bodyFatPercent: bf,
      bodyFatKg: 0, muscleMassKg: 0, muscleMassPercent: 0, leanBodyMassKg: lean,
      biologicalAge: 0, visceralFatIndex: 0, bmr: 0, bodyWaterPercent: 0,
      boneMassKg: 0, proteinPercent: 0, skeletalMuscleMassKg: 0,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── Sex-aware body-composition thresholds ──────────────────────────────────
  group('bodyCompositionStatus is sex-specific', () {
    late FitnessProvider p;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      p = FitnessProvider();
      await p.loadData();
    });

    test('30% body fat: Overfat for a man, Average for a woman', () async {
      await p.logScaleEntry(_scale(bf: 30));
      await p.saveSex(true);
      expect(p.bodyCompositionStatus.label, 'Overfat');
      await p.saveSex(false);
      expect(p.bodyCompositionStatus.label, 'Average'); // < 32% female overfat
    });

    test('23% body fat: Average for a man, Lean for a woman', () async {
      await p.logScaleEntry(_scale(bf: 23));
      await p.saveSex(true);
      expect(p.bodyCompositionStatus.label, 'Average');
      await p.saveSex(false);
      expect(p.bodyCompositionStatus.label, 'Lean'); // < 27% female lean
    });

    test('12% body fat is Athletic for both sexes', () async {
      await p.logScaleEntry(_scale(bf: 12));
      await p.saveSex(true);
      expect(p.bodyCompositionStatus.label, 'Athletic');
      await p.saveSex(false);
      expect(p.bodyCompositionStatus.label, 'Athletic');
    });
  });

  group('ffmiStatus is sex-specific', () {
    late FitnessProvider p;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      p = FitnessProvider();
      await p.loadData();
      await p.saveHeight(180); // h = 1.8 → ffmi = lean/3.24
    });

    test('FFMI 17.5: Below average for a man, Athletic for a woman', () async {
      await p.logScaleEntry(_scale(bf: 18, lean: 56.7)); // 56.7/3.24 = 17.5
      expect(p.ffmi, closeTo(17.5, 0.01));
      await p.saveSex(true);
      expect(p.ffmiStatus.label, 'Below average');
      await p.saveSex(false);
      expect(p.ffmiStatus.label, 'Athletic');
    });
  });

  // ── Onboarding profile capture ─────────────────────────────────────────────
  group('onboarding profile capture', () {
    Future<FitnessProvider> pumpOnboarding(WidgetTester tester) async {
      // Tall viewport so the scrollable Profile/Activity pages render fully —
      // otherwise the bottom "Skip for now" button is off-screen and taps miss.
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final provider = FitnessProvider();
      await provider.loadData();
      await tester.pumpWidget(
        ChangeNotifierProvider<FitnessProvider>(
          // create: (not .value) so the widget tree disposes the provider at
          // teardown, cancelling its day-reset Timer (avoids !timersPending).
          create: (_) => provider,
          child: const MaterialApp(home: OnboardingScreen()),
        ),
      );
      await tester.pumpAndSettle();
      return provider;
    }

    testWidgets('saves sex + weight/height/age/goal entered on the profile page',
        (tester) async {
      final p = await pumpOnboarding(tester);

      // Page 0 — name, then Continue → Profile.
      await tester.enterText(
          find.widgetWithText(TextField, 'Enter your name'), 'Asha');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
      await tester.pumpAndSettle();

      // Page 1 — pick Female + fill the four fields.
      await tester.tap(find.text('Female'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('ob_weight')), '60');
      await tester.enterText(find.byKey(const ValueKey('ob_height')), '160');
      await tester.enterText(find.byKey(const ValueKey('ob_age')), '30');
      await tester.enterText(find.byKey(const ValueKey('ob_goal')), '55');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
      await tester.pumpAndSettle();

      // Page 2 — finish via Skip.
      await tester.tap(find.widgetWithText(TextButton, 'Skip for now'));
      await tester.pumpAndSettle();

      expect(p.userName, 'Asha');
      expect(p.isMale, isFalse); // explicitly chose Female — no silent male default
      expect(p.heightCm, 160);
      expect(p.age, 30);
      expect(p.goalWeightKg, 55);
      expect(p.latestWeightKg, 60); // logged as the first body entry
      expect(p.onboardingDone, isTrue);
      // The whole app is now "lit up": BMI/BMR are computable on day one.
      expect(p.bmi, isNotNull);
      expect(p.bmr, isNotNull);
    });

    testWidgets('skipping the profile leaves defaults intact (no crash)',
        (tester) async {
      final p = await pumpOnboarding(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
      await tester.pumpAndSettle();
      // Profile page shown but nothing entered, no sex picked.
      expect(find.text('A bit about you'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Skip for now'));
      await tester.pumpAndSettle();

      expect(p.onboardingDone, isTrue);
      expect(p.isMale, isTrue); // untouched provider default
      expect(p.latestWeightKg, isNull); // no weight logged
    });
  });
}
