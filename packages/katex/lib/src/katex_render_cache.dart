/// A process-scoped LRU cache of parsed KaTeX box trees.
///
/// Keyed on `(latex, displayMode)` — the two inputs that fully determine the
/// resulting tree. **Colour is intentionally excluded**: the tree is
/// colour-neutral and the colour is applied at paint time, so recolouring a
/// formula never invalidates the cache. The same reasoning RaTeX uses for its
/// own render cache.
///
/// The cache is a pure-Dart map, so a hit is a hash lookup — orders of
/// magnitude cheaper than re-running the lexer/parser. That matters for a
/// note-taking app where the same formula is repainted on every rebuild.
///
/// Best-effort: a miss simply falls through to the parser.
library;

import 'package:katex_dart/katex_dart.dart';

/// A cache of parsed KaTeX box trees, keyed on `(latex, displayMode)`.
class KaTeXRenderCache {
  /// Creates a cache holding at most [maxSize] entries.
  KaTeXRenderCache({int maxSize = 64}) : _maxSize = maxSize;

  final int _maxSize;
  final _cache = <String, BoxNode>{};

  String _key(String latex, bool displayMode) => '$latex\x00$displayMode';

  /// Returns the cached box tree for `(latex, displayMode)`, or `null` on a
  /// miss. A hit refreshes the entry's recency.
  BoxNode? get(String latex, bool displayMode) {
    final key = _key(latex, displayMode);
    final box = _cache.remove(key);
    if (box == null) return null;
    _cache[key] = box; // move to end (most-recently-used)
    return box;
  }

  /// Stores [box] for `(latex, displayMode)`, evicting the least-recently-used
  /// entry when the cache is full.
  void put(String latex, bool displayMode, BoxNode box) {
    final key = _key(latex, displayMode);
    _cache.remove(key); // remove old entry if present
    _cache[key] = box;
    if (_cache.length > _maxSize) {
      _cache.remove(_cache.keys.first); // evict least-recently-used
    }
  }

  /// Drops every cached entry.
  void clear() => _cache.clear();

  /// The number of entries currently held.
  int get length => _cache.length;
}

/// The process-wide render cache shared by all `KaTeXWidget` instances.
///
/// ponytail: a global singleton is the simplest process-scoped cache. If
/// isolates ever need their own cache, pass it via the isolate args.
final kaTeXRenderCache = KaTeXRenderCache();
