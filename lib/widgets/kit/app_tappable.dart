import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_tokens.dart';

/// A ripple wrapper for the many small tap targets (chips, +/− buttons, presets)
/// that previously used a bare [GestureDetector] and so felt "dead". Gives a
/// Material ink ripple clipped to [borderRadius], with an optional selection
/// haptic.
///
/// Pass [decoration] (and optional [padding]) to replace a tappable
/// `Container(decoration: …)`: the decoration is painted via [Ink] so the ripple
/// renders *on top* of it (a plain InkWell behind an opaque Container shows no
/// splash). Use [AppCard] for full cards; this is for everything smaller.
class AppTappable extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final bool haptic;
  final Decoration? decoration;
  final EdgeInsetsGeometry? padding;

  /// When set (e.g. `CircleBorder()`), clips the ripple to this shape instead of
  /// [borderRadius] — for circular/pill targets.
  final ShapeBorder? customBorder;

  const AppTappable({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = AppRadii.rMd,
    this.haptic = true,
    this.decoration,
    this.padding,
    this.customBorder,
  });

  @override
  Widget build(BuildContext context) {
    final tap = onTap == null
        ? null
        : () {
            if (haptic) HapticFeedback.selectionClick();
            onTap!();
          };
    final content =
        padding == null ? child : Padding(padding: padding!, child: child);
    final inkWell = InkWell(
      borderRadius: customBorder == null ? borderRadius : null,
      customBorder: customBorder,
      onTap: tap,
      child: content,
    );

    return Material(
      type: MaterialType.transparency,
      child: decoration == null
          ? inkWell
          : Ink(decoration: decoration, child: inkWell),
    );
  }
}
