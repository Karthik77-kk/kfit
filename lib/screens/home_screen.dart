import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/fitness_provider.dart';
import '../models/models.dart';
import '../services/notification_service.dart';
import 'settings_screen.dart';

// ─── Design tokens ─────────────────────────────────────────────────────────────
const _kGreen  = Color(0xFF30D158);
const _kBlue   = Color(0xFF40C8E0);
const _kRed    = Color(0xFFFF453A);
const _kOrange = Color(0xFFFF9F0A);
const _kCard   = Color(0xFF1C1C1E);
const _kSecond = Color(0xFF8E8E93);

// ─── Home Screen ───────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Timer _refreshTimer;

  @override
  void initState() {
    super.initState();
    NotificationService().scheduleMorningSummary();
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    super.dispose();
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 6)  return 'morning';
    if (h < 12) return 'morning';
    if (h < 17) return 'afternoon';
    if (h < 21) return 'evening';
    return 'evening';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<FitnessProvider>();
    final today = DateFormat('EEEE, MMMM d').format(DateTime.now());
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: RefreshIndicator(
        color: _kGreen,
        backgroundColor: _kCard,
        onRefresh: () async {
          await context.read<FitnessProvider>().loadData();
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 110,
              pinned: true,
              backgroundColor: Colors.black,
              surfaceTintColor: Colors.transparent,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 20, bottom: 14, right: 20),
                title: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(today, style: const TextStyle(color: _kSecond, fontSize: 11, fontWeight: FontWeight.w400)),
                    Text('Good ${_greeting()}, ${context.watch<FitnessProvider>().userName}! 👋', style: const TextStyle(
                      color: Colors.white, fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: -0.5,
                    )),
                  ],
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 4, top: 8),
                  child: _StreakBadge(streak: p.workoutStreak),
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined, size: 22),
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen())),
                ),
              ],
            ),

            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 32 + bottomPad),
              sliver: SliverList(
                delegate: SliverChildListDelegate([

                  // ── Activity rings ────────────────────────────────────────
                  const _SectionHdr('TODAY\'S ACTIVITY'),
                  const SizedBox(height: 10),
                  _ActivityRingsCard(provider: p),
                  const SizedBox(height: 20),

                  // ── Calorie ring tile ─────────────────────────────────────
                  const _SectionHdr('CALORIE BALANCE'),
                  const SizedBox(height: 10),
                  const _CalorieRingTile(),
                  const SizedBox(height: 10),
                  const _MacroRow(),
                  const SizedBox(height: 20),

                  // ── Burn breakdown ────────────────────────────────────────
                  const _SectionHdr('BURN BREAKDOWN'),
                  const SizedBox(height: 10),
                  const _BurnBreakdownTile(),
                  const SizedBox(height: 20),

                  // ── Steps + Water ─────────────────────────────────────────
                  const _SectionHdr('MOVE & HYDRATE'),
                  const SizedBox(height: 10),
                  const _StepsWaterRow(),
                  const SizedBox(height: 20),

                  // ── Body stats ────────────────────────────────────────────
                  const _BodyStatsTile(),
                  const SizedBox(height: 20),

                  // ── Weight prediction chart ───────────────────────────────
                  if (p.getRecentBodyEntries(days: 90).length >= 3) ...[
                    const _SectionHdr('WEIGHT PREDICTION (AI TREND)'),
                    const SizedBox(height: 10),
                    _WeightPredictionCard(provider: p),
                    const SizedBox(height: 20),
                  ],

                  // ── Workout ───────────────────────────────────────────────
                  const _SectionHdr('WORKOUT'),
                  const SizedBox(height: 10),
                  _WorkoutCard(workouts: p.todayWorkouts),
                  const SizedBox(height: 20),

                  // ── Supplements ───────────────────────────────────────────
                  const _SectionHdr('SUPPLEMENTS'),
                  const SizedBox(height: 10),
                  _SupplementsCard(supp: p.supplements),
                  const SizedBox(height: 20),

                  // ── Weekly snapshot ───────────────────────────────────────
                  const _SectionHdr('THIS WEEK'),
                  const SizedBox(height: 10),
                  _WeeklySnapshotCard(provider: p),
                  const SizedBox(height: 20),

                  // ── Smart tip ─────────────────────────────────────────────
                  _SmartTip(provider: p),
                  const SizedBox(height: 8),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helpers ───────────────────────────────────────────────────────────────────
String _fmtInt(int n) {
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}k';
  return '$n';
}

/// Estimate calories burned for a given body weight and exercise duration.
/// Uses MET 5 (moderate intensity) as a sensible default for 30-min sessions.
int estimateCaloriesBurned(double weightKg, int minutes) =>
    (5.0 * weightKg * minutes / 60.0).round();

// ─── Section header ────────────────────────────────────────────────────────────
class _SectionHdr extends StatelessWidget {
  final String text;
  const _SectionHdr(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(
    color: _kSecond, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8,
  ));
}

// ─── Streak badge ──────────────────────────────────────────────────────────────
class _StreakBadge extends StatelessWidget {
  final int streak;
  const _StreakBadge({required this.streak});
  @override
  Widget build(BuildContext context) {
    if (streak == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _kOrange.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kOrange.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Text('🔥', style: TextStyle(fontSize: 14)),
        const SizedBox(width: 4),
        Text('$streak day${streak == 1 ? '' : 's'}', style: const TextStyle(
          color: _kOrange, fontSize: 12, fontWeight: FontWeight.w600,
        )),
      ]),
    );
  }
}

