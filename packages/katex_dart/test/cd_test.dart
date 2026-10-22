import 'package:katex_dart/katex_dart.dart';
import 'package:test/test.dart';

// Tests for `{CD}` (commutative diagrams) and the stacked arrow delimiters
// it needs (`\Big\uparrow` etc.). KaTeX-level reference: KaTeX 0.17.0
// `src/environments/cd.ts` + `src/delimiter.ts`.

/// Every span in [root] carrying [cls], in document order.
List<SpanNode> spansWithClass(BoxNode root, String cls) {
  final out = <SpanNode>[];
  void walk(BoxNode node) {
    if (node is SpanNode && node.classes.contains(cls)) out.add(node);
    final children = switch (node) {
      HBox(:final children) => children,
      SpanNode(:final children) => children,
      _ => const <BoxNode>[],
    };
    for (final child in children) {
      walk(child);
    }
    if (node is VList) {
      for (final position in node.positions) {
        walk(position.box);
      }
    }
    if (node is EncloseNode) walk(node.child);
  }

  walk(root);
  return out;
}

/// The glyph ink under [root] (codepoints in document order).
String ink(BoxNode root) {
  final chars = <String>[];
  void walk(BoxNode node) {
    if (node is GlyphNode) {
      chars.add(String.fromCharCode(node.codepoint));
      return;
    }
    final children = switch (node) {
      HBox(:final children) => children,
      SpanNode(:final children) => children,
      _ => const <BoxNode>[],
    };
    for (final child in children) {
      walk(child);
    }
    if (node is VList) {
      for (final position in node.positions) {
        walk(position.box);
      }
    }
    if (node is EncloseNode) walk(node.child);
  }

  walk(root);
  return chars.join();
}

void main() {
  const disp = KatexOptions(displayMode: true);

  group('stacked arrow delimiters', () {
    test(r'\Big\downarrow is 1.8em tall', () {
      final root = renderToBox(r'\Big\downarrow', options: disp);
      expect(root.width, greaterThan(0.5));
      expect(root.height + root.depth, closeTo(1.8, 0.05));
    });

    test(r'\bigg\updownarrow is 2.4em tall', () {
      final root = renderToBox(r'\bigg\updownarrow', options: disp);
      expect(root.height + root.depth, closeTo(2.4, 0.05));
    });

    test(r'\left\downarrow sizes to its body', () {
      final plain = renderToBox(r'\left\downarrow x \right.', options: disp);
      final tall = renderToBox(
        r'\left\downarrow \frac{a}{b} \right.',
        options: disp,
      );
      expect(tall.height + tall.depth, greaterThan(plain.height + plain.depth));
    });
  });

  group('{CD}', () {
    test('a full diagram renders cells, arrows, and labels', () {
      final root = renderToBox(
        r'\begin{CD} A @>a>> B \\ @VbVV @AAcA \\ C @= D \end{CD}',
        options: disp,
      );
      expect(root.width, greaterThan(0));
      // Two horizontal arrows (`@>a>>` and `@=`, which is an extensible
      // equals), both vertical arrows, and all three labels.
      expect(spansWithClass(root, 'x-arrow'), hasLength(2));
      expect(spansWithClass(root, 'cd-vert-arrow'), hasLength(2));
      final text = ink(root);
      for (final token in ['A', 'B', 'C', 'D', 'a', 'b', 'c']) {
        expect(text, contains(token));
      }
    });

    test('unlabeled arrows render', () {
      final root = renderToBox(
        r'\begin{CD} A @>>> B \\ @VVV \\ C @>>> D \end{CD}',
        options: disp,
      );
      expect(root.width, greaterThan(0));
      expect(spansWithClass(root, 'x-arrow'), hasLength(2));
      expect(spansWithClass(root, 'cd-vert-arrow'), hasLength(1));
    });

    test('@= @| @. render without labels', () {
      for (final tex in [
        r'\begin{CD} A @= B \end{CD}',
        r'\begin{CD} A @| B \end{CD}',
        r'\begin{CD} A @. B \end{CD}',
      ]) {
        final root = renderToBox(tex, options: disp);
        expect(root.width, greaterThan(0), reason: tex);
      }
    });

    test('an unknown arrow character is a parse error', () {
      expect(
        () => renderToBox(r'\begin{CD} A @? B \end{CD}', options: disp),
        throwsA(
          isA<ParseError>().having(
            (e) => e.message,
            'message',
            contains('Expected one of'),
          ),
        ),
      );
    });

    test('an unterminated arrow is a parse error', () {
      expect(
        () => renderToBox(r'\begin{CD} A @> B \end{CD}', options: disp),
        throwsA(
          isA<ParseError>().having(
            (e) => e.message,
            'message',
            contains('to complete a CD arrow'),
          ),
        ),
      );
    });

    test('an @ inside a label is a parse error', () {
      expect(
        () => renderToBox(r'\begin{CD} A @>x@y>> B \end{CD}', options: disp),
        throwsA(isA<ParseError>()),
      );
    });
  });
}
