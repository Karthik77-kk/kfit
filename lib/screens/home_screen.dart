import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/fitness_provider.dart';
import '../models/models.dart';
import '../services/weather_service.dart';
import '../services/notification_service.dart';

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
  WeatherData? _weather;
  bool _weatherLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWeather();
    // Schedule morning notification on first load
    NotificationService().scheduleMorningSummary();
  }

  Future<void> _loadWeather() async {
    final w = await WeatherService().fetchWeather();
    if (mounted) setState(() { _weather = w; _weatherLoading = false; });
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 6)  return 'Rise and grind';
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    if (h < 21) return 'Good evening';
    return 'Good night';
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
        onRefresh: _loadWeather,
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
                    Text('${_greeting()}, Karthik 👋', style: const TextStyle(
                      color: Colors.white, fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: -0.5,
                    )),
                  ],
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16, top: 8),
                  child: _StreakBadge(streak: p.workoutStreak),
                ),
              ],
            ),

            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 32 + bottomPad),
              sliver: SliverList(
                delegate: SliverChildListDelegate([

                  // ── Weather card ──────────────────────────────────────────
                  _WeatherCard(weather: _weather, loading: _weatherLoading),
                  const SizedBox(height: 20),

                  // ── Activity rings ────────────────────────────────────────
                  const _SectionHdr('TODAY\'S ACTIVITY'),
                  const SizedBox(height: 10),
                  _ActivityRingsCard(provider: p),
                  const SizedBox(height: 20),

                  // ── Calorie balance ───────────────────────────────────────
                  const _SectionHdr('CALORIE BALANCE'),
                  const SizedBox(height: 10),
                  _CalorieBalanceCard(provider: p),
                  const SizedBox(height: 20),

                  // ── Move metrics ──────────────────────────────────────────
                  const _SectionHdr('MOVE'),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _MetricTile(
                      label: 'Steps', value: _fmtInt(p.todaySteps),
                      goal: '/ ${_fmtInt(FitnessProvider.kStepGoal)}',
                      icon: Icons.directions_walk_rounded, color: _kBlue,
                      progress: p.stepProgress,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _MetricTile(
                      label: 'Cal Burned', value: '${p.todayCaloriesBurned}',
                      goal: 'kcal',
                      icon: Icons.local_fire_department_rounded, color: _kRed,
                      progress: (p.todayCaloriesBurned / 400).clamp(0.0, 1.0),
                    )),
                  ]),
                  const SizedBox(height: 20),

                  // ── Nutrition ─────────────────────────────────────────────
                  const _SectionHdr('NUTRITION'),
                  const SizedBox(height: 10),
                  _NutritionCard(provider: p),
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
                  _WorkoutCard(workout: p.todayWorkout),
                  const SizedBox(height: 20),

                  // ── Supplements ───────────────────────────────────────────
                  const _SectionHdr('SUPPLEMENTS'),
                  const SizedBox(height: 10),
                  _SupplementsCard(supp: p.supplements),
                  const SizedBox(height: 20),

                  // ── Body ──────────────────────────────────────────────────
                  if (p.latestWeightKg != null) ...[
                    const _SectionHdr('BODY'),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: _MetricTile(
                        label: 'Weight',
                        value: p.latestWeightKg!.toStringAsFixed(1),
                        goal: 'kg  •  Goal: ${p.goalWeightKg.toStringAsFixed(1)} kg',
                        icon: Icons.monitor_weight_outlined,
                        color: _kOrange, progress: -1,
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _MetricTile(
                        label: 'BMI',
                        value: p.bmi?.toStringAsFixed(1) ?? '--',
                        goal: p.bmiCategory,
                        icon: Icons.health_and_safety_outlined,
                        color: p.bmiColor(context), progress: -1,
                      )),
                    ]),
                    if (p.weightChangeKg != null) ...[
                      const SizedBox(height: 8),
                      _WeightChangeBadge(change: p.weightChangeKg!),
                    ],
                    const SizedBox(height: 20),
                  ],

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

