import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/fitness_provider.dart';
import '../models/models.dart';

// ─── Design tokens ──────────────────────────────────────────────────────────────
const _kGreen  = Color(0xFF30D158);
const _kBlue   = Color(0xFF40C8E0);
const _kOrange = Color(0xFFFF9F0A);
const _kCard   = Color(0xFF1C1C1E);
const _kSec    = Color(0xFF8E8E93);

// ══════════════════════════════════════════════════════════════════════════════
// History Screen
// ══════════════════════════════════════════════════════════════════════════════

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  final _tabs = const [
    Tab(text: 'Workouts'),
    Tab(text: 'Calories'),
    Tab(text: 'Weight'),
    Tab(text: 'Water'),
    Tab(text: 'Food'),
    Tab(text: 'Supps'),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        title: const Text('History'),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: _kGreen,
          labelColor: _kGreen,
          unselectedLabelColor: _kSec,
          dividerColor: const Color(0xFF38383A),
          tabs: _tabs,
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _WorkoutHistoryTab(),
          _CalorieHistoryTab(),
          _WeightHistoryTab(),
          _WaterHistoryTab(),
          _FoodHistoryTab(),
          _SuppHistoryTab(),
        ],
      ),
    );
  }
}

// ─── Shared helpers ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 20, 0, 10),
        child: Text(
          text,
          style: const TextStyle(
            color: _kSec,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
      );
}

class _EmptySlate extends StatelessWidget {
  final String emoji;
  final String message;
  const _EmptySlate({required this.emoji, required this.message});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.45), fontSize: 14),
            ),
          ],
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// WORKOUT TAB
// ══════════════════════════════════════════════════════════════════════════════

class _WorkoutHistoryTab extends StatelessWidget {
  const _WorkoutHistoryTab();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<FitnessProvider>();
    final logs = p.getRecentWorkouts(days: 90);

    if (logs.isEmpty) {
      return const _EmptySlate(
        emoji: '🏋️',
        message: 'No workouts yet.\nStart one from the Workout tab!',
      );
    }

    final weeklyData = _buildWeeklyWorkoutData(logs);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        const _SectionHeader('WORKOUTS PER WEEK (LAST 8 WEEKS)'),
        _BarChart(
          bars: weeklyData
              .map((w) => _Bar(
                    label: w.label,
                    value: w.count.toDouble(),
                    maxValue: 7,
                    color: _kGreen,
                  ))
              .toList(),
          height: 140,
        ),
        const _SectionHeader('WORKOUT LOG'),
        ...logs.map((w) => _WorkoutLogTile(workout: w)),
      ],
    );
  }

  List<({String label, int count})> _buildWeeklyWorkoutData(
      List<WorkoutLog> logs) {
    final now = DateTime.now();
    // i=0 = 7 weeks ago; i=7 = current week
    return List.generate(8, (i) {
      final weeksAgo = 7 - i;
      final weekStart = DateUtils.dateOnly(
          now.subtract(Duration(days: now.weekday - 1 + weeksAgo * 7)));
      final weekEnd =
          weekStart.add(const Duration(days: 6, hours: 23, minutes: 59));
      final count = logs
          .where((l) =>
              !l.date.isBefore(weekStart) && !l.date.isAfter(weekEnd))
          .length;
      final label =
          weeksAgo == 0 ? 'This' : DateFormat('d/M').format(weekStart);
      return (label: label, count: count);
    });
  }
}

class _WorkoutLogTile extends StatelessWidget {
  final WorkoutLog workout;
  const _WorkoutLogTile({required this.workout});

  @override
  Widget build(BuildContext context) {
    final isCustom = workout.workoutType == WorkoutType.custom;
    final color = workout.workoutType == WorkoutType.a
        ? _kGreen
        : isCustom
            ? _kOrange
            : _kBlue;
    final label = isCustom ? '✏️' : workout.workoutType.name.toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
          color: _kCard, borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color: color.withOpacity(0.15), shape: BoxShape.circle),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: isCustom ? 16 : 13)),
          ),
        ),
        title: Text(
          DateFormat('EEE, d MMM yyyy').format(workout.date),
          style: const TextStyle(
              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${workout.durationMinutes} min · ${workout.exercises.length} exercises · ${workout.caloriesBurned} kcal',
          style: TextStyle(
              color: Colors.white.withOpacity(0.45), fontSize: 11),
        ),
        iconColor: _kSec,
        collapsedIconColor: _kSec,
        children: workout.exercises.map((ex) {
          final bestSet = ex.sets.isEmpty
              ? null
              : ex.sets.reduce((a, b) =>
                  (a.weight * a.reps) >= (b.weight * b.reps) ? a : b);
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.6),
                    shape: BoxShape.circle),
              ),
              Expanded(
                child: Text(ex.name,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13)),
              ),
              if (bestSet != null)
                Text(
                  '${ex.sets.length} sets · best: ${bestSet.reps}×${bestSet.weight.toStringAsFixed(bestSet.weight.truncateToDouble() == bestSet.weight ? 0 : 1)}kg',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 11),
                ),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CALORIE TAB
