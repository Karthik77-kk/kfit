// PR 5 — brand & delight: animated wordmark splash, Weekly Recap story,
// and the milestone-confetti signal on the provider.
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kfit/providers/fitness_provider.dart';
import 'package:kfit/widgets/brand_splash.dart';
import 'package:kfit/screens/weekly_recap_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => call.method == 'getApplicationDocumentsDirectory'
          ? Directory.systemTemp.path
          : null,
    );
  });

  group('BrandSplash', () {
    testWidgets('shows the K wordmark', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: BrandSplash()));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('K Fitness'), findsOneWidget);
      expect(find.text('K'), findsOneWidget);
      await tester.pumpAndSettle(); // let the reveal animation finish
    });
  });

  group('WeeklyRecapScreen', () {
    testWidgets('renders the first slide and advances on tap', (tester) async {
      // Unmount at teardown so the provider's day-reset timer (started in
      // loadData) is disposed before the pending-timer check.
      addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));

      SharedPreferences.setMockInitialValues({'onboarding_done': true});
      final p = FitnessProvider();
      await p.loadData();

      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<FitnessProvider>(create: (_) => p, lazy: false),
        ],
        child: const MaterialApp(home: WeeklyRecapScreen()),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Your week'), findsOneWidget);

      // Tap the right half → next slide.
      await tester.tapAt(const Offset(700, 400));
      await tester.pumpAndSettle();
      expect(find.byType(WeeklyRecapScreen), findsOneWidget);
    });
  });

  group('milestone confetti signal', () {
    test('fresh provider has no pending celebration', () async {
      SharedPreferences.setMockInitialValues({});
      final p = FitnessProvider();
      addTearDown(p.dispose);
      await p.loadData();
      await pumpEventQueue();
      expect(p.hasPendingCelebration, isFalse);
    });

    test('reaching goal weight queues a celebration, then consume clears it',
        () async {
      final now = DateTime.now();
      final body = [
        {
          'id': 'b1',
          'date': now.subtract(const Duration(days: 30)).toIso8601String(),
          'weightKg': 80.0,
          'steps': 0,
        },
        {'id': 'b2', 'date': now.toIso8601String(), 'weightKg': 70.0, 'steps': 0},
      ];
      SharedPreferences.setMockInitialValues({
        'goal_weight_kg': 70.0,
        'body_history': jsonEncode(body),
      });
      final p = FitnessProvider();
      addTearDown(p.dispose);
      await p.loadData();
      // Milestone detection runs via an un-awaited populate — drain it.
      await pumpEventQueue();

      expect(p.hasPendingCelebration, isTrue);
      p.consumeCelebration();
      expect(p.hasPendingCelebration, isFalse);
    });
  });
}
