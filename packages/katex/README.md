# katex

A Flutter widget that renders LaTeX math by painting the backend-agnostic box tree produced by
the pure-Dart [`katex_dart`](https://pub.dev/packages/katex_dart) package. No re-parsing — the
widget is a direct consumer of the same box tree the SVG serializer uses.

See Flutter demo at [roszkowski.dev/katex](https://roszkowski.dev/katex).

See [main README](https://github.com/orestesgaolin/katex) for a comparison with other Flutter math libraries, and for the architecture of the `katex_dart` + `katex` combo.

## Usage

```dart
import 'package:katex/katex.dart';

Math(r'\frac{a}{b}');                          // inline
Math(r'\sum_{i=0}^n i', displayMode: true);    // display
Math(r'x^2', fontSize: 24, color: Colors.indigo);
Math(r'\frac{a}', throwOnError: false,         // graceful error handling
     onError: (context, e) => Text('bad: $e'));
```

See [`example/`](example/) for a runnable gallery demo.

## RaTeX-compatible API (`mathnote` branch)

This fork's `mathnote` branch adds a second, **drop-in-compatible** surface
that mirrors `ratex_flutter`'s API, so an app can swap the two engines
without touching call sites:

```dart
import 'package:katex/katex.dart';

KaTeXWidget(latex: r'\frac{a}{b}', fontSize: 24, color: Colors.black);
KaTeXWidget(
  latex: r'\sum_{i=0}^n i',
  displayMode: true,
  maxWidth: 320,
  onError: (e) => log(e.message),
);

await initKaTeX(); // no-op — KaTeX is pure Dart
final dl = KaTeXEngine.instance.parseAndLayout(r'x^2');
print(dl.width); // em
```

| `ratex_flutter`            | `katex` (`mathnote`)        | Notes                                      |
| -------------------------- | --------------------------- | ------------------------------------------ |
| `RaTeXWidget`              | `KaTeXWidget`               | Same parameter names and defaults          |
| `RaTeXException`           | `KaTeXException`            | Both carry `.message`                      |
| `RaTeXEngine.instance`     | `KaTeXEngine.instance`      | Same `parseAndLayout` signature            |
| `RaTeXColor`               | Flutter `Color`             |                                             |
| `initRaTeX()`              | `initKaTeX()`               | No-op — KaTeX is pure Dart                 |
| `raTeXRenderCache`         | `kaTeXRenderCache`          | Same LRU shape, keyed on `(latex, mode)`   |
| `DisplayList`              | `KaTeXDisplayList`          | Same em `width`/`height`/`depth` triple    |

Two behavioural differences are deliberate:

* **RaTeX wraps** a too-wide formula onto multiple lines; **KaTeX scales it
  down** to fit (KaTeX.js has no automatic line breaking either).
* RaTeX renders through FFI + an isolate hop, so it needs a frame before the
  formula appears. KaTeX is pure Dart, so the formula is in the first frame.

## How it works

The [`katex_dart`](https://pub.dev/packages/katex_dart) package parses the TeX into a `BoxNode`
tree once; `Math` paints it with a `CustomPainter` — `GlyphNode` → `TextPainter` (using the
bundled `KaTeX_*` fonts), `RuleNode` → `drawRect`, `SvgPathNode` → `drawPath`. Glyph baselines,
kerning, and vlist positioning mirror the `katex_dart` SVG serializer so both backends render
identically.

## License

MIT — see `LICENSE`. Ported from KaTeX (MIT). Bundled fonts are SIL OFL (`fonts/OFL.txt`).


## Previous katex library

The previous `katex` library is now deprecated and available [on GitHub](https://github.com/motorcityadam/katex.dart). The previous library was a wrapper around the original KaTeX JavaScript library. Thank you, Adam, for handing over the package to me. The new `katex` library is a pure Dart implementation of KaTeX, with no JavaScript dependency.