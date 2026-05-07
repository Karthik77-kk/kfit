import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/fitness_provider.dart';
import '../models/models.dart';

class FoodScreen extends StatelessWidget {
  const FoodScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<FitnessProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Tracker 🍽️'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${p.todayCalories.toInt()} / ${FitnessProvider.kCalorieGoal} kcal',
                  style: TextStyle(
                    color: p.todayCalories > FitnessProvider.kCalorieGoal
                        ? Colors.redAccent
                        : const Color(0xFFFF6B35),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${p.todayProtein.toInt()}g protein',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.5), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddFoodSheet(context),
        backgroundColor: const Color(0xFFFF6B35),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Food', style: TextStyle(color: Colors.white)),
      ),
      body: p.todayFood.isEmpty
          ? _EmptyState()
          : ListView(
              padding: const EdgeInsets.only(bottom: 100, top: 8),
              children: [
                _MealSection(
                  title: '☀️ Breakfast',
                  entries: p.breakfastEntries,
                  mealType: MealType.breakfast,
                  provider: p,
                ),
                _MealSection(
                  title: '🌤️ Lunch',
                  entries: p.lunchEntries,
                  mealType: MealType.lunch,
                  provider: p,
                ),
                _MealSection(
                  title: '🌙 Dinner',
                  entries: p.dinnerEntries,
                  mealType: MealType.dinner,
                  provider: p,
                ),
                _MealSection(
                  title: '🍎 Snacks',
                  entries: p.snackEntries,
                  mealType: MealType.snack,
                  provider: p,
                ),
              ],
            ),
    );
  }

  void _showAddFoodSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _AddFoodSheet(),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🍽️', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 16),
          const Text(
            'No food logged today',
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + Add Food to start logging',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _MealSection extends StatelessWidget {
  final String title;
  final List<FoodEntry> entries;
  final MealType mealType;
  final FitnessProvider provider;

  const _MealSection({
    required this.title,
    required this.entries,
    required this.mealType,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (entries.isNotEmpty)
                Text(
                  '${entries.fold(0.0, (s, e) => s + e.calories).toInt()} kcal',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              'Nothing logged',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.25), fontSize: 12),
            ),
          )
        else
          ...entries.map(
            (entry) => Dismissible(
              key: Key(entry.id),
              direction: DismissDirection.endToStart,
              background: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(Icons.delete_outline, color: Colors.red),
              ),
              onDismissed: (_) => provider.removeFoodEntry(entry.id),
              child: _FoodEntryTile(entry: entry),
            ),
          ),
      ],
    );
  }
}

class _FoodEntryTile extends StatelessWidget {
  final FoodEntry entry;
  const _FoodEntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.white.withOpacity(0.06), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              entry.name,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.calories.toInt()} kcal',
                style: const TextStyle(
                  color: Color(0xFFFF6B35),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                '${entry.protein.toStringAsFixed(1)}g protein',
                style: TextStyle(
                    color: const Color(0xFF4ECDC4).withOpacity(0.8),
                    fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Add Food Bottom Sheet ──────────────────────────────────────────────────────

class _AddFoodSheet extends StatefulWidget {
  const _AddFoodSheet();

  @override
  State<_AddFoodSheet> createState() => _AddFoodSheetState();
}

class _AddFoodSheetState extends State<_AddFoodSheet> {
  final _searchController = TextEditingController();
  MealType _selectedMeal = MealType.breakfast;
  String _search = '';
  bool _showCustom = false;

  // Custom entry controllers
  final _nameCtrl = TextEditingController();
  final _calCtrl = TextEditingController();
  final _protCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Auto-select meal type based on time
    final h = DateTime.now().hour;
    if (h >= 5 && h < 11) _selectedMeal = MealType.breakfast;
    else if (h >= 11 && h < 16) _selectedMeal = MealType.lunch;
    else if (h >= 16 && h < 21) _selectedMeal = MealType.dinner;
    else _selectedMeal = MealType.snack;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameCtrl.dispose();
    _calCtrl.dispose();
    _protCtrl.dispose();
    super.dispose();
  }

  List<FoodItem> get _filtered {
    if (_search.isEmpty) return kFoodDatabase;
    return kFoodDatabase
        .where((f) => f.name.toLowerCase().contains(_search.toLowerCase()))
        .toList();
  }

  void _addItem(BuildContext ctx, FoodItem item) {
    final provider = ctx.read<FitnessProvider>();
    provider.addFoodEntry(FoodEntry(
      id: provider.newId(),
      name: item.name,
      calories: item.calories,
      protein: item.protein,
      mealType: _selectedMeal,
      timestamp: DateTime.now(),
    ));
    Navigator.pop(ctx);
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text('${item.name} added ✓'),
      backgroundColor: const Color(0xFF27AE60),
      duration: const Duration(seconds: 1),
    ));
  }

  void _addCustom(BuildContext ctx) {
    final name = _nameCtrl.text.trim();
    final cal = double.tryParse(_calCtrl.text) ?? 0;
    final prot = double.tryParse(_protCtrl.text) ?? 0;
    if (name.isEmpty || cal == 0) return;

    final provider = ctx.read<FitnessProvider>();
    provider.addFoodEntry(FoodEntry(
      id: provider.newId(),
      name: name,
      calories: cal,
      protein: prot,
      mealType: _selectedMeal,
      timestamp: DateTime.now(),
    ));
    Navigator.pop(ctx);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Add Food',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              // Meal type selector
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: MealType.values.map((mt) {
                    final labels = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];
                    final selected = _selectedMeal == mt;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedMeal = mt),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFFFF6B35)
                              : Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          labels[mt.index],
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.white.withOpacity(0.6),
                            fontSize: 13,
                            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Search food...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                    prefixIcon:
                        Icon(Icons.search, color: Colors.white.withOpacity(0.4)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.07),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),

              // Custom entry toggle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => setState(() => _showCustom = !_showCustom),
                      icon: Icon(
                        _showCustom ? Icons.expand_less : Icons.add,
                        size: 18,
                        color: const Color(0xFF4ECDC4),
                      ),
                      label: Text(
                        _showCustom ? 'Hide custom entry' : 'Add custom food',
                        style: const TextStyle(
                            color: Color(0xFF4ECDC4), fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

              if (_showCustom) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _MiniField(ctrl: _nameCtrl, hint: 'Food name'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MiniField(
                            ctrl: _calCtrl,
                            hint: 'kcal',
                            keyboard: TextInputType.number),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MiniField(
                            ctrl: _protCtrl,
                            hint: 'prot g',
                            keyboard: TextInputType.number),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _addCustom(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B35),
                          padding: const EdgeInsets.all(12),
                          minimumSize: Size.zero,
                        ),
                        child: const Icon(Icons.check,
                            color: Colors.white, size: 18),
                      ),
                    ],
                  ),
                ),
              ],

              // Food list
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.only(bottom: 20),
                  itemCount: _filtered.length,
                  itemBuilder: (ctx, i) {
                    final item = _filtered[i];
                    return ListTile(
                      leading: Text(item.emoji,
                          style: const TextStyle(fontSize: 22)),
                      title: Text(item.name,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14)),
                      subtitle: Text(
                        '${item.calories.toInt()} kcal · ${item.protein}g protein',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.45),
                            fontSize: 12),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.add_circle,
                            color: Color(0xFFFF6B35)),
                        onPressed: () => _addItem(context, item),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MiniField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final TextInputType keyboard;
  const _MiniField(
      {required this.ctrl,
      required this.hint,
      this.keyboard = TextInputType.text});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12),
        filled: true,
        fillColor: Colors.white.withOpacity(0.07),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
    );
  }
}