// ─── Activity Rings ────────────────────────────────────────────────────────────
class _ActivityRingsCard extends StatelessWidget {
  final FitnessProvider provider;
  const _ActivityRingsCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final p = provider;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        SizedBox(
          width: 110, height: 110,
          child: CustomPaint(painter: _RingsPainter(
            values: [p.calorieProgress, p.proteinProgress, p.waterProgress],
            colors: [_kRed, _kGreen, _kBlue],
          )),
        ),
        const SizedBox(width: 18),
        Expanded(child: Column(children: [
          _RingRow(color: _kRed, label: 'Calories',
            value: '${p.todayCaloriesTotal.round()} / ${p.calorieGoal} kcal',
            progress: p.calorieProgress),
          const SizedBox(height: 10),
          _RingRow(color: _kGreen, label: 'Protein',
            value: '${p.todayProteinTotal.round()} / ${p.proteinGoal}g',
            progress: p.proteinProgress),
          const SizedBox(height: 10),
          _RingRow(color: _kBlue, label: 'Water',
            value: '${p.todayWaterMl} / ${p.waterGoalMl} ml',
            progress: p.waterProgress),
        ])),
      ]),
    );
  }
}

class _RingRow extends StatelessWidget {
  final Color color;
  final String label, value;
  final double progress;
  const _RingRow({required this.color, required this.label, required this.value, required this.progress});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(color: _kSecond, fontSize: 11)),
      const Spacer(),
      Text('${(progress * 100).round()}%', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    ]),
    const SizedBox(height: 4),
    ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(
      value: progress, backgroundColor: color.withOpacity(0.15),
      valueColor: AlwaysStoppedAnimation<Color>(color), minHeight: 5,
    )),
    const SizedBox(height: 2),
    Text(value, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
  ]);
}

class _RingsPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  const _RingsPainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const stroke = 10.0;
    const gap = 14.0;
    for (int i = 0; i < values.length; i++) {
      final r = size.width / 2 - stroke / 2 - i * gap;
      if (r <= 0) continue;
      canvas.drawCircle(center, r, Paint()
        ..color = colors[i].withOpacity(0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke);
      if (values[i] > 0) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: r),
          -math.pi / 2, 2 * math.pi * values[i].clamp(0.0, 1.0),
          false,
          Paint()
            ..color = colors[i]
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_) => true;
}

