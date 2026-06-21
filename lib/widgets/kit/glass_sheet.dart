import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/app_tokens.dart';

/// Frosted-glass panel for bottom-sheet content (blur + translucent surface,
/// top-rounded). Use with showModalBottomSheet(backgroundColor: Colors.transparent).
class GlassSheet extends StatelessWidget {
  final Widget child;
  const GlassSheet({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface3.withValues(alpha: 0.82),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: const Border(top: BorderSide(color: AppColors.rim, width: 1)),
          ),
          child: child,
        ),
      ),
    );
  }
}
