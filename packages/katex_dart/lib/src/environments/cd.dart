/// The `{CD}` environment for commutative diagrams — a Dart port of KaTeX's
/// `src/environments/cd.ts`.
///
/// Cells are implicit (everything that is not an arrow collects into a
/// cell); `@>>>`, `@<<<`, `@AAA`, `@VVV` take two optional labels,
/// `@=` / `@|` / `@.` take none. Horizontal arrows desugar to the
/// `\cdrightarrow` / `\cdleftarrow` / `\cdlongequal` extensible arrows,
/// vertical arrows to a `\Big`-sized `\uparrow` / `\downarrow` / `\Vert`
/// flanked by `\cdleft` / `\cdright` labels inside `\cdparent`.
library;

import 'package:katex_dart/src/ast/parse_node.dart';
import 'package:katex_dart/src/environments/environment_spec.dart';
import 'package:katex_dart/src/parse/parse_error.dart';
import 'package:katex_dart/src/parse/parser.dart';
import 'package:katex_dart/src/symbols/symbols.dart';

/// Registers the `{CD}` environment.
void registerCdEnvironment() {
  defineEnvironment(
    <String>['CD'],
    EnvSpec(
      type: 'array',
      numArgs: 0,
      handler: (context, args, optArgs) => parseCD(context.parser),
    ),
  );
}

const Map<String, String> _cdArrowFunctionName = <String, String>{
  '>': r'\\cdrightarrow',
  '<': r'\\cdleftarrow',
  '=': r'\\cdlongequal',
  'A': r'\uparrow',
  'V': r'\downarrow',
  '|': r'\Vert',
  '.': 'no arrow',
};

StylingNode _newCell(Mode mode) {
  // An empty cell, shaped like the ones `parseArray` produces: CD is
  // always displaystyle.
  return StylingNode(mode: mode, style: StyleStr.display, body: [], resetFont: true);
}

bool _isStartOfArrow(ParseNode node) =>
    node is TextOrdNode && node.text == '@';

bool _isLabelEnd(ParseNode node, String endChar) {
  final text = node is SymbolParseNode ? node.text : null;
  return (node is MathOrdNode || node is AtomNode) && text == endChar;
}

SymbolParseNode _assertSymbolNode(ParseNode node) {
  if (node is! SymbolParseNode) {
    throw ParseError('Expected node of symbol group type, got ${node.type}');
  }
  return node;
}

/// Returns the parse tree of an arrow with its labels, acting like a macro
/// expansion (mirrors KaTeX's `cdArrow`).
ParseNode _cdArrow(
  String arrowChar,
  List<OrdGroupNode> labels,
  Parser parser,
) {
  final funcName = _cdArrowFunctionName[arrowChar];
  switch (funcName) {
    case r'\\cdrightarrow':
    case r'\\cdleftarrow':
      return parser.callFunction(funcName!, [labels[0]], [labels[1]]);
    case r'\uparrow':
    case r'\downarrow':
      final leftLabel = parser.callFunction(
        r'\\cdleft',
        [labels[0]],
        <ParseNode?>[],
      );
      final bareArrow = AtomNode(
        mode: parser.mode,
        text: funcName!,
        family: Group.rel,
      );
      final sizedArrow = parser.callFunction(
        r'\Big',
        [bareArrow],
        <ParseNode?>[],
      );
      final rightLabel = parser.callFunction(
        r'\\cdright',
        [labels[1]],
        <ParseNode?>[],
      );
      final arrowGroup = OrdGroupNode(
        mode: parser.mode,
        body: [leftLabel, sizedArrow, rightLabel],
      );
      return parser.callFunction(
        r'\\cdparent',
        [arrowGroup],
        <ParseNode?>[],
      );
    case r'\\cdlongequal':
      return parser.callFunction(
        r'\\cdlongequal',
        [OrdGroupNode(mode: parser.mode, body: [])],
        <ParseNode?>[null],
      );
    case r'\Vert':
      final arrow = TextOrdNode(mode: parser.mode, text: r'\Vert');
      return parser.callFunction(r'\Big', [arrow], <ParseNode?>[]);
    default:
      return TextOrdNode(mode: parser.mode, text: ' ');
  }
}

