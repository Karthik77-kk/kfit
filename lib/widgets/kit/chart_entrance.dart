import 'package:flutter/material.dart';
import '../../theme/app_tokens.dart';

/// Drives a one-shot `0 → 1` entrance progress on first build, so charts can
/// animate themselves in (bars grow up, a line draws left→right) instead of
/// popping. Collapses to its end-state instantly when the OS "reduce motion"
/// setting is on, exactly like the ring sweep on Home.
///
/// The progress is exposed to the [builder] so each chart applies it however it
/// needs — multiplying bar heights, or clipping a reveal via [RevealClipper].
class ChartEntrance extends StatelessWidget {
  final Widget Function(BuildContext context, double t) builder;
  final Duration duration;
  const ChartEntrance({
    super.key,
    required this.builder,
    this.duration = AppDurations.ring,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: reduceMotion(context) ? Duration.zero : duration,
      curve: AppCurves.emphasized,
      builder: (ctx, t, _) => builder(ctx, t),
    );
  }
}

/// Clips a child to a left→right fraction of its width — pair with
/// [ChartEntrance] to "draw" a line chart on first paint. At `t == 1` the clip
/// is the full size, so hit-testing (chart tooltips) is unaffected once the
/// reveal finishes.
class RevealClipper extends CustomClipper<Rect> {
  final double t;
  const RevealClipper(this.t);

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width * t, size.height);

  @override
  bool shouldReclip(RevealClipper oldClipper) => oldClipper.t != t;
}
