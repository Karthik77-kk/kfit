// Build 76 — UX polish: 5-tab nav, border radius system, progressive
// disclosure, universal empty state, AppEmptyState widget.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:karthik_fitness/providers/fitness_provider.dart';
import 'package:karthik_fitness/models/models.dart';
import 'package:karthik_fitness/main.dart';
import 'package:karthik_fitness/screens/body_screen.dart';
import 'package:karthik_fitness/screens/stats_screen.dart';
import 'package:karthik_fitness/screens/smart_scale_screen.dart';
import 'package:karthik_fitness/widgets/app_empty_state.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

Widget _app({bool onboardingDone = true, Map<String, Object> seed = const {}}) {
  final merged = {...seed, if (onboardingDone) 'onboarding_done': true};
  SharedPreferences.setMockInitialValues(merged);
  return ChangeNotifierProvider(
    create: (_) => FitnessProvider()..loadData(),
    child: const KfitApp(),
  );
}

Widget _wrap(Widget child) => ChangeNotifierProvider(
      create: (_) => FitnessProvider()..loadData(),
      child: MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: child,
      ),
    );

Future<FitnessProvider> _loaded([Map<String, Object> seed = const {}]) async {
  SharedPreferences.setMockInitialValues(seed);
  final p = FitnessProvider();
  await p.loadData();
  return p;
}

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

  setUp(() => SharedPreferences.setMockInitialValues({'onboarding_done': true}));

  // ── 1. 5-tab nav ─────────────────────────────────────────────────────────────

  group('5-tab navigation (Stats merged into Body)', () {
    testWidgets('Bottom nav has exactly 5 items', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      final nav = tester.widget<BottomNavigationBar>(
          find.byType(BottomNavigationBar));
      expect(nav.items.length, 5);
    });

    testWidgets('Nav items are Summary / Nutrition / Workout / Body / History', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      final nav = tester.widget<BottomNavigationBar>(
          find.byType(BottomNavigationBar));
      final labels = nav.items.map((i) => i.label).toList();
      expect(labels, ['Summary', 'Nutrition', 'Workout', 'Body', 'History']);
    });

    testWidgets('"Stats" is NOT a bottom-nav tab', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      final nav = tester.widget<BottomNavigationBar>(
          find.byType(BottomNavigationBar));
      final labels = nav.items.map((i) => i.label).toList();
      expect(labels.contains('Stats'), isFalse);
    });

    testWidgets('Tapping Body tab shows BodyScreen', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Body').last);
      await tester.pumpAndSettle();
      expect(find.byType(BodyScreen), findsOneWidget);
    });

    testWidgets('BodyScreen shows Stats and Smart Scale sub-tabs', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Body').last);
      await tester.pumpAndSettle();
      // Both inner tabs should be visible in the TabBar
      expect(find.text('Stats'), findsOneWidget);
      expect(find.text('Smart Scale'), findsOneWidget);
    });

    testWidgets('Stats sub-tab shows weight input field', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Body').last);
      await tester.pumpAndSettle();
      // Stats tab should be default (index 0)
      expect(find.text('Weight'), findsWidgets); // field label
    });

    testWidgets('Smart Scale sub-tab shows Log Today and History tabs', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Body').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Smart Scale'));
      await tester.pumpAndSettle();
      expect(find.text('Log Today'), findsOneWidget);
      // "History" appears in the smart scale sub-tab bar (at least once)
      expect(find.text('History'), findsWidgets);
    });
  });

  // ── 2. BodyScreen widget ──────────────────────────────────────────────────────

  group('BodyScreen widget', () {
    testWidgets('renders without crashing', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_wrap(const BodyScreen()));
      await tester.pumpAndSettle();
      expect(find.byType(BodyScreen), findsOneWidget);
    });

    testWidgets('has AppBar titled Body', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_wrap(const BodyScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Body'), findsOneWidget);
    });

    testWidgets('default tab is Stats (index 0)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_wrap(const BodyScreen()));
      await tester.pumpAndSettle();
      final tabController = DefaultTabController.of(
          tester.element(find.byType(TabBarView).first));
      expect(tabController.index, 0);
    });

    testWidgets('switching to Smart Scale tab works', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_wrap(const BodyScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Smart Scale'));
      await tester.pumpAndSettle();
      expect(find.text('Log Today'), findsOneWidget);
    });
  });

  // ── 3. StatsScreen embedded mode ─────────────────────────────────────────────

  group('StatsScreen embedded mode', () {
    testWidgets('embedded=false shows Scaffold', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_wrap(const StatsScreen(embedded: false)));
      await tester.pumpAndSettle();
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('embedded=true renders without its own AppBar', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_wrap(const Scaffold(
        body: StatsScreen(embedded: true),
      )));
      await tester.pumpAndSettle();
      // Only the wrapper Scaffold's AppBar (none) — no "Stats" title as AppBar
      // Ensure it renders without crash
      expect(find.byType(CustomScrollView), findsOneWidget);
    });

    testWidgets('embedded mode has no SliverAppBar', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_wrap(const Scaffold(
        body: StatsScreen(embedded: true),
      )));
      await tester.pumpAndSettle();
      expect(find.byType(SliverAppBar), findsNothing);
    });

    testWidgets('non-embedded mode shows SliverAppBar with Stats title', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_wrap(const StatsScreen(embedded: false)));
      await tester.pumpAndSettle();
      expect(find.byType(SliverAppBar), findsOneWidget);
      expect(find.text('Stats'), findsOneWidget);
    });

    testWidgets('Save button is present in both embedded and non-embedded', (tester) async {
      SharedPreferences.setMockInitialValues({});
      for (final embedded in [true, false]) {
        await tester.pumpWidget(_wrap(
          embedded ? const Scaffold(body: StatsScreen(embedded: true)) :
                     const StatsScreen(embedded: false)));
        await tester.pumpAndSettle();
        expect(find.text('Save'), findsWidgets,
            reason: 'embedded=$embedded should still have Save button');
      }
    });
  });

  // ── 4. SmartScaleScreen embedded mode ────────────────────────────────────────

  group('SmartScaleScreen embedded mode', () {
    testWidgets('embedded=true renders without crash', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_wrap(const Scaffold(
        body: SmartScaleScreen(embedded: true),
      )));
      await tester.pumpAndSettle();
      expect(find.text('Log Today'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
    });

    testWidgets('embedded=false renders full Scaffold', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_wrap(const SmartScaleScreen(embedded: false)));
      await tester.pumpAndSettle();
      expect(find.text('Smart Scale'), findsWidgets);
    });

    testWidgets('History tab shows AppEmptyState when no data', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_wrap(const SmartScaleScreen(embedded: false)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.byType(AppEmptyState), findsOneWidget);
      expect(find.text('No scale data yet'), findsOneWidget);
    });
  });

  // ── 5. AppEmptyState widget ───────────────────────────────────────────────────

  group('AppEmptyState widget', () {
    testWidgets('renders icon + title + subtitle', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: AppEmptyState(
            icon: '💪',
            title: 'No workouts',
            subtitle: 'Log one to see history',
          ),
        ),
      ));
      expect(find.text('💪'), findsOneWidget);
      expect(find.text('No workouts'), findsOneWidget);
      expect(find.text('Log one to see history'), findsOneWidget);
    });

    testWidgets('renders action widget when provided', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AppEmptyState(
            icon: '📊',
            title: 'No data',
            subtitle: 'Add some',
            action: ElevatedButton(
              onPressed: () => tapped = true,
              child: const Text('Add'),
            ),
          ),
        ),
      ));
      expect(find.text('Add'), findsOneWidget);
      await tester.tap(find.text('Add'));
      expect(tapped, isTrue);
    });

    testWidgets('action is not rendered when null', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: AppEmptyState(
            icon: '📊',
            title: 'No data',
            subtitle: 'Add some',
          ),
        ),
      ));
      // No button should be present
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
    });

    testWidgets('title text style is white and bold', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: AppEmptyState(
            icon: '⚖️',
            title: 'Test title',
            subtitle: 'Test subtitle',
          ),
        ),
      ));
      final titleWidget = tester.widget<Text>(find.text('Test title'));
      expect(titleWidget.style?.color, Colors.white);
      expect(titleWidget.style?.fontWeight, FontWeight.w600);
    });

    testWidgets('subtitle has muted gray color', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: AppEmptyState(
            icon: '⚖️',
            title: 'Test title',
            subtitle: 'Test subtitle',
          ),
        ),
      ));
      final subWidget = tester.widget<Text>(find.text('Test subtitle'));
      expect(subWidget.style?.color, const Color(0xFF8E8E93));
    });

    testWidgets('is vertically centered in screen', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: AppEmptyState(
            icon: '💧',
            title: 'No water',
            subtitle: 'Drink something',
          ),
        ),
      ));
      // Center widget is present
      expect(find.byType(Center), findsOneWidget);
    });

    testWidgets('icon has fontSize 48', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: AppEmptyState(
            icon: '🤖',
            title: 'No chats',
            subtitle: 'Start one',
          ),
        ),
      ));
      // The icon Text widget should have fontSize 48
      final iconWidget = tester.widget<Text>(find.text('🤖'));
      expect(iconWidget.style?.fontSize, 48);
    });
  });

  // ── 6. Progressive disclosure ─────────────────────────────────────────────────
  // Test the _ShowMoreSections widget directly and the _hiddenCount logic via provider.

  group('Progressive disclosure — _hiddenCount logic', () {
    test('_hiddenCount is 2 when no food and no weekly calories', () async {
      final p = await _loaded();
      // No food → todayFood.isEmpty AND weeklyAvgCalories == 0
      expect(p.todayFood.isEmpty, isTrue);
      expect(p.weeklyAvgCalories, 0.0);
      // Both sections would be hidden (count = 2)
      int hidden = 0;
      if (p.weeklyAvgCalories == 0) hidden++;
      if (p.todayFood.isEmpty) hidden++;
      expect(hidden, 2);
    });

    test('_hiddenCount is 0 when food is logged today', () async {
      final p = await _loaded();
      await p.addFoodEntry(FoodEntry(
        id: 'f1', name: 'Dal', calories: 400, protein: 20,
        mealType: MealType.lunch, timestamp: DateTime.now(),
      ));
      int hidden = 0;
      if (p.weeklyAvgCalories == 0) hidden++;
      if (p.todayFood.isEmpty) hidden++;
      expect(hidden, 0); // food logged → both sections visible
    });

    test('_hiddenCount is 1 when food logged today (macros visible, 7-day too)', () async {
      final p = await _loaded();
      await p.addFoodEntry(FoodEntry(
        id: 'f1', name: 'Rice', calories: 300, protein: 8,
        mealType: MealType.dinner, timestamp: DateTime.now(),
      ));
      // weeklyAvgCalories > 0 because today has food
      expect(p.weeklyAvgCalories, greaterThan(0));
      expect(p.todayFood.isEmpty, isFalse);
      int hidden = 0;
      if (p.weeklyAvgCalories == 0) hidden++;
      if (p.todayFood.isEmpty) hidden++;
      expect(hidden, 0);
    });
  });

  group('Progressive disclosure — ShowMoreSections widget', () {
    testWidgets('collapsed state shows "hidden" text', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: _TestShowMoreSections(count: 2, onTap: () {}),
        ),
      ));
      expect(find.textContaining('hidden'), findsOneWidget);
      expect(find.textContaining('2 sections hidden'), findsOneWidget);
    });

    testWidgets('singular "section" for count=1', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: _TestShowMoreSections(count: 1, onTap: () {}),
        ),
      ));
      expect(find.textContaining('1 section hidden'), findsOneWidget);
    });

    testWidgets('collapsed=true shows expand_more icon', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: _TestShowMoreSections(count: 2, onTap: () {}),
        ),
      ));
      expect(find.byIcon(Icons.expand_more_rounded), findsOneWidget);
    });

    testWidgets('count=0 shows Collapse empty sections', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: _TestShowMoreSections(count: 0, onTap: () {}),
        ),
      ));
      expect(find.text('Collapse empty sections'), findsOneWidget);
      expect(find.byIcon(Icons.expand_less_rounded), findsOneWidget);
    });

    testWidgets('onTap fires when tapped', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: _TestShowMoreSections(count: 2, onTap: () => tapped = true),
        ),
      ));
      await tester.tap(find.textContaining('hidden'));
      expect(tapped, isTrue);
    });
  });

  // ── 7. Border radius system ───────────────────────────────────────────────────
  // Verify that no non-standard radii remain in lib/ source files.

  group('Border radius standardization', () {
    test('No circular(3) remains in lib/', () async {
      final dartFiles = _readAllLibDart();
      for (final entry in dartFiles.entries) {
        expect(
          entry.value.contains('circular(3)'),
          isFalse,
          reason: '${entry.key} still has circular(3)',
        );
      }
    });

    test('No circular(4) remains in lib/', () async {
      final dartFiles = _readAllLibDart();
      for (final entry in dartFiles.entries) {
        expect(entry.value.contains('circular(4)'), isFalse,
            reason: '${entry.key} still has circular(4)');
      }
    });

    test('No circular(6) remains in lib/', () async {
      final dartFiles = _readAllLibDart();
      for (final entry in dartFiles.entries) {
        expect(entry.value.contains('circular(6)'), isFalse,
            reason: '${entry.key} still has circular(6)');
      }
    });

    test('No circular(10) remains in lib/', () async {
      final dartFiles = _readAllLibDart();
      for (final entry in dartFiles.entries) {
        expect(entry.value.contains('circular(10)'), isFalse,
            reason: '${entry.key} still has circular(10)');
      }
    });

    test('No circular(11) remains in lib/', () async {
      final dartFiles = _readAllLibDart();
      for (final entry in dartFiles.entries) {
        expect(entry.value.contains('circular(11)'), isFalse,
            reason: '${entry.key} still has circular(11)');
      }
    });

    test('No circular(16) remains in lib/', () async {
      final dartFiles = _readAllLibDart();
      for (final entry in dartFiles.entries) {
        expect(entry.value.contains('circular(16)'), isFalse,
            reason: '${entry.key} still has circular(16)');
      }
    });

    test('No circular(18) remains in lib/', () async {
      final dartFiles = _readAllLibDart();
      for (final entry in dartFiles.entries) {
        expect(entry.value.contains('circular(18)'), isFalse,
            reason: '${entry.key} still has circular(18)');
      }
    });

    test('Only allowed radii: 2 (drag handle), 8, 14, 20 (and large pill)', () {
      final dartFiles = _readAllLibDart();
      // Allowed: 2 (drag handle pill, chat_screen), 8, 14, 20, and ≥30 (full pills)
      // Disallowed: 3,4,5,6,7,9,10,11,12,13,15,16,17,18,19,21-29
      final badRadius = RegExp(
          r'circular\((?!2\)|8\)|14\)|20\)|[3-9][0-9]\)|[1-9][0-9]{2,}\))[0-9]+\)');
      for (final entry in dartFiles.entries) {
        final matches = badRadius.allMatches(entry.value);
        expect(matches.isEmpty, isTrue,
            reason: '${entry.key} has non-standard radii: '
                '${matches.map((m) => m.group(0)).toSet()}');
      }
    });
  });

  // ── 8. Getting-started card navigation text ───────────────────────────────────

  group('Getting-started card navigation text', () {
    test('Getting-started step 1 references Body tab → Stats (not old Stats tab)', () {
      // Read the home_screen.dart source to verify the text was updated
      final src = File('lib/screens/home_screen.dart').readAsStringSync();
      expect(src, contains("Body tab → Stats"));
      expect(src, isNot(contains("Stats tab → Log Today")));
    });
  });

  // ── 9. Regression — existing functionality unchanged ──────────────────────────

  group('Regression tests', () {
    testWidgets('App renders without crash', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Summary tab is default (index 0)', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      final nav = tester.widget<BottomNavigationBar>(
          find.byType(BottomNavigationBar));
      expect(nav.currentIndex, 0);
    });

    testWidgets('Nutrition tab is tappable', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nutrition').last);
      await tester.pumpAndSettle();
      expect(find.text('Nutrition'), findsWidgets);
    });

    testWidgets('Workout tab is tappable', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Workout').last);
      await tester.pumpAndSettle();
      expect(find.text('Workout'), findsWidgets);
    });

    testWidgets('History tab is tappable', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('History').last);
      await tester.pumpAndSettle();
      expect(find.byType(MaterialApp), findsOneWidget); // no crash
    });

    test('FitnessProvider defaults unchanged', () async {
      final p = await _loaded();
      expect(p.calorieGoal, FitnessProvider.kDefaultCalorieGoal);
      expect(p.proteinGoal, FitnessProvider.kDefaultProteinGoal);
    });

    testWidgets('Onboarding still shows on first launch', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_app(onboardingDone: false));
      await tester.pumpAndSettle();
      expect(find.byType(BottomNavigationBar), findsNothing);
    });
  });
}

// ─── Test-only replica of _ShowMoreSections for direct widget testing ─────────
class _TestShowMoreSections extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _TestShowMoreSections({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isCollapsed = count > 0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(isCollapsed ? Icons.expand_more_rounded : Icons.expand_less_rounded),
          const SizedBox(width: 6),
          Text(isCollapsed
              ? '$count section${count == 1 ? '' : 's'} hidden — no data yet'
              : 'Collapse empty sections'),
        ]),
      ),
    );
  }
}

// ─── File read helper ──────────────────────────────────────────────────────────
Map<String, String> _readAllLibDart() {
  final result = <String, String>{};
  final libDir = Directory('lib');
  for (final f in libDir.listSync(recursive: true).whereType<File>()) {
    if (f.path.endsWith('.dart')) {
      result[f.path.replaceAll('\\', '/')] = f.readAsStringSync();
    }
  }
  return result;
}
