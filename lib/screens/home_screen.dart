import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/fitness_provider.dart';
import '../models/models.dart';

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
    final today = DateFormat('EEEE, d MMMM').format(DateTime.now());

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_greeting()}, Karthik 👋',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        today,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.5), fontSize: 13),
                      ),
                    ],
                  ),
                  _WorkoutStreakBadge(streak: p.workoutStreak),
                ],
              ),
              const SizedBox(height: 20),

              // ── Calories card ───────────────────────────────────────────
              _MacroCard(
                title: 'Calories',
                current: p.todayCalories.toInt(),
                goal: FitnessProvider.kCalorieGoal,
                unit: 'kcal',
                progress: p.calorieProgress,
                color: const Color(0xFFFF6B35),
                icon: Icons.local_fire_department,
              ),
              const SizedBox(height: 12),

              // ── Protein & Water row ─────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _MacroCard(
                      title: 'Protein',
                      current: p.todayProtein.toInt(),
                      goal: FitnessProvider.kProteinGoal,
                      unit: 'g',
                      progress: p.proteinProgress,
                      color: const Color(0xFF4ECDC4),
                      icon: Icons.egg_alt,
                      compact: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MacroCard(
                      title: 'Water',
                      current: p.todayWaterMl,
                      goal: FitnessProvider.kWaterGoalMl,
                      unit: 'ml',
                      progress: p.waterProgress,
                      color: const Color(0xFF5C9BD6),
                      icon: Icons.water_drop,
                      compact: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Supplements row ─────────────────────────────────────────
              _SupplementCard(supp: p.supplements),
              const SizedBox(height: 12),

              // ── Workout card ────────────────────────────────────────────
              _WorkoutCard(workout: p.todayWorkout),
              const SizedBox(height: 12),

              // ── Tip card ────────────────────────────────────────────────
              _TipCard(calories: p.todayCalories, protein: p.todayProtein),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Macro progress card ────────────────────────────────────────────────────────

class _MacroCard extends StatelessWidget {
  final String title;
  final int current;
  final int goal;
  final String unit;
  final double progress;
  final Color color;
  final IconData icon;
  final bool compact;

  const _MacroCard({
    required this.title,
    required this.current,
    required this.goal,
    required this.unit,
    required this.progress,
    required this.color,
    required this.icon,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 14 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: compact ? 16 : 20),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: compact ? 12 : 13,
                ),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  color: color,
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 8 : 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$current',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 22 : 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                ' / $goal $unit',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: compact ? 11 : 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: compact ? 6 : 8,
              backgroundColor: color.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Supplement status card ─────────────────────────────────────────────────────

class _SupplementCard extends StatelessWidget {
  final SupplementStatus supp;
  const _SupplementCard({required this.supp});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF9B59B6).withOpacity(0.25), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.medication, color: Color(0xFF9B59B6), size: 18),
              const SizedBox(width: 6),
              Text(
                'Supplements Today',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.6), fontSize: 13),
              ),
              const Spacer(),
              Text(
                '${supp.takenCount}/3',
                style: const TextStyle(
                  color: Color(0xFF9B59B6),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _SuppPill(label: 'Whey', taken: supp.whey, emoji: '💪'),
              _SuppPill(label: 'Creatine', taken: supp.creatine, emoji: '⚡'),
              _SuppPill(label: 'Multivit', taken: supp.multivitamin, emoji: '🌿'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SuppPill extends StatelessWidget {
  final String label;
  final bool taken;
  final String emoji;
  const _SuppPill({required this.label, required this.taken, required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: taken
            ? const Color(0xFF27AE60).withOpacity(0.2)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: taken
              ? const Color(0xFF27AE60).withOpacity(0.5)
              : Colors.white.withOpacity(0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(taken ? '✅' : emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: taken ? const Color(0xFF27AE60) : Colors.white.withOpacity(0.5),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Workout card ───────────────────────────────────────────────────────────────

class _WorkoutCard extends StatelessWidget {
  final WorkoutLog? workout;
  const _WorkoutCard({this.workout});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: workout != null
              ? const Color(0xFF27AE60).withOpacity(0.4)
              : const Color(0xFFFF6B35).withOpacity(0.25),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: workout != null
                  ? const Color(0xFF27AE60).withOpacity(0.15)
                  : const Color(0xFFFF6B35).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              workout != null ? Icons.check_circle : Icons.fitness_center,
              color: workout != null
                  ? const Color(0xFF27AE60)
                  : const Color(0xFFFF6B35),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workout != null
                      ? 'Workout ${workout!.workoutType.name.toUpperCase()} ✅'
                      : "Today's Workout",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  workout != null
                      ? '${workout!.durationMinutes} min · ${workout!.exercises.length} exercises logged'
                      : 'Not logged yet — head to Workout tab!',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Streak badge ───────────────────────────────────────────────────────────────

class _WorkoutStreakBadge extends StatelessWidget {
  final int streak;
  const _WorkoutStreakBadge({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B35).withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFFFF6B35).withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '$streak',
                style: const TextStyle(
                  color: Color(0xFFFF6B35),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
              ),
              Text(
                'streak',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Daily tip card ─────────────────────────────────────────────────────────────

class _TipCard extends StatelessWidget {
  final double calories;
  final double protein;
  const _TipCard({required this.calories, required this.protein});

  String _tip() {
    if (protein < 50) return '⚡ Protein is low — add eggs, chicken or a whey scoop to hit your 100g goal.';
    if (calories < 800) return '🍽️ You\'ve eaten very little today. Make sure you fuel those muscles!';
    if (calories > 1800) return '⚠️ Close to calorie limit. Keep dinner low-carb to stay in the deficit.';
    if (protein >= 80) return '💪 Great protein intake today! Keep it up — muscle preservation on track.';
    return '👊 Consistency is your biggest weapon. Hit your targets and results will follow!';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF6B35).withOpacity(0.15),
            const Color(0xFF4ECDC4).withOpacity(0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              _tip(),
              style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
