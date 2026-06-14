import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/fitness_provider.dart';
import '../services/smart_insight_engine.dart';
import '../theme/app_tokens.dart';
import '../widgets/kit/kit.dart';

/// "Spotify Wrapped"-style swipeable recap of the last 7 days. Every input is
/// already computed by [FitnessProvider] / the insight engine, so this is a
/// presentation layer only. Swipe (or tap the right/left half) between slides.
class WeeklyRecapScreen extends StatefulWidget {
  const WeeklyRecapScreen({super.key});

  @override
  State<WeeklyRecapScreen> createState() => _WeeklyRecapScreenState();
}

class _WeeklyRecapScreenState extends State<WeeklyRecapScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int delta, int count) {
    final next = _page + delta;
    if (next < 0 || next >= count) return;
    _controller.animateToPage(next,
        duration: AppDurations.normal, curve: AppCurves.emphasized);
  }

  List<_Slide> _slides(FitnessProvider p) {
    final slides = <_Slide>[
      const _Slide(
        emoji: '📊',
        value: 7,
        suffix: '',
        decimals: 0,
        big: 'Your week',
        caption: 'in review — last 7 days',
        colors: [AppColors.green, AppColors.blue],
      ),
    ];

    final weekly = p.weeklyWeightChange;
    if (weekly != null) {
      final losing = weekly <= 0;
      slides.add(_Slide(
        emoji: '⚖️',
        value: weekly,
        decimals: 2,
        suffix: ' kg',
        signed: true,
        big: losing ? 'Trending down' : 'Weight change',
        caption: 'change per week',
        colors: const [AppColors.green, Color(0xFF1E7A3C)],
      ));
    }

    final bestLift = p.topLiftsOneRm.entries.isNotEmpty
        ? p.topLiftsOneRm.entries.first
        : null;
    slides.add(_Slide(
      emoji: '🏋️',
      value: p.weeklyWorkoutDays.toDouble(),
      suffix: '/7',
      decimals: 0,
      big: 'Workouts',
      caption: bestLift != null
          ? '${p.workoutStreak}-day streak · best lift ${bestLift.key} ~${bestLift.value.round()}kg'
          : '${p.workoutStreak}-day workout streak',
      colors: const [AppColors.orange, Color(0xFFB35900)],
    ));

    slides.add(_Slide(
      emoji: '🍽️',
      value: p.weeklyAvgProtein.toDouble(),
      suffix: 'g',
      decimals: 0,
      big: 'Avg protein / day',
      caption:
          '${p.weeklyAvgCalories.round()} avg kcal · protein goal hit ${p.weeklyProteinGoalHitDays}/7 days',
      colors: const [AppColors.blue, Color(0xFF1E6A7A)],
    ));

    final insight = topInsight(p, DateTime.now());
    slides.add(_Slide(
      emoji: '🔥',
      value: p.habitScore.toDouble(),
      suffix: '/100',
      decimals: 0,
      big: 'Habit score',
      caption: insight.title,
      colors: const [AppColors.indigo, Color(0xFF3A2E8C)],
    ));

    return slides;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<FitnessProvider>();
    final slides = _slides(p);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            // Tap right half → next, left half → previous (story-style).
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) {
                final mid = MediaQuery.of(context).size.width / 2;
                _go(d.localPosition.dx < mid ? -1 : 1, slides.length);
              },
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: slides.length,
                itemBuilder: (_, i) => _SlideView(slide: slides[i]),
              ),
            ),

            // Progress dots
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(slides.length, (i) {
                  final active = i == _page;
                  return AnimatedContainer(
                    duration: AppDurations.fast,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: active
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  );
                }),
              ),
            ),

            // Close
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide {
  final String emoji;
  final double value;
  final int decimals;
  final String suffix;
  final bool signed;
  final String big;
  final String caption;
  final List<Color> colors;

  const _Slide({
    required this.emoji,
    required this.value,
    required this.big,
    required this.caption,
    required this.colors,
    this.decimals = 0,
    this.suffix = '',
    this.signed = false,
  });
}

class _SlideView extends StatelessWidget {
  final _Slide slide;
  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            slide.colors.first.withValues(alpha: 0.30),
            AppColors.background,
            slide.colors.last.withValues(alpha: 0.18),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(slide.emoji, style: const TextStyle(fontSize: 56))
              .animate()
              .fadeIn(duration: 350.ms)
              .scale(begin: const Offset(0.7, 0.7)),
          const SizedBox(height: 24),
          CountUpText(
            slide.value,
            decimals: slide.decimals,
            suffix: slide.suffix,
            signed: slide.signed,
            style: const TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -1.5),
          ).animate().fadeIn(delay: 120.ms, duration: 400.ms),
          const SizedBox(height: 8),
          Text(slide.big,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white))
              .animate()
              .fadeIn(delay: 200.ms)
              .slideY(begin: 0.2, end: 0),
          const SizedBox(height: 10),
          Text(slide.caption,
                  style: const TextStyle(fontSize: 14, color: AppColors.muted))
              .animate()
              .fadeIn(delay: 300.ms),
        ],
      ),
    );
  }
}
