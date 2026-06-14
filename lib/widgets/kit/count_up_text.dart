import 'package:flutter/material.dart';
import '../../theme/app_tokens.dart';

/// A number that rolls up from 0 to [value] on first build (and animates
/// between values on change), giving the "counting" feel premium dashboards
/// use. Collapses to the final value instantly when the OS "reduce motion"
/// setting is on.
///
/// Formatting mirrors plain `Text`: pass [decimals], an optional [prefix] /
/// [suffix], and [signed] to force a leading `+` for non-negative values
/// (matches the existing net-calorie display).
class CountUpText extends StatelessWidget {
  final double value;
  final int decimals;
  final String prefix;
  final String suffix;
  final bool signed;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;

  const CountUpText(
    this.value, {
    super.key,
    this.decimals = 0,
    this.prefix = '',
    this.suffix = '',
    this.signed = false,
    this.style,
    this.duration = AppDurations.count,
    this.curve = AppCurves.emphasized,
  });

  String _format(double v) {
    final sign = (signed && v >= 0) ? '+' : '';
    return '$prefix$sign${v.toStringAsFixed(decimals)}$suffix';
  }

  @override
  Widget build(BuildContext context) {
    // Render the final value directly when motion is reduced (also keeps tests
    // that don't pump frames deterministic).
    if (reduceMotion(context)) {
      return Text(_format(value), style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: duration,
      curve: curve,
      builder: (_, v, __) => Text(_format(v), style: style),
    );
  }
}
