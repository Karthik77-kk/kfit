import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/fitness_provider.dart';
import '../models/models.dart';
import '../services/food_api_service.dart';

/// Call this from any context (standalone or embedded) to open the Add Food sheet.
void showAddFoodSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1C1C1E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _AddFoodSheet(),
  );
}

class FoodScreen extends StatelessWidget {
  final bool embedded;
  const FoodScreen({super.key, this.embedded = false});

  Widget _buildBody(FitnessProvider p) {
    if (p.todayFood.isEmpty) return const _EmptyState();
    return ListView(
      padding: const EdgeInsets.only(bottom: 100, top: 8),
      children: [
        _MealSection(title: '☀️ Breakfast', entries: p.breakfastEntries, provider: p),
        _MealSection(title: '🌤️ Lunch', entries: p.lunchEntries, provider: p),
        _MealSection(title: '🌙 Dinner', entries: p.dinnerEntries, provider: p),
        _MealSection(title: '🍎 Snacks', entries: p.snackEntries, provider: p),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<FitnessProvider>();

    // When embedded inside NutritionScreen, just return the body
    if (embedded) return _buildBody(p);

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
                  '${p.todayCalories.toInt()} / ${p.calorieGoal} kcal',
                  style: TextStyle(
                    color: p.todayCalories > p.calorieGoal
                        ? Colors.redAccent
                        : const Color(0xFF30D158),
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
        onPressed: () => showAddFoodSheet(context),
        backgroundColor: const Color(0xFF30D158),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Food', style: TextStyle(color: Colors.white)),
      ),
      body: _buildBody(p),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🍽️', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 16),
          const Text('No food logged today',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Tap + Add Food to start logging',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
        ],
      ),
    );
  }
}

// ── Meal Section ──────────────────────────────────────────────────────────────

class _MealSection extends StatelessWidget {
  final String title;
  final List<FoodEntry> entries;
  final FitnessProvider provider;

  const _MealSection({required this.title, required this.entries, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (entries.isNotEmpty)
                Text(
                  '${entries.fold(0.0, (s, e) => s + e.calories).toInt()} kcal',
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                ),
            ],
          ),
        ),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text('Nothing logged',
                style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 12)),
          )
        else
          ...entries.map((entry) => Dismissible(
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
                onDismissed: (_) {
                  final removed = entry;
                  provider.removeFoodEntry(removed.id);
                  // CRITICAL: capture messenger BEFORE any navigation/pop
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('${removed.name} removed'),
                    backgroundColor: const Color(0xFF2C2C2E),
                    duration: const Duration(seconds: 4),
                    action: SnackBarAction(
                      label: 'Undo',
                      textColor: const Color(0xFF30D158),
                      onPressed: () => provider.addFoodEntry(removed),
                    ),
                  ));
                },
                child: _FoodEntryTile(entry: entry),
              )),
      ],
    );
  }
}

// ── Food Entry Tile ───────────────────────────────────────────────────────────

