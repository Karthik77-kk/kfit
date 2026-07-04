import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/fitness_provider.dart';
import '../services/gemini_vision_service.dart';
import '../widgets/input_formatters.dart';

/// Full-screen review of an AI meal scan. Every detected food is editable —
/// rename (free text or pick from the food DB), tweak macros, remove — then
/// "Add all" logs them to the chosen meal. The food DB search fills a row's
/// name + macros from a known item.
class MealScanResultScreen extends StatefulWidget {
  final List<ScannedFood> foods;
  const MealScanResultScreen({super.key, required this.foods});

  @override
  State<MealScanResultScreen> createState() => _MealScanResultScreenState();
}

class _EditRow {
  final TextEditingController name;
  final TextEditingController kcal;
  final TextEditingController protein;
  final TextEditingController carbs;
  final TextEditingController fat;
  final double grams;
  double confidence;

  _EditRow(ScannedFood f)
      : name = TextEditingController(text: f.name),
        kcal = TextEditingController(text: f.kcal.round().toString()),
        protein = TextEditingController(text: f.protein.round().toString()),
        carbs = TextEditingController(text: f.carbs.round().toString()),
        fat = TextEditingController(text: f.fat.round().toString()),
        grams = f.grams,
        confidence = f.confidence;

  void dispose() {
    name.dispose();
    kcal.dispose();
    protein.dispose();
    carbs.dispose();
    fat.dispose();
  }
}

class _MealScanResultScreenState extends State<MealScanResultScreen> {
  late final List<_EditRow> _rows;
  late MealType _meal;

  static const _green = Color(0xFF30D158);
  static const _card = Color(0xFF1C1C1E);
  static const _muted = Color(0xFF8E8E93);

  @override
  void initState() {
    super.initState();
    _rows = widget.foods.map((f) => _EditRow(f)).toList();
    final h = DateTime.now().hour;
    _meal = h < 11
        ? MealType.breakfast
        : h < 16
            ? MealType.lunch
            : h < 21
                ? MealType.dinner
                : MealType.snack;
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  int get _totalKcal =>
      _rows.fold(0, (s, r) => s + (int.tryParse(r.kcal.text) ?? 0));

  String _mealLabel(MealType m) =>
      {'breakfast': 'Breakfast', 'lunch': 'Lunch', 'dinner': 'Dinner', 'snack': 'Snacks'}[
          m.name]!;

  Future<void> _pickFromDb(_EditRow row) async {
    final picked = await showModalBottomSheet<FoodItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _FoodDbPicker(),
    );
    if (picked == null) return;
    setState(() {
      row.name.text = picked.name;
      row.kcal.text = picked.calories.round().toString();
      row.protein.text = picked.protein.round().toString();
      row.carbs.text = picked.carbs.round().toString();
      row.fat.text = picked.fat.round().toString();
      row.confidence = 1.0; // user-confirmed via DB
    });
  }

