import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kfit/widgets/markdown_text.dart';

/// The AI chat used to print literal `**` / `*` because assistant replies were
/// rendered as plain Text. MarkdownText parses the LLM subset; these tests pin
/// that bold/italic/code/headings/lists are styled and no markers leak.
void main() {
  const base = TextStyle(fontSize: 14, color: Colors.white);

  String plain(List<InlineSpan> spans) =>
      spans.map((s) => s is TextSpan ? (s.text ?? '') : '').join();

  group('inlineSpans', () {
    test('**bold** becomes a bold span with markers stripped', () {
      final spans = MarkdownText.inlineSpans('**hi**', base);
      expect(spans, hasLength(1));
      final s = spans.first as TextSpan;
      expect(s.text, 'hi');
      expect(s.style!.fontWeight, FontWeight.w700);
      expect(plain(spans).contains('*'), isFalse);
    });

    test('*italic* and _italic_ become italic spans', () {
      for (final src in ['*x*', '_x_']) {
        final s = MarkdownText.inlineSpans(src, base).single as TextSpan;
        expect(s.text, 'x');
        expect(s.style!.fontStyle, FontStyle.italic, reason: src);
      }
    });

    test('`code` uses a monospace span', () {
      final s = MarkdownText.inlineSpans('`fn()`', base).single as TextSpan;
      expect(s.text, 'fn()');
      expect(s.style!.fontFamily, 'monospace');
    });

    test('mixed text splits into literal + styled runs, order preserved', () {
      final spans = MarkdownText.inlineSpans('a **b** c', base);
      expect(plain(spans), 'a b c');
      final bold =
          spans.firstWhere((s) => (s as TextSpan).style?.fontWeight == FontWeight.w700);
      expect((bold as TextSpan).text, 'b');
    });

    test('plain text yields a single literal span', () {
      final spans = MarkdownText.inlineSpans('just words', base);
      expect(spans, hasLength(1));
      expect((spans.single as TextSpan).text, 'just words');
    });

    test('unmatched marker is kept literal, never throws', () {
      final spans = MarkdownText.inlineSpans('a * b', base);
      expect(plain(spans), 'a * b');
    });
  });

  testWidgets('renders headings, bullets and bold without leaking markers',
      (tester) async {
    const md = '# Title\n\n'
        'Your **protein** is low.\n'
        '- eat *eggs*\n'
        '- add `whey`\n'
        '1. step one';
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: MarkdownText(md, baseStyle: base)),
    ));

    // No literal markdown markers survive anywhere in the rendered tree.
    final allText = <String>[];
    for (final e in find.byType(RichText).evaluate()) {
      final rt = e.widget as RichText;
      allText.add(rt.text.toPlainText());
    }
    final joined = allText.join('\n');
    expect(joined.contains('**'), isFalse);
    expect(joined.contains('- '), isFalse); // bullets converted to •
    expect(joined.contains('Title'), isTrue);
    expect(joined.contains('protein'), isTrue);
    expect(joined.contains('•'), isTrue); // bullet marker rendered
  });

  testWidgets('empty string does not throw', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: MarkdownText('', baseStyle: base)),
    ));
    expect(find.byType(MarkdownText), findsOneWidget);
  });
}
