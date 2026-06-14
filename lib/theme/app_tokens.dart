import 'package:flutter/material.dart';

/// ─── Design tokens ───────────────────────────────────────────────────────────
///
/// Single source of truth for the K Fitness visual language. Before this file,
/// the same palette was copy-pasted as private `_kGreen` / `_kCard` / … consts
/// across ~10 screens; those now alias back to [AppColors] so the values live in
/// exactly one place. The app is dark-only, so plain `static const` token classes
/// are used (no `ThemeExtension` lerp boilerplate — there is no second theme to
/// interpolate toward). Everything here is `const`, so it is usable in `const`
/// contexts and inside `CustomPainter`s.

/// Brand + semantic colors. Values are byte-identical to the legacy palette so
/// adopting tokens does not change any pixels.
abstract final class AppColors {
  // Brand / accents
  static const Color green = Color(0xFF30D158); // primary
  static const Color blue = Color(0xFF40C8E0); // secondary
  static const Color red = Color(0xFFFF453A); // error / over-goal
  static const Color orange = Color(0xFFFF9F0A); // warning / eaten
  static const Color indigo = Color(0xFF5E5CE6); // rare accent

  // Surfaces (near-black, OLED-friendly)
  static const Color background = Color(0xFF000000);
  static const Color card = Color(0xFF1C1C1E);
  static const Color surface2 = Color(0xFF2C2C2E); // inputs, raised chips
  static const Color navBackground = Color(0xFF111111);

  // Text / lines
  static const Color textPrimary = Colors.white;
  static const Color muted = Color(0xFF8E8E93); // secondary text
  static const Color border = Color(0xFF38383A); // hairline dividers
}

/// 8-pt-ish spacing scale. Named steps keep padding/gaps consistent.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 32;
}

/// Corner radii. The app historically used 8 / 14 / 20 — codified here.
abstract final class AppRadii {
  static const double sm = 8;
  static const double md = 14;
  static const double lg = 20;

  static const BorderRadius rSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius rMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius rLg = BorderRadius.all(Radius.circular(lg));
}

/// Motion durations. Kept ≤900ms per the mid-range-Android performance budget.
abstract final class AppDurations {
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration count = Duration(milliseconds: 800); // number roll-ups
  static const Duration ring = Duration(milliseconds: 700); // ring sweep
  static const Duration stagger = Duration(milliseconds: 40); // list entrance interval
}

/// Easing curves. `easeOutCubic` gives the "snap into place" premium feel.
abstract final class AppCurves {
  static const Curve emphasized = Curves.easeOutCubic;
  static const Curve standard = Curves.easeOut;
}

/// Typographic scale. Exposed as explicit styles (not a global Material
/// [TextTheme] override) so adopting them never silently restyles ListTile /
/// AppBar text elsewhere in the app.
abstract final class AppText {
  static const TextStyle display = TextStyle(
      fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: AppColors.textPrimary);
  static const TextStyle title = TextStyle(
      fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: AppColors.textPrimary);
  static const TextStyle headline = TextStyle(
      fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary);
  static const TextStyle body = TextStyle(
      fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.textPrimary);
  static const TextStyle bodySmall = TextStyle(
      fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.textPrimary);
  static const TextStyle caption = TextStyle(
      fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: AppColors.muted);
  static const TextStyle label = TextStyle(
      fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.muted);
}

/// True when the OS "reduce motion" setting is on, or the platform/tests have
/// disabled animations. Animations should collapse to their end state when true.
bool reduceMotion(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;