class _FoodEntryTile extends StatelessWidget {
  final FoodEntry entry;
  const _FoodEntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.name,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                if (entry.servingNote.isNotEmpty)
                  Text(entry.servingNote,
                      style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 11),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${entry.calories.toInt()} kcal',
                  style: const TextStyle(color: Color(0xFF30D158), fontWeight: FontWeight.bold, fontSize: 13)),
              Text('${entry.protein.toStringAsFixed(1)}g protein',
                  style: TextStyle(color: const Color(0xFF40C8E0).withOpacity(0.8), fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Add Food Bottom Sheet ─────────────────────────────────────────────────────

class _AddFoodSheet extends StatefulWidget {
  const _AddFoodSheet();
  @override
  State<_AddFoodSheet> createState() => _AddFoodSheetState();
}

class _AddFoodSheetState extends State<_AddFoodSheet> {
  final _searchCtrl = TextEditingController();
  MealType _selectedMeal = MealType.breakfast;
  String _search = '';
  String _selectedCategory = 'Popular';
  bool _showCustom = false;

  final _nameCtrl = TextEditingController();
  final _calCtrl = TextEditingController();
  final _protCtrl = TextEditingController();

  // Online search state
  List<FoodApiResult> _onlineResults  = [];
  bool                _searchingOnline = false;
  String?             _onlineError;
  String              _lastOnlineQuery = '';

  @override
  void initState() {
    super.initState();
    final h = DateTime.now().hour;
    if (h >= 5 && h < 11) _selectedMeal = MealType.breakfast;
    else if (h >= 11 && h < 16) _selectedMeal = MealType.lunch;
    else if (h >= 16 && h < 21) _selectedMeal = MealType.dinner;
    else _selectedMeal = MealType.snack;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    _calCtrl.dispose();
    _protCtrl.dispose();
    super.dispose();
  }

  List<FoodItem> get _filtered {
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      // Deduplicate by name — keep first occurrence (specific category wins over Popular)
      final seen = <String>{};
      // Pass 1: non-Popular items first (more specific)
      final results = <FoodItem>[];
      for (final f in kFoodDatabase) {
        if (f.category == 'Popular') continue;
        if ((f.name.toLowerCase().contains(q) || f.category.toLowerCase().contains(q))
            && seen.add(f.name.toLowerCase())) {
          results.add(f);
        }
      }
      // Pass 2: Popular items not already shown
      for (final f in kFoodDatabase) {
        if (f.category != 'Popular') continue;
        if ((f.name.toLowerCase().contains(q) || f.category.toLowerCase().contains(q))
            && seen.add(f.name.toLowerCase())) {
          results.add(f);
        }
      }
      return results;
    }
    return kFoodDatabase.where((f) => f.category == _selectedCategory).toList();
  }

  // ── Online search ────────────────────────────────────────────────────────────

  Future<void> _searchOnline(BuildContext ctx) async {
    if (_searchingOnline) return;
    final query = _search.trim();
    if (query.length < 2) return;

    setState(() {
      _searchingOnline = true;
      _onlineError     = null;
      _onlineResults   = [];
      _lastOnlineQuery = query;
    });

    try {
      final results = await FoodApiService.search(query);
      if (!mounted) return;
      setState(() {
        _searchingOnline = false;
        _onlineResults   = results;
        if (results.isEmpty) {
          _onlineError = 'No online results for "$query".\nTry a different name or add a custom entry.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searchingOnline = false;
        _onlineError     = 'No internet connection. Try again later.';
      });
    }
  }

  // ── Gram picker (for API results — per-100g basis) ───────────────────────────

  void _showGramPicker(BuildContext ctx, FoodApiResult item) {
    final gCtrl = TextEditingController(text: '100');

    showDialog(
      context: ctx,
      barrierColor: Colors.black87,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setD) {
          final raw    = double.tryParse(gCtrl.text) ?? 100.0;
          final grams  = raw.clamp(1.0, 5000.0);
          final cal    = item.caloriesForGrams(grams).round();
          final prot   = item.proteinForGrams(grams);
          final carbs  = item.carbsForGrams(grams);
          final fat    = item.fatForGrams(grams);

          return AlertDialog(
            backgroundColor: const Color(0xFF1C1C1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(item.name,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  const Text('🌐', style: TextStyle(fontSize: 11)),
                  const SizedBox(width: 4),
                  Text(
                    '${item.source} · per 100g: ${item.calories100g.round()} kcal, '
                    '${item.protein100g.toStringAsFixed(1)}g protein',
                    style: TextStyle(color: Colors.white.withOpacity(0.38), fontSize: 10),
                  ),
                ]),
              ],
            ),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 4),
              // Quick gram presets
              Row(children: [50, 100, 150, 200].map((g) {
                final sel = grams.round() == g;
                return Expanded(child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: GestureDetector(
                    onTap: () { gCtrl.text = '$g'; setD(() {}); },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: sel
                            ? const Color(0xFF40C8E0).withValues(alpha: 0.18)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: sel
                              ? const Color(0xFF40C8E0).withValues(alpha: 0.5)
                              : Colors.transparent,
                        ),
                      ),
                      child: Text('${g}g',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: sel
                                ? const Color(0xFF40C8E0)
                                : Colors.white.withOpacity(0.5),
                            fontSize: 12,
                            fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                          )),
                    ),
                  ),
                ));
              }).toList()),
              const SizedBox(height: 12),
              // Custom gram field
              TextField(
                controller: gCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  suffix: Text('g', style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 16)),
                  hintText: '100',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                ),
                onChanged: (_) => setD(() {}),
              ),
              const SizedBox(height: 12),
              // Live macro preview
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _NutCol(label: 'Calories', value: '$cal kcal', color: const Color(0xFF30D158)),
                  _NutCol(label: 'Protein',  value: '${prot.toStringAsFixed(1)}g', color: const Color(0xFF40C8E0)),
                  _NutCol(label: 'Carbs',    value: '${carbs.toStringAsFixed(1)}g', color: const Color(0xFFFF9F0A)),
                  _NutCol(label: 'Fat',      value: '${fat.toStringAsFixed(1)}g',   color: const Color(0xFF8E8E93)),
                ]),
              ),
              const SizedBox(height: 4),
            ]),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dCtx),
                child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5))),
              ),
              ElevatedButton(
                onPressed: raw < 1 ? null : () {
                  Navigator.pop(dCtx);
                  _addApiItem(ctx, item, grams);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF30D158),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _addApiItem(BuildContext ctx, FoodApiResult item, double grams) {
    HapticFeedback.lightImpact();
    final provider = ctx.read<FitnessProvider>();
    final gStr = grams == grams.roundToDouble()
        ? '${grams.toInt()}g'
        : '${grams.toStringAsFixed(1)}g';
    provider.addFoodEntry(FoodEntry(
      id:          provider.newId(),
      name:        item.name,
      calories:    item.caloriesForGrams(grams),
      protein:     item.proteinForGrams(grams),
      mealType:    _selectedMeal,
      timestamp:   DateTime.now(),
      servingNote: '$gStr · 🌐 ${item.source}',
    ));
    final messenger = ScaffoldMessenger.of(ctx);
    Navigator.pop(ctx);
    messenger.showSnackBar(SnackBar(
      content: Text('${item.name} added ✓'),
      backgroundColor: const Color(0xFF30D158),
      duration: const Duration(seconds: 1),
    ));
  }

  // ────────────────────────────────────────────────────────────────────────────

  void _showQuantityPicker(BuildContext ctx, FoodItem item) {
    double servings = 1.0;
    showDialog(
      context: ctx,
      barrierColor: Colors.black87,
      builder: (dCtx) => StatefulBuilder(builder: (dCtx, setDState) {
        final cal = (item.calories * servings).round();
        final prot = item.protein * servings;
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Text(item.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Expanded(child: Text(item.name,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold))),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Per serving: ${item.serving}',
                style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12)),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _QtyBtn(icon: Icons.remove, onTap: () {
                if (servings > 0.5) setDState(() => servings = (servings - 0.5).clamp(0.5, 10.0));
              }),
              const SizedBox(width: 20),
              Column(children: [
                Text(
                  servings == servings.roundToDouble() ? '${servings.toInt()}' : servings.toStringAsFixed(1),
                  style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold),
                ),
                Text('serving${servings != 1.0 ? 's' : ''}',
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
              ]),
              const SizedBox(width: 20),
              _QtyBtn(icon: Icons.add, onTap: () {
                if (servings < 10) setDState(() => servings = (servings + 0.5).clamp(0.5, 10.0));
              }),
            ]),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _NutCol(label: 'Calories', value: '$cal kcal', color: const Color(0xFF30D158)),
                _NutCol(label: 'Protein', value: '${prot.toStringAsFixed(1)}g', color: const Color(0xFF40C8E0)),
              ]),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5))),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dCtx);
                _addItemWithQty(ctx, item, servings);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF30D158),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      }),
    );
  }

  void _addItemWithQty(BuildContext ctx, FoodItem item, double servings) {
    HapticFeedback.lightImpact();
    final provider = ctx.read<FitnessProvider>();
    // Format whole servings as "2×" not "2.0×"; keep one decimal for halves.
    final qtyStr = servings == servings.roundToDouble()
        ? servings.toInt().toString()
        : servings.toStringAsFixed(1);
    final label = servings == 1.0 ? item.serving : '$qtyStr× ${item.serving}';
    provider.addFoodEntry(FoodEntry(
      id: provider.newId(),
      name: item.name,
      calories: item.calories * servings,
      protein: item.protein * servings,
      mealType: _selectedMeal,
      timestamp: DateTime.now(),
      servingNote: label,
    ));
    // Capture messenger BEFORE pop (avoids using deactivated context)
    final messenger = ScaffoldMessenger.of(ctx);
    Navigator.pop(ctx);
    messenger.showSnackBar(SnackBar(
      content: Text('${item.name} added ✓'),
      backgroundColor: const Color(0xFF30D158),
      duration: const Duration(seconds: 1),
    ));
  }

  void _addCustom(BuildContext ctx) {
    final name = _nameCtrl.text.trim();
    final cal = double.tryParse(_calCtrl.text.trim()) ?? 0;
    // Clamp protein to >= 0 so a stray "-5" can't subtract from the day's total.
    final prot = (double.tryParse(_protCtrl.text.trim()) ?? 0).clamp(0.0, 100000.0);
    if (name.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('⚠️ Enter a food name'), duration: Duration(seconds: 1)));
      return;
    }
    if (cal <= 0) {
      ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('⚠️ Enter calories > 0'), duration: Duration(seconds: 1)));
      return;
    }
    HapticFeedback.lightImpact();
    final provider = ctx.read<FitnessProvider>();
    provider.addFoodEntry(FoodEntry(
      id: provider.newId(),
      name: name,
      calories: cal,
      protein: prot,
      mealType: _selectedMeal,
      timestamp: DateTime.now(),
      servingNote: 'custom entry',
    ));
    final messenger = ScaffoldMessenger.of(ctx);
    Navigator.pop(ctx);
    messenger.showSnackBar(SnackBar(
      content: Text('$name added ✓'),
      backgroundColor: const Color(0xFF30D158),
      duration: const Duration(seconds: 1),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (ctx, scrollCtrl) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Add Food', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),

            // Meal type chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: MealType.values.map((mt) {
                  const labels = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];
                  final sel = _selectedMeal == mt;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedMeal = mt),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: sel ? const Color(0xFF30D158) : Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(labels[mt.index],
                          style: TextStyle(
                            color: sel ? Colors.white : Colors.white.withOpacity(0.6),
                            fontSize: 13,
                            fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                          )),
                    ),
                  );
                }).toList(),
              ),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: Colors.white),
                onChanged: (v) => setState(() {
                  _search = v;
                  // Reset online results when query changes
                  if (v != _lastOnlineQuery) {
                    _onlineResults  = [];
                    _onlineError    = null;
                    _searchingOnline = false;
                  }
                }),
                decoration: InputDecoration(
                  hintText: 'Search 200+ Indian foods...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                  prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.4)),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.white.withOpacity(0.4), size: 18),
                          onPressed: () { _searchCtrl.clear(); setState(() => _search = ''); },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.07),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),

            // Category tabs
            if (_search.isEmpty)
              SizedBox(
                height: 36,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: kFoodCategories.length,
                  itemBuilder: (_, i) {
                    final cat = kFoodCategories[i];
                    final sel = _selectedCategory == cat;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategory = cat),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: sel ? const Color(0xFF30D158).withOpacity(0.2) : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: sel ? const Color(0xFF30D158) : Colors.white.withOpacity(0.15),
                          ),
                        ),
                        child: Text(cat,
                            style: TextStyle(
                              color: sel ? const Color(0xFF30D158) : Colors.white.withOpacity(0.55),
                              fontSize: 12,
                              fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                            )),
                      ),
                    );
                  },
                ),
              ),

            // Custom entry
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: TextButton.icon(
                onPressed: () => setState(() => _showCustom = !_showCustom),
                icon: Icon(_showCustom ? Icons.expand_less : Icons.add, size: 16, color: const Color(0xFF40C8E0)),
                label: Text(_showCustom ? 'Hide custom entry' : 'Add custom food',
                    style: const TextStyle(color: Color(0xFF40C8E0), fontSize: 12)),
              ),
            ),
            if (_showCustom)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Row(children: [
                  Expanded(flex: 3, child: _MiniField(ctrl: _nameCtrl, hint: 'Food name')),
                  const SizedBox(width: 6),
                  Expanded(child: _MiniField(ctrl: _calCtrl, hint: 'kcal', keyboard: TextInputType.number)),
                  const SizedBox(width: 6),
                  Expanded(child: _MiniField(ctrl: _protCtrl, hint: 'prot g', keyboard: TextInputType.number)),
                  const SizedBox(width: 6),
                  ElevatedButton(
                    onPressed: () => _addCustom(context),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF30D158), padding: const EdgeInsets.all(12), minimumSize: Size.zero),
                    child: const Icon(Icons.check, color: Colors.white, size: 18),
                  ),
                ]),
              ),

            // Food list (local DB + online results)
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.only(bottom: 20),
                children: [
                  // ── Local results ───────────────────────────────────────
                  if (_filtered.isNotEmpty)
                    ..._filtered.map((item) => ListTile(
                      leading: Text(item.emoji, style: const TextStyle(fontSize: 22)),
                      title: Text(item.name, style: const TextStyle(color: Colors.white, fontSize: 14)),
                      subtitle: Text(
                        '${item.calories.toInt()} kcal · ${item.protein.toStringAsFixed(1)}g protein · ${item.serving}',
                        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.add_circle, color: Color(0xFF30D158)),
                        onPressed: () => _showQuantityPicker(context, item),
                      ),
                    )),

                  // ── Online search section ────────────────────────────────
                  if (_search.length > 2 && _filtered.isEmpty) ...[
                    // Divider
                    if (_onlineResults.isNotEmpty || _searchingOnline || _onlineError != null)
                      const Divider(color: Color(0xFF2C2C2E), height: 1),

                    // "Search online" button (idle state)
                    if (!_searchingOnline && _onlineResults.isEmpty && _onlineError == null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(children: [
                          Text(
                            'No local results for "$_search"',
                            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _searchOnline(context),
                              icon: const Text('🌐', style: TextStyle(fontSize: 14)),
                              label: const Text('Search online food database'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF40C8E0),
                                side: const BorderSide(color: Color(0xFF40C8E0), width: 1),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 11),
                              ),
                            ),
                          ),
                        ]),
                      ),

                    // Loading
                    if (_searchingOnline)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            CircularProgressIndicator(color: Color(0xFF40C8E0), strokeWidth: 2),
                            SizedBox(height: 10),
                            Text('Searching online…',
                                style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12)),
                          ]),
                        ),
                      ),

                    // Error state
                    if (_onlineError != null && !_searchingOnline)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(children: [
                          Text(_onlineError!,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13)),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () => _searchOnline(context),
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Try again'),
                            style: TextButton.styleFrom(foregroundColor: const Color(0xFF40C8E0)),
                          ),
                        ]),
                      ),

                    // Online results
                    if (_onlineResults.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                        child: Row(children: [
                          const Text('🌐 ', style: TextStyle(fontSize: 11)),
                          Text(
                            'Online results  ·  values per 100 g',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.35),
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ]),
                      ),
                      ..._onlineResults.map((item) => ListTile(
                        leading: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF40C8E0).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text('🌐', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                        title: Text(
                          item.name,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${item.calories100g.round()} kcal · '
                          '${item.protein100g.toStringAsFixed(1)}g prot · '
                          '${item.carbs100g.toStringAsFixed(1)}g carbs per 100g',
                          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.add_circle, color: Color(0xFF40C8E0)),
                          onPressed: () => _showGramPicker(context, item),
                        ),
                      )),
                    ],
                  ],

                  // ── Catch-all: empty local + not searching online ─────────
                  if (_search.isNotEmpty && _filtered.isEmpty &&
                      _onlineResults.isEmpty && !_searchingOnline &&
                      _onlineError == null && _search.length <= 2)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'Type more to search…',
                          style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ]),
        );
      },
    );
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFF30D158).withOpacity(0.15),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF30D158).withOpacity(0.4)),
        ),
        child: Icon(icon, color: const Color(0xFF30D158), size: 20),
      ),
    );
  }
}

class _NutCol extends StatelessWidget {
  final String label, value;
  final Color color;
  const _NutCol({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
      Text(label, style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11)),
    ]);
  }
}

class _MiniField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final TextInputType keyboard;
  const _MiniField({required this.ctrl, required this.hint, this.keyboard = TextInputType.text});
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12),
        filled: true,
        fillColor: Colors.white.withOpacity(0.07),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
    );
  }
}
