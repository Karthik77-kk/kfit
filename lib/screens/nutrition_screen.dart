import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/fitness_provider.dart';
import '../services/nav_router.dart';
import 'food_screen.dart';
import 'water_screen.dart';
import 'supplements_screen.dart';

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  // NavRouter integration — drives deep-link sub-tab jumps from widget taps.
  NavRouter? _navRouter;
  VoidCallback? _navListener;
  int _lastRequestId = -1;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() {
      if (!_tab.indexIsChanging) setState(() {});
    });
    // Attach NavRouter listener after the first frame so context is stable.
    WidgetsBinding.instance.addPostFrameCallback((_) => _initNavListener());
  }

  void _initNavListener() {
    if (!mounted) return;
    // NavRouter is provided in production; tolerate its absence in focused
    // widget tests by skipping deep-link sub-tab wiring rather than throwing.
    final NavRouter router;
    try {
      router = context.read<NavRouter>();
    } catch (_) {
      return;
    }
    _navRouter = router;
    _navListener = () {
      if (!mounted) return;
      final r = _navRouter!;
      // Only react if this is a new request targeting the Nutrition tab (1).
      if (r.tabIndex == 1 && r.requestId != _lastRequestId) {
        _lastRequestId = r.requestId;
        _tab.animateTo(r.nutritionSubTab.clamp(0, 2));
      }
    };
    router.addListener(_navListener!);
  }

  @override
  void dispose() {
    if (_navListener != null) _navRouter?.removeListener(_navListener!);
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<FitnessProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutrition'),
        actions: [
          // Show calorie/protein summary in the AppBar when on Food tab
          if (_tab.index == 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${p.todayCaloriesTotal.toInt()} / ${p.calorieGoal} kcal',
                    style: TextStyle(
                      color: p.todayCaloriesTotal > p.calorieGoal
                          ? Colors.redAccent
                          : const Color(0xFF30D158),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${p.todayProteinTotal.toInt()}g protein',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                  ),
                ],
              ),
            ),
          // Show water summary on Water tab
          if (_tab.index == 1)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${p.todayWaterMl} / ${p.waterGoalMl} ml',
                    style: TextStyle(
                      color: p.todayWaterMl >= p.waterGoalMl
                          ? const Color(0xFF30D158)
                          : const Color(0xFF40C8E0),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${(p.waterProgress * 100).toInt()}% of goal',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                  ),
                ],
              ),
            ),
          // Show supplement count on Supplements tab
          if (_tab.index == 2)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${p.supplements.takenCount}/3 taken',
                    style: TextStyle(
                      color: p.supplements.takenCount == 3
                          ? const Color(0xFF30D158)
                          : const Color(0xFF40C8E0),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'today',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                  ),
                ],
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: const Color(0xFF30D158),
          labelColor: const Color(0xFF30D158),
          unselectedLabelColor: const Color(0xFF8E8E93),
          indicatorWeight: 2.5,
          tabs: const [
            Tab(
              icon: Icon(Icons.restaurant_menu_outlined, size: 20),
              text: 'Food',
              iconMargin: EdgeInsets.only(bottom: 2),
            ),
            Tab(
              icon: Icon(Icons.water_drop_outlined, size: 20),
              text: 'Water',
              iconMargin: EdgeInsets.only(bottom: 2),
            ),
            Tab(
              icon: Icon(Icons.medication_liquid_outlined, size: 20),
              text: 'Supplements',
              iconMargin: EdgeInsets.only(bottom: 2),
            ),
          ],
        ),
      ),
      // FAB only appears on the Food tab
      floatingActionButton: _tab.index == 0
          ? FloatingActionButton.extended(
              onPressed: () => showAddFoodSheet(context),
              backgroundColor: const Color(0xFF30D158),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add Food',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            )
          : null,
      body: TabBarView(
        controller: _tab,
        children: const [
          FoodScreen(embedded: true),
          WaterScreen(embedded: true),
          SupplementsScreen(embedded: true),
        ],
      ),
    );
  }
}
