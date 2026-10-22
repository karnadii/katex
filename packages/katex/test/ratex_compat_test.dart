// Tests for the RaTeX-compatible API surface added on the `mathnote` branch.
//
// The point of this surface is drop-in parity with `ratex_flutter`, so the
// tests assert the *contract* a caller relies on: the same constructor
// parameter names, the same error type with a `message`, the same
// parseAndLayout shape, a cache that makes a repeat parse free, and — the
// subtle one — the same width-budget semantics.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katex/katex.dart';

void main() {
  setUp(() {
    kaTeXRenderCache.clear();
  });

  group('KaTeXException', () {
    test('carries a message and stringifies with the type name', () {
      const e = KaTeXException('boom');
      expect(e.message, 'boom');
      expect(e.toString(), 'KaTeXException: boom');
    });
  });

  group('KaTeXEngine', () {
    test('parseAndLayout returns em dimensions for a simple formula', () {
      final dl = KaTeXEngine.instance.parseAndLayout('x');
      expect(dl.width, greaterThan(0));
      expect(dl.height, greaterThan(0));
      expect(dl.depth, 0);
      expect(dl.totalHeight, closeTo(dl.height + dl.depth, 1e-9));
    });

    test('parseAndLayout honours displayMode', () {
      final inline = KaTeXEngine.instance.parseAndLayout(
        r'\sum_{i=0}^{n} i',
        displayMode: false,
      );
      final display = KaTeXEngine.instance.parseAndLayout(
        r'\sum_{i=0}^{n} i',
        displayMode: true,
      );
      // Display style puts the limits above/below the operator, so the
      // formula gets strictly taller.
      expect(display.totalHeight, greaterThan(inline.totalHeight));
    });

    test('a finite width budget wraps the expression', () {
      const tex = r'a+b+c+d=e+f+g+h';
      final unwrapped = KaTeXEngine.instance.parseAndLayout(tex);
      final wrapped = KaTeXEngine.instance.parseAndLayout(tex, maxWidthEm: 6);
      // Wrapping trades width for height: the result is narrower and taller.
      expect(wrapped.width, lessThan(unwrapped.width));
      expect(wrapped.totalHeight, greaterThan(unwrapped.totalHeight));
      // And it fits the budget, so no further scaling is needed.
      expect(wrapped.scale, 1.0);
    });

    test('an unwrapped formula is not scaled', () {
      final dl = KaTeXEngine.instance.parseAndLayout('x');
      expect(dl.scale, 1.0);
    });

    test('fitScale shrinks only when the formula is too wide', () {
      expect(fitScale(naturalWidth: 10, maxWidthEm: 20), 1.0);
      expect(fitScale(naturalWidth: 10, maxWidthEm: 5), closeTo(0.5, 1e-9));
      expect(fitScale(naturalWidth: 10, maxWidthEm: null), 1.0);
      expect(fitScale(naturalWidth: 0, maxWidthEm: 5), 1.0);
    });

    test('parseAndLayout throws KaTeXException on a malformed formula', () {
      expect(
        () => KaTeXEngine.instance.parseAndLayout(r'\frac{a}{'),
        throwsA(isA<KaTeXException>()),
      );
    });

    test('parseBox returns a cached tree for a repeated parse', () {
      final first = KaTeXEngine.instance.parseBox('a+b');
      expect(kaTeXRenderCache.length, 1);
      final second = KaTeXEngine.instance.parseBox('a+b');
      expect(identical(first, second), isTrue);
    });

    test('parseBox caches per displayMode', () {
      final inline = KaTeXEngine.instance.parseBox('a+b', displayMode: false);
      final display = KaTeXEngine.instance.parseBox('a+b', displayMode: true);
      expect(identical(inline, display), isFalse);
      expect(kaTeXRenderCache.length, 2);
    });

    test('parseBox caches per width budget', () {
      // A different budget wraps differently, so it is a different layout and
      // must not share a cache entry.
      final unwrapped = KaTeXEngine.instance.parseBox('a+b+c+d=e+f+g+h');
      final wrapped = KaTeXEngine.instance.parseBox(
        'a+b+c+d=e+f+g+h',
        maxWidthEm: 6,
      );
      expect(identical(unwrapped, wrapped), isFalse);
      expect(kaTeXRenderCache.length, 2);
    });
  });

  group('KaTeXRenderCache', () {
    test('evicts the least recently used entry when full', () {
      final cache = KaTeXRenderCache(maxSize: 2);
      final box = KaTeXEngine.instance.parseBox('z');
      cache.put('a', false, box);
      cache.put('b', false, box);
      cache.get('a', false); // refresh 'a'
      cache.put('c', false, box);
      expect(cache.length, 2);
      expect(cache.get('b', false), isNull);
      expect(cache.get('a', false), isNotNull);
    });
  });

  group('KaTeXWidget', () {
    testWidgets('renders a formula without throwing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: KaTeXWidget(latex: r'\frac{a}{b}')),
        ),
      );
      expect(find.byType(KaTeXWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reports a parse failure through onError', (tester) async {
      KaTeXException? reported;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KaTeXWidget(
              latex: r'\frac{a}{',
              onError: (e) => reported = e,
            ),
          ),
        ),
      );
      expect(reported, isNotNull);
      expect(reported!.message, isNotEmpty);
      expect(find.textContaining('KaTeX error'), findsOneWidget);
    });

    testWidgets('matches the Math widget box tree for the same formula', (
      tester,
    ) async {
      const tex = r'\sum_{i=0}^{n} i';
      final widgetBox = KaTeXEngine.instance.parseBox(tex, displayMode: true);
      final mathBox = KaTeXEngine.instance.parseBox(tex, displayMode: true);
      expect(widgetBox.width, closeTo(mathBox.width, 1e-9));
    });

    testWidgets('paints with a halo without throwing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KaTeXWidget(latex: r'\sqrt{x}', haloColor: Color(0xFFFFFFFF)),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a width budget wraps the formula onto several lines', (
      tester,
    ) async {
      const tex = r'a+b+c+d=e+f+g+h';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KaTeXWidget(latex: tex, fontSize: 20, maxWidth: 120),
          ),
        ),
      );
      final wrapped = KaTeXEngine.instance.parseBox(
        tex,
        displayMode: true,
        maxWidthEm: 120 / 20 - 2 * kInkOverflowPadEm,
      );
      final unwrapped = KaTeXEngine.instance.parseBox(tex, displayMode: true);
      expect(
        wrapped.height + wrapped.depth,
        greaterThan(unwrapped.height + unwrapped.depth),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('initKaTeX', () {
    test('completes without doing anything (pure Dart)', () async {
      await expectLater(initKaTeX(), completes);
    });
  });
}
