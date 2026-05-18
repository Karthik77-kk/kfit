import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/fitness_provider.dart';
import '../models/models.dart';

// ─── Apple Fitness design tokens ──────────────────────────────────────────────
const _kGreen = Color(0xFF30D158);
const _kBlue = Color(0xFF40C8E0);
const _kRed = Color(0xFFFF453A);
const _kOrange = Color(0xFFFF9F0A);
const _kCard = Color(0xFF1C1C1E);
const _kSecondary = Color(0xFF8E8E93);

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 100,
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
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Text(
                    '${_greeting()}, Karthik',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
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
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _SectionHeader(title: "Today's Activity"),
                const SizedBox(height: 12),
                _ActivityRingsCard(provider: p),
                const SizedBox(height: 24),

                const _SectionHeader(title: 'Move'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        label: 'Steps',
                        value: '${p.todaySteps}',
                        goal: '/ ${FitnessProvider.kStepGoal}',
                        icon: Icons.directions_walk_rounded,
                        color: _kBlue,
                        progress: p.stepProgress,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricTile(
                        label: 'Cal Burned',
                        value: '${p.todayCaloriesBurned}',
                        goal: 'kcal',
                        icon: Icons.local_fire_department_rounded,
                        color: _kRed,
                        progress: p.todayCaloriesBurned > 0 ? 1.0 : 0.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                const _SectionHeader(title: 'Nutrition'),
                const SizedBox(height: 12),
                _NutritionCard(provider: p),
                const SizedBox(height: 24),

                const _SectionHeader(title: 'Workout'),
                const SizedBox(height: 12),
                _WorkoutCard(workout: p.todayWorkout),
                const SizedBox(height: 24),

                const _SectionHeader(title: 'Supplements'),
                const SizedBox(height: 12),
                _SupplementsCard(supp: p.supplements),
                const SizedBox(height: 24),

                if (p.latestWeightKg != null) ...[
                  const _SectionHeader(title: 'Body'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricTile(
                          label: 'Weight',
                          value: p.latestWeightKg!.toStringAsFixed(1),
                          goal: 'kg',
                          icon: Icons.monitor_weight_outlined,
                          color: _kOrange,
                          progress: -1,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricTile(
                          label: 'BMI',
                          value: p.bmi?.toStringAsFixed(1) ?? '--',
                          goal: p.bmiCategory,
                          icon: Icons.health_and_safety_outlined,
                          color: p.bmiColor(context),
                          progress: -1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                _SmartTip(calories: p.todayCalories, protein: p.todayProtein),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: _kSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _StreakBadge extends StatelessWidget {
  final int streak;
  const _StreakBadge({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _kRed.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kRed.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            '$streak day${streak == 1 ? "" : "s"}',
            style: const TextStyle(
              color: _kRed,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityRingsCard extends StatelessWidget {
  final FitnessProvider provider;
  const _ActivityRingsCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            height: 110,
            child: CustomPaint(
              painter: _RingsPainter(
                rings: [
                  _Ring(provider.calorieProgress, _kRed),
                  _Ring(provider.proteinProgress, _kGreen),
                  _Ring(provider.waterProgress, _kBlue),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RingLegendRow(
                  color: _kRed,
                  label: 'Calories',
                  value:
                      '${provider.todayCalories.toInt()} / ${FitnessProvider.kCalorieGoal} kcal',
                  progress: provider.calorieProgress,
                ),
                const SizedBox(height: 14),
                _RingLegendRow(
                  color: _kGreen,
                  label: 'Protein',
                  value:
                      '${provider.todayProtein.toInt()} / ${FitnessProvider.kProteinGoal}g',
                  progress: provider.proteinProgress,
                ),
                const SizedBox(height: 14),
                _RingLegendRow(
                  color: _kBlue,
                  label: 'Water',
                  value:
                      '${provider.todayWaterMl} / ${FitnessProvider.kWaterGoalMl}ml',
                  progress: provider.waterProgress,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Ring {
  final double progress;
  final Color color;
  _Ring(this.progress, this.color);
}

class _RingsPainter extends CustomPainter {
  final List<_Ring> rings;
  _RingsPainter({required this.rings});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const strokeWidth = 12.0;
    const gap = 6.0;

    for (int i = 0; i < rings.length; i++) {
      final radius =
          (size.width / 2) - (i * (strokeWidth + gap)) - strokeWidth / 2;
      final ring = rings[i];

      final trackPaint = Paint()
        ..color = ring.color.withOpacity(0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(center, radius, trackPaint);

      final progressPaint = Paint()
        ..color = ring.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      final sweepAngle = 2 * math.pi * ring.progress.clamp(0.0, 1.0);
      if (sweepAngle > 0) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          -math.pi / 2,
          sweepAngle,
          false,
          progressPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => true;
}

class _RingLegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  final double progress;

  const _RingLegendRow({
    required this.color,
    required this.label,
    required this.value,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: _kSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _NutritionCard extends StatelessWidget {
  final FitnessProvider provider;
  const _NutritionCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _NutritionRow(
            label: 'Calories',
            current: provider.todayCalories.toInt(),
            goal: FitnessProvider.kCalorieGoal,
            unit: 'kcal',
            color: _kRed,
            progress: provider.calorieProgress,
          ),
          const SizedBox(height: 4),
          const Divider(height: 20),
          _NutritionRow(
            label: 'Protein',
            current: provider.todayProtein.toInt(),
            goal: FitnessProvider.kProteinGoal,
            unit: 'g',
            color: _kGreen,
            progress: provider.proteinProgress,
          ),
        ],
      ),
    );
  }
}

class _NutritionRow extends StatelessWidget {
  final String label;
  final int current;
  final int goal;
  final String unit;
  final Color color;
  final double progress;

  const _NutritionRow({
    required this.label,
    required this.current,
    required this.goal,
    required this.unit,
    required this.color,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500),
            ),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$current',
                    style: TextStyle(
                        color: color,
                        fontSize: 18,
                        fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: ' / $goal $unit',
                    style: const TextStyle(color: _kSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: color.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String goal;
  final IconData icon;
  final Color color;
  final double progress;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.goal,
    required this.icon,
    required this.color,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              color: _kSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            goal,
            style: const TextStyle(color: _kSecondary, fontSize: 12),
          ),
          if (progress >= 0) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: color.withOpacity(0.15),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  final WorkoutLog? workout;
  const _WorkoutCard({this.workout});

  @override
  Widget build(BuildContext context) {
    final done = workout != null;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: done
                  ? _kGreen.withOpacity(0.15)
                  : _kOrange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              done ? Icons.check_rounded : Icons.fitness_center_rounded,
              color: done ? _kGreen : _kOrange,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  done
                      ? 'Workout ${workout!.workoutType.name.toUpperCase()} Complete'
                      : 'No Workout Yet',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  done
                      ? '${workout!.durationMinutes} min · ${workout!.exercises.length} exercises · ${workout!.caloriesBurned} kcal'
                      : 'Tap Workout tab to log today\'s session',
                  style: const TextStyle(color: _kSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SupplementsCard extends StatelessWidget {
  final SupplementStatus supp;
  const _SupplementsCard({required this.supp});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _SuppChip(label: 'Whey', emoji: '💪', taken: supp.whey),
          _SuppChip(label: 'Creatine', emoji: '⚡', taken: supp.creatine),
          _SuppChip(label: 'Multivit', emoji: '🌿', taken: supp.multivitamin),
        ],
      ),
    );
  }
}

class _SuppChip extends StatelessWidget {
  final String label;
  final String emoji;
  final bool taken;
  const _SuppChip(
      {required this.label, required this.emoji, required this.taken});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: taken
            ? _kGreen.withOpacity(0.12)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: taken ? _kGreen.withOpacity(0.4) : Colors.white.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(taken ? '✅' : emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: taken ? _kGreen : _kSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmartTip extends StatelessWidget {
  final double calories;
  final double protein;
  const _SmartTip({required this.calories, required this.protein});

  String _tip() {
    if (protein < 50) {
      return '⚡ Protein is low — add eggs, chicken, or a whey scoop to hit your 100g goal.';
    }
    if (calories < 800) {
      return '🍽️ You have eaten very little today. Make sure you fuel those muscles!';
    }
    if (calories > 1800) {
      return '⚠️ Close to calorie limit. Keep dinner light to stay in your deficit.';
    }
    if (protein >= 80) {
      return '💪 Solid protein intake! Muscle preservation is on track — keep it up.';
    }
    return '👊 Consistency is your biggest weapon. Hit your targets and results will follow!';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kGreen.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kGreen.withOpacity(0.2), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline_rounded, color: _kGreen, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _tip(),
              style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