// ─── Calorie Ring Tile ─────────────────────────────────────────────────────────
class _CalorieRingTile extends StatelessWidget {
  const _CalorieRingTile();
  @override
  Widget build(BuildContext context) {
    final p = context.watch<FitnessProvider>();
    final eaten = p.todayCaloriesTotal;
    final burned = p.totalCaloriesBurned;
    final goal = p.calorieGoal.toDouble();
    final net = eaten - burned;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          const Text('Calorie Balance',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(180, 180),
                  painter: _CalorieRingPainter(eaten: eaten, burned: burned, goal: goal),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      net >= 0 ? '+${net.round()}' : '${net.round()}',
                      style: TextStyle(
                        fontSize: 32, fontWeight: FontWeight.w800,
                        color: net > 200 ? _kRed : net < -200 ? _kGreen : Colors.white,
                      ),
                    ),
                    Text(
                      net >= 0 ? 'kcal surplus' : 'kcal deficit',
                      style: const TextStyle(color: _kSecond, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _RingLegend(color: _kOrange, label: 'Eaten', value: '${eaten.round()} kcal'),
              _RingLegend(color: _kGreen, label: 'Burned', value: '${burned.round()} kcal'),
              _RingLegend(color: _kBlue, label: 'Goal', value: '${goal.round()} kcal'),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingLegend extends StatelessWidget {
  final Color color;
  final String label, value;
  const _RingLegend({required this.color, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: _kSecond, fontSize: 11)),
      ]),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    ]);
  }
}

class _CalorieRingPainter extends CustomPainter {
  final double eaten, burned, goal;
  const _CalorieRingPainter({required this.eaten, required this.burned, required this.goal});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2 - 8;
    final innerRadius = outerRadius - 22;

    final bgPaint = Paint()
      ..color = const Color(0xFF2C2C2E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..strokeCap = StrokeCap.round;

    final eatenPaint = Paint()
      ..color = _kOrange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..strokeCap = StrokeCap.round;

    final burnedPaint = Paint()
      ..color = _kGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    const startAngle = -90 * (3.14159 / 180);
    const fullCircle = 2 * 3.14159;

    canvas.drawArc(Rect.fromCircle(center: center, radius: outerRadius),
        startAngle, fullCircle, false, bgPaint);
    canvas.drawArc(Rect.fromCircle(center: center, radius: innerRadius),
        startAngle, fullCircle, false, bgPaint..color = const Color(0xFF2C2C2E));

    final eatenSweep = (eaten / goal * fullCircle).clamp(0.0, fullCircle);
    if (eatenSweep > 0) {
      canvas.drawArc(Rect.fromCircle(center: center, radius: outerRadius),
          startAngle, eatenSweep, false, eatenPaint);
    }

    final burnedMax = goal * 1.2;
    final burnedSweep = (burned / burnedMax * fullCircle).clamp(0.0, fullCircle);
    if (burnedSweep > 0) {
      canvas.drawArc(Rect.fromCircle(center: center, radius: innerRadius),
          startAngle, burnedSweep, false, burnedPaint);
    }
  }

  @override
  bool shouldRepaint(_CalorieRingPainter old) =>
      old.eaten != eaten || old.burned != burned || old.goal != goal;
}

// ─── Macro Row ─────────────────────────────────────────────────────────────────
class _MacroRow extends StatelessWidget {
  const _MacroRow();
  @override
  Widget build(BuildContext context) {
    final p = context.watch<FitnessProvider>();
    final protein = p.todayProteinTotal;
    final proteinGoal = p.proteinGoal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Expanded(child: _MacroChip(
            label: 'Protein',
            value: '${protein.round()}g',
            goal: '/ ${proteinGoal}g',
            color: _kBlue,
            progress: (protein / proteinGoal).clamp(0.0, 1.0),
          )),
          const SizedBox(width: 8),
          Expanded(child: _MacroChip(
            label: 'Calories in',
            value: '${p.todayCaloriesTotal.round()}',
            goal: '/ ${p.calorieGoal} kcal',
            color: _kOrange,
            progress: p.calorieProgress,
          )),
          const SizedBox(width: 8),
          Expanded(child: _MacroChip(
            label: 'Net',
            value: '${p.netCalories}',
            goal: p.netCalories <= p.calorieGoal ? 'under goal ✓' : 'over goal',
            color: p.netCalories <= p.calorieGoal ? _kGreen : _kRed,
            progress: 1.0,
          )),
        ],
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label, value, goal;
  final Color color;
  final double progress;
  const _MacroChip({required this.label, required this.value, required this.goal, required this.color, required this.progress});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: _kSecond, fontSize: 11)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
      Text(goal, style: const TextStyle(color: _kSecond, fontSize: 10)),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: progress,
          backgroundColor: const Color(0xFF2C2C2E),
          valueColor: AlwaysStoppedAnimation(color),
          minHeight: 4,
        ),
      ),
    ]);
  }
}