// ─── Weather Card ──────────────────────────────────────────────────────────────
class _WeatherCard extends StatelessWidget {
  final WeatherData? weather;
  final bool loading;
  const _WeatherCard({required this.weather, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Container(
        height: 80,
        decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(16)),
        child: const Center(child: SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(color: _kGreen, strokeWidth: 2),
        )),
      );
    }

    final w = weather;
    if (w == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(16)),
        child: const Row(children: [
          Text('🌐', style: TextStyle(fontSize: 20)),
          SizedBox(width: 10),
          Text('Weather unavailable — check connection', style: TextStyle(color: _kSecond, fontSize: 13)),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1A2A3A), _kCard],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(children: [
        Text(w.emoji, style: const TextStyle(fontSize: 40)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('${w.tempC.round()}°C', style: const TextStyle(
              color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700,
            )),
            const SizedBox(width: 10),
            Text(w.description, style: const TextStyle(color: _kSecond, fontSize: 14)),
          ]),
          const SizedBox(height: 4),
          Text(w.workoutAdvice, style: TextStyle(
            color: Colors.white.withOpacity(0.65), fontSize: 12,
          )),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('💧 ${w.humidity}%', style: const TextStyle(color: _kBlue, fontSize: 12)),
          const SizedBox(height: 4),
          Text('💨 ${w.windKph.round()} km/h', style: const TextStyle(color: _kSecond, fontSize: 12)),
          const SizedBox(height: 2),
          const Text('Bangalore', style: TextStyle(color: _kSecond, fontSize: 10)),
        ]),
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
            value: '${p.todayCalories.round()} / ${FitnessProvider.kCalorieGoal} kcal',
            progress: p.calorieProgress),
          const SizedBox(height: 10),
          _RingRow(color: _kGreen, label: 'Protein',
            value: '${p.todayProtein.round()} / ${FitnessProvider.kProteinGoal}g',
            progress: p.proteinProgress),
          const SizedBox(height: 10),
          _RingRow(color: _kBlue, label: 'Water',
            value: '${p.todayWaterMl} / ${FitnessProvider.kWaterGoalMl} ml',
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

// ─── Calorie Balance Card ──────────────────────────────────────────────────────
class _CalorieBalanceCard extends StatelessWidget {
  final FitnessProvider provider;
  const _CalorieBalanceCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final p = provider;
    final deficit = p.calorieDeficit;
    final inDef = deficit > 0;
    final color = inDef ? _kGreen : _kRed;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(inDef ? Icons.trending_down_rounded : Icons.trending_up_rounded, color: color, size: 18),
          const SizedBox(width: 8),
          Text(inDef ? 'In Deficit 🎯' : 'In Surplus', style: TextStyle(
            color: color, fontSize: 13, fontWeight: FontWeight.w600,
          )),
          const Spacer(),
          Text('${inDef ? '-' : '+'}${deficit.abs()} kcal', style: TextStyle(
            color: color, fontSize: 22, fontWeight: FontWeight.w700,
          )),
        ]),
        const SizedBox(height: 12),
        ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(
          value: (p.netCalories / FitnessProvider.kCalorieGoal).clamp(0.0, 1.0),
          backgroundColor: Colors.white.withOpacity(0.08),
          valueColor: AlwaysStoppedAnimation<Color>(p.netCalories > FitnessProvider.kCalorieGoal ? _kRed : _kGreen),
          minHeight: 8,
        )),
        const SizedBox(height: 10),
        Row(children: [
          _BalStat('Eaten', '${p.todayCalories.round()}', _kOrange),
          const Text(' − ', style: TextStyle(color: _kSecond, fontSize: 12)),
          _BalStat('Burned', '${p.todayCaloriesBurned}', _kRed),
          const Text(' = ', style: TextStyle(color: _kSecond, fontSize: 12)),
          _BalStat('Net', '${p.netCalories}', inDef ? _kGreen : _kRed),
          const Spacer(),
          Text('Goal: ${FitnessProvider.kCalorieGoal}', style: const TextStyle(color: _kSecond, fontSize: 11)),
        ]),
      ]),
    );
  }
}

