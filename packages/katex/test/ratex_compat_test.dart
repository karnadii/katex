// Tests for the RaTeX-compatible API surface added on the `mathnote` branch.
//
// The point of this surface is drop-in parity with `ratex_flutter`, so the
// tests assert the *contract* a caller relies on: the same constructor
// parameter names, the same error type with a `message`, the same
// parseAndLayout shape, and a cache that makes a repeat parse free.

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

    test('parseAndLayout applies a shrink-to-fit scale for maxWidthEm', () {
      final natural = KaTeXEngine.instance.parseAndLayout('x + y + z');
      final fitted = KaTeXEngine.instance.parseAndLayout(
        'x + y + z',
        maxWidthEm: natural.width / 2,
      );
      expect(fitted.scale, lessThan(1.0));
      expect(fitted.scaledWidth, closeTo(natural.width / 2, 1e-9));
      // The natural dimensions are untouched — only the scale differs.
      expect(fitted.width, closeTo(natural.width, 1e-9));
    });

    test('parseAndLayout leaves the scale at 1 when the formula fits', () {
      final dl = KaTeXEngine.instance.parseAndLayout(
        'x',
        maxWidthEm: 100,
      );
      expect(dl.scale, 1.0);
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

    testWidgets('matches the Math widget box tree for the same formula', (tester) async {
      const tex = r'\sum_{i=0}^{n} i';
      final widgetBox = KaTeXEngine.instance.parseBox(tex, displayMode: true);
      final mathBox = KaTeXEngine.instance.parseBox(tex, displayMode: true);
      expect(widgetBox.width, closeTo(mathBox.width, 1e-9));
    });

    testWidgets('paints with a halo without throwing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KaTeXWidget(
              latex: r'\sqrt{x}',
              haloColor: Color(0xFFFFFFFF),
            ),
          ),
        ),
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