// ─── Burn Breakdown Tile ───────────────────────────────────────────────────────
class _BurnBreakdownTile extends StatelessWidget {
  const _BurnBreakdownTile();
  @override
  Widget build(BuildContext context) {
    final p = context.watch<FitnessProvider>();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Calories Burned Today',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _BurnChip(icon: '😴', label: 'Resting',
                value: p.restingCaloriesBurned.round(), color: const Color(0xFF5E5CE6))),
            const SizedBox(width: 8),
            Expanded(child: _BurnChip(icon: '👟', label: 'Walking',
                value: p.walkingCaloriesBurned.round(), color: _kBlue)),
            const SizedBox(width: 8),
            Expanded(child: _BurnChip(icon: '💪', label: 'Workout',
                value: p.todayCaloriesBurned, color: _kGreen)),
          ]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2E),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Burned', style: TextStyle(fontSize: 13, color: _kSecond)),
                Text('${p.totalCaloriesBurned.round()} kcal',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kGreen)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BurnChip extends StatelessWidget {
  final String icon, label;
  final int value;
  final Color color;
  const _BurnChip({required this.icon, required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text('$value kcal',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        Text(label,
            style: const TextStyle(fontSize: 10, color: _kSecond)),
      ]),
    );
  }
}

// ─── Steps + Water Row ────────────────────────────────────────────────────────
class _StepsWaterRow extends StatelessWidget {
  const _StepsWaterRow();
  @override
  Widget build(BuildContext context) {
    final p = context.watch<FitnessProvider>();
    return Row(children: [
      Expanded(child: _MiniRingCard(
        icon: '👟',
        label: p.hasPedometerData ? 'Steps 📱' : 'Steps',
        current: p.todaySteps.toDouble(),
        goal: p.stepGoal.toDouble(),
        valueText: _fmtInt(p.todaySteps),
        goalText: '/ ${_fmtInt(p.stepGoal)}',
        color: _kBlue,
      )),
      const SizedBox(width: 10),
      Expanded(child: _MiniRingCard(
        icon: '💧',
        label: 'Water',
        current: p.todayWaterMl.toDouble(),
        goal: p.waterGoalMl.toDouble(),
        valueText: '${p.todayWaterMl} ml',
        goalText: '/ ${p.waterGoalMl} ml',
        color: const Color(0xFF0A84FF),
      )),
    ]);
  }
}

class _MiniRingCard extends StatelessWidget {
  final String icon, label, valueText, goalText;
  final double current, goal;
  final Color color;
  const _MiniRingCard({required this.icon, required this.label, required this.current,
      required this.goal, required this.valueText, required this.goalText, required this.color});

  @override
  Widget build(BuildContext context) {
    final progress = (current / goal).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
        const SizedBox(height: 10),
        Text(valueText, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        Text(goalText, style: const TextStyle(color: _kSecond, fontSize: 11)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: const Color(0xFF2C2C2E),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 6,
          ),
        ),
      ]),
    );
  }
}

// ─── Body Stats Tile ───────────────────────────────────────────────────────────
class _BodyStatsTile extends StatelessWidget {
  const _BodyStatsTile();
  @override
  Widget build(BuildContext context) {
    final p = context.watch<FitnessProvider>();
    final scale = p.latestScaleEntry;
    final bmi = p.bmi;
    if (scale == null && bmi == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Body Stats', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const Spacer(),
          if (scale != null)
            Text(
              '${scale.date.day}/${scale.date.month}',
              style: const TextStyle(color: _kSecond, fontSize: 12),
            ),
        ]),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (p.latestWeightKg != null)
              _StatChip('⚖️', 'Weight', '${p.latestWeightKg!.toStringAsFixed(1)} kg', Colors.white),
            if (bmi != null)
              _StatChip('📊', 'BMI', bmi.toStringAsFixed(1), p.bmiColor(context)),
            if (scale != null) ...[
              _StatChip('🔥', 'Body Fat', '${scale.bodyFatPercent.toStringAsFixed(1)}%', _kOrange),
              _StatChip('💪', 'Muscle', '${scale.muscleMassKg.toStringAsFixed(1)} kg', _kGreen),
              _StatChip('💧', 'Water', '${scale.bodyWaterPercent.toStringAsFixed(1)}%', _kBlue),
              _StatChip('🧬', 'Bio Age', '${scale.biologicalAge} yr', const Color(0xFF5E5CE6)),
            ],
          ],
        ),
      ]),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String emoji, label, value;
  final Color color;
  const _StatChip(this.emoji, this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 5),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: _kSecond, fontSize: 10)),
          Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      ]),
    );
  }
}

