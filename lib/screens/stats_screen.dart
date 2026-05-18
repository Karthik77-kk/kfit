import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/fitness_provider.dart';
import '../models/models.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final _weightCtrl = TextEditingController();
  final _stepsCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final p = context.read<FitnessProvider>();
    _heightCtrl.text = p.heightCm.toStringAsFixed(0);
    if (p.latestWeightKg != null) {
      _weightCtrl.text = p.latestWeightKg!.toStringAsFixed(1);
    }
    if (p.todaySteps > 0) {
      _stepsCtrl.text = p.todaySteps.toString();
    }
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _stepsCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveEntries() async {
    final p = context.read<FitnessProvider>();
    final weight = double.tryParse(_weightCtrl.text);
    final steps = int.tryParse(_stepsCtrl.text) ?? 0;
    final height = double.tryParse(_heightCtrl.text);

    if (height != null && height > 50 && height < 300) {
      await p.saveHeight(height);
    }
    if (weight != null && weight > 10 && weight < 500) {
      await p.logBodyEntry(weightKg: weight, steps: steps);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stats saved ✓'),
            backgroundColor: Color(0xFF30D158),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<FitnessProvider>();
    final recent = p.getRecentBodyEntries(days: 30);

    return Scaffold(
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
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const SizedBox(height: 8),

          // ── Log Today ────────────────────────────────────────────────────
          _SectionHeader('LOG TODAY'),
          _AppleCard(
            child: Column(
              children: [
                _InputRow(
                  label: 'Weight',
                  unit: 'kg',
                  controller: _weightCtrl,
                  icon: Icons.monitor_weight_outlined,
                  iconColor: const Color(0xFF30D158),
                ),
                _Divider(),
                _InputRow(
                  label: 'Steps',
                  unit: 'steps',
                  controller: _stepsCtrl,
                  icon: Icons.directions_walk_outlined,
                  iconColor: const Color(0xFF30D158),
                  keyboardType: TextInputType.number,
                ),
                _Divider(),
                _InputRow(
                  label: 'Height',
                  unit: 'cm',
                  controller: _heightCtrl,
                  icon: Icons.height_outlined,
                  iconColor: const Color(0xFF40C8E0),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    label: 'Save',
                    color: const Color(0xFF30D158),
                    onPressed: _saveEntries,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Summary Cards ────────────────────────────────────────────────
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
                  color: const Color(0xFF30D158),
                  icon: Icons.monitor_weight_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'BMI',
                  value: p.bmi != null
                      ? p.bmi!.toStringAsFixed(1)
                      : '—',
                  sub: p.bmiCategory,
                  color: p.bmi != null ? p.bmiColor(context) : const Color(0xFF8E8E93),
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
                  value: p.todaySteps > 0 ? _fmt(p.todaySteps) : '—',
                  sub: p.todaySteps > 0
                      ? '${(p.stepProgress * 100).round()}% of goal'
                      : '8,000 goal',
                  color: const Color(0xFF30D158),
                  icon: Icons.directions_walk_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Workout Streak',
                  value: '${p.workoutStreak}d',
                  sub: p.workoutStreak > 0 ? 'Keep going! 🔥' : 'Start today',
                  color: const Color(0xFFFF9F0A),
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
                  color: const Color(0xFFFF453A),
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
                  color: const Color(0xFFFF453A),
                  icon: Icons.bar_chart_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Weight History ───────────────────────────────────────────────
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
                          '${recent.map((e) => e.weightKg).reduce((a, b) => a < b ? a : b).toStringAsFixed(1)} kg'),
                      _ChartStat('High',
                          '${recent.map((e) => e.weightKg).reduce((a, b) => a > b ? a : b).toStringAsFixed(1)} kg'),
                      _ChartStat('Avg',
                          '${(recent.map((e) => e.weightKg).reduce((a, b) => a + b) / recent.length).toStringAsFixed(1)} kg'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── BMI Scale ────────────────────────────────────────────────────
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
                    _BmiLabel('Under', '< 18.5', const Color(0xFF40C8E0)),
                    _BmiLabel('Normal', '18.5–24.9', const Color(0xFF30D158)),
                    _BmiLabel('Over', '25–29.9', const Color(0xFFFF9F0A)),
                    _BmiLabel('Obese', '≥ 30', const Color(0xFFFF453A)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
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
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}k';
    }
    return n.toString();
  }
}

// ── Mini weight line chart ─────────────────────────────────────────────────────

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

    final minW = entries.map((e) => e.weightKg).reduce((a, b) => a < b ? a : b);
    final maxW = entries.map((e) => e.weightKg).reduce((a, b) => a > b ? a : b);
    final range = (maxW - minW).clamp(1.0, double.infinity);

    final minD = entries.first.date.millisecondsSinceEpoch.toDouble();
    final maxD = entries.last.date.millisecondsSinceEpoch.toDouble();
    final dateRange = (maxD - minD).clamp(1.0, double.infinity);

    Offset toOffset(BodyEntry e) {
      final x = ((e.date.millisecondsSinceEpoch - minD) / dateRange) * size.width;
      final y = size.height - ((e.weightKg - minW) / range) * size.height;
      return Offset(x, y);
    }

    // Fill
    final fillPaint = Paint()
      ..color = const Color(0xFF30D158).withOpacity(0.15)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height);
    for (final e in entries) {
      final o = toOffset(e);
      path.lineTo(o.dx, o.dy);
    }
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, fillPaint);

    // Line
    final linePaint = Paint()
      ..color = const Color(0xFF30D158)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final linePath = Path();
    linePath.moveTo(toOffset(entries.first).dx, toOffset(entries.first).dy);
    for (final e in entries.skip(1)) {
      linePath.lineTo(toOffset(e).dx, toOffset(e).dy);
    }
    canvas.drawPath(linePath, linePaint);

    // Last point dot
    final dotPaint = Paint()
      ..color = const Color(0xFF30D158)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(toOffset(entries.last), 4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ── BMI Bar ───────────────────────────────────────────────────────────────────

class _BmiBar extends StatelessWidget {
  final double? bmi;
  const _BmiBar({this.bmi});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 16,
      child: LayoutBuilder(builder: (_, constraints) {
        const segments = [
          Color(0xFF40C8E0),
          Color(0xFF30D158),
          Color(0xFFFF9F0A),
          Color(0xFFFF453A),
        ];
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
                          left: i == 0 ? const Radius.circular(8) : Radius.zero,
                          right: i == 3 ? const Radius.circular(8) : Radius.zero,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (bmi != null)
              Positioned(
                left: _bmiToFraction(bmi!) * constraints.maxWidth - 6,
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

  double _bmiToFraction(double bmi) {
    // Map BMI 15–40 to 0–1
    return ((bmi - 15) / 25).clamp(0.0, 1.0);
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

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
          color: Color(0xFF8E8E93),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
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
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

class _InputRow extends StatelessWidget {
  final String label;
  final String unit;
  final TextEditingController controller;
  final IconData icon;
  final Color iconColor;
  final TextInputType keyboardType;

  const _InputRow({
    required this.label,
    required this.unit,
    required this.controller,
    required this.icon,
    required this.iconColor,
    this.keyboardType = const TextInputType.numberWithOptions(decimal: true),
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
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
          const Spacer(),
          SizedBox(
            width: 80,
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                border: InputBorder.none,
                hintText: '0',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                suffix: Text(
                  ' $unit',
                  style: const TextStyle(
                      color: Color(0xFF8E8E93), fontSize: 13),
                ),
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
        color: const Color(0xFF1C1C1E),
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
          Text(
            label,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
          ),
          Text(
            sub,
            style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 11),
          ),
        ],
      ),
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
            style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 11)),
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
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        Text(range, style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 10)),
      ],
    );
  }
}

class CupertinoButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const CupertinoButton({
    super.key,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: const Text(
          'Save',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
