import 'package:flutter/material.dart';
import '../providers/fitness_provider.dart';

// ─── Palette (mirror of home_screen) ─────────────────────────────────────────
const _kGreen = Color(0xFF30D158);
const _kBlue = Color(0xFF40C8E0);
const _kRed = Color(0xFFFF453A);
const _kOrange = Color(0xFFFF9F0A);
const _kIndigo = Color(0xFF5E5CE6);

/// Category — used to keep the top-N insights varied (max one per category).
enum InsightCategory {
  weight,
  prediction,
  nutrition,
  hydration,
  activity,
  workout,
  bodyComp,
  measurements,
  motivation,
}

/// A single ranked, personalized insight.
class Insight {
  final String emoji;
  final String title;
  final String body;
  final Color accent;
  final InsightCategory category;
  final double score; // 0–100, higher = more relevant/urgent

  const Insight({
    required this.emoji,
    required this.title,
    required this.body,
    required this.accent,
    required this.category,
    required this.score,
  });
}

const _weekdayNames = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
];
const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];
String _fmtDate(DateTime d) => '${d.day} ${_monthNames[d.month - 1]} ${d.year}';

/// Generates every applicable insight, each scored. Pure & deterministic given
/// [p] and [now] — [now] is injectable so time-dependent rules are testable.
List<Insight> generateInsights(FitnessProvider p, DateTime now) {
  final out = <Insight>[];
  final hour = now.hour;
  final weight = p.latestWeightKg;
  final weekly = p.weeklyWeightChange; // kg/week, from linear regression
  final goal = p.calorieGoal;
  final proteinGoal = p.proteinGoal;
  final todayCal = p.todayCaloriesTotal.round();
  final todayProt = p.todayProteinTotal.round();

  // ── Weight: losing too fast (safety — highest priority) ───────────────────
  if (weekly != null && weekly < -0.9) {
    out.add(Insight(
      emoji: '⚠️',
      title: 'Losing too fast (${weekly.abs().toStringAsFixed(2)} kg/wk)',
      body: 'Above the safe 0.7 kg/week limit — you risk muscle loss. Add '
          '200–300 kcal: 2 extra rotis or a banana + whey shake.',
      accent: _kRed,
      category: InsightCategory.weight,
      score: 96,
    ));
  }

  // ── Predictive: plateau correlated with rising intake ─────────────────────
  if (weekly != null && weekly.abs() < 0.15) {
    final recent = p.avgCaloriesForDays(0, 6);
    final prior = p.avgCaloriesForDays(7, 13);
    if (recent > 0 && prior > 0 && recent > prior + 150) {
      out.add(Insight(
        emoji: '🔎',
        title: 'Fat loss stalled — intake crept up',
        body: 'Your weight is flat and your daily average rose '
            '~${(recent - prior).round()} kcal vs last week. Trim one roti or '
            'rice serving at dinner to restart the deficit.',
        accent: _kOrange,
        category: InsightCategory.prediction,
        score: 86,
      ));
    } else {
      out.add(Insight(
        emoji: '➡️',
        title: 'Weight plateau this week',
        body: 'Within ±0.15 kg/week. Add one more workout day or cut '
            '~150 kcal from dinner to break through.',
        accent: _kOrange,
        category: InsightCategory.weight,
        score: 52,
      ));
    }
  }

  // ── Weight: gaining ───────────────────────────────────────────────────────
  if (weekly != null && weekly > 0.25) {
    out.add(Insight(
      emoji: '📈',
      title: 'Trending up ${weekly.toStringAsFixed(2)} kg/wk',
      body: 'Review dinner portions — palm-sized protein, fist-sized carbs, '
          'unlimited sabji. A daily 30-min walk burns ~${_walkBurn(weight)} kcal.',
      accent: _kRed,
      category: InsightCategory.weight,
      score: 83,
    ));
  }

  // ── Weight: healthy loss + projected goal date ────────────────────────────
  if (weekly != null && weekly <= -0.2 && weekly >= -0.9) {
    final eta = p.estimatedGoalDate;
    out.add(Insight(
      emoji: '📉',
      title: 'Healthy loss ${weekly.abs().toStringAsFixed(2)} kg/wk',
      body: eta != null
          ? 'Perfect pace. At this rate you\'ll hit '
              '${p.goalWeightKg.toStringAsFixed(1)} kg by ${_fmtDate(eta)}. '
              'Keep protein above ${proteinGoal}g to protect muscle.'
          : 'Perfect pace — keep protein above ${proteinGoal}g to retain muscle '
              'while the fat comes off.',
      accent: _kGreen,
      category: InsightCategory.prediction,
      score: 58,
    ));
  }

  // ── Measurements: waist down even if scale is flat ────────────────────────
  final measures = p.getRecentMeasurements(days: 60);
  if (measures.length >= 2) {
    final firstWaist = measures.first.waistCm;
    final lastWaist = measures.last.waistCm;
    if (firstWaist != null && lastWaist != null) {
      final delta = lastWaist - firstWaist;
      if (delta <= -1.5) {
        out.add(Insight(
          emoji: '📏',
          title: 'Waist down ${delta.abs().toStringAsFixed(1)} cm',
          body: 'Real fat loss — even if the scale moves slowly, your waist '
              'shrinking means you\'re losing fat and keeping muscle. Stay the course.',
          accent: _kGreen,
          category: InsightCategory.measurements,
          score: 72,
        ));
      }
    }
  }

  // ── Body composition trend from smart scale ───────────────────────────────
  final scales = p.scaleHistory;
  if (scales.length >= 2) {
    final latest = scales.last;
    final prev = scales[scales.length - 2];
    if (latest.visceralFatIndex >= 13) {
      out.add(Insight(
        emoji: '🫀',
        title: 'Visceral fat is high (${latest.visceralFatIndex})',
        body: 'Index ≥13 raises health risk. Prioritise the deficit and daily '
            'steps — visceral fat responds fast to consistent fat loss.',
        accent: _kRed,
        category: InsightCategory.bodyComp,
        score: 79,
      ));
    }
    if (latest.muscleMassKg > 0 && prev.muscleMassKg > 0 &&
        latest.muscleMassKg < prev.muscleMassKg - 0.4 &&
        weekly != null && weekly < 0) {
      out.add(Insight(
        emoji: '💪',
        title: 'Muscle dipped ${(prev.muscleMassKg - latest.muscleMassKg).toStringAsFixed(1)} kg',
        body: 'You\'re losing some muscle with the fat. Push protein to '
            '${proteinGoal}g+ and keep lifting heavy to hold onto it.',
        accent: _kOrange,
        category: InsightCategory.bodyComp,
        score: 80,
      ));
    }
    if (latest.bodyFatPercent > 0 && prev.bodyFatPercent > 0 &&
        latest.bodyFatPercent < prev.bodyFatPercent - 0.3) {
      out.add(Insight(
        emoji: '🔥',
        title: 'Body fat down ${(prev.bodyFatPercent - latest.bodyFatPercent).toStringAsFixed(1)}%',
        body: 'Your scale shows real fat loss since last reading. Whatever you '
            'did this week — repeat it.',
        accent: _kGreen,
        category: InsightCategory.bodyComp,
        score: 56,
      ));
    }
  }

  // ── Nutrition: over goal today ────────────────────────────────────────────
  if (todayCal > goal + 400) {
    out.add(Insight(
      emoji: '🚨',
      title: '${todayCal - goal} kcal over goal',
      body: 'You\'re well above your ${goal} kcal target. Skip evening snacks '
          'and take a 30-min walk (~${_walkBurn(weight)} kcal).',
      accent: _kRed,
      category: InsightCategory.nutrition,
      score: 77,
    ));
  }

  // ── Nutrition: weekday protein habit pattern ──────────────────────────────
  final wdProtein = p.proteinAvgForWeekday(now.weekday);
  if (wdProtein != null && wdProtein < proteinGoal * 0.7 && hour < 17) {
    out.add(Insight(
      emoji: '🍳',
      title: 'You under-eat protein on ${_weekdayNames[now.weekday - 1]}s',
      body: 'Your ${_weekdayNames[now.weekday - 1]} average is only '
          '${wdProtein.round()}g vs your ${proteinGoal}g goal. Plan a whey shake '
          'or paneer/eggs early today to break the pattern.',
      accent: _kBlue,
      category: InsightCategory.nutrition,
      score: 69,
    ));
  }

  // ── Nutrition: protein behind personal pace today ─────────────────────────
  if (hour >= 13 && hour <= 21) {
    final expectedFraction = ((hour - 6) / 16).clamp(0.0, 1.0);
    final expected = proteinGoal * expectedFraction;
    if (todayProt < expected * 0.6) {
      out.add(Insight(
        emoji: '🥩',
        title: 'Protein behind pace ($todayProt g)',
        body: 'By now you\'d expect ~${expected.round()}g. You need '
            '${(proteinGoal - todayProt).clamp(0, proteinGoal)}g more — '
            'grilled chicken (31g/100g), 3 eggs (18g), or a whey shake (25g).',
        accent: _kBlue,
        category: InsightCategory.nutrition,
        score: 62,
      ));
    }
  }

  // ── Hydration: weekday water habit pattern ────────────────────────────────
  final wdWater = p.waterAvgForWeekday(now.weekday);
  if (wdWater != null && wdWater < p.waterGoalMl * 0.6 && hour >= 10) {
    out.add(Insight(
      emoji: '💧',
      title: 'Hydration dips on ${_weekdayNames[now.weekday - 1]}s',
      body: 'You average only ${wdWater.round()} ml on '
          '${_weekdayNames[now.weekday - 1]}s. Keep a bottle on your desk — '
          'aim for 500 ml before each meal today.',
      accent: _kBlue,
      category: InsightCategory.hydration,
      score: 54,
    ));
  } else if (p.todayWaterMl < p.waterGoalMl * 0.4 && hour >= 14) {
    out.add(Insight(
      emoji: '💧',
      title: 'Water only at ${p.todayWaterMl} ml',
      body: 'Less than halfway to your ${p.waterGoalMl} ml goal. Dehydration '
          'reads as hunger — a 500 ml bottle now curbs evening snacking.',
      accent: _kBlue,
      category: InsightCategory.hydration,
      score: 50,
    ));
  }

  // ── Activity: steps vs personal average ───────────────────────────────────
  final steps = p.todaySteps;
  if (hour >= 12) {
    if (steps > p.stepGoal) {
      out.add(Insight(
        emoji: '🏃',
        title: 'Step goal smashed (${_fmtK(steps)})',
        body: 'Your walking alone burns ~${p.walkingCaloriesBurned.round()} kcal '
            'today. This daily movement is what drives a steady weekly drop.',
        accent: _kGreen,
        category: InsightCategory.activity,
        score: 34,
      ));
    } else if (steps < p.stepGoal * 0.3) {
      out.add(Insight(
        emoji: '🚶',
        title: 'Only ${_fmtK(steps)} steps so far',
        body: 'A 20-min walk after lunch adds ~2,000 steps and '
            '~${_walkBurn(weight, minutes: 20)} kcal — and lowers blood sugar.',
        accent: _kBlue,
        category: InsightCategory.activity,
        score: 53,
      ));
    }
  }

  // ── Workout: days since last session ──────────────────────────────────────
  final dslw = p.daysSinceLastWorkout;
  if (dslw >= 3 && dslw < 900) {
    out.add(Insight(
      emoji: '🏋️',
      title: '$dslw days since your last workout',
      body: 'Momentum fades after 3 days off. Even a 20-min session today '
          '(push-ups, squats, plank) keeps the habit and the muscle.',
      accent: _kOrange,
      category: InsightCategory.workout,
      score: 73,
    ));
  } else if (p.workoutStreak >= 7) {
    out.add(Insight(
      emoji: '🔥',
      title: '${p.workoutStreak}-day workout streak!',
      body: 'Top-tier consistency. Past 21 days this becomes identity, not '
          'discipline. Keep the chain unbroken.',
      accent: _kOrange,
      category: InsightCategory.workout,
      score: 42,
    ));
  }

  // ── Workout: weekly frequency low late in week ────────────────────────────
  if (now.weekday >= 5 && p.weeklyWorkoutDays < 3) {
    out.add(Insight(
      emoji: '📅',
      title: 'Only ${p.weeklyWorkoutDays} workouts this week',
      body: 'Aim for 3–4 sessions weekly to retain muscle in a deficit. '
          'You\'ve got the weekend — fit one or two in.',
      accent: _kIndigo,
      category: InsightCategory.workout,
      score: 57,
    ));
  }

  // ── Motivation / positive default ─────────────────────────────────────────
  if (p.calorieStreak >= 3 && p.workoutStreak >= 3) {
    out.add(Insight(
      emoji: '✅',
      title: 'You\'re dialled in today',
      body: '${p.calorieStreak}-day diet + ${p.workoutStreak}-day workout streak. '
          'Fat loss is 90% showing up — and you are.',
      accent: _kGreen,
      category: InsightCategory.motivation,
      score: 26,
    ));
  }

  // Always-present fallback so topInsight never fails.
  out.add(Insight(
    emoji: '💡',
    title: 'Stay consistent',
    body: 'Hit ${goal} kcal, ${proteinGoal}g protein and '
        '${p.waterGoalMl} ml water daily. Results compound over 90 days.',
    accent: _kGreen,
    category: InsightCategory.motivation,
    score: 5,
  ));

  return out;
}

/// Top [count] insights, sorted by score and de-duplicated by category so the
/// surfaced set is varied. If fewer distinct categories apply, fills the rest
/// with the next-highest-scored regardless of category.
List<Insight> topInsights(FitnessProvider p, DateTime now, {int count = 3}) {
  final all = generateInsights(p, now)
    ..sort((a, b) => b.score.compareTo(a.score));
  final picked = <Insight>[];
  final usedCategories = <InsightCategory>{};
  for (final ins in all) {
    if (picked.length >= count) break;
    if (usedCategories.add(ins.category)) picked.add(ins);
  }
  if (picked.length < count) {
    for (final ins in all) {
      if (picked.length >= count) break;
      if (!picked.contains(ins)) picked.add(ins);
    }
  }
  return picked;
}

/// Single highest-priority insight (used by the home-screen widget).
Insight topInsight(FitnessProvider p, DateTime now) =>
    topInsights(p, now, count: 1).first;

// ── helpers ──────────────────────────────────────────────────────────────────
int _walkBurn(double? weightKg, {int minutes = 30}) =>
    (5.0 * (weightKg ?? 70.0) * minutes / 60.0).round();

String _fmtK(int n) =>
    n >= 1000 ? '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}k' : '$n';
