import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/fitness_provider.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          indicatorColor: Color(0xFF30D158),
          labelColor: Color(0xFF30D158),
          unselectedLabelColor: Color(0xFF8E8E93),
          tabs: const [
            Tab(text: 'Workouts'),
            Tab(text: 'Nutrition'),
            Tab(text: 'Weight'),
            Tab(text: 'Water'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _WorkoutHistory(),
          _NutritionHistory(),
          _WeightHistory(),
          _WaterHistory(),
        ],
      ),
    );
  }
}

class _WorkoutHistory extends StatelessWidget {
  const _WorkoutHistory();
  @override
  Widget build(BuildContext context) {
    final p = context.watch<FitnessProvider>();
    final workouts = p.getRecentWorkouts(days: 30);
    if (workouts.isEmpty) {
      return const Center(child: Text('No workouts logged yet',
          style: TextStyle(color: Color(0xFF8E8E93))));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: workouts.length,
      itemBuilder: (ctx, i) {
        final w = workouts[i];
        final cals = p.calculateWorkoutCalories(w);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(w.name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
              Text('~$cals kcal',
                  style: const TextStyle(color: Color(0xFF30D158), fontSize: 13)),
            ]),
            const SizedBox(height: 4),
            Text(
              '${w.date.day}/${w.date.month}/${w.date.year}  •  ${w.exercises.length} exercise${w.exercises.length == 1 ? '' : 's'}',
              style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 12),
            ),
            if (w.exercises.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...w.exercises.map((ex) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(children: [
                  const Icon(Icons.fiber_manual_record, size: 6, color: Color(0xFF8E8E93)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(ex.name, style: const TextStyle(fontSize: 13))),
                  Text(
                    ex.sets.isNotEmpty
                        ? '${ex.sets.length}×${ex.sets.first.reps}'
                            '${ex.sets.first.weight > 0 ? ' @ ${ex.sets.first.weight.toStringAsFixed(1)}kg' : ''}'
                        : '',
                    style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 12),
                  ),
                ]),
              )),
            ],
          ]),
        );
      },
    );
  }
}

class _NutritionHistory extends StatelessWidget {
  const _NutritionHistory();
  @override
  Widget build(BuildContext context) {
    final p = context.watch<FitnessProvider>();
    final history = p.foodHistory;
    final sortedDays = history.keys.toList()..sort((a, b) => b.compareTo(a));
    if (sortedDays.isEmpty) {
      return const Center(child: Text('No food logged yet',
          style: TextStyle(color: Color(0xFF8E8E93))));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedDays.length,
      itemBuilder: (ctx, i) {
        final day = sortedDays[i];
        final entries = history[day] ?? [];
        final totalCal = entries.fold(0.0, (s, e) => s + e.calories);
        final totalProt = entries.fold(0.0, (s, e) => s + e.protein);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(day, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              Text('${entries.length} items',
                  style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 12)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${totalCal.round()} kcal',
                  style: const TextStyle(color: Color(0xFFFF9F0A), fontWeight: FontWeight.w600)),
              Text('${totalProt.round()}g protein',
                  style: const TextStyle(color: Color(0xFF40C8E0), fontSize: 12)),
            ]),
          ]),
        );
      },
    );
  }
}

class _WeightHistory extends StatelessWidget {
  const _WeightHistory();
  @override
  Widget build(BuildContext context) {
    final p = context.watch<FitnessProvider>();
    final entries = p.getRecentBodyEntries(days: 30);
    if (entries.length < 2) {
      return const Center(child: Text('Log at least 2 weight entries to see a chart',
          style: TextStyle(color: Color(0xFF8E8E93), textAlign: TextAlign.center)));
    }
    final spots = entries.asMap().entries.map((e) =>
        FlSpot(e.key.toDouble(), e.value.weightKg)).toList();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        SizedBox(
          height: 200,
          child: LineChart(LineChartData(
            gridData: const FlGridData(show: false),
            titlesData: const FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: const Color(0xFF30D158),
                barWidth: 2.5,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: const Color(0xFF30D158).withOpacity(0.1),
                ),
              ),
            ],
          )),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: entries.length,
            itemBuilder: (ctx, i) {
              final e = entries[entries.length - 1 - i];
              return ListTile(
                title: Text('${e.date.day}/${e.date.month}/${e.date.year}'),
                trailing: Text('${e.weightKg.toStringAsFixed(1)} kg',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF30D158))),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _WaterHistory extends StatelessWidget {
  const _WaterHistory();
  @override
  Widget build(BuildContext context) {
    final p = context.watch<FitnessProvider>();
    final history = p.waterHistory;
    final sortedDays = history.keys.toList()..sort((a, b) => b.compareTo(a));
    if (sortedDays.isEmpty) {
      return const Center(child: Text('No water logged yet',
          style: TextStyle(color: Color(0xFF8E8E93))));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedDays.length,
      itemBuilder: (ctx, i) {
        final day = sortedDays[i];
        final ml = history[day] ?? 0;
        final progress = (ml / 2500).clamp(0.0, 1.0);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(day,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
              Text('$ml ml',
                  style: TextStyle(
                    color: ml >= 2500 ? const Color(0xFF30D158) : const Color(0xFF40C8E0),
                    fontWeight: FontWeight.w600,
                  )),
            ]),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: const Color(0xFF2C2C2E),
                valueColor: AlwaysStoppedAnimation(
                    ml >= 2500 ? const Color(0xFF30D158) : const Color(0xFF40C8E0)),
                minHeight: 5,
              ),
            ),
          ]),
        );
      },
    );
  }
}
