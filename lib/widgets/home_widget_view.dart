import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/smart_insight_engine.dart';

// Palette
const _kGreen = Color(0xFF30D158);
const _kBlue = Color(0xFF40C8E0);
const _kRed = Color(0xFFFF453A);
const _kCard = Color(0xFF1C1C1E);
const _kSecond = Color(0xFF8E8E93);

/// Off-screen widget rendered to a PNG by `HomeWidget.renderFlutterWidget`, then
/// displayed by the Android home-screen widget. Concentric activity rings
/// (calories / protein / water) on the left, the smartest insight underneath.
class HomeWidgetView extends StatelessWidget {
  final double calProgress;
  final double proteinProgress;
  final double waterProgress;
  final int calories;
  final int protein;
  final int waterMl;
  final Insight insight;

  const HomeWidgetView({
    super.key,
    required this.calProgress,
    required this.proteinProgress,
    required this.waterProgress,
    required this.calories,
    required this.protein,
    required this.waterMl,
    required this.insight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      height: 170,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Row(
              children: [
                // Concentric rings
                SizedBox(
                  width: 96,
                  height: 96,
                  child: CustomPaint(
                    painter: _ConcentricRingsPainter(
                      values: [calProgress, proteinProgress, waterProgress],
                      colors: const [_kRed, _kGreen, _kBlue],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Legend with live numbers
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _legend(_kRed, 'Calories', '$calories', calProgress),
                      const SizedBox(height: 8),
                      _legend(_kGreen, 'Protein', '${protein}g', proteinProgress),
                      const SizedBox(height: 8),
                      _legend(_kBlue, 'Water', '${waterMl}ml', waterProgress),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Insight line
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(insight.emoji, style: const TextStyle(fontSize: 15)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  insight.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: insight.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label, String value, double pct) {
    return Row(
      children: [
        Container(
          width: 9, height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Text(label, style: const TextStyle(color: _kSecond, fontSize: 12)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(width: 6),
        Text('${(pct * 100).round()}%',
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _ConcentricRingsPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  const _ConcentricRingsPainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const stroke = 9.0;
    const gap = 13.0;
    for (int i = 0; i < values.length; i++) {
      final r = size.width / 2 - stroke / 2 - i * gap;
      if (r <= 0) continue;
      // Track
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..color = colors[i].withOpacity(0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke,
      );
      // Progress arc
      final v = values[i].clamp(0.0, 1.0);
      if (v > 0) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: r),
          -math.pi / 2,
          2 * math.pi * v,
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
  bool shouldRepaint(_ConcentricRingsPainter old) =>
      old.values != values || old.colors != colors;
}
