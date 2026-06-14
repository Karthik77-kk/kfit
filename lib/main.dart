import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'providers/fitness_provider.dart';
import 'services/on_device_ai_service.dart';
import 'theme/app_theme.dart';
import 'theme/app_tokens.dart';
import 'screens/home_screen.dart';
import 'screens/nutrition_screen.dart';
import 'screens/workout_screen.dart';
import 'screens/body_screen.dart';
import 'screens/history_screen.dart';
import 'screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Capture Flutter framework errors (widget build errors, assertion failures)
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details); // show red screen in debug
    _appendCrashLog('FlutterError', details.exceptionAsString(),
        details.stack?.toString() ?? '');
  };

  // Capture uncaught async errors (Future exceptions, stream errors)
  runZonedGuarded(
    () async {
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF000000),
        systemNavigationBarIconBrightness: Brightness.light,
      ));

      runApp(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => FitnessProvider()..loadData()),
            // lazy:false → service created at app start, not at first chat open.
            // Model loading begins immediately in background so it's ready
            // (or nearly ready) by the time the user taps Ask AI.
            ChangeNotifierProvider(
              lazy: false,
              create: (_) => OnDeviceAiService()..init(),
            ),
          ],
          child: const KfitApp(),
        ),
      );
    },
    (error, stack) {
      _appendCrashLog('DartError', error.toString(), stack.toString());
    },
  );
}

/// Appends a crash entry to crash_log.txt in the app documents directory.
/// Exported via "Export Data" so users can share it when reporting bugs.
/// Fire-and-forget — never rethrows or crashes the app itself.
void _appendCrashLog(String type, String error, String stack) {
  getApplicationDocumentsDirectory().then((dir) {
    try {
      final file = File('${dir.path}/crash_log.txt');
      final ts   = DateTime.now().toIso8601String();
      file.writeAsStringSync(
        '[$ts] [$type]\n$error\n$stack\n---\n',
        mode: FileMode.append,
      );
    } catch (_) {
      // If log write fails, swallow — never crash inside an error handler.
    }
  }).catchError((_) {});
}

class KfitApp extends StatelessWidget {
  const KfitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'K Fitness',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: Consumer<FitnessProvider>(
        builder: (context, p, _) {
          if (!p.isLoaded) return const _SplashScreen();
          if (!p.onboardingDone) return const OnboardingScreen();
          return const MainNavigationScreen();
        },
      ),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text('💪', style: TextStyle(fontSize: 72)),
      ),
    );
  }
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  int _index = 0;

  // Drives a quick fade-through of the active tab on switch. IndexedStack keeps
  // every screen mounted (state + correct offstage semantics); this just fades
  // the newly-shown one in.
  late final AnimationController _tabFade;

  final List<Widget> _screens = const [
    HomeScreen(),
    NutritionScreen(),
    WorkoutScreen(),
    BodyScreen(),
    HistoryScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabFade = AnimationController(
        vsync: this, duration: AppDurations.normal, value: 1);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabFade.dispose();
    super.dispose();
  }

  void _onTabTap(int i) {
    if (i == _index) return;
    setState(() => _index = i);
    if (reduceMotion(context)) {
      _tabFade.value = 1;
    } else {
      _tabFade.forward(from: 0);
    }
  }

  /// Refresh all data whenever the app returns to the foreground so the
  /// summary (and every screen) is always current — same as pull-to-refresh.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<FitnessProvider>().loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack keeps all tabs mounted (scroll positions, sub-tab
      // selections, Home's entrance animation) and offstage-hides the inactive
      // ones; the FadeTransition fades the active tab in on each switch.
      body: FadeTransition(
        opacity: _tabFade,
        child: IndexedStack(index: _index, children: _screens),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFF38383A), width: 0.5),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: _onTabTap,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.house_outlined, size: 24),
              activeIcon: Icon(Icons.house_rounded, size: 24),
              label: 'Summary',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.restaurant_menu_outlined, size: 24),
              activeIcon: Icon(Icons.restaurant_menu_rounded, size: 24),
              label: 'Nutrition',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.fitness_center_outlined, size: 24),
              activeIcon: Icon(Icons.fitness_center_rounded, size: 24),
              label: 'Workout',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded, size: 24),
              activeIcon: Icon(Icons.person_rounded, size: 24),
              label: 'Body',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined, size: 24),
              activeIcon: Icon(Icons.history_rounded, size: 24),
              label: 'History',
            ),
          ],
        ),
      ),
    );
  }
}
