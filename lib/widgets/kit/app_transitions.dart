import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import '../../theme/app_tokens.dart';

/// A Material 3 shared-axis route for full-screen pushes — the premium
/// replacement for the default `MaterialPageRoute` slide. The incoming page
/// slides + fades along the given axis while the outgoing one recedes.
Route<T> sharedAxisRoute<T>(
  Widget page, {
  SharedAxisTransitionType type = SharedAxisTransitionType.horizontal,
}) {
  return PageRouteBuilder<T>(
    transitionDuration: AppDurations.normal,
    reverseTransitionDuration: AppDurations.normal,
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, secondaryAnimation, child) =>
        SharedAxisTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      transitionType: type,
      fillColor: AppColors.background,
      child: child,
    ),
  );
}
