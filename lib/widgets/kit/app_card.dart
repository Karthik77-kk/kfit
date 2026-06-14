import 'package:flutter/material.dart';
import '../../theme/app_tokens.dart';

/// The standard surface container used across the app: a rounded card on the
/// [AppColors.card] surface. When [onTap] is provided it uses an [InkWell] so
/// taps get a Material ripple (replacing bare `GestureDetector`s). Pass
/// [gradient] / [border] for accent cards (e.g. the AI Coach entry).
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;
  final Gradient? gradient;
  final BoxBorder? border;
  final VoidCallback? onTap;
  final List<BoxShadow>? boxShadow;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.radius = AppRadii.lg,
    this.color = AppColors.card,
    this.gradient,
    this.border,
    this.onTap,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    final decorated = Container(
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient,
        borderRadius: br,
        border: border,
        boxShadow: boxShadow,
      ),
      child: onTap == null
          ? Padding(padding: padding, child: child)
          // Material + InkWell so the ripple is clipped to the rounded shape.
          : Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: br,
                onTap: onTap,
                child: Padding(padding: padding, child: child),
              ),
            ),
    );
    return decorated;
  }
}
