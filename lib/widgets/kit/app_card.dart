import 'package:flutter/material.dart';
import '../../theme/app_tokens.dart';

/// The standard surface container used across the app: a rounded card on the
/// [AppColors.card] surface. When [onTap] is provided it uses an [InkWell] so
/// taps get a Material ripple (replacing bare `GestureDetector`s). Pass
/// [gradient] / [border] for accent cards (e.g. the AI Coach entry).
///
/// By default the card is [elevated]: it gets a soft blue-black shadow plus a
/// 1px top rim-light, so it lifts off the pure-black canvas. Set
/// `elevated: false` for flat nested tiles, or pass an explicit [boxShadow] /
/// [border] to override.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;
  final Gradient? gradient;
  final BoxBorder? border;
  final VoidCallback? onTap;
  final List<BoxShadow>? boxShadow;
  final bool elevated;

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
    this.elevated = true,
  });

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    final effectiveShadow =
        boxShadow ?? (elevated ? AppShadows.card : null);
    final effectiveBorder = border ??
        (elevated
            ? const Border(top: BorderSide(color: AppColors.rim, width: 1))
            : null);
    final decorated = Container(
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient,
        borderRadius: br,
        border: effectiveBorder,
        boxShadow: effectiveShadow,
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