// ══════════════════════════════════════════════════════════════════════════════

class _CalorieHistoryTab extends StatelessWidget {
  const _CalorieHistoryTab();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<FitnessProvider>();
    final days = _buildDailyCalorieData(p);

    if (days.every((d) => d.eaten == 0)) {
      return const _EmptySlate(
        emoji: '🍽️',
        message: 'No food logged yet.\nAdd meals from the Food tab!',
      );
    }

    final goal = p.tdeeKcal > 0 ? p.tdeeKcal : FitnessProvider.kCalorieGoal;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        const _SectionHeader('CALORIES EATEN — LAST 14 DAYS'),
        _BarChart(
          bars: days
              .map((d) => _Bar(
                    label: d.label,
                    value: d.eaten.toDouble(),
                    maxValue: (goal * 1.4).toDouble(),
                    color: d.eaten > goal ? _kOrange : _kGreen,
                    goalLine: goal.toDouble(),
                  ))
              .toList(),
          height: 160,
        ),
        const _SectionHeader('DAILY LOG'),
        ...days.reversed
            .where((d) => d.eaten > 0)
            .map((d) => _CalorieDayTile(day: d, goal: goal)),
      ],
    );
  }

  List<({String label, int eaten, DateTime date})> _buildDailyCalorieData(
      FitnessProvider p) {
    final now = DateTime.now();
    final hist = p.foodHistory;
    return List.generate(14, (i) {
      final date = now.subtract(Duration(days: 13 - i));
      final key = DateFormat('yyyy-MM-dd').format(date);
      final entries = hist[key] ?? [];
      final eaten = entries.fold<int>(0, (s, e) => s + e.calories.round());
      return (label: DateFormat('d/M').format(date), eaten: eaten, date: date);
    });
  }
}

class _CalorieDayTile extends StatelessWidget {
  final ({String label, int eaten, DateTime date}) day;
  final int goal;
  const _CalorieDayTile({required this.day, required this.goal});

