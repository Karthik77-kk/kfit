import 'package:flutter/material.dart';

/// Lightweight Markdown renderer for the AI chat.
///
/// LLMs emit a small, predictable subset of Markdown — **bold**, *italic* /
/// _italic_, `inline code`, `#`/`##`/`###` headings, and `-`/`*`/`+` or `1.`
/// lists. Rendering them as plain text leaks literal `**` and `*` into the
/// bubble (the single most "unpolished" thing users see). This widget parses
/// that subset into styled spans so nothing leaks and the text inherits the
/// app's typography. It is intentionally dependency-free (flutter_markdown is
/// discontinued) and never throws on malformed input — unmatched markers fall
/// back to literal text.
class MarkdownText extends StatelessWidget {
  const MarkdownText(this.data, {super.key, required this.baseStyle});

  final String data;
  final TextStyle baseStyle;

  static final RegExp _bullet = RegExp(r'^\s*[-*+]\s+');
  static final RegExp _numbered = RegExp(r'^\s*(\d+)\.\s+');
  static final RegExp _heading = RegExp(r'^(#{1,3})\s+');
  // Order matters: bold (**) is tried before italic (*) so `**x**` isn't
  // mis-read as two italic markers.
  static final RegExp _inline = RegExp(
    r'\*\*(.+?)\*\*|__(.+?)__|\*(.+?)\*|_(.+?)_|`([^`]+)`',
  );

  /// Parses one line of inline Markdown into styled [InlineSpan]s. Exposed for
  /// testing. Unmatched `*`/`_`/`` ` `` are emitted as literal text.
  static List<InlineSpan> inlineSpans(String text, TextStyle style) {
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _inline.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start), style: style));
      }
      if (m.group(1) != null || m.group(2) != null) {
        spans.add(TextSpan(
          text: m.group(1) ?? m.group(2),
          style: style.copyWith(fontWeight: FontWeight.w700),
        ));
      } else if (m.group(3) != null || m.group(4) != null) {
        spans.add(TextSpan(
          text: m.group(3) ?? m.group(4),
          style: style.copyWith(fontStyle: FontStyle.italic),
        ));
      } else if (m.group(5) != null) {
        spans.add(TextSpan(
          text: m.group(5),
          style: style.copyWith(
            fontFamily: 'monospace',
            backgroundColor: Colors.white.withValues(alpha: 0.08),
          ),
        ));
      }
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last), style: style));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final muted = baseStyle.color?.withValues(alpha: 0.7) ?? Colors.white70;
    final lines = data.split('\n');
    final blocks = <Widget>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty) {
        // Collapse runs of blank lines into a single small gap.
        if (blocks.isNotEmpty && i != lines.length - 1) {
          blocks.add(const SizedBox(height: 6));
        }
        continue;
      }

      final heading = _heading.firstMatch(line);
      if (heading != null) {
        final level = heading.group(1)!.length; // 1..3
        final content = line.substring(heading.end);
        final size = (baseStyle.fontSize ?? 14) + (4 - level) * 2; // # biggest
        blocks.add(Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 2),
          child: Text.rich(
            TextSpan(
              children: inlineSpans(
                content,
                baseStyle.copyWith(
                    fontSize: size, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ));
        continue;
      }

      final bullet = _bullet.firstMatch(line);
      if (bullet != null) {
        blocks.add(_listRow(
          marker: '•  ',
          content: line.substring(bullet.end),
          markerStyle: baseStyle.copyWith(color: muted),
        ));
        continue;
      }

      final numbered = _numbered.firstMatch(line);
      if (numbered != null) {
        blocks.add(_listRow(
          marker: '${numbered.group(1)}.  ',
          content: line.substring(numbered.end),
          markerStyle: baseStyle.copyWith(color: muted),
        ));
        continue;
      }

      blocks.add(Text.rich(TextSpan(children: inlineSpans(line, baseStyle))));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: blocks.isEmpty
          ? [Text(data, style: baseStyle)]
          : blocks,
    );
  }

  Widget _listRow({
    required String marker,
    required String content,
    required TextStyle markerStyle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 1, bottom: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(marker, style: markerStyle),
          Expanded(
            child: Text.rich(
              TextSpan(children: inlineSpans(content, baseStyle)),
            ),
          ),
        ],
      ),
    );
  }
}
