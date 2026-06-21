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
///
/// When [onTap] is provided the card also sinks slightly under the finger
/// (0.97 scale) for a tactile "press-to-lift" feel. Static cards (no onTap)
/// are unaffected. The animation is suppressed when the OS reduce-motion
/// setting is active.
class AppCard extends StatefulWidget {
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
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(widget.radius);
    final effectiveShadow =
        widget.boxShadow ?? (widget.elevated ? AppShadows.card : null);
    final effectiveBorder = widget.border ??
        (widget.elevated
            ? const Border(top: BorderSide(color: AppColors.rim, width: 1))
            : null);
    final decorated = Container(
      decoration: BoxDecoration(
        color: widget.gradient == null ? widget.color : null,
        gradient: widget.gradient,
        borderRadius: br,
        border: effectiveBorder,
        boxShadow: effectiveShadow,
      ),
      child: widget.onTap == null
          ? Padding(padding: widget.padding, child: widget.child)
          // Material + InkWell so the ripple is clipped to the rounded shape.
          : Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: br,
                onTap: widget.onTap,
                onHighlightChanged: widget.onTap != null
                    ? (v) => setState(() => _pressed = v)
                    : null,
                child: Padding(padding: widget.padding, child: widget.child),
              ),
            ),
    );

    // Only animate when tappable and motion is not reduced.
    final scale = (widget.onTap != null && !reduceMotion(context))
        ? (_pressed ? 0.97 : 1.0)
        : 1.0;
    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: decorated,
    );
  }
}
