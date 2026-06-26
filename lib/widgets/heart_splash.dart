import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A one-shot, full-screen heart greeting. Plays for ~3 seconds then calls
/// [onDone]. Purely decorative and fully self-contained — a single controller
/// drives a 3D flip-in (perspective rotateY), a heartbeat pulse, a soft glow,
/// and a fade-out. Callers decide *when* to show it; this widget owns the
/// animation and clean-up only.
class HeartSplash extends StatefulWidget {
  /// Fired once when the 3s animation completes (so the caller can remove it).
  final VoidCallback onDone;

  /// Name shown under the heart.
  final String name;

  /// Celebratory line shown beneath the name.
  final String message;

  const HeartSplash({
    super.key,
    required this.onDone,
    this.name = 'Jaswini',
    this.message = 'Congrats 🎉',
  });

  @override
  State<HeartSplash> createState() => _HeartSplashState();
}

class _HeartSplashState extends State<HeartSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) widget.onDone();
        })
        ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // Elastic "pop" over the first 30% of the timeline.
  double _intro(double t) =>
      Curves.elasticOut.transform((t / 0.30).clamp(0.0, 1.0));

  // Fade/shrink over the last 15%.
  double _outro(double t) => ((t - 0.85) / 0.15).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final intro = _intro(t); // elasticOut, overshoots >1 for the "pop"
        final fade = intro.clamp(0.0, 1.0); // safe for Opacity / alpha
        final outro = _outro(t);
        final opacity = 1.0 - outro;
        final holding = t > 0.30 && t < 0.85;
        // Subtle heartbeat during the hold phase.
        final beat = 1.0 + (holding ? 0.06 * math.sin(t * math.pi * 8) : 0.0);
        final scale = (0.2 + 0.8 * intro) * beat * (1.0 - 0.15 * outro);
        // 3D: flip in around Y, then a gentle oscillation.
        final rotY =
            (1 - intro) * (math.pi / 2) + 0.12 * math.sin(t * math.pi * 4) * intro;

        return Opacity(
          opacity: opacity,
          child: Container(
            color: Colors.black.withValues(alpha: 0.55 * opacity),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0015) // perspective
                    ..rotateY(rotY)
                    ..scaleByDouble(scale, scale, scale, 1.0),
                  child: _Heart(glow: fade),
                ),
                const SizedBox(height: 20),
                Opacity(
                  opacity: fade,
                  child: Text(
                    widget.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Opacity(
                  opacity: fade,
                  child: Text(
                    widget.message,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Heart extends StatelessWidget {
  final double glow;
  const _Heart({required this.glow});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF2D55).withValues(alpha: 0.55 * glow),
            blurRadius: 60 * glow,
            spreadRadius: 8 * glow,
          ),
        ],
      ),
      child: ShaderMask(
        shaderCallback: (r) => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF6B8B), Color(0xFFFF2D55)],
        ).createShader(r),
        child: const Icon(Icons.favorite, color: Colors.white, size: 140),
      ),
    );
  }
}