  @override
  Widget build(BuildContext context) {
    final pct = (day.eaten / goal).clamp(0.0, 1.5);
    final color = day.eaten > goal ? _kOrange : _kGreen;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: _kCard, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(
                DateFormat('EEE, d MMM').format(day.date),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
            ),
            Text(
              '${day.eaten} / $goal kcal',
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// WEIGHT TAB
// ══════════════════════════════════════════════════════════════════════════════

class _WeightHistoryTab extends StatelessWidget {
  const _WeightHistoryTab();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<FitnessProvider>();
    // bodyHistory is sorted oldest→newest by the provider
    final entries = p.bodyHistory;

    if (entries.isEmpty) {
      return const _EmptySlate(
        emoji: '⚖️',
        message: 'No weight entries yet.\nLog your weight from the Stats tab!',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        const _SectionHeader('WEIGHT TREND'),
        _LineChart(
          points: entries
              .map((e) => _ChartPoint(
                    label: DateFormat('d/M').format(e.date),
                    value: e.weightKg,
                  ))
              .toList(),
          color: _kBlue,
          height: 160,
        ),
        const _SectionHeader('ALL ENTRIES'),
        ...entries.reversed
            .map((e) => _WeightTile(entry: e, goalKg: p.goalWeightKg)),
      ],
    );
  }
}

class _WeightTile extends StatelessWidget {
  final BodyEntry entry;
  final double goalKg;
  const _WeightTile({required this.entry, required this.goalKg});

  @override
  Widget build(BuildContext context) {
    final diff = entry.weightKg - goalKg;
    final color = diff.abs() < 0.5
        ? _kGreen
        : (diff < 0 ? _kBlue : _kOrange);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
          color: _kCard, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Expanded(
          child: Text(
            DateFormat('EEE, d MMM yyyy').format(entry.date),
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
        Text(
          '${entry.weightKg.toStringAsFixed(1)} kg',
          style: TextStyle(
              color: color, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        Text(
          diff >= 0
              ? '+${diff.toStringAsFixed(1)} from goal'
              : '${diff.toStringAsFixed(1)} from goal',
          style: TextStyle(
              color: Colors.white.withOpacity(0.35), fontSize: 11),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// WATER TAB
// ══════════════════════════════════════════════════════════════════════════════

class _WaterHistoryTab extends StatelessWidget {
  const _WaterHistoryTab();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<FitnessProvider>();
    final days = _buildWaterData(p);

    if (days.every((d) => d.ml == 0)) {
      return const _EmptySlate(
        emoji: '💧',
        message: 'No water tracked yet.\nLog it from the Water tab!',
      );
    }

    const goal = FitnessProvider.kWaterGoalMl;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        const _SectionHeader('WATER INTAKE — LAST 14 DAYS'),
        _BarChart(
          bars: days
              .map((d) => _Bar(
                    label: d.label,
                    value: d.ml.toDouble(),
                    maxValue: 4000,
                    color: d.ml >= goal ? _kBlue : _kSec,
                    goalLine: goal.toDouble(),
                  ))
              .toList(),
          height: 140,
        ),
        const _SectionHeader('DAILY LOG'),
        ...days.reversed
            .where((d) => d.ml > 0)
            .map((d) => _WaterDayTile(day: d, goal: goal)),
      ],
    );
  }

  List<({String label, int ml, DateTime date})> _buildWaterData(
      FitnessProvider p) {
    final now = DateTime.now();
    final hist = p.waterHistory;
    return List.generate(14, (i) {
      final date = now.subtract(Duration(days: 13 - i));
      final key = DateFormat('yyyy-MM-dd').format(date);
      return (
        label: DateFormat('d/M').format(date),
        ml: hist[key] ?? 0,
        date: date,
      );
    });
  }
}

class _WaterDayTile extends StatelessWidget {
  final ({String label, int ml, DateTime date}) day;
  final int goal;
  const _WaterDayTile({required this.day, required this.goal});

  @override
  Widget build(BuildContext context) {
    final pct = (day.ml / goal).clamp(0.0, 1.0);
    final color = day.ml >= goal ? _kBlue : _kSec;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: _kCard, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(
                DateFormat('EEE, d MMM').format(day.date),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
            ),
            Text(
              '${(day.ml / 1000).toStringAsFixed(1)} L',
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// FOOD TAB
// ══════════════════════════════════════════════════════════════════════════════

class _FoodHistoryTab extends StatelessWidget {
  const _FoodHistoryTab();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<FitnessProvider>();
    final hist = p.foodHistory;

    // Collect all entries with their date
    final all = <({FoodEntry entry, DateTime date})>[];
    hist.forEach((dateKey, entries) {
      final date = DateTime.tryParse(dateKey);
      if (date == null) return;
      for (final e in entries) {
        all.add((entry: e, date: date));
      }
    });
    all.sort((a, b) => b.date.compareTo(a.date));

    if (all.isEmpty) {
      return const _EmptySlate(
        emoji: '🍛',
        message: 'No food entries yet.\nLog meals from the Food tab!',
      );
    }

    // Group by date string
    final grouped = <String, List<({FoodEntry entry, DateTime date})>>{};
    for (final e in all) {
      final key = DateFormat('yyyy-MM-dd').format(e.date);
      grouped.putIfAbsent(key, () => []).add(e);
    }
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        for (final key in sortedKeys) ...[
          _SectionHeader(
              DateFormat('EEE, d MMM yyyy').format(DateTime.parse(key))),
          ...grouped[key]!.map((e) => _FoodEntryTile(entry: e.entry)),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Total: ${grouped[key]!.fold(0, (s, e) => s + e.entry.calories.round())} kcal  ·  ${grouped[key]!.fold(0.0, (s, e) => s + e.entry.protein).toStringAsFixed(0)}g protein',
                  style: TextStyle(
                      color: _kGreen.withOpacity(0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
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
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          color: _kCard, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.name,
                  style:
                      const TextStyle(color: Colors.white, fontSize: 13)),
              if (entry.servingNote.isNotEmpty)
                Text(entry.servingNote,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 11)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${entry.calories.round()} kcal',
              style: const TextStyle(
                  color: _kGreen, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            Text(
              '${entry.protein.toStringAsFixed(0)}g protein',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.45), fontSize: 11),
            ),
          ],
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SUPPLEMENTS TAB
// ══════════════════════════════════════════════════════════════════════════════

class _SuppHistoryTab extends StatelessWidget {
  const _SuppHistoryTab();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<FitnessProvider>();
    final suppData = _buildSuppData(p);

    final multiTaken = suppData.map((e) => e.status.multivitamin).toList();
    final creatineTaken = suppData.map((e) => e.status.creatine).toList();

    if (multiTaken.every((v) => !v) && creatineTaken.every((v) => !v)) {
      return const _EmptySlate(
        emoji: '💊',
        message:
            'No supplements logged yet.\nTrack them from the Supps tab!',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        const _SectionHeader('LAST 30 DAYS'),
        _SuppStreakRow(
            name: 'Multivitamin', taken: multiTaken, color: _kGreen),
        const SizedBox(height: 12),
        _SuppStreakRow(
            name: 'Creatine', taken: creatineTaken, color: _kBlue),
        const SizedBox(height: 20),
        _SuppStatsCard(multivitamin: multiTaken, creatine: creatineTaken),
        const _SectionHeader('SUPPLEMENT LOG'),
        ...suppData.reversed
            .where((e) => e.status.multivitamin || e.status.creatine)
            .map((e) => _SuppDayTile(date: e.date, status: e.status)),
      ],
    );
  }

  List<({DateTime date, SupplementStatus status})> _buildSuppData(
      FitnessProvider p) {
    final now = DateTime.now();
    final hist = p.supplementHistory;
    return List.generate(30, (i) {
      final date = now.subtract(Duration(days: 29 - i));
      final key = DateFormat('yyyy-MM-dd').format(date);
      return (
        date: date,
        status: hist[key] ?? SupplementStatus(),
      );
    });
  }
}

class _SuppStreakRow extends StatelessWidget {
  final String name;
  final List<bool> taken;
  final Color color;
  const _SuppStreakRow(
      {required this.name, required this.taken, required this.color});

  @override
  Widget build(BuildContext context) {
    final streak = _currentStreak(taken);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: _kCard, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ),
            Text(
              '🔥 $streak day streak',
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ]),
          const SizedBox(height: 10),
          Wrap(
            spacing: 3,
            runSpacing: 3,
            children: taken.asMap().entries.map((e) {
              return Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: e.value
                      ? color.withOpacity(0.25)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: e.value
                          ? color.withOpacity(0.6)
                          : Colors.white12,
                      width: 1),
                ),
                child: e.value
                    ? Icon(Icons.check_rounded, color: color, size: 12)
                    : null,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  int _currentStreak(List<bool> taken) {
    int streak = 0;
    for (int i = taken.length - 1; i >= 0; i--) {
      if (taken[i]) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }
}

class _SuppStatsCard extends StatelessWidget {
  final List<bool> multivitamin;
  final List<bool> creatine;
  const _SuppStatsCard(
      {required this.multivitamin, required this.creatine});

  @override
  Widget build(BuildContext context) {
    final mDays = multivitamin.where((v) => v).length;
    final cDays = creatine.where((v) => v).length;
    final consistency =
        ((mDays + cDays) / 60 * 100).clamp(0.0, 100.0).toStringAsFixed(0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: _kCard, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
              label: 'Multivitamin',
              value: '$mDays',
              sub: 'of 30 days',
              color: _kGreen),
          Container(width: 1, height: 40, color: Colors.white12),
          _StatItem(
              label: 'Creatine',
              value: '$cDays',
              sub: 'of 30 days',
              color: _kBlue),
          Container(width: 1, height: 40, color: Colors.white12),
          _StatItem(
              label: 'Consistency',
              value: '$consistency%',
              sub: 'overall',
              color: _kOrange),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label, value, sub;
  final Color color;
  const _StatItem(
      {required this.label,
      required this.value,
      required this.sub,
      required this.color});

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 22, fontWeight: FontWeight.bold)),
        Text(sub,
            style: TextStyle(
                color: Colors.white.withOpacity(0.35), fontSize: 10)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: _kSec, fontSize: 11)),
      ]);
}

class _SuppDayTile extends StatelessWidget {
  final DateTime date;
  final SupplementStatus status;
  const _SuppDayTile({required this.date, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          color: _kCard, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Expanded(
          child: Text(
            DateFormat('EEE, d MMM yyyy').format(date),
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
        if (status.multivitamin) _SuppChip(label: '💊 Multi', color: _kGreen),
        if (status.creatine) ...[
          const SizedBox(width: 6),
          _SuppChip(label: '⚗️ Creatine', color: _kBlue),
        ],
      ]),
    );
  }
}

class _SuppChip extends StatelessWidget {
  final String label;
  final Color color;
  const _SuppChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3), width: 1)),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// Chart primitives — custom painted, no external lib
// ══════════════════════════════════════════════════════════════════════════════

class _Bar {
  final String label;
  final double value;
  final double maxValue;
  final Color color;
  final double? goalLine;
  const _Bar({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
    this.goalLine,
  });
}

class _BarChart extends StatelessWidget {
  final List<_Bar> bars;
  final double height;

  const _BarChart({required this.bars, this.height = 140});

  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: height + 28,
      child: Column(children: [
        Expanded(
          child: CustomPaint(
            painter: _BarChartPainter(bars: bars),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: bars
              .map((b) => Expanded(
                    child: Text(
                      b.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _kSec, fontSize: 9),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(),
        ),
      ]),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<_Bar> bars;
  _BarChartPainter({required this.bars});

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    const gap = 3.0;
    final barW = (size.width - gap * (bars.length - 1)) / bars.length;

    for (int i = 0; i < bars.length; i++) {
      final b = bars[i];
      final frac =
          (b.maxValue > 0 ? b.value / b.maxValue : 0.0).clamp(0.0, 1.0);
      final left = i * (barW + gap);
      final barH = frac * size.height;

      // Background track
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, 0, barW, size.height),
          const Radius.circular(4),
        ),
        Paint()..color = Colors.white.withOpacity(0.05),
      );

      // Value bar
      if (barH > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left, size.height - barH, barW, barH),
            const Radius.circular(4),
          ),
          Paint()..color = b.color.withOpacity(0.85),
        );
      }

      // Goal line
      if (b.goalLine != null && b.maxValue > 0) {
        final goalY = size.height -
            (b.goalLine! / b.maxValue).clamp(0.0, 1.0) * size.height;
        canvas.drawLine(
          Offset(left, goalY),
          Offset(left + barW, goalY),
          Paint()
            ..color = Colors.white.withOpacity(0.3)
            ..strokeWidth = 1
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) => true;
}

// ─── Line chart ─────────────────────────────────────────────────────────────

class _ChartPoint {
  final String label;
  final double value;
  const _ChartPoint({required this.label, required this.value});
}

class _LineChart extends StatelessWidget {
  final List<_ChartPoint> points;
  final Color color;
  final double height;

  const _LineChart(
      {required this.points, required this.color, this.height = 160});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: height + 28,
      child: Column(children: [
        Expanded(
          child: CustomPaint(
            painter: _LineChartPainter(points: points, color: color),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(points.first.label,
                style: const TextStyle(color: _kSec, fontSize: 9)),
            Text(points.last.label,
                style: const TextStyle(color: _kSec, fontSize: 9)),
          ],
        ),
      ]),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<_ChartPoint> points;
  final Color color;
  _LineChartPainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final vals = points.map((p) => p.value).toList();
    final minV = vals.reduce((a, b) => a < b ? a : b);
    final maxV = vals.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs();
    final pad = range == 0 ? 1.0 : range * 0.15;

    Offset _offset(int i, double v) {
      final x = i / (points.length - 1) * size.width;
      final y = size.height -
          ((v - (minV - pad)) / (range + pad * 2)) * size.height;
      return Offset(x, y.clamp(0, size.height));
    }

    // Gradient fill
    final fillPath = Path()..moveTo(0, size.height);
    for (int i = 0; i < points.length; i++) {
      final o = _offset(i, points[i].value);
      fillPath.lineTo(o.dx, o.dy);
    }
    fillPath..lineTo(size.width, size.height)..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.28), color.withOpacity(0.0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Line
    final linePath = Path();
    linePath.moveTo(_offset(0, points[0].value).dx,
        _offset(0, points[0].value).dy);
    for (int i = 1; i < points.length; i++) {
      linePath.lineTo(_offset(i, points[i].value).dx,
          _offset(i, points[i].value).dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = color
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Endpoint dots
    for (final idx in [0, points.length - 1]) {
      final o = _offset(idx, points[idx].value);
      canvas.drawCircle(o, 4, Paint()..color = color);
      canvas.drawCircle(o, 2.5, Paint()..color = Colors.black);
      canvas.drawCircle(o, 1.5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_LineChartPainter old) => true;
}
