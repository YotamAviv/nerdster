import 'statement.dart';
import 'util.dart';

/// Caching...
/// History:
/// - I used to cache here, which I suspected, but which seemed to work. Back then, 
///   Fetcher.statements used to return an Iterable that made (Statement.make(..)) the statements 
///   from a cached List<Jsonish>, and so each was distinct.
/// - When Fetcher.statements was changed to directly return its cached List<Statements> things 
///   broke.
/// 
/// There are costs to computing (instead of caching), but there are also costs in maintaining
/// correct caching (complexity, bugs, time, listener pointers..)
/// RAN I feel that clearing the entire cache liberally is the best way forward:
/// - correct
/// - simple
/// - balance: the cache would still exist and should help when, say, traversing trusts and 
///   blocks over and over (although some blocks that affect revokedAt should clear the cache).
/// 
/// The cache should be cleared
/// - Fetcher.setRevokeAt(..)
/// - push(..)
/// 
/// Future: (unlikely complex and correct caching)
/// I believe that the only instances of calling distinct with a dynamically computed 
/// Iterable<Statement> (instead of a Fetcher.statements List<Statement>) are:
/// - filtered for something, and this could be reversed (distinct first, then filter)
/// - merge Fetchers, and this could be combined with this here and observe each Fetcher to avoid 
///   clearing all caches.

Map<(Iterable<Statement>, Transformer?), List<Statement>> _cache =
    <(Iterable<Statement>, Transformer?), List<Statement>>{};

void clearDistinct() {
  _cache.clear();
}

List<Statement> distinct(Iterable<Statement> source, {Transformer? transformer}) {
  List<Statement>? distinct = _cache[(source, transformer)];
  if (b(distinct)) return distinct!;

  final Set<String> already = <String>{};
  distinct = <Statement>[];
  for (Statement s in source) {
    String key = s.getDistinctSignature(transformer: transformer);
    if (!already.contains(key)) {
      already.add(key);
      if (!s.isClear) distinct.add(s);
    }
  }
  _cache[(source, transformer)] = distinct;
  return distinct;
}