/// Parses a `{CD}` environment into an [ArrayNode]. Mirrors KaTeX's
/// `parseCD`.
ArrayNode parseCD(Parser parser) {
  // Get the array's parse nodes with `\\` temporarily mapped to `\cr`.
  final parsedRows = <List<ParseNode>>[];
  parser.gullet.beginGroup();
  parser.gullet.macros.set(r'\cr', r'\\\relax');
  parser.gullet.beginGroup();
  while (true) {
    // Get the parse nodes for the next row.
    parsedRows.add(
      parser.parseExpression(breakOnInfix: false, breakOnTokenText: r'\\'),
    );
    parser.gullet.endGroup();
    parser.gullet.beginGroup();
    final next = parser.fetch().text;
    if (next == '&' || next == r'\\') {
      parser.consume();
    } else if (next == r'\end') {
      if (parsedRows[parsedRows.length - 1].isEmpty) {
        parsedRows.removeLast(); // final row ended in `\\`
      }
      break;
    } else {
      throw ParseError(
        r'Expected \\ or \cr or \end',
        parser.fetch(),
      );
    }
  }

  var row = <StylingNode>[];
  final body = <List<StylingNode>>[row];

  // Loop through the parse nodes. Collect them into cells and arrows.
  for (var i = 0; i < parsedRows.length; i++) {
    // Start a new row.
    final rowNodes = parsedRows[i];
    // Create the first cell.
    var cell = _newCell(parser.mode);

    for (var j = 0; j < rowNodes.length; j++) {
      if (!_isStartOfArrow(rowNodes[j])) {
        // If a parse node is not an arrow, it goes into a cell.
        cell.body.add(rowNodes[j]);
      } else {
        // Parse node j is an `@`, the start of an arrow.
        // Before starting on the arrow, push the cell into `row`.
        row.add(cell);

        // Now collect parse nodes into an arrow.
        // The character after `@` defines the arrow type.
        j += 1;
        final arrowChar = _assertSymbolNode(rowNodes[j]).text;

        // Create two empty label nodes. We may or may not use them.
        final labels = <OrdGroupNode>[
          OrdGroupNode(mode: parser.mode, body: []),
          OrdGroupNode(mode: parser.mode, body: []),
        ];

        // Process the arrow.
        if ('=|.'.contains(arrowChar)) {
          // Three "arrows", `@=`, `@|`, and `@.`, do not take labels.
          // Do nothing here.
        } else if ('<>AV'.contains(arrowChar)) {
          // Four arrows, `@>>>`, `@<<<`, `@AAA`, and `@VVV`, each take
          // two optional labels. E.g. the right-point arrow syntax is
          // really: `@>{optional label}>{optional label}>`.
          // Collect parse nodes into labels.
          for (var labelNum = 0; labelNum < 2; labelNum++) {
            var inLabel = true;
            for (var k = j + 1; k < rowNodes.length; k++) {
              if (_isLabelEnd(rowNodes[k], arrowChar)) {
                inLabel = false;
                j = k;
                break;
              }
              if (_isStartOfArrow(rowNodes[k])) {
                throw ParseError(
                  'Missing a $arrowChar character to complete a CD arrow.',
                );
              }
              labels[labelNum].body.add(rowNodes[k]);
            }
            if (inLabel) {
              // _isLabelEnd never returned true.
              throw ParseError(
                'Missing a $arrowChar character to complete a CD arrow.',
              );
            }
          }
        } else {
          throw ParseError('Expected one of "<>AV=|." after @');
        }

        // Now join the arrow to its labels.
        final arrow = _cdArrow(arrowChar, labels, parser);

        // Wrap the arrow in a styling node, to match `parseArray` behavior.
        // CD is always displaystyle.
        row.add(
          StylingNode(
            mode: parser.mode,
            style: StyleStr.display,
            body: [arrow],
            resetFont: true,
          ),
        );
        // In CD's syntax, cells are implicit. That is, everything that
        // is not an arrow gets collected into a cell. So create an empty
        // cell now. It will collect upcoming parse nodes.
        cell = _newCell(parser.mode);
      }
    }
    if (i % 2 == 0) {
      // Even-numbered rows consist of: cell, arrow, cell, arrow, ... cell.
      // The last cell is not yet pushed into `row`, so:
      row.add(cell);
    } else {
      // Odd-numbered rows consist of: vert arrow, empty cell, ...
      // vert arrow. Remove the empty cell placed at the beginning of `row`.
      row.removeAt(0);
    }
    row = <StylingNode>[];
    body.add(row);
  }

  // End row group.
  parser.gullet.endGroup();
  // End array group defining `\\`.
  parser.gullet.endGroup();

  // Column separation: the CD package sets `\enskip` between columns, so
  // pre and post each get half an `\enskip`, i.e. 0.25em.
  final cols = List<AlignSpec>.filled(
    body[0].length,
    const AlignSpec.align('c', pregap: 0.25, postgap: 0.25),
  );

  return ArrayNode(
    mode: Mode.math,
    body: body,
    arraystretch: 1,
    addJot: true,
    rowGaps: const [null],
    cols: cols,
    colSeparationType: ColSeparationType.cd,
    hLinesBeforeRow: List<List<bool>>.generate(
      body.length + 1,
      (_) => <bool>[],
    ),
  );
}
