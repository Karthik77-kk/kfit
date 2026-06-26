import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kfit/widgets/heart_splash.dart';

void main() {
  testWidgets('renders the heart + name and fires onDone once after ~3s',
      (tester) async {
    var done = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: HeartSplash(name: 'Jaswini', onDone: () => done++)),
    ));
    await tester.pump(); // first frame

    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.text('Jaswini'), findsOneWidget);
    expect(find.text('Congrats 🎉'), findsOneWidget);
    expect(done, 0);

    await tester.pumpAndSettle(); // run controller to completion (~3s)
    expect(done, 1);

    // Dispose cleanly so the ticker doesn't leak.
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
  });

  testWidgets('does not fire onDone if removed before it completes',
      (tester) async {
    var done = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: HeartSplash(onDone: () => done++)),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Remove before the 3s completes.
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    await tester.pump(const Duration(seconds: 3));

    expect(done, 0);
  });

  testWidgets('defaults the caption to Jaswini', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: HeartSplash(onDone: () {})),
    ));
    await tester.pump();
    expect(find.text('Jaswini'), findsOneWidget);
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
  });
}