  Future<void> _addAll() async {
    final p = context.read<FitnessProvider>();
    var added = 0;
    for (final r in _rows) {
      final name = r.name.text.trim();
      final kcal = double.tryParse(r.kcal.text) ?? 0;
      if (name.isEmpty || kcal <= 0) continue;
      await p.addFoodEntry(FoodEntry(
        id: p.newId(),
        name: name,
        calories: kcal,
        protein: double.tryParse(r.protein.text) ?? 0,
        carbs: double.tryParse(r.carbs.text) ?? 0,
        fat: double.tryParse(r.fat.text) ?? 0,
        macrosKnown: true,
        mealType: _meal,
        timestamp: DateTime.now(),
        servingNote: r.grams > 0 ? '~${r.grams.round()} g · AI scan' : 'AI scan',
      ));
      added++;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          'Added $added item${added == 1 ? '' : 's'} to ${_mealLabel(_meal)}'),
      backgroundColor: _green,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review scan'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text('$_totalKcal kcal',
                  style: const TextStyle(
                      color: _green, fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _mealSelector(),
          const Divider(height: 1, color: Color(0xFF2C2C2E)),
          Expanded(
            child: _rows.isEmpty
                ? const Center(
                    child: Text('No items — go back and rescan.',
                        style: TextStyle(color: _muted)))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: _rows.length,
                    itemBuilder: (_, i) => _rowCard(_rows[i], i),
                  ),
          ),
          _bottomBar(),
        ],
      ),
    );
  }

  Widget _mealSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: MealType.values.map((m) {
          final sel = m == _meal;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(_mealLabel(m)),
              selected: sel,
              onSelected: (_) => setState(() => _meal = m),
              selectedColor: _green.withValues(alpha: 0.2),
              backgroundColor: const Color(0xFF2C2C2E),
              labelStyle: TextStyle(
                  color: sel ? _green : _muted,
                  fontSize: 13,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.normal),
              side: BorderSide(
                  color: sel ? _green : const Color(0xFF38383A)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _rowCard(_EditRow r, int i) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: r.name,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Food name',
                  ),
                ),
              ),
              if (r.confidence > 0 && r.confidence < 0.6)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.help_outline_rounded,
                      size: 16, color: Color(0xFFFF9F0A)),
                ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.search_rounded, size: 20, color: _muted),
                tooltip: 'Replace from food database',
                onPressed: () => _pickFromDb(r),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded,
                    size: 20, color: Color(0xFFFF453A)),
                tooltip: 'Remove',
                onPressed: () => setState(() {
                  _rows.removeAt(i).dispose();
                }),
              ),
            ],
          ),
          if (r.grams > 0)
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 6),
              child: Text('~${r.grams.round()} g estimated',
                  style: const TextStyle(color: _muted, fontSize: 11)),
            ),
          Row(
            children: [
              _macroField(r.kcal, 'kcal', const Color(0xFFFF453A)),
              _macroField(r.protein, 'P (g)', _green),
              _macroField(r.carbs, 'C (g)', const Color(0xFFFF9F0A)),
              _macroField(r.fat, 'F (g)', const Color(0xFF40C8E0)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _macroField(TextEditingController c, String label, Color color) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          inputFormatters: positiveIntInput,
          onChanged: (_) => setState(() {}), // refresh total
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(fontSize: 11, color: _muted),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 6),
          ),
        ),
      ),
    );
  }

  Widget _bottomBar() {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _green,
            foregroundColor: Colors.black,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _rows.isEmpty ? null : _addAll,
          child: Text(
            _rows.isEmpty
                ? 'Nothing to add'
                : 'Add ${_rows.length} item${_rows.length == 1 ? '' : 's'} · $_totalKcal kcal',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

/// Searchable picker over the local food DB (+ IFCT), returns the chosen item.
class _FoodDbPicker extends StatefulWidget {
  const _FoodDbPicker();
  @override
  State<_FoodDbPicker> createState() => _FoodDbPickerState();
}

class _FoodDbPickerState extends State<_FoodDbPicker> {
  final _ctrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<FoodItem> get _results {
    final q = _q.trim().toLowerCase();
    final base = q.isEmpty
        ? kFoodDatabase.take(30).toList()
        : kFoodDatabase
            .where((f) => f.name.toLowerCase().contains(q))
            .take(40)
            .toList();
    return base;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        builder: (_, scroll) => Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: const Color(0xFF8E8E93).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                onChanged: (v) => setState(() => _q = v),
                decoration: const InputDecoration(
                  hintText: 'Search food database…',
                  prefixIcon: Icon(Icons.search, size: 20, color: Color(0xFF8E8E93)),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scroll,
                itemCount: _results.length,
                itemBuilder: (_, i) {
                  final f = _results[i];
                  return ListTile(
                    dense: true,
                    title: Text(f.name),
                    subtitle: Text(
                      '${f.calories.round()} kcal · ${f.protein.round()}g P · ${f.serving}',
                      style: const TextStyle(
                          color: Color(0xFF8E8E93), fontSize: 12),
                    ),
                    onTap: () => Navigator.pop(context, f),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
