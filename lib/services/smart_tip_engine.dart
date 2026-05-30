import 'package:flutter/material.dart';
import '../providers/fitness_provider.dart';

// Design tokens (mirror of home_screen palette)
const _kGreen = Color(0xFF30D158);
const _kBlue = Color(0xFF40C8E0);
const _kRed = Color(0xFFFF453A);
const _kOrange = Color(0xFFFF9F0A);
const _kSecond = Color(0xFF8E8E93);
const _kIndigo = Color(0xFF5E5CE6);

/// A single contextual home-screen suggestion.
class SmartTipInfo {
  final String emoji;
  final String title;
  final String body;
  final Color accent;
  final int priority; // lower = more urgent (shown first)

  const SmartTipInfo({
    required this.emoji,
    required this.title,
    required this.body,
    required this.accent,
    this.priority = 50,
  });
}

/// Calories burned in [minutes] of moderate activity at [weightKg] (MET≈5).
/// Mirrors the home-screen helper so the engine is self-contained.
int _estBurn(double weightKg, int minutes) =>
    (5.0 * weightKg * minutes / 60.0).round();

/// Selects the single most relevant tip for the current state.
///
/// [now] is injectable so the time-dependent branches are deterministically
/// testable. Production callers pass `DateTime.now()`.
SmartTipInfo selectSmartTip(FitnessProvider p, DateTime now) {
  final hour = now.hour;
  final weight = p.latestWeightKg ?? 70.0;
  final protein = p.todayProteinTotal.round();
  final cals = p.todayCaloriesTotal.round();
  final water = p.todayWaterMl;
  final deficit = p.calorieDeficit;
  final weekly = p.weeklyWeightChange;
  final noWorkout = p.todayWorkouts.isEmpty;
  final steps = p.todaySteps;
  final remaining = p.caloriesRemaining;

  // ── P0 — Critical warnings ───────────────────────────────────────────────
  if (weekly != null && weekly < -0.9) {
    return SmartTipInfo(
      emoji: '⚠️', priority: 1,
      title: 'Losing too fast',
      body: '${weekly.abs().toStringAsFixed(2)} kg/week is above the safe limit of 0.7 kg. '
          'Add 200–300 kcal — try 2 extra rotis or a banana protein shake to protect muscle.',
      accent: _kRed,
    );
  }
  if (cals > p.calorieGoal + 400) {
    return SmartTipInfo(
      emoji: '🚨', priority: 2,
      title: '${cals - p.calorieGoal} kcal over goal',
      body: 'You\'re ${cals - p.calorieGoal} kcal above your ${p.calorieGoal} kcal target. '
          'Skip evening snacks and take a 30-min walk (~${_estBurn(weight, 30)} kcal burned).',
      accent: _kRed,
    );
  }

  // ── P1 — Morning priorities (6–11 AM) ────────────────────────────────────
  if (hour >= 6 && hour < 10 && cals == 0) {
    return SmartTipInfo(
      emoji: '🌅', priority: 3,
      title: 'Start your morning strong',
      body: 'Log breakfast to activate your ${p.calorieGoal} kcal goal. '
          'Try 3 boiled eggs + 2 rotis = ~420 kcal, 22g protein.',
      accent: _kOrange,
    );
  }
  if (hour >= 9 && hour < 12 && !p.supplements.creatine) {
    return const SmartTipInfo(
      emoji: '⚡', priority: 10,
      title: 'Take creatine now',
      body: 'Best window: 10 AM with water or whey. 3–5g daily improves strength by 5–15% '
          'and supports muscle retention during fat loss.',
      accent: _kIndigo,
    );
  }
  if (hour >= 8 && hour < 9 && !p.supplements.multivitamin) {
    return const SmartTipInfo(
      emoji: '🌿', priority: 10,
      title: 'Multivitamin after breakfast',
      body: 'Take MuscleBlaze MB-Vite now. Fat-soluble vitamins (A, D, E, K) absorb '
          'much better with food.',
      accent: _kGreen,
    );
  }

  // ── P2 — Protein urgency ─────────────────────────────────────────────────
  if (protein < 40 && hour > 12) {
    return SmartTipInfo(
      emoji: '💪', priority: 4,
      title: 'Protein critically low ($protein g)',
      body: 'You need ${p.proteinGoal - protein}g more. Add grilled chicken (31g/100g), '
          '3 eggs (18g), or a whey shake (25g) to protect your muscle during fat loss.',
      accent: _kBlue,
    );
  }
  if (protein < 70 && hour > 14) {
    return SmartTipInfo(
      emoji: '🥩', priority: 5,
      title: 'Protein behind schedule ($protein g / ${p.proteinGoal}g)',
      body: 'You still need ${p.proteinGoal - protein}g protein. Options: '
          'paneer tikka (19g/100g), chole (11g/150g), or dal + 2 eggs (22g).',
      accent: _kBlue,
    );
  }

  // ── P3 — Hydration ───────────────────────────────────────────────────────
  if (water == 0 && hour > 9) {
    return const SmartTipInfo(
      emoji: '💧', priority: 6,
      title: 'No water logged yet',
      body: 'Aim for 500ml before 10 AM. Drinking water first reduces hunger by up to 25% '
          'and boosts metabolism by ~30% for 90 minutes.',
      accent: _kBlue,
    );
  }
  if (water < 1000 && hour > 13) {
    return SmartTipInfo(
      emoji: '💧', priority: 7,
      title: 'Water only at ${water}ml',
      body: 'You\'re less than halfway to your ${p.waterGoalMl}ml goal. '
          'Drink a 500ml bottle now — dehydration increases hunger and reduces fat burn.',
      accent: _kBlue,
    );
  }
  if (water < p.waterGoalMl - 500 && hour > 18) {
    return SmartTipInfo(
      emoji: '💧', priority: 7,
      title: '${p.waterGoalMl - water}ml left for today',
      body: 'Finish your water before 10 PM. Try adding a slice of lemon — '
          'it improves compliance and has 0 calories.',
      accent: _kBlue,
    );
  }

  // ── P4 — Workout reminders ───────────────────────────────────────────────
  if (noWorkout && hour >= 16 && hour < 20) {
    return SmartTipInfo(
      emoji: '🏋️', priority: 8,
      title: 'Perfect workout window (4–8 PM)',
      body: 'Peak muscle performance is 4–8 PM. Even 30 min burns ~${_estBurn(weight, 30)} kcal. '
          'Log Workout A (Push) or B (Pull) to keep your streak alive.',
      accent: _kGreen,
    );
  }
  if (noWorkout && hour >= 20) {
    return SmartTipInfo(
      emoji: '🌙', priority: 9,
      title: 'No workout today',
      body: '10-min bodyweight session still counts: 3×10 push-ups + 3×15 squats + plank. '
          'Burns ~${_estBurn(weight, 10)} kcal and maintains the habit.',
      accent: _kSecond,
    );
  }

  // ── P5a — Evening protein/log nudges (more actionable at night than a
  //          generic deficit status, so these run before the deficit block) ──
  if (hour >= 20 && cals < (p.calorieGoal * 0.7).round()) {
    return SmartTipInfo(
      emoji: '🌙', priority: 18,
      title: '$remaining kcal left to log',
      body: 'You still have $remaining kcal left for the day. '
          'A whey shake + banana = ~220 kcal, 26g protein. Don\'t skip protein before sleep.',
      accent: _kSecond,
    );
  }
  if (hour >= 21 && !p.supplements.whey) {
    return const SmartTipInfo(
      emoji: '🥛', priority: 19,
      title: 'Pre-sleep protein boost',
      body: 'A protein shake before bed reduces overnight muscle breakdown. '
          '25g casein or whey mixed with 200ml cold milk is a great option.',
      accent: _kBlue,
    );
  }

  // ── P5 — Deficit / surplus ───────────────────────────────────────────────
  if (deficit > 500) {
    return SmartTipInfo(
      emoji: '🔥', priority: 15,
      title: '$deficit kcal deficit — excellent!',
      body: 'At this rate you\'ll lose ~${(deficit / 7700 * 7).toStringAsFixed(2)} kg this week. '
          'Make sure protein stays above ${p.proteinGoal}g to keep muscle intact.',
      accent: _kGreen,
    );
  }
  if (deficit > 200 && deficit <= 500) {
    return const SmartTipInfo(
      emoji: '🎯', priority: 20,
      title: 'On track in deficit',
      body: 'A consistent 200–500 kcal deficit gives safe fat loss of 0.25–0.5 kg/week. '
          'Skip the evening snack to lock it in.',
      accent: _kGreen,
    );
  }
  if (deficit < -100 && deficit >= -400) {
    return SmartTipInfo(
      emoji: '📈', priority: 12,
      title: '${-deficit} kcal surplus',
      body: 'You\'ve eaten ${-deficit} kcal more than your goal. '
          'A 30-min walk burns ~${_estBurn(weight, 30)} kcal. '
          'Skip late-night snacking to stay on track.',
      accent: _kOrange,
    );
  }

  // ── P6 — Steps & movement ────────────────────────────────────────────────
  if (steps < 2000 && hour > 12) {
    return SmartTipInfo(
      emoji: '🚶', priority: 16,
      title: 'Only $steps steps today',
      body: 'Walk for 20 min after lunch — that\'s ~2000 steps and burns '
          '~${_estBurn(weight, 20)} kcal. Walking after meals also lowers blood sugar.',
      accent: _kBlue,
    );
  }
  if (steps > p.stepGoal) {
    return SmartTipInfo(
      emoji: '🏃', priority: 30,
      title: 'Step goal hit!',
      body: 'Amazing! Your steps burn ~${p.walkingCaloriesBurned.round()} kcal from walking alone. '
          'Keep this level to see a consistent weekly weight drop.',
      accent: _kGreen,
    );
  }

  // ── P7 — Weight trend ────────────────────────────────────────────────────
  if (weekly != null && weekly < -0.3 && weekly >= -0.9) {
    return SmartTipInfo(
      emoji: '📉', priority: 25,
      title: 'Losing ${weekly.abs().toStringAsFixed(2)} kg/week',
      body: 'Healthy pace — keep it up! Target ${p.goalWeightKg.toStringAsFixed(1)} kg'
          '${p.estimatedGoalDate != null ? " by ${p.estimatedGoalDate!.day}/${p.estimatedGoalDate!.month}/${p.estimatedGoalDate!.year}" : ""}. '
          'Stay consistent with protein.',
      accent: _kGreen,
    );
  }
  if (weekly != null && weekly >= 0 && weekly <= 0.2) {
    return const SmartTipInfo(
      emoji: '➡️', priority: 30,
      title: 'Weight plateauing',
      body: 'You\'re within ±0.2 kg/week. Try adding one more workout day or cutting '
          '100 kcal from dinner — swap 1 roti for extra sabji.',
      accent: _kOrange,
    );
  }
  if (weekly != null && weekly > 0.2) {
    return SmartTipInfo(
      emoji: '📈', priority: 11,
      title: 'Gaining ${weekly.toStringAsFixed(2)} kg/week',
      body: 'Weight trending up. Review portion sizes — especially rice and roti at dinner. '
          'Aim for palm-sized protein + fist-sized carbs + unlimited sabji.',
      accent: _kRed,
    );
  }

  // ── P8 — Streaks & motivation ────────────────────────────────────────────
  if (p.workoutStreak >= 7) {
    return SmartTipInfo(
      emoji: '🔥', priority: 35,
      title: '${p.workoutStreak}-day workout streak!',
      body: 'Incredible consistency — you\'re in the top habit tier. '
          'Streaks past 21 days encode as identity, not discipline. Keep the chain unbroken.',
      accent: _kOrange,
    );
  }
  if (p.calorieStreak >= 7 && p.workoutStreak >= 3) {
    return SmartTipInfo(
      emoji: '⚡', priority: 36,
      title: '7-day diet + ${p.workoutStreak}d workout combo!',
      body: 'This consistency is exactly what drives visible results. '
          'Take your before photo — the 4-week version of you will look different.',
      accent: _kGreen,
    );
  }

  // ── P10 — Nothing logged late ────────────────────────────────────────────
  if (cals == 0 && hour >= 11) {
    return SmartTipInfo(
      emoji: '⏰', priority: 13,
      title: 'Nothing logged yet today',
      body: 'Log your next meal now — you have $remaining kcal left, '
          'enough for a full lunch + dinner.',
      accent: _kOrange,
    );
  }

  // ── Default — positive feedback ──────────────────────────────────────────
  if (p.calorieStreak >= 3 && p.workoutStreak >= 3) {
    return SmartTipInfo(
      emoji: '✅', priority: 99,
      title: 'You\'re on track today',
      body: '${p.calorieStreak}d diet streak + ${p.workoutStreak}d workout streak. '
          'Stay consistent — fat loss is 90% showing up every day.',
      accent: _kGreen,
    );
  }
  return SmartTipInfo(
    emoji: '💡', priority: 99,
    title: 'Stay consistent',
    body: 'Hit your ${p.calorieGoal} kcal goal, ${p.proteinGoal}g protein and '
        '${p.waterGoalMl}ml water daily. Results compound over 90 days.',
    accent: _kGreen,
  );
}
