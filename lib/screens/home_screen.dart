import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/fitness_provider.dart';
import '../models/models.dart';
import '../services/weather_service.dart';
import '../services/notification_service.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _kGreen = Color(0xFF30D158);
const _kBlue = Color(0xFF40C8E0);
const _kRed = Color(0xFFFF453A);
const _kOrange = Color(0xFFFF9F0A);
const _kCard = Color(0xFF1C1C1E);
const _kSecondary = Color(0xFF8E8E93);

String _fmtInt(num v) => v.round().toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

// ══════════════════════════════════════════════════════════════════════════════
// Home Screen
// ══════════════════════════════════════════════════════════════════════════════

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
    NotificationService().scheduleMorningSummary();
  }

  Future<void> _loadWeather() async {
    setState(() => _weatherLoading = true);
    final data = await WeatherService().fetchWeather();
    if (mounted) {
      setState(() {
        _weather = data;
        _weatherLoading = false;
      });
    }
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
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
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Header ────────────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 110,
              pinned: true,
              backgroundColor: Colors.black,
              surfaceTintColor: Colors.transparent,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding:
                    const EdgeInsets.only(left: 20, bottom: 14, right: 20),
                title: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      today,
                      style: const TextStyle(
                        color: _kSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${_greeting()}, Karthik 👋',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Content ───────────────────────────────────────────────────
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomPad),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Weather
                  _WeatherCard(weather: _weather, loading: _weatherLoading),
                  const SizedBox(height: 16),

                  // Activity rings
                  _ActivityRingsCard(p: p),
                  const SizedBox(height: 16),

                  // Calorie balance
                  _CalorieBalanceCard(p: p),
                  const SizedBox(height: 16),

                  // Weight prediction
                  _WeightPredictionCard(p: p),
                  const SizedBox(height: 16),

                  // Weekly snapshot
                  _WeeklySnapshotCard(p: p),
                  const SizedBox(height: 16),

                  // Nutrition breakdown
                  _NutritionCard(p: p),
                  const SizedBox(height: 16),

                  // Smart tip
                  _SmartTip(p: p),
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

// ── Weather card ───────────────────────────────────────────────────────────────
class _WeatherCard extends StatelessWidget {
  final WeatherData? weather;
  final bool loading;
  const _WeatherCard({required this.weather, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Container(
        height: 90,
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: _kBlue),
          ),
        ),
      );
    }

    final w = weather;
    if (w == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Text('🌡️', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Bangalore weather unavailable\nCheck your connection',
                style: TextStyle(color: _kSecondary, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1A2A3A),
            _kCard,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBlue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(w.emoji, style: const TextStyle(fontSize: 36)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${w.tempC.round()}°C',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          w.description,
                          style: const TextStyle(
                              color: _kSecondary, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Bangalore  💧 ${w.humidity.round()}%  💨 ${w.windKph.round()} km/h',
                      style: const TextStyle(
                          color: _kSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _kBlue.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              w.workoutAdvice,
              style: const TextStyle(color: _kBlue, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Activity rings card ────────────────────────────────────────────────────────
class _ActivityRingsCard extends StatelessWidget {
  final FitnessProvider p;
  const _ActivityRingsCard({required this.p});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Rings
          SizedBox(
            width: 110,
            height: 110,
            child: CustomPaint(
              painter: _RingsPainter(
                values: [p.calorieProgress, p.proteinProgress, p.waterProgress],
                colors: [_kRed, _kGreen, _kBlue],
              ),
            ),
          ),
          const SizedBox(width: 20),
          // Legend
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Today\'s Rings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _RingLegend(
                  color: _kRed,
                  label: 'Calories',
                  value:
                      '${_fmtInt(p.todayCalories)} / ${_fmtInt(FitnessProvider.kCalorieGoal)}',
                  progress: p.calorieProgress,
                ),
                const SizedBox(height: 8),
                _RingLegend(
                  color: _kGreen,
                  label: 'Protein',
                  value:
                      '${p.todayProtein.round()}g / ${FitnessProvider.kProteinGoal}g',
                  progress: p.proteinProgress,
                ),
                const SizedBox(height: 8),
                _RingLegend(
                  color: _kBlue,
                  label: 'Water',
                  value:
                      '${(p.todayWaterMl / 1000).toStringAsFixed(1)}L / 2.5L',
                  progress: p.waterProgress,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingLegend extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  final double progress;
  const _RingLegend(
      {required this.color,
      required this.label,
      required this.value,
      required this.progress});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                      const TextStyle(color: _kSecondary, fontSize: 11)),
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        Text(
          '${(progress * 100).round()}%',
          style: TextStyle(
              color: progress >= 1 ? color : _kSecondary, fontSize: 11),
        ),
      ],
    );
  }
}

class _RingsPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  const _RingsPainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const ringCount = 3;
    final maxRadius = math.min(size.width, size.height) / 2 - 4;
    const strokeW = 12.0;
    const gap = 6.0;

    for (int i = 0; i < ringCount; i++) {
      final radius = maxRadius - i * (strokeW + gap);
      final progress = values[i].clamp(0.0, 1.0);

      // Background track
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = colors[i].withOpacity(0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW
          ..strokeCap = StrokeCap.round,
      );

      // Progress arc
      if (progress > 0) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          -math.pi / 2,
          2 * math.pi * progress,
          false,
          Paint()
            ..color = colors[i]
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeW
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => true;
}

// ── Calorie balance card ───────────────────────────────────────────────────────
class _CalorieBalanceCard extends StatelessWidget {
  final FitnessProvider p;
  const _CalorieBalanceCard({required this.p});

  @override
  Widget build(BuildContext context) {
    final deficit = p.calorieDeficit;
    final isDeficit = p.inDeficit;
    final color = isDeficit ? _kGreen : _kOrange;
    final icon = isDeficit ? '📉' : '📈';
    final label = isDeficit ? 'Calorie Deficit' : 'Calorie Surplus';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${deficit > 0 ? '' : '+'}${_fmtInt(deficit.abs())} kcal',
                  style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _CalStat(
                  label: 'Eaten',
                  value: '${_fmtInt(p.todayCalories)} kcal',
                  color: _kRed),
              const SizedBox(width: 8),
              _CalStat(
                  label: 'Burned',
                  value: '${_fmtInt(p.todayCaloriesBurned)} kcal',
                  color: _kOrange),
              const SizedBox(width: 8),
              _CalStat(
                  label: 'TDEE',
                  value: '${_fmtInt(p.tdee)} kcal',
                  color: _kSecondary),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (p.todayCalories / p.tdee).clamp(0.0, 1.5),
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(
                p.todayCalories > p.tdee ? _kRed : _kGreen,
              ),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isDeficit
                ? '${_fmtInt(p.caloriesRemaining)} kcal remaining to hit your target'
                : 'Over target by ${_fmtInt((p.todayCalories - FitnessProvider.kCalorieGoal).abs())} kcal',
            style: const TextStyle(color: _kSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _CalStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _CalStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(color: _kSecondary, fontSize: 10),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Weight prediction card ─────────────────────────────────────────────────────
class _WeightPredictionCard extends StatelessWidget {
  final FitnessProvider p;
  const _WeightPredictionCard({required this.p});

  @override
  Widget build(BuildContext context) {
    final forecast = p.weightForecast(days: 30);
    final current = p.latestWeightKg;
    final predicted = p.predictedWeightInDays(30);
    final goal = p.goalWeightKg;
    final eta = p.estimatedGoalDate;
    final weeklyChange = p.weeklyWeightChange;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('⚖️', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              const Text(
                'Weight Prediction',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (weeklyChange != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: weeklyChange < 0
                        ? _kGreen.withOpacity(0.15)
                        : _kOrange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${weeklyChange < 0 ? '' : '+'}${weeklyChange.toStringAsFixed(2)} kg/wk',
                    style: TextStyle(
                      color: weeklyChange < 0 ? _kGreen : _kOrange,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          if (p.bodyHistory.length < 3)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Log your weight for at least 3 days to see AI predictions and trends.',
                style: TextStyle(
                    color: _kSecondary, fontSize: 13, height: 1.5),
                textAlign: TextAlign.center,
              ),
            )
          else ...[
            // Chart
            SizedBox(
              height: 140,
              child: CustomPaint(
                painter: _PredictionPainter(
                  history: p.bodyHistory,
                  forecast: forecast,
                  goalWeight: goal,
                ),
                size: Size.infinite,
              ),
            ),
            const SizedBox(height: 16),

            // Legend
            Row(
              children: [
                _ChartLegend(color: _kGreen, label: 'Actual', dashed: false),
                const SizedBox(width: 16),
                _ChartLegend(color: _kBlue, label: '30-day AI', dashed: true),
                const SizedBox(width: 16),
                _ChartLegend(
                    color: _kOrange, label: 'Goal', dashed: true),
              ],
            ),
            const SizedBox(height: 14),

            // Stats row
            Row(
              children: [
                _PredStat(
                  label: 'Now',
                  value: current != null
                      ? '${current.toStringAsFixed(1)} kg'
                      : '—',
                  color: _kGreen,
                ),
                _PredStat(
                  label: 'In 30 days',
                  value: predicted != null
                      ? '${predicted.toStringAsFixed(1)} kg'
                      : '—',
                  color: _kBlue,
                ),
                _PredStat(
                  label: 'Goal',
                  value: '${goal.toStringAsFixed(1)} kg',
                  color: _kOrange,
                ),
                _PredStat(
                  label: 'ETA',
                  value: eta != null
                      ? DateFormat('d MMM').format(eta)
                      : '—',
                  color: _kSecondary,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  final Color color;
  final String label;
  final bool dashed;
  const _ChartLegend(
      {required this.color, required this.label, required this.dashed});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 20,
          height: 2,
          child: CustomPaint(
            painter: _DashLinePainter(color: color, dashed: dashed),
          ),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(color: _kSecondary, fontSize: 11)),
      ],
    );
  }
}

class _DashLinePainter extends CustomPainter {
  final Color color;
  final bool dashed;
  const _DashLinePainter({required this.color, required this.dashed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    if (!dashed) {
      canvas.drawLine(
          Offset(0, size.height / 2), Offset(size.width, size.height / 2), paint);
    } else {
      double x = 0;
      while (x < size.width) {
        canvas.drawLine(Offset(x, size.height / 2),
            Offset(math.min(x + 4, size.width), size.height / 2), paint);
        x += 7;
      }
    }
  }

  @override
  bool shouldRepaint(_DashLinePainter old) => false;
}

class _PredStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _PredStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label,
              style:
                  const TextStyle(color: _kSecondary, fontSize: 10)),
        ],
      ),
    );
  }
}

// ── Weight chart painter ───────────────────────────────────────────────────────
class _PredictionPainter extends CustomPainter {
  final List<BodyEntry> history;
  final List<(DateTime, double)> forecast;
  final double goalWeight;

  const _PredictionPainter({
    required this.history,
    required this.forecast,
    required this.goalWeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty) return;

    // Compute bounds
    final allWeights = [
      ...history.map((e) => e.weightKg),
      ...forecast.map((t) => t.$2),
      goalWeight,
    ];
    final minW = allWeights.reduce(math.min) - 1;
    final maxW = allWeights.reduce(math.max) + 1;
    final wRange = maxW - minW;

    // Date bounds
    final firstDate = history.first.date;
    final lastForecastDate =
        forecast.isNotEmpty ? forecast.last.$1 : DateTime.now();
    final totalDays =
        lastForecastDate.difference(firstDate).inDays.toDouble();

    double xOf(DateTime d) {
      if (totalDays <= 0) return 0;
      return (d.difference(firstDate).inDays / totalDays) * size.width;
    }

    double yOf(double w) {
      return size.height - ((w - minW) / wRange) * size.height;
    }

    // ── Goal line (dashed orange) ──────────────────────────────────────────
    final goalY = yOf(goalWeight);
    final goalPaint = Paint()
      ..color = _kOrange.withOpacity(0.5)
      ..strokeWidth = 1.5;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(
          Offset(x, goalY), Offset(math.min(x + 6, size.width), goalY), goalPaint);
      x += 10;
    }

    // ── Forecast line (dashed blue) ────────────────────────────────────────
    if (forecast.length >= 2) {
      final forecastPaint = Paint()
        ..color = _kBlue.withOpacity(0.8)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      final path = Path();
      path.moveTo(xOf(forecast.first.$1), yOf(forecast.first.$2));
      for (final point in forecast.skip(1)) {
        path.lineTo(xOf(point.$1), yOf(point.$2));
      }
      _drawDashedPath(canvas, path, forecastPaint, size.width);
    }

    // ── History line (solid green) ─────────────────────────────────────────
    if (history.length >= 2) {
      final histPaint = Paint()
        ..color = _kGreen
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final path = Path();
      for (int i = 0; i < history.length; i++) {
        final px = xOf(history[i].date);
        final py = yOf(history[i].weightKg);
        if (i == 0) {
          path.moveTo(px, py);
        } else {
          path.lineTo(px, py);
        }
      }
      canvas.drawPath(path, histPaint);

      // Dots on each history point
      final dotPaint = Paint()..color = _kGreen;
      for (final e in history) {
        canvas.drawCircle(Offset(xOf(e.date), yOf(e.weightKg)), 3.0, dotPaint);
      }
    }
  }

  void _drawDashedPath(
      Canvas canvas, Path path, Paint paint, double width) {
    final metrics = path.computeMetrics();
    const dashLen = 8.0;
    const gapLen = 5.0;
    for (final metric in metrics) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final len = draw ? dashLen : gapLen;
        final next = (distance + len).clamp(0.0, metric.length);
        if (draw) {
          canvas.drawPath(metric.extractPath(distance, next), paint);
        }
        distance = next;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(_PredictionPainter old) => true;
}

// ── Weekly snapshot card ───────────────────────────────────────────────────────
class _WeeklySnapshotCard extends StatelessWidget {
  final FitnessProvider p;
  const _WeeklySnapshotCard({required this.p});

  @override
  Widget build(BuildContext context) {
    final map = p.weeklyWorkoutMap;
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final todayIndex = DateTime.now().weekday - 1; // 0=Mon

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📅', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              const Text(
                'This Week',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${p.weeklyWorkoutDays}/6 workouts',
                style: const TextStyle(color: _kSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (i) {
              final done = map[i];
              final isToday = i == todayIndex;
              return Column(
                children: [
                  Text(
                    days[i],
                    style: TextStyle(
                      color: isToday ? Colors.white : _kSecondary,
                      fontSize: 11,
                      fontWeight: isToday
                          ? FontWeight.w700
                          : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: done
                          ? _kGreen
                          : isToday
                              ? Colors.white.withOpacity(0.1)
                              : Colors.white.withOpacity(0.05),
                      shape: BoxShape.circle,
                      border: isToday && !done
                          ? Border.all(color: _kGreen, width: 1.5)
                          : null,
                    ),
                    child: Center(
                      child: done
                          ? const Icon(Icons.check,
                              color: Colors.black, size: 16)
                          : Text(
                              days[i],
                              style: TextStyle(
                                color: isToday
                                    ? _kGreen
                                    : Colors.white.withOpacity(0.3),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: p.weeklyWorkoutDays / 6,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(_kGreen),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Nutrition card ─────────────────────────────────────────────────────────────
class _NutritionCard extends StatelessWidget {
  final FitnessProvider p;
  const _NutritionCard({required this.p});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🥗', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text(
                'Nutrition',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _NutrBar(
            label: 'Calories',
            current: p.todayCalories.round(),
            goal: FitnessProvider.kCalorieGoal,
            unit: 'kcal',
            color: _kRed,
          ),
          const SizedBox(height: 10),
          _NutrBar(
            label: 'Protein',
            current: p.todayProtein.round(),
            goal: FitnessProvider.kProteinGoal,
            unit: 'g',
            color: _kGreen,
          ),
          const SizedBox(height: 10),
          _NutrBar(
            label: 'Water',
            current: p.todayWaterMl,
            goal: FitnessProvider.kWaterGoalMl,
            unit: 'ml',
            color: _kBlue,
          ),
          const SizedBox(height: 10),
          _NutrBar(
            label: 'Steps',
            current: p.todaySteps,
            goal: FitnessProvider.kStepGoal,
            unit: 'steps',
            color: _kOrange,
          ),
        ],
      ),
    );
  }
}

class _NutrBar extends StatelessWidget {
  final String label;
  final int current;
  final int goal;
  final String unit;
  final Color color;
  const _NutrBar(
      {required this.label,
      required this.current,
      required this.goal,
      required this.unit,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final progress = (current / goal).clamp(0.0, 1.0);
    return Column(
      children: [
        Row(
          children: [
            Text(label,
                style:
                    const TextStyle(color: _kSecondary, fontSize: 12)),
            const Spacer(),
            Text(
              '${_fmtInt(current)} / ${_fmtInt(goal)} $unit',
              style: TextStyle(
                  color: progress >= 1 ? color : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white.withOpacity(0.07),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 5,
          ),
        ),
      ],
    );
  }
}

// ── Smart tip ──────────────────────────────────────────────────────────────────
class _SmartTip extends StatelessWidget {
  final FitnessProvider p;
  const _SmartTip({required this.p});

  String _tip() {
    final wc = p.weeklyWeightChange;
    if (p.bodyHistory.length < 3) {
      return '📊 Log your weight daily to unlock AI predictions and personalised tips!';
    }
    if (wc != null && wc > 0.3) {
      return '⚠️ You\'re gaining weight. Try reducing carbs and increasing steps.';
    }
    if (wc != null && wc < -1.0) {
      return '🔥 You\'re losing weight fast. Make sure protein stays above 100g to protect muscle.';
    }
    if (!p.inDeficit) {
      return '🍽️ You\'re over your calorie target today. Skip the evening snack!';
    }
    if (p.todayProtein < 80) {
      return '💪 Protein is low today — add a whey shake or chicken meal to hit 100g.';
    }
    if (p.waterProgress < 0.5) {
      return '💧 You\'re under halfway on water. Drink 500 ml right now!';
    }
    if (p.workoutStreak >= 5) {
      return '🔥 ${p.workoutStreak}-day streak! You\'re on fire. Consider a deload next week.';
    }
    return '✅ You\'re on track today! Stay consistent and the results will follow.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kGreen.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kGreen.withOpacity(0.2)),
      ),
      child: Text(
        _tip(),
        style: const TextStyle(
            color: Colors.white, fontSize: 13, height: 1.5),
      ),
    );
  }
}
