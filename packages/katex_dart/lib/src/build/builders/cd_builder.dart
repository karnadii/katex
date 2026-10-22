/// Builders for the `{CD}`-internal `cdlabel` / `cdlabelparent` nodes.
library;

import 'package:katex_dart/src/ast/parse_node.dart';
import 'package:katex_dart/src/box/box_node.dart';
import 'package:katex_dart/src/build/build_common.dart';
import 'package:katex_dart/src/build/build_expression.dart';
import 'package:katex_dart/src/build/options.dart';

/// Registers the CD builders into [registry].
void registerCdBuilders(Map<String, GroupBuilder> registry) {
  registry['cdlabel'] = (node, options) =>
      _buildCdLabel(node as CdLabelNode, options);
  registry['cdlabelparent'] = (node, options) =>
      _buildCdParent(node as CdParentNode, options);
}

BoxNode _buildCdLabel(CdLabelNode group, Options options) {
  // Labels beside vertical arrows are set in script style, like the
  // labels on extensible arrows. Mirrors KaTeX's cdlabel htmlBuilder
  // (`options.havingStyle(options.style.sup())`). Vertical placement
  // happens in [_buildCdParent], which knows the arrow's depth.
  final labelOptions = options.havingStyle(options.style.sup());
  return makeSpan(
    buildExpression([group.label], labelOptions, isRealGroup: true),
  );
}

BoxNode _buildCdParent(CdParentNode group, Options options) {
  // Lays a vertical arrow with its side labels: the arrow on the baseline,
  // each label shifted up beside it. KaTeX takes the labels out of flow
  // (absolute positioning, bottom edge at 0.8em above the arrow's bottom
  // edge, label metrics zeroed so the arrow sets the row metrics). The
  // box-tree equivalent puts the label's baseline at
  // `arrowDepth - 0.8em`: with the depthless `\Big` arrows CD uses this is
  // 0.8em above the baseline, and the small script-size labels stay inside
  // the arrow's vertical extent, so the arrow still sets the row metrics.
  final fragment = group.fragment;
  final parts = fragment is OrdGroupNode
      ? fragment.body
      : <ParseNode>[fragment];
  final built = <ParseNode, BoxNode>{
    for (final part in parts) part: buildGroup(part, options),
  };
  var arrowDepth = 0.0;
  for (final entry in built.entries) {
    if (entry.key is! CdLabelNode) arrowDepth = entry.value.depth;
  }
  final shift = arrowDepth - 0.8;
  final row = <BoxNode>[];
  for (final entry in built.entries) {
    final part = entry.key;
    final box = entry.value;
    if (part is CdLabelNode) {
      final label = part.label;
      if (label is OrdGroupNode && label.body.isEmpty) continue;
      row.add(
        makeVList(
          positionType: VListPositionType.individualShift,
          children: [VListChild.elem(box, shift: shift)],
        ),
      );
    } else {
      row.add(box);
    }
  }
  return makeSpan([makeFragment(row)], classes: const ['cd-vert-arrow']);
}
