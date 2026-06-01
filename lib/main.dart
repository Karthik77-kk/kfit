import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/fitness_provider.dart';
import 'services/on_device_ai_service.dart';
import 'screens/home_screen.dart';
import 'screens/nutrition_screen.dart';
import 'screens/workout_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/history_screen.dart';
import 'screens/smart_scale_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
        ChangeNotifierProvider(create: (_) => OnDeviceAiService()..init()),
      ],
      child: const KarthikFitnessApp(),
    ),
  );
}

class KarthikFitnessApp extends StatelessWidget {
  const KarthikFitnessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'K Fitness',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF30D158),
          secondary: Color(0xFF40C8E0),
          surface: Color(0xFF1C1C1E),
          onPrimary: Colors.black,
          onSurface: Colors.white,
          error: Color(0xFFFF453A),
        ),
        scaffoldBackgroundColor: Colors.black,
        cardColor: const Color(0xFF1C1C1E),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
          iconTheme: IconThemeData(color: Colors.white),
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF111111),
          selectedItemColor: Color(0xFF30D158),
          unselectedItemColor: Color(0xFF8E8E93),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
          unselectedLabelStyle: TextStyle(fontSize: 10),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Color(0xFF2C2C2E),
          contentTextStyle: TextStyle(color: Colors.white),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2C2C2E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF30D158), width: 1.5),
          ),
          hintStyle: const TextStyle(color: Color(0xFF8E8E93)),
          labelStyle: const TextStyle(color: Color(0xFF8E8E93)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFF38383A),
          thickness: 0.5,
        ),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver {
  int _index = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    NutritionScreen(),
    WorkoutScreen(),
    SmartScaleScreen(),
    StatsScreen(),
    HistoryScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
      body: IndexedStack(
        index: _index,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFF38383A), width: 0.5),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
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
              icon: Icon(Icons.monitor_weight_outlined, size: 24),
              activeIcon: Icon(Icons.monitor_weight_rounded, size: 24),
              label: 'Scale',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined, size: 24),
              activeIcon: Icon(Icons.bar_chart_rounded, size: 24),
              label: 'Stats',
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
