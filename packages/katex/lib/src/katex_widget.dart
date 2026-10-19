/// The public `KaTeXWidget` — the user-facing entry point for rendering LaTeX
/// math with KaTeX in Flutter.
///
/// This widget is the **drop-in twin** of `ratex_flutter`'s `RaTeXWidget`:
/// same constructor parameter names, same defaults, same error contract, same
/// semantics. Code that renders a formula with RaTeX can swap the widget name
/// and the import and keep working:
///
/// ```dart
/// // RaTeX
/// RaTeXWidget(latex: r'\frac{a}{b}', fontSize: 20, color: Colors.black)
///
/// // KaTeX
/// KaTeXWidget(latex: r'\frac{a}{b}', fontSize: 20, color: Colors.black)
/// ```
///
/// The two differences worth knowing about:
///
///  * **Where the work happens.** RaTeX is native (FFI) and renders through
///    an isolate hop; KaTeX here is pure Dart and renders on the calling
///    isolate. A KaTeX formula therefore appears in its first frame, with no
///    loading placeholder.
///  * **What `maxWidth` does.** RaTeX *wraps* a too-wide formula onto
///    multiple lines. KaTeX (like KaTeX.js) has no automatic line breaking,
///    so a too-wide formula is *scaled down* to fit instead.
library;

import 'package:flutter/widgets.dart';
import 'package:katex_dart/katex_dart.dart';

import 'katex_engine.dart';
import 'katex_exception.dart';
import 'render/box_painter.dart';

/// A widget that renders a LaTeX math [latex] string with KaTeX.
///
/// Example:
/// ```dart
/// KaTeXWidget(latex: r'\sum_{i=0}^{n} i', displayMode: true, fontSize: 28)
/// ```
class KaTeXWidget extends StatefulWidget {
  /// Creates a widget that renders [latex].
  const KaTeXWidget({
    super.key,
    required this.latex,
    this.fontSize = 24,
    this.displayMode = true,
    this.color,
    this.maxWidth,
    this.haloColor,
    this.haloWidth = 3.0,
    this.onError,
  });

  /// The LaTeX math source to render (e.g. `r'\frac{a}{b}'`).
  final String latex;

  /// Base size in **logical pixels per em**.
  final double fontSize;

  /// Whether to typeset as display math (`true`) or inline math (`false`),
  /// mirroring KaTeX's `displayMode` and RaTeX's `displayMode`.
  final bool displayMode;

  /// The base text colour. When `null`, the ambient [DefaultTextStyle] colour
  /// is used (falling back to opaque black). Colours set *inside* the
  /// expression (e.g. `\textcolor`) still override this for their sub-tree.
  final Color? color;

  /// Available width in logical pixels. A formula wider than this is scaled
  /// down to fit.
  final double? maxWidth;

  /// Optional contrasting colour drawn as a glyph-level stroke behind every
  /// item in the formula. Pass the plot's background colour so the label
  /// stays readable when it crosses a curve, grid line, or axis. Set `null`
  /// (default) to skip the halo pass.
  final Color? haloColor;

  /// Halo stroke width in logical pixels. Ignored when [haloColor] is `null`.
  /// Defaults to `3.0` (matches RaTeX and the plotter's `paintTextWithHalo`).
  final double haloWidth;

  /// Called when the formula cannot be parsed. The widget then falls back to
  /// a red error label rather than throwing.
  final void Function(KaTeXException)? onError;

  @override
  State<KaTeXWidget> createState() => _KaTeXWidgetState();
}

class _KaTeXWidgetState extends State<KaTeXWidget> {
  BoxNode? _box;
  KaTeXException? _error;

  @override
  void initState() {
    super.initState();
    _parse();
  }

  @override
  void didUpdateWidget(KaTeXWidget old) {
    super.didUpdateWidget(old);
    if (old.latex != widget.latex || old.displayMode != widget.displayMode) {
      _parse();
    }
  }

  void _parse() {
    try {
      final box = KaTeXEngine.instance.parseBox(
        widget.latex,
        displayMode: widget.displayMode,
      );
      _box = box;
      _error = null;
    } on KaTeXException catch (e) {
      _box = null;
      _error = e;
      widget.onError?.call(e);
    } catch (e) {
      // Non-KaTeXException failures (StateError, ArgumentError, …) must not
      // escape `build`; coerce them so `onError` and the fallback see a
      // uniform type.
      final wrapped = coerceRenderError(e);
      _box = null;
      _error = wrapped;
      widget.onError?.call(wrapped);
    }
  }

  Color get _inheritedColor => DefaultTextStyle.of(context).style.color ?? const Color(0xFF000000);

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return Text(
        'KaTeX error: ${error.message}',
        style: const TextStyle(color: Color(0xFFCC0000), fontSize: 12),
      );
    }
    final box = _box;
    if (box == null) {
      return const SizedBox.shrink();
    }

    final resolvedColor = widget.color ?? _inheritedColor;
    final painter = KatexBoxPainter(
      box,
      fontSize: widget.fontSize,
      color: resolvedColor,
      inkPadEm: kInkOverflowPadEm,
      haloColor: widget.haloColor,
      haloWidth: widget.haloWidth,
    );

    // The padded extent is what the canvas must be: glyph/SVG ink can
    // overflow the metric box, and clipping it looks like a bug.
    final pad = kInkOverflowPadEm * widget.fontSize;
    final naturalWidth = box.width * widget.fontSize + 2 * pad;
    final naturalHeight = (box.height + box.depth) * widget.fontSize + 2 * pad;

    final maxWidth = widget.maxWidth;
    final scale = (maxWidth != null && maxWidth.isFinite && maxWidth > 0 && naturalWidth > 0)
        ? (maxWidth / naturalWidth).clamp(0.0, 1.0)
        : 1.0;

    final canvas = CustomPaint(
      size: Size(naturalWidth, naturalHeight),
      painter: painter,
    );

    if (scale >= 1.0) {
      return Semantics(
        label: widget.latex,
        child: SizedBox(
          width: naturalWidth,
          height: naturalHeight,
          child: canvas,
        ),
      );
    }

    // Shrink to fit. The child keeps its natural size and is scaled at paint
    // time; `Align` (not `Transform` alone) keeps the overflow out of the
    // parent's layout, which is what stops a `Column` from reporting it.
    return Semantics(
      label: widget.latex,
      child: SizedBox(
        width: maxWidth,
        height: naturalHeight * scale,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Transform.scale(
            alignment: Alignment.centerLeft,
            scale: scale,
            child: SizedBox(
              width: naturalWidth,
              height: naturalHeight,
              child: canvas,
            ),
          ),
        ),
      ),
    );
  }
}
