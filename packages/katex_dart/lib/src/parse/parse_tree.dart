/// Top-level parse entry point — a Dart port of KaTeX's `parseTree.ts`.
library;

import 'package:katex_dart/src/ast/parse_node.dart';
import 'package:katex_dart/src/parse/parse_error.dart';
import 'package:katex_dart/src/parse/parser.dart';
import 'package:katex_dart/src/parse/settings.dart';
import 'package:katex_dart/src/parse/token.dart';
import 'package:katex_dart/src/types.dart';

/// Parses [tex] with [settings] and returns the parse-node AST.
///
/// Faithful port of KaTeX's `parseTree`, including the `\tag`/`\df@tag`
/// wrapping path: a top-level `\tag{…}` wraps the whole formula in a
/// [TagNode], and tags outside display equations are a parse error. The
/// cleanup of color/tag macros is preserved so repeated calls don't leak
/// state.
List<ParseNode> parseTree(String tex, Settings settings) {
  final parser = Parser(tex, settings);

  // Blank out any \df@tag to avoid spurious "Duplicate \tag" errors.
  parser.gullet.macros.current.remove(r'\df@tag');

  final tree = parser.parse();

  // Prevent a color definition from persisting between calls.
  parser.gullet.macros.current
    ..remove(r'\current@color')
    ..remove(r'\color');

  // If the input used \tag, it set the \df@tag macro to the tag.
  // In this case, separately parse the tag and wrap the tree.
  if (parser.gullet.macros.get(r'\df@tag') != null) {
    if (!settings.displayMode) {
      throw ParseError(r'\tag works only in display equations');
    }
    return [
      TagNode(
        mode: Mode.text,
        body: tree,
        tag: parser.subparse([Token(r'\df@tag')]),
      ),
    ];
  }

  return tree;
}
