/// A Flutter widget that renders LaTeX math by painting the box tree produced
/// by the pure-Dart `katex_dart` package.
///
/// Two API surfaces live here:
///
///  * The original widget surface — [Math], [mathSpan], [AnimatedMath] — built
///    on the `katex_dart` box tree and the [KatexBoxPainter].
///  * The **RaTeX-compatible surface** — [KaTeXWidget], [KaTeXEngine],
///    [KaTeXException], [KaTeXDisplayList], [KaTeXRenderCache] — a drop-in
///    twin of `ratex_flutter`'s API, so the two engines can be swapped in an
///    app (or measured against each other) without touching call sites.
///
/// See `PLAN.md` and `tickets/BOARD.md` at the repo root for status.
library;

export 'src/animated_math_widget.dart';
export 'src/font_mapping.dart';
export 'src/katex_display_list.dart';
export 'src/katex_engine.dart';
export 'src/katex_exception.dart';
export 'src/katex_render_cache.dart';
export 'src/katex_widget.dart';
export 'src/math_span.dart' show mathSpan;
export 'src/math_widget.dart';
export 'src/render/box_painter.dart';