class _BalStat extends StatelessWidget {
  final String l, v;
  final Color c;
  const _BalStat(this.l, this.v, this.c);
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(v, style: TextStyle(color: c, fontSize: 15, fontWeight: FontWeight.bold)),
    Text(l, style: const TextStyle(color: _kSecond, fontSize: 10)),
  ]);
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
        // Header
        Row(children: [
          Text('🤖', style: const TextStyle(fontSize: 18)),
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

        // Prediction chart
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

        // Stats row
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

    // Build all points for scale
    final allWeights = [
      ...history.map((e) => e.weightKg),
      ...forecast.map((f) => f.$2),
      goalWeight,
    ];
    final minW = allWeights.reduce(math.min) - 1.0;
    final maxW = allWeights.reduce(math.max) + 1.0;
    final range = (maxW - minW).clamp(0.5, double.infinity);

    // Time range: history start to forecast end
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

    // Draw goal weight line
    if (goalWeight >= minW && goalWeight <= maxW) {
      final goalY = size.height - ((goalWeight - minW) / range) * size.height;
      canvas.drawLine(
        Offset(0, goalY), Offset(size.width, goalY),
        Paint()..color = _kOrange.withOpacity(0.4)..strokeWidth = 1
          ..style = PaintingStyle.stroke,
      );
      // Draw dashed line manually
      final dashPaint = Paint()..color = _kOrange.withOpacity(0.5)..strokeWidth = 1.5;
      for (double x = 0; x < size.width; x += 10) {
        canvas.drawLine(Offset(x, goalY), Offset((x + 6).clamp(0, size.width), goalY), dashPaint);
      }
    }

    // Draw history (solid green)
    if (history.length >= 2) {
      final histPath = Path();
      final histPts = history.map((e) => toOff(e.date, e.weightKg)).toList();
      histPath.moveTo(histPts.first.dx, histPts.first.dy);
      for (final pt in histPts.skip(1)) histPath.lineTo(pt.dx, pt.dy);
      canvas.drawPath(histPath, Paint()
        ..color = _kGreen..strokeWidth = 2.5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);

      // Dots
      for (final pt in histPts) {
        canvas.drawCircle(pt, 3, Paint()..color = _kGreen);
      }
    }

    // Draw forecast (dashed blue)
    if (forecast.isNotEmpty && history.isNotEmpty) {
      final startPt = toOff(history.last.date, history.last.weightKg);
      final forecastPts = [startPt, ...forecast.map((f) => toOff(f.$1, f.$2))];

      // Dashed forecast line
      final dashPaint = Paint()
        ..color = _kBlue..strokeWidth = 2..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
      for (int i = 0; i < forecastPts.length - 1; i++) {
        if (i % 3 == 0) { // Draw every 3rd segment for dashed effect
          canvas.drawLine(forecastPts[i], forecastPts[i + 1], dashPaint);
        }
      }

      // Shade forecast area
      final shadePath = Path()
        ..moveTo(startPt.dx, size.height)
        ..lineTo(startPt.dx, startPt.dy);
      for (final pt in forecastPts.skip(1)) shadePath.lineTo(pt.dx, pt.dy);
      shadePath.lineTo(forecastPts.last.dx, size.height);
      shadePath.close();
      canvas.drawPath(shadePath, Paint()
        ..color = _kBlue.withOpacity(0.07)..style = PaintingStyle.fill);

      // End dot
      canvas.drawCircle(forecastPts.last, 5,
        Paint()..color = _kBlue.withOpacity(0.3)..style = PaintingStyle.fill);
      canvas.drawCircle(forecastPts.last, 4,
        Paint()..color = _kBlue..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(_) => true;
}

// ─── Metric Tile ───────────────────────────────────────────────────────────────
class _MetricTile extends StatelessWidget {
  final String label, value, goal;
  final IconData icon;
  final Color color;
  final double progress;
  const _MetricTile({
    required this.label, required this.value, required this.goal,
    required this.icon, required this.color, required this.progress,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(16)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, color: color, size: 16), const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: _kSecond, fontSize: 11))]),
      const SizedBox(height: 8),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 22,
          fontWeight: FontWeight.w700, height: 1.0)),
      Text(goal, style: const TextStyle(color: _kSecond, fontSize: 11)),
      if (progress >= 0) ...[
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(
          value: progress, backgroundColor: color.withOpacity(0.15),
          valueColor: AlwaysStoppedAnimation<Color>(color), minHeight: 4,
        )),
      ],
    ]),
  );
}