// ─── Weight Prediction Card ────────────────────────────────────────────────────
class _WeightPredictionCard extends StatelessWidget {
  final FitnessProvider provider;
  const _WeightPredictionCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final p = provider;
    final forecast = p.weightForecast(days: 30);
    final current = p.latestWeightKg!;
    final weekly = p.weeklyWeightChange;
    final goalDate = p.estimatedGoalDate;
    final predicted30 = forecast.isNotEmpty ? forecast.last.$2 : null;

    final isLosing = weekly != null && weekly < 0;
    final trendColor = isLosing ? _kGreen : _kRed;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('🤖', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('AI Weight Forecast', style: TextStyle(
              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600,
            )),
            Text('Linear trend from your last ${p.getRecentBodyEntries(days: 90).length} logs',
                style: const TextStyle(color: _kSecond, fontSize: 11)),
          ]),
          const Spacer(),
          if (weekly != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: trendColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: trendColor.withOpacity(0.3)),
              ),
              child: Text(
                '${weekly >= 0 ? '+' : ''}${weekly.toStringAsFixed(2)} kg/wk',
                style: TextStyle(color: trendColor, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          height: 120,
          child: CustomPaint(
            painter: _PredictionPainter(
              history: p.getRecentBodyEntries(days: 30),
              forecast: forecast,
              goalWeight: p.goalWeightKg,
            ),
            size: Size.infinite,
          ),
        ),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _PredStat('Now', '${current.toStringAsFixed(1)} kg', Colors.white),
          _PredStat('In 30 days', predicted30 != null
              ? '${predicted30.toStringAsFixed(1)} kg' : '—', trendColor),
          _PredStat('Goal', '${p.goalWeightKg.toStringAsFixed(1)} kg', _kOrange),
          _PredStat('ETA', goalDate != null
              ? DateFormat('d MMM').format(goalDate) : '—', _kBlue),
        ]),
        if (goalDate != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _kGreen.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const Text('🎯', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'At this rate you\'ll reach ${p.goalWeightKg.toStringAsFixed(1)} kg by ${DateFormat('d MMMM yyyy').format(goalDate)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
              )),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _PredStat extends StatelessWidget {
  final String l, v;
  final Color c;
  const _PredStat(this.l, this.v, this.c);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(v, style: TextStyle(color: c, fontSize: 14, fontWeight: FontWeight.bold)),
    Text(l, style: const TextStyle(color: _kSecond, fontSize: 10)),
  ]);
}

class _PredictionPainter extends CustomPainter {
  final List<BodyEntry> history;
  final List<(DateTime, double)> forecast;
  final double goalWeight;

