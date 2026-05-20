import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/fitness_provider.dart';
import '../models/models.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _kGreen = Color(0xFF30D158);
const _kBlue = Color(0xFF40C8E0);
const _kRed = Color(0xFFFF453A);
const _kOrange = Color(0xFFFF9F0A);
const _kCard = Color(0xFF1C1C1E);
const _kSecondary = Color(0xFF8E8E93);

// ══════════════════════════════════════════════════════════════════════════════
// Stats Screen
// ══════════════════════════════════════════════════════════════════════════════

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final _weightCtrl = TextEditingController();
  final _stepsCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _goalWeightCtrl = TextEditingController();

  // 1RM state
  String _ormExercise = 'Bench Press';
  double _ormWeight = 60;
  int _ormReps = 8;

  static const _ormExercises = [
    'Bench Press', 'Squat', 'Deadlift', 'OHP', 'Barbell Row',
    'Incline Press', 'Romanian DL'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<FitnessProvider>();
      _heightCtrl.text = p.heightCm.toStringAsFixed(0);
      _ageCtrl.text = p.age.toString();
      _goalWeightCtrl.text = p.goalWeightKg.toStringAsFixed(1);
      if (p.latestWeightKg != null) {
        _weightCtrl.text = p.latestWeightKg!.toStringAsFixed(1);
      }
      if (p.todaySteps > 0) {
        _stepsCtrl.text = p.todaySteps.toString();
      }
    });
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _stepsCtrl.dispose();
    _heightCtrl.dispose();
    _ageCtrl.dispose();
    _goalWeightCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveEntries() async {
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();

    final p = context.read<FitnessProvider>();
    final weight = double.tryParse(_weightCtrl.text);
    final steps = int.tryParse(_stepsCtrl.text) ?? 0;
    final height = double.tryParse(_heightCtrl.text);
    final age = int.tryParse(_ageCtrl.text);
    final goalWeight = double.tryParse(_goalWeightCtrl.text);

    if (height != null && height > 50 && height < 300) {
      await p.saveHeight(height);
    }
    if (age != null && age > 10 && age < 120) {
      await p.saveAge(age);
    }
    if (goalWeight != null && goalWeight > 30 && goalWeight < 300) {
      await p.saveGoalWeight(goalWeight);
    }
    if (weight != null && weight > 10 && weight < 500) {
      await p.logBodyEntry(weightKg: weight, steps: steps);
    } else if (steps > 0) {
      await p.updateTodaySteps(steps);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stats saved ✓'),
          backgroundColor: _kGreen,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  double _epley1RM(double weight, int reps) {
    if (reps == 1) return weight;
    return weight * (1 + reps / 30.0);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<FitnessProvider>();
    final recent = p.getRecentBodyEntries(days: 30);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text(
            'Body & Stats',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
        ),
        body: ListView(
          padding: EdgeInsets.fromLTRB(
              16, 8, 16, 24 + MediaQuery.of(context).padding.bottom),
          children: [
            // ── Log Today ────────────────────────────────────────────────
            _SectionHeader('LOG TODAY'),
            _AppleCard(
              child: Column(
                children: [
                  _FieldRow(
                    label: 'Weight',
                    unit: 'kg',
                    controller: _weightCtrl,
                    icon: Icons.monitor_weight_outlined,
                    iconColor: _kGreen,
                    action: TextInputAction.next,
                    onNext: () => FocusScope.of(context).nextFocus(),
                  ),
                  _Divider(),
                  _FieldRow(
                    label: 'Steps',
                    unit: 'steps',
                    controller: _stepsCtrl,
                    icon: Icons.directions_walk_outlined,
                    iconColor: _kGreen,
                    keyboard: TextInputType.number,
                    action: TextInputAction.next,
                    onNext: () => FocusScope.of(context).nextFocus(),
                  ),
                  _Divider(),
                  _FieldRow(
                    label: 'Height',
                    unit: 'cm',
                    controller: _heightCtrl,
                    icon: Icons.height_outlined,
                    iconColor: _kBlue,
                    action: TextInputAction.next,
                    onNext: () => FocusScope.of(context).nextFocus(),
                  ),
                  _Divider(),
                  _FieldRow(
                    label: 'Age',
                    unit: 'yrs',
                    controller: _ageCtrl,
                    icon: Icons.cake_outlined,
                    iconColor: _kOrange,
                    keyboard: TextInputType.number,
                    action: TextInputAction.next,
                    onNext: () => FocusScope.of(context).nextFocus(),
                  ),
                  _Divider(),
                  _FieldRow(
                    label: 'Goal Weight',
                    unit: 'kg',
                    controller: _goalWeightCtrl,
                    icon: Icons.flag_outlined,
                    iconColor: _kRed,
                    action: TextInputAction.done,
                    onNext: _saveEntries,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: _SaveBtn(onPressed: _saveEntries),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── BMR / TDEE card ─────────────────────────────────────────
            _SectionHeader('METABOLISM'),
            _BmrTdeeCard(p: p),
            const SizedBox(height: 12),

            // ── Goal progress ───────────────────────────────────────────
            _GoalCard(p: p),
            const SizedBox(height: 20),

            // ── Overview stats ──────────────────────────────────────────
            _SectionHeader('OVERVIEW'),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Current Weight',
                    value: p.latestWeightKg != null
                        ? '${p.latestWeightKg!.toStringAsFixed(1)} kg'
                        : '—',
                    sub: _weightChangeLine(p),
                    color: _kGreen,
                    icon: Icons.monitor_weight_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'BMI',
                    value: p.bmi != null ? p.bmi!.toStringAsFixed(1) : '—',
                    sub: p.bmiCategory,
                    color: p.bmi != null
                        ? p.bmiColor(context)
                        : _kSecondary,
                    icon: Icons.accessibility_new_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: "Today's Steps",
                    value:
                        p.todaySteps > 0 ? _fmt(p.todaySteps) : '—',
                    sub: p.todaySteps > 0
                        ? '${(p.stepProgress * 100).round()}% of goal'
                        : '8,000 goal',
                    color: _kGreen,
                    icon: Icons.directions_walk_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Workout Streak',
                    value: '${p.workoutStreak}d',
                    sub: p.workoutStreak > 0
                        ? 'Keep going! 🔥'
                        : 'Start today',
                    color: _kOrange,
                    icon: Icons.local_fire_department_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Cal Burned Today',
                    value: p.todayCaloriesBurned > 0
                        ? '${p.todayCaloriesBurned} kcal'
                        : '—',
                    sub: 'From workout',
                    color: _kRed,
                    icon: Icons.whatshot_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Weekly Burned',
                    value: p.weeklyCaloriesBurned > 0
                        ? '${p.weeklyCaloriesBurned} kcal'
                        : '—',
                    sub: 'Last 7 days',
                    color: _kRed,
                    icon: Icons.bar_chart_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── 1RM Calculator ───────────────────────────────────────────
            _SectionHeader('1RM CALCULATOR (EPLEY)'),
            _OrmCalc(
              exercises: _ormExercises,
              selected: _ormExercise,
              weight: _ormWeight,
              reps: _ormReps,
              orm: _epley1RM(_ormWeight, _ormReps),
              onExercise: (e) => setState(() => _ormExercise = e),
              onWeight: (v) => setState(() => _ormWeight = v),
              onReps: (v) => setState(() => _ormReps = v),
            ),
            const SizedBox(height: 20),

            // ── Weight history chart ─────────────────────────────────────
            if (recent.length >= 2) ...[
              _SectionHeader('WEIGHT TREND (30 DAYS)'),
              _AppleCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MiniWeightChart(entries: recent),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _ChartStat('Low',
                            '${recent.map((e) => e.weightKg).reduce(math.min).toStringAsFixed(1)} kg'),
                        _ChartStat('High',
                            '${recent.map((e) => e.weightKg).reduce(math.max).toStringAsFixed(1)} kg'),
                        _ChartStat('Avg',
                            '${(recent.map((e) => e.weightKg).reduce((a, b) => a + b) / recent.length).toStringAsFixed(1)} kg'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── BMI scale ────────────────────────────────────────────────
            _SectionHeader('BMI SCALE'),
            _AppleCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BmiBar(bmi: p.bmi),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _BmiLabel(
                          'Under', '< 18.5', const Color(0xFF40C8E0)),
                      _BmiLabel(
                          'Normal', '18.5–25', const Color(0xFF30D158)),
                      _BmiLabel(
                          'Over', '25–30', const Color(0xFFFF9F0A)),
                      _BmiLabel(
                          'Obese', '≥ 30', const Color(0xFFFF453A)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _weightChangeLine(FitnessProvider p) {
    final change = p.weightChangeKg;
    if (change == null) return 'Log daily to track trend';
    final sign = change > 0 ? '+' : '';
    return '$sign${change.toStringAsFixed(1)} kg this month';
  }

  String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }
}

// ── BMR / TDEE card ────────────────────────────────────────────────────────────
class _BmrTdeeCard extends StatelessWidget {
  final FitnessProvider p;
  const _BmrTdeeCard({required this.p});

  @override
  Widget build(BuildContext context) {
    return _AppleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🔥', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text(
                'Your Metabolism',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _MetaChip(
                label: 'BMR',
                value: '${p.bmr.round()} kcal',
                sub: 'At rest',
                color: _kBlue,
              ),
              const SizedBox(width: 10),
              _MetaChip(
                label: 'TDEE',
                value: '${p.tdee.round()} kcal',
                sub: 'With activity',
                color: _kOrange,
              ),
              const SizedBox(width: 10),
              _MetaChip(
                label: 'Cut Target',
                value: '${p.fatLossCalorieTarget.round()} kcal',
                sub: '500 kcal deficit',
                color: _kGreen,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Mifflin-St Jeor formula · ${p.weeklyWorkoutDays} workout days/week',
            style:
                const TextStyle(color: _kSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color color;
  const _MetaChip(
      {required this.label,
      required this.value,
      required this.sub,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
            Text(sub,
                style: const TextStyle(
                    color: _kSecondary, fontSize: 9)),
          ],
        ),
      ),
    );
  }
}

// ── Goal progress card ─────────────────────────────────────────────────────────
class _GoalCard extends StatelessWidget {
  final FitnessProvider p;
  const _GoalCard({required this.p});

  @override
  Widget build(BuildContext context) {
    final current = p.latestWeightKg;
    final goal = p.goalWeightKg;
    final eta = p.estimatedGoalDate;
    final wc = p.weeklyWeightChange;

    if (current == null) return const SizedBox.shrink();

    final startWeight = p.bodyHistory.isNotEmpty
        ? p.bodyHistory.first.weightKg
        : current;
    final totalToLose = (startWeight - goal).clamp(0.01, 200.0);
    final lost = (startWeight - current).clamp(0.0, totalToLose);
    final progress = (lost / totalToLose).clamp(0.0, 1.0);

    return _AppleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🎯', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              const Text('Goal Progress',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(
                '${current.toStringAsFixed(1)} → ${goal.toStringAsFixed(1)} kg',
                style: const TextStyle(color: _kSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor:
                  AlwaysStoppedAnimation<Color>(_kGreen),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progress * 100).toStringAsFixed(1)}% complete',
                style: const TextStyle(color: _kGreen, fontSize: 12),
              ),
              Text(
                eta != null
                    ? 'ETA: ${_fmtDate(eta)}'
                    : wc != null && wc >= 0
                        ? 'Gaining weight ⚠️'
                        : 'Log more data',
                style: const TextStyle(color: _kSecondary, fontSize: 12),
              ),
            ],
          ),
          if (wc != null) ...[
            const SizedBox(height: 6),
            Text(
              '${wc < 0 ? '📉' : '📈'} ${wc.toStringAsFixed(2)} kg/week trend',
              style: TextStyle(
                  color: wc < 0 ? _kGreen : _kOrange, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) {
    final diff = d.difference(DateTime.now()).inDays;
    if (diff < 7) return 'This week!';
    if (diff < 30) return '${(diff / 7).round()} weeks';
    return '${(diff / 30).round()} months';
  }
}

// ── 1RM Calculator ─────────────────────────────────────────────────────────────
class _OrmCalc extends StatelessWidget {
  final List<String> exercises;
  final String selected;
  final double weight;
  final int reps;
  final double orm;
  final void Function(String) onExercise;
  final void Function(double) onWeight;
  final void Function(int) onReps;

  const _OrmCalc({
    required this.exercises,
    required this.selected,
    required this.weight,
    required this.reps,
    required this.orm,
    required this.onExercise,
    required this.onWeight,
    required this.onReps,
  });

  @override
  Widget build(BuildContext context) {
    // Training zones from 1RM
    final zones = [
      (
        'Strength',
        _kRed,
        '${(orm * 0.85).round()}–${orm.round()} kg',
        '1–5 reps'
      ),
      (
        'Hypertrophy',
        _kOrange,
        '${(orm * 0.67).round()}–${(orm * 0.85).round()} kg',
        '6–12 reps'
      ),
      (
        'Endurance',
        _kGreen,
        '<${(orm * 0.67).round()} kg',
        '13+ reps'
      ),
    ];

    return _AppleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Exercise picker
          SizedBox(
            height: 34,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: exercises.length,
              itemBuilder: (_, i) {
                final ex = exercises[i];
                final sel = ex == selected;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onExercise(ex);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel
                          ? _kBlue
                          : Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      ex,
                      style: TextStyle(
                        color: sel ? Colors.black : _kSecondary,
                        fontSize: 12,
                        fontWeight: sel
                            ? FontWeight.w700
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Weight slider
          Row(
            children: [
              const Text('Weight',
                  style: TextStyle(color: _kSecondary, fontSize: 12)),
              const Spacer(),
              Text(
                '${weight.toStringAsFixed(1)} kg',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: _kBlue,
              inactiveTrackColor: Colors.white.withOpacity(0.1),
              thumbColor: _kBlue,
              overlayColor: _kBlue.withOpacity(0.2),
              trackHeight: 4,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: weight,
              min: 5,
              max: 200,
              divisions: 195,
              onChanged: onWeight,
            ),
          ),

          // Reps slider
          Row(
            children: [
              const Text('Reps',
                  style: TextStyle(color: _kSecondary, fontSize: 12)),
              const Spacer(),
              Text(
                '$reps reps',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: _kOrange,
              inactiveTrackColor: Colors.white.withOpacity(0.1),
              thumbColor: _kOrange,
              overlayColor: _kOrange.withOpacity(0.2),
              trackHeight: 4,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: reps.toDouble(),
              min: 1,
              max: 20,
              divisions: 19,
              onChanged: (v) => onReps(v.round()),
            ),
          ),

          const SizedBox(height: 6),
          // 1RM result
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_kBlue.withOpacity(0.2), _kGreen.withOpacity(0.15)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kBlue.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                const Text('Estimated 1RM',
                    style: TextStyle(color: _kSecondary, fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  '${orm.round()} kg',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1),
                ),
                Text(
                  '(${(orm * 2.205).round()} lbs)',
                  style: const TextStyle(color: _kSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Training zones
          const Text('TRAINING ZONES',
              style: TextStyle(
                  color: _kSecondary,
                  fontSize: 10,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...zones.map((z) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: z.$2, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(z.$1,
                        style: TextStyle(
                            color: z.$2,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text(z.$3,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12)),
                    const SizedBox(width: 8),
                    Text(z.$4,
                        style: const TextStyle(
                            color: _kSecondary, fontSize: 11)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ── Reusable widgets ───────────────────────────────────────────────────────────

class _SaveBtn extends StatelessWidget {
  final VoidCallback onPressed;
  const _SaveBtn({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _kGreen,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: const Text(
          'Save',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final String label;
  final String unit;
  final TextEditingController controller;
  final IconData icon;
  final Color iconColor;
  final TextInputType keyboard;
  final TextInputAction action;
  final VoidCallback onNext;

  const _FieldRow({
    required this.label,
    required this.unit,
    required this.controller,
    required this.icon,
    required this.iconColor,
    this.keyboard =
        const TextInputType.numberWithOptions(decimal: true),
    required this.action,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 17),
          ),
          const SizedBox(width: 12),
          Text(label,
              style:
                  const TextStyle(color: Colors.white, fontSize: 15)),
          const Spacer(),
          SizedBox(
            width: 90,
            child: TextField(
              controller: controller,
              keyboardType: keyboard,
              textAlign: TextAlign.right,
              textInputAction: action,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              onSubmitted: (_) => onNext(),
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 4),
                border: InputBorder.none,
                hintText: '0',
                hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.3)),
                suffix: Text(' $unit',
                    style: const TextStyle(
                        color: _kSecondary, fontSize: 13)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        height: 0.5,
        color: const Color(0xFF3A3A3C),
        margin: const EdgeInsets.symmetric(vertical: 4),
      );
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: _kSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _AppleCard extends StatelessWidget {
  final Widget child;
  const _AppleCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
          Text(sub,
              style: const TextStyle(color: _kSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

class _MiniWeightChart extends StatelessWidget {
  final List<BodyEntry> entries;
  const _MiniWeightChart({required this.entries});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: CustomPaint(
        painter: _WeightChartPainter(entries: entries),
        size: Size.infinite,
      ),
    );
  }
}

class _WeightChartPainter extends CustomPainter {
  final List<BodyEntry> entries;
  const _WeightChartPainter({required this.entries});

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.length < 2) return;

    final minW = entries.map((e) => e.weightKg).reduce(math.min);
    final maxW = entries.map((e) => e.weightKg).reduce(math.max);
    final range = (maxW - minW).clamp(0.5, double.infinity);

    final minD = entries.first.date.millisecondsSinceEpoch.toDouble();
    final maxD = entries.last.date.millisecondsSinceEpoch.toDouble();
    final dateRange = (maxD - minD).clamp(1.0, double.infinity);

    Offset toOffset(BodyEntry e) {
      final x =
          ((e.date.millisecondsSinceEpoch - minD) / dateRange) * size.width;
      final y = size.height - ((e.weightKg - minW) / range) * size.height * 0.9;
      return Offset(x, y);
    }

    // Fill
    final fillPath = Path()..moveTo(0, size.height);
    for (final e in entries) {
      final o = toOffset(e);
      fillPath.lineTo(o.dx, o.dy);
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    canvas.drawPath(fillPath,
        Paint()..color = _kGreen.withOpacity(0.15)..style = PaintingStyle.fill);

    // Line
    final linePath = Path();
    for (int i = 0; i < entries.length; i++) {
      final o = toOffset(entries[i]);
      if (i == 0) {
        linePath.moveTo(o.dx, o.dy);
      } else {
        linePath.lineTo(o.dx, o.dy);
      }
    }
    canvas.drawPath(
        linePath,
        Paint()
          ..color = _kGreen
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);

    // Dots
    final dotPaint = Paint()..color = _kGreen..style = PaintingStyle.fill;
    for (final e in entries) {
      canvas.drawCircle(toOffset(e), 2.5, dotPaint);
    }
    // Last dot bigger
    canvas.drawCircle(toOffset(entries.last), 4.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

class _BmiBar extends StatelessWidget {
  final double? bmi;
  const _BmiBar({this.bmi});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 16,
      child: LayoutBuilder(builder: (_, constraints) {
        const segments = [_kBlue, _kGreen, _kOrange, _kRed];
        return Stack(
          children: [
            Row(
              children: [
                for (int i = 0; i < 4; i++)
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: segments[i],
                        borderRadius: BorderRadius.horizontal(
                          left: i == 0
                              ? const Radius.circular(8)
                              : Radius.zero,
                          right: i == 3
                              ? const Radius.circular(8)
                              : Radius.zero,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (bmi != null)
              Positioned(
                left: (((bmi! - 15) / 25).clamp(0.0, 1.0) *
                        constraints.maxWidth -
                    6),
                top: 0,
                child: Container(
                  width: 12,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }
}

class _ChartStat extends StatelessWidget {
  final String label;
  final String value;
  const _ChartStat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(color: _kSecondary, fontSize: 11)),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _BmiLabel extends StatelessWidget {
  final String label;
  final String range;
  final Color color;
  const _BmiLabel(this.label, this.range, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        Text(range,
            style:
                const TextStyle(color: _kSecondary, fontSize: 10)),
      ],
    );
  }
}
