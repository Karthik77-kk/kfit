import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kfit/widgets/kit/kit.dart';

/// PR 2 (instant-premium): component kit + motion primitives.
void main() {
  // Pumps [child] with animations disabled (reduce-motion ON) so animated
  // widgets render their final state on the first frame.
  Future<void> pumpReduced(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Scaffold(body: Center(child: child)),
      ),
    ));
  }

  group('CountUpText', () {
    testWidgets('reduce-motion shows the final value immediately', (tester) async {
      await pumpReduced(tester, const CountUpText(213, signed: true));
      expect(find.text('+213'), findsOneWidget);
    });

    testWidgets('signed negative keeps its minus sign', (tester) async {
      await pumpReduced(tester, const CountUpText(-50, signed: true));
      expect(find.text('-50'), findsOneWidget);
    });

    testWidgets('suffix + decimals format like Text', (tester) async {
      await pumpReduced(tester, const CountUpText(67, suffix: '%'));
      expect(find.text('67%'), findsOneWidget);
      await pumpReduced(tester, const CountUpText(72.5, decimals: 1, suffix: ' kg'));
      expect(find.text('72.5 kg'), findsOneWidget);
    });

    testWidgets('animates up to the final value over time', (tester) async {
      // Motion enabled (default): the value rolls from 0 → 100.
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: CountUpText(100))),
      ));
      // Mid-flight it should not yet be at the final value.
      await tester.pump(const Duration(milliseconds: 10));
      expect(find.text('100'), findsNothing);
      // After the animation completes it lands on the final value.
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('100'), findsOneWidget);
    });
  });

  group('SectionHeader', () {
    testWidgets('renders its label', (tester) async {
      await pumpReduced(tester, const SectionHeader('TODAY\'S ACTIVITY'));
      expect(find.text('TODAY\'S ACTIVITY'), findsOneWidget);
    });
  });

  group('AppCard', () {
    testWidgets('uses an InkWell + fires onTap when tappable', (tester) async {
      var tapped = 0;
      await pumpReduced(
        tester,
        AppCard(onTap: () => tapped++, child: const Text('tap me')),
      );
      expect(find.byType(InkWell), findsOneWidget);
      await tester.tap(find.text('tap me'));
      expect(tapped, 1);
    });

    testWidgets('no InkWell when not tappable', (tester) async {
      await pumpReduced(tester, const AppCard(child: Text('static')));
      expect(find.byType(InkWell), findsNothing);
      expect(find.text('static'), findsOneWidget);
    });
  });
}