  const _PredictionPainter({
    required this.history, required this.forecast, required this.goalWeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty && forecast.isEmpty) return;

    final allWeights = [
      ...history.map((e) => e.weightKg),
      ...forecast.map((f) => f.$2),
      goalWeight,
    ];
    final minW = allWeights.reduce(math.min) - 1.0;
    final maxW = allWeights.reduce(math.max) + 1.0;
    final range = (maxW - minW).clamp(0.5, double.infinity);

    final allDates = [
      if (history.isNotEmpty) history.first.date,
      if (forecast.isNotEmpty) forecast.last.$1,
    ];
    if (allDates.length < 2) return;
    final minT = allDates.first.millisecondsSinceEpoch.toDouble();
    final maxT = allDates.last.millisecondsSinceEpoch.toDouble();
    final timeRange = (maxT - minT).clamp(1.0, double.infinity);

    Offset toOff(DateTime d, double w) {
      final x = ((d.millisecondsSinceEpoch - minT) / timeRange) * size.width;
      final y = size.height - ((w - minW) / range) * size.height;
      return Offset(x.clamp(0, size.width), y.clamp(0, size.height));
    }

    if (goalWeight >= minW && goalWeight <= maxW) {
      final goalY = size.height - ((goalWeight - minW) / range) * size.height;
      final dashPaint = Paint()..color = _kOrange.withOpacity(0.5)..strokeWidth = 1.5;
      for (double x = 0; x < size.width; x += 10) {
        canvas.drawLine(Offset(x, goalY), Offset((x + 6).clamp(0, size.width), goalY), dashPaint);
      }
    }

    if (history.length >= 2) {
      final histPath = Path();
      final histPts = history.map((e) => toOff(e.date, e.weightKg)).toList();
      histPath.moveTo(histPts.first.dx, histPts.first.dy);
      for (final pt in histPts.skip(1)) histPath.lineTo(pt.dx, pt.dy);
      canvas.drawPath(histPath, Paint()
        ..color = _kGreen..strokeWidth = 2.5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
      for (final pt in histPts) {
        canvas.drawCircle(pt, 3, Paint()..color = _kGreen);
      }
    }

    if (forecast.isNotEmpty && history.isNotEmpty) {
      final startPt = toOff(history.last.date, history.last.weightKg);
      final forecastPts = [startPt, ...forecast.map((f) => toOff(f.$1, f.$2))];
      final dashPaint = Paint()
        ..color = _kBlue..strokeWidth = 2..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
      for (int i = 0; i < forecastPts.length - 1; i++) {
        if (i % 3 == 0) canvas.drawLine(forecastPts[i], forecastPts[i + 1], dashPaint);
      }
      final shadePath = Path()
        ..moveTo(startPt.dx, size.height)
        ..lineTo(startPt.dx, startPt.dy);
      for (final pt in forecastPts.skip(1)) shadePath.lineTo(pt.dx, pt.dy);
      shadePath.lineTo(forecastPts.last.dx, size.height);
      shadePath.close();
      canvas.drawPath(shadePath, Paint()
        ..color = _kBlue.withOpacity(0.07)..style = PaintingStyle.fill);
      canvas.drawCircle(forecastPts.last, 4, Paint()..color = _kBlue..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(_) => true;
}

// ─── Workout Card ──────────────────────────────────────────────────────────────
class _WorkoutCard extends StatelessWidget {
  final List<WorkoutLog> workouts;
  const _WorkoutCard({required this.workouts});

  @override
  Widget build(BuildContext context) {
    if (workouts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _kGreen.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.fitness_center_rounded, color: _kGreen, size: 20)),
          const SizedBox(width: 14),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('No workout logged yet', style: TextStyle(
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            Text('Tap Workout tab to start', style: TextStyle(color: _kSecond, fontSize: 12)),
          ]),
        ]),
      );
    }
    final totalExercises = workouts.fold(0, (s, w) => s + w.exercises.length);
    final displayName = workouts.length == 1
        ? workouts.first.name
        : '${workouts.length} sessions done';
    final sessionLabel = workouts.length == 1
        ? '$totalExercises exercises logged today'
        : '$totalExercises exercises across ${workouts.length} sessions';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kGreen.withOpacity(0.3))),
      child: Row(children: [
        const Icon(Icons.check_circle_rounded, color: _kGreen, size: 26),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(displayName,
            style: const TextStyle(color: _kGreen, fontWeight: FontWeight.bold, fontSize: 14)),
          Text(sessionLabel,
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
        ])),
      ]),
    );
  }
}

// ─── Supplements Card ──────────────────────────────────────────────────────────
class _SupplementsCard extends StatelessWidget {
  final SupplementStatus supp;
  const _SupplementsCard({required this.supp});

  @override
  Widget build(BuildContext context) {
    final items = [('Whey', supp.whey, '🥛'), ('Creatine', supp.creatine, '⚡'), ('Multivitamin', supp.multivitamin, '💊')];
    final done = items.where((e) => e.$2).length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('$done/${items.length} taken', style: const TextStyle(color: _kSecond, fontSize: 12)),
          const Spacer(),
          if (done == items.length) const Text('✅ All done!',
              style: TextStyle(color: _kGreen, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 10),
        Row(children: items.map((item) => Expanded(child: Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: item.$2 ? _kGreen.withOpacity(0.15) : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: item.$2 ? _kGreen.withOpacity(0.4) : Colors.transparent),
            ),
            child: Column(children: [
              Text(item.$3, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 4),
              Text(item.$1, style: TextStyle(
                color: item.$2 ? _kGreen : _kSecond, fontSize: 10, fontWeight: FontWeight.w500)),
            ]),
          ),
        ))).toList()),
      ]),
    );
  }
}

