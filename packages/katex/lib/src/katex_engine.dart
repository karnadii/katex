/// The KaTeX engine facade — the entry point for parsing and laying out
/// formulas.
///
/// This is the deliberate twin of `ratex_flutter`'s `RaTeXEngine`: the same
/// class name shape, the same singleton accessor, the same
/// `parseAndLayout(latex, {displayMode, color, maxWidthEm})` signature, and
/// the same "throws on a bad formula" contract. Code written against one
/// engine reads almost identically against the other.
///
/// The one structural difference is *where the work happens*. RaTeX is a
/// native library reached over FFI, so its output is a flat list of draw
/// commands. KaTeX here is **pure Dart**, so its output is the backend-
/// agnostic box tree and the parsing runs on the calling isolate — no FFI
/// boundary, no JSON round-trip, and no isolate hop required to use it.
library;

import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:katex_dart/katex_dart.dart';

import 'katex_display_list.dart';
import 'katex_exception.dart';
import 'katex_render_cache.dart';

/// Coerces any render-time failure into a [KaTeXException] so the `onError`
/// callback and raw-value fallback receive a uniform type.
///
/// A [KaTeXException] is passed through unchanged; everything else
/// (`StateError`, `ArgumentError`, …) is wrapped with its string
/// representation so the message survives.
KaTeXException coerceRenderError(Object error) {
  if (error is KaTeXException) return error;
  return KaTeXException(error.toString());
}

/// The KaTeX engine.
///
/// Use [KaTeXEngine.instance] — the engine is stateless and thread-safe
/// (it holds no mutable state of its own; the cache is process-wide and
/// separately resettable).
class KaTeXEngine {
  static final KaTeXEngine instance = KaTeXEngine._();
  KaTeXEngine._();

  /// Parses [latex] and lays it out, returning the painted artifact.
  ///
  /// [displayMode] selects display (`true`) vs. inline (`false`) styling,
  /// matching KaTeX's `displayMode` and RaTeX's `displayMode`.
  ///
  /// [color] is the base colour to paint with. It is **not** baked into the
  /// returned tree — it travels with it and is applied at paint time, so a
  /// colour change costs nothing. Colours set inside the expression
  /// (`\textcolor{red}{x}`) still win for their own sub-tree.
  ///
  /// [maxWidthEm] is an optional width budget in em units. KaTeX (like
  /// KaTeX.js) does not implement automatic line breaking, so the budget is
  /// honoured by **scaling the formula down** to fit instead of wrapping it:
  /// the returned display list carries a [KaTeXDisplayList.scale] factor
  /// (`1.0` when the formula already fits). RaTeX, by contrast, wraps onto
  /// multiple lines for the same budget — the one behavioural divergence
  /// between the two engines.
  ///
  /// Throws [KaTeXException] when the formula cannot be parsed.
  KaTeXDisplayList parseAndLayout(
    String latex, {
    bool displayMode = true,
    Color color = const Color(0xFF000000),
    double? maxWidthEm,
  }) {
    final box = parseBox(latex, displayMode: displayMode);
    var scale = 1.0;
    if (maxWidthEm != null && maxWidthEm.isFinite && maxWidthEm > 0) {
      final natural = box.width;
      if (natural > maxWidthEm && natural > 0) {
        scale = maxWidthEm / natural;
      }
    }
    return KaTeXDisplayList(box: box, color: color, scale: scale);
  }

  /// Parses [latex] and lays it out, returning the raw box tree.
  ///
  /// The tree is colour-neutral and cached in [kaTeXRenderCache], so repeated
  /// calls with the same `(latex, displayMode)` are a hash lookup.
  ///
  /// Throws [KaTeXException] when the formula cannot be parsed.
  BoxNode parseBox(String latex, {bool displayMode = true}) {
    final cached = kaTeXRenderCache.get(latex, displayMode);
    if (cached != null) return cached;
    final BoxNode box;
    try {
      box = renderToBox(
        latex,
        options: KatexOptions(displayMode: displayMode, throwOnError: true),
      );
    } on ParseError catch (e) {
      throw KaTeXException(e.message);
    } on KaTeXException {
      rethrow;
    } on Object catch (e) {
      throw KaTeXException(e.toString());
    }
    kaTeXRenderCache.put(latex, displayMode, box);
    return box;
  }
}

/// The scale factor that fits a formula of width [naturalWidth] em into a
/// budget of [maxWidthEm] em.
///
/// Exposed for callers that need the same "shrink to fit" arithmetic the
/// widget applies, without going through [KaTeXEngine.parseAndLayout].
double fitScale({required double naturalWidth, required double maxWidthEm}) {
  if (!maxWidthEm.isFinite || maxWidthEm <= 0) return 1.0;
  if (!naturalWidth.isFinite || naturalWidth <= 0) return 1.0;
  return math.min(1.0, maxWidthEm / naturalWidth);
}

/// Initialises the KaTeX engine.
///
/// KaTeX here is **pure Dart** — there is no WASM module to download and no
/// native library to load — so this is a no-op that exists purely for API
/// symmetry with `ratex_flutter`'s `initRaTeX()`. Call it once in `main()`
/// before `runApp()` so a call site can be migrated between the two engines
/// unchanged:
///
/// ```dart
/// Future<void> main() async {
///   await initKaTeX();
///   runApp(const MyApp());
/// }
/// ```
Future<void> initKaTeX() async {}
