import 'package:flutter/material.dart';
import '../../theme/app_tokens.dart';

/// Uppercase muted section label used between cards on the Home feed and
/// elsewhere. Replaces the per-screen private `_SectionHdr` / `_Header`
/// copies; style comes from [AppText.caption].
class SectionHeader extends StatelessWidget {
  final String text;
  const SectionHeader(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(text, style: AppText.caption);
}