// ─── Nutrition Card ────────────────────────────────────────────────────────────
class _NutritionCard extends StatelessWidget {
  final FitnessProvider provider;
  const _NutritionCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final p = provider;
    final rem = p.caloriesRemaining;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(18)),
      child: Column(children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${p.todayCalories.round()}', style: const TextStyle(
              color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700, height: 1.0)),
            const Text('kcal eaten', style: TextStyle(color: _kSecond, fontSize: 12)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${rem.abs()}', style: TextStyle(
              color: rem >= 0 ? Colors.white : _kRed, fontSize: 20, fontWeight: FontWeight.bold)),
            Text(rem >= 0 ? 'remaining' : 'over goal',
              style: TextStyle(color: rem >= 0 ? _kSecond : _kRed, fontSize: 11)),
          ]),
        ]),
        const SizedBox(height: 10),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
          value: p.calorieProgress,
          backgroundColor: _kOrange.withOpacity(0.15),
          valueColor: AlwaysStoppedAnimation<Color>(p.calorieProgress >= 1 ? _kRed : _kOrange),
          minHeight: 6,
        )),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _NutrChip('Protein', '${p.todayProtein.round()}g',
              '/${FitnessProvider.kProteinGoal}g', _kGreen, p.proteinProgress),
          _NutrChip('Breakfast', '${p.breakfastEntries.fold(0.0, (s, e) => s + e.calories).round()}',
              'kcal', _kBlue, -1),
          _NutrChip('Items', '${p.todayFood.length}', 'logged', _kSecond, -1),
        ]),
      ]),
    );
  }
}

class _NutrChip extends StatelessWidget {
  final String label, value, sub;
  final Color color;
  final double progress;
  const _NutrChip(this.label, this.value, this.sub, this.color, this.progress);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
    child: Column(children: [
      Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      Text(label, style: const TextStyle(color: _kSecond, fontSize: 10)),
      if (progress >= 0) ...[
        const SizedBox(height: 3),
        SizedBox(width: 55, child: ClipRRect(borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(value: progress,
            backgroundColor: color.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color), minHeight: 3))),
      ],
    ]),
  );
}

// ─── Workout Card ──────────────────────────────────────────────────────────────
class _WorkoutCard extends StatelessWidget {
  final WorkoutLog? workout;
  const _WorkoutCard({required this.workout});

  @override
  Widget build(BuildContext context) {
    if (workout == null) {
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
    final color = workout!.workoutType == WorkoutType.a ? _kGreen : _kBlue;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3))),
      child: Row(children: [
        Icon(Icons.check_circle_rounded, color: color, size: 26),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Workout ${workout!.workoutType.name.toUpperCase()} done!',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
          Text('${workout!.durationMinutes} min · ${workout!.exercises.length} exercises · ${workout!.caloriesBurned} kcal',
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

// ─── Weight Change Badge ───────────────────────────────────────────────────────
class _WeightChangeBadge extends StatelessWidget {
  final double change;
  const _WeightChangeBadge({required this.change});

  @override
  Widget build(BuildContext context) {
    final loss = change < 0;
    final color = loss ? _kGreen : _kRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(loss ? Icons.trending_down_rounded : Icons.trending_up_rounded, color: color, size: 14),
        const SizedBox(width: 6),
        Text('${loss ? '' : '+'}${change.toStringAsFixed(1)} kg this month',
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
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
          const SizedBox(width: 12),
          _WeekStat('Kcal Burned', '${p.weeklyCaloriesBurned}', _kRed, Icons.local_fire_department_rounded),
          const SizedBox(width: 12),
          _WeekStat('Streak', '${p.workoutStreak} 🔥', _kOrange, null),
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
    final deficit = p.calorieDeficit;
    final weekly = p.weeklyWeightChange;
    if (p.todayCalories == 0)
      return '🌅 Start logging meals to track your 1700 kcal goal. Consistency is everything!';
    if (p.todayProtein < 60)
      return '💪 Protein is low (${p.todayProtein.round()}g). Add chicken, paneer, eggs or whey to protect muscle.';
    if (weekly != null && weekly < -0.8)
      return '⚠️ Losing ${weekly.abs().toStringAsFixed(2)} kg/week — that\'s too fast. Add 200–300 kcal to preserve muscle.';
    if (weekly != null && weekly > 0.2)
      return '📈 Trend shows weight gain. Reduce dinner portion or skip evening snacks.';
    if (deficit > 300)
      return '🎯 $deficit kcal deficit today — great fat-loss progress! Keep it consistent.';
    if (deficit < -200)
      return '⚠️ ${deficit.abs()} kcal over goal. A 30-min walk burns ~${(p.latestWeightKg ?? 70) ~/ 10 * 30} kcal.';
    if (p.todayWaterMl < 1000)
      return '💧 Only ${p.todayWaterMl}ml water so far. Hydration speeds up metabolism and reduces hunger.';
    if (p.todayWorkout == null && DateTime.now().hour > 10)
      return '🏋️ No workout yet. Even 30 min burns ~${estimateCaloriesBurned(p.latestWeightKg ?? 70, 30)} kcal.';
    return '✅ You\'re on track, Karthik! Consistency over 90 days = transformation. 💪';
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