// ─── Weekly Snapshot Card ──────────────────────────────────────────────────────
class _WeeklySnapshotCard extends StatelessWidget {
  final FitnessProvider provider;
  const _WeeklySnapshotCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final p = provider;
    final map = p.weeklyWorkoutMap;
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final today = DateTime.now().weekday - 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(18)),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (i) {
            final done = i < map.length ? map[i] : false;
            final isToday = i == today;
            return Column(children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: done ? _kGreen.withOpacity(0.2) : isToday
                      ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.04),
                  shape: BoxShape.circle,
                  border: Border.all(color: done ? _kGreen : isToday ? Colors.white38 : Colors.transparent, width: 1.5),
                ),
                child: done ? const Icon(Icons.check_rounded, color: _kGreen, size: 16) : null,
              ),
              const SizedBox(height: 4),
              Text(days[i], style: TextStyle(
                color: done ? _kGreen : isToday ? Colors.white : _kSecond,
                fontSize: 11, fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              )),
            ]);
          }),
        ),
        const SizedBox(height: 12),
        const Divider(color: Color(0xFF38383A), thickness: 0.5, height: 1),
        const SizedBox(height: 12),
        Row(children: [
          _WeekStat('Workouts', '${p.weeklyWorkoutDays}/7', _kGreen, Icons.fitness_center_rounded),
          const SizedBox(width: 8),
          _WeekStat('Kcal Burned', '${p.weeklyCaloriesBurned}', _kRed, Icons.local_fire_department_rounded),
          const SizedBox(width: 8),
          _WeekStat('Workout 🔥', '${p.workoutStreak}d', _kOrange, null),
          const SizedBox(width: 8),
          _WeekStat('Diet 🥗', '${p.calorieStreak}d', const Color(0xFF40C8E0), null),
        ]),
      ]),
    );
  }
}

class _WeekStat extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData? icon;
  const _WeekStat(this.label, this.value, this.color, this.icon);

  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
    decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (icon != null) ...[Icon(icon, color: color, size: 14), const SizedBox(height: 4)],
      Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      Text(label, style: const TextStyle(color: _kSecond, fontSize: 10)),
    ]),
  ));
}

// ─── Smart Tip ─────────────────────────────────────────────────────────────────
class _SmartTip extends StatelessWidget {
  final FitnessProvider provider;
  const _SmartTip({required this.provider});

  String _tip(FitnessProvider p) {
    if (p.todayCaloriesTotal == 0)
      return '🌅 Start logging meals to track your ${p.calorieGoal} kcal goal. Consistency is everything!';
    if (p.todayProteinTotal < 60)
      return '💪 Protein is low (${p.todayProteinTotal.round()}g). Add chicken, paneer, eggs or whey to protect muscle.';
    final weekly = p.weeklyWeightChange;
    if (weekly != null && weekly < -0.8)
      return '⚠️ Losing ${weekly.abs().toStringAsFixed(2)} kg/week — that\'s too fast. Add 200–300 kcal to preserve muscle.';
    if (weekly != null && weekly > 0.2)
      return '📈 Trend shows weight gain. Reduce dinner portion or skip evening snacks.';
    final deficit = p.calorieDeficit;
    if (deficit > 300)
      return '🎯 $deficit kcal deficit today — great fat-loss progress! Keep it consistent.';
    if (deficit < -200)
      return '⚠️ ${deficit.abs()} kcal over goal. A 30-min walk burns ~${(p.latestWeightKg ?? 70) ~/ 10 * 30} kcal.';
    if (p.todayWaterMl < 1000)
      return '💧 Only ${p.todayWaterMl}ml water so far. Hydration speeds up metabolism and reduces hunger.';
    if (p.todayWorkout == null && DateTime.now().hour > 10)
      return '🏋️ No workout yet. Even 30 min burns ~${estimateCaloriesBurned(p.latestWeightKg ?? 70, 30)} kcal.';
    return '✅ You\'re on track! Consistency over 90 days = transformation. 💪';
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _kGreen.withOpacity(0.08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _kGreen.withOpacity(0.2)),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('💡', style: TextStyle(fontSize: 18)),
      const SizedBox(width: 10),
      Expanded(child: Text(_tip(provider),
        style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5))),
    ]),
  );
}
