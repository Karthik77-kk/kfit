import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

/// Branded launch screen shown while the provider loads. Replaces the bare 💪
/// emoji with a code-drawn "K" wordmark on the signature green→blue gradient,
/// revealed with a short fade + scale (the first 800ms a user sees sets the
/// whole quality expectation). Collapses to the static logo under reduce-motion.
class BrandSplash extends StatefulWidget {
  const BrandSplash({super.key});

  @override
  State<BrandSplash> createState() => _BrandSplashState();
}

class _BrandSplashState extends State<BrandSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _scale =
        Tween<double>(begin: 0.82, end: 1).animate(
            CurvedAnimation(parent: _c, curve: AppCurves.emphasized));
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const logo = _Wordmark();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: reduceMotion(context)
            ? logo
            : FadeTransition(
                opacity: _fade,
                child: ScaleTransition(scale: _scale, child: logo),
              ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.green, AppColors.blue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.green.withValues(alpha: 0.35),
                blurRadius: 32,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Center(
            child: Text('K',
                style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                    letterSpacing: -1)),
          ),
        ),
        const SizedBox(height: 18),
        const Text('K Fitness',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.5)),
      ],
    );
  }
}
