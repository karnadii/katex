/// The laid-out result of a KaTeX formula.
///
/// This is the analogue of `ratex_flutter`'s `DisplayList` and exists for the
/// same reason: both engines expose "parse + layout" as one call that returns
/// a self-describing, immutable artifact the widget layer can paint without
/// re-running the parser.
///
/// The two artifacts differ in *shape* but agree in *meaning*:
///
/// * RaTeX returns a flat list of draw commands (`DisplayList.items`).
/// * KaTeX returns the backend-agnostic **box tree** ([KaTeXDisplayList.box])
///   — the tree the Flutter painter and the SVG serializer both consume.
///
/// Both expose the same three dimensions, in **em** units, measured relative
/// to the formula's baseline:
///
/// * [width]  — horizontal advance.
/// * [height] — distance from the baseline up to the top of the formula.
/// * [depth]  — distance from the baseline down to the bottom.
///
/// Because KaTeX's tree is colour-neutral, the base [color] travels
/// alongside it and is applied at paint time. That keeps a colour change free
/// (no re-parse), which is the same trade-off RaTeX makes for the same reason.
library;

import 'package:flutter/painting.dart';
import 'package:katex_dart/katex_dart.dart';

/// The laid-out box tree of a KaTeX formula plus the base colour to paint it
/// with.
class KaTeXDisplayList {
  /// Creates a display list from a laid-out [box] and a base [color].
  const KaTeXDisplayList({
    required this.box,
    this.color = const Color(0xFF000000),
    this.scale = 1.0,
  });

  /// The root of the laid-out box tree.
  ///
  /// The tree is immutable, so a display list can be cached and shared across
  /// widgets and frames.
  final BoxNode box;

  /// The base colour to paint the formula with.
  ///
  /// Colours set *inside* the expression (e.g. `\textcolor{red}{x}`) still
  /// override this for their own sub-tree.
  final Color color;

  /// The uniform scale factor to paint the formula at.
  ///
  /// `1.0` means "natural size". A value below `1.0` means the formula was
  /// too wide for the requested width and was scaled down to fit — the same
  /// "shrink to fit" behaviour `RaTeXWidget` applies for its `maxWidth`.
  final double scale;

  /// The natural horizontal advance of the formula, in em.
  double get width => box.width;

  /// The distance from the baseline to the top of the formula, in em.
  double get height => box.height;

  /// The distance from the baseline to the bottom of the formula, in em.
  double get depth => box.depth;

  /// The total vertical extent of the formula (above + below the baseline),
  /// in em.
  double get totalHeight => box.height + box.depth;

  /// The horizontal advance after [scale] is applied, in em.
  double get scaledWidth => width * scale;

  /// The vertical extent after [scale] is applied, in em.
  double get scaledTotalHeight => totalHeight * scale;

  @override
  String toString() =>
      'KaTeXDisplayList(w: ${width.toStringAsFixed(4)}, '
      'h: ${height.toStringAsFixed(4)}, d: ${depth.toStringAsFixed(4)}, '
      'scale: $scale)';
}
