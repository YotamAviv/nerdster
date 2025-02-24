import 'statement.dart';
import 'util.dart';

/// Caching...
/// There are costs to computing (instead of caching), but there are also costs in maintaining
/// correct caching (complexity, bugs, time, listener pointers..)
/// 
/// Compounding the complexity:
/// - dynamically computed Iterable<Statement> instances (filtered, transformed, mereged, or worse ..)
///
/// RAN I feel that clearing the entire cache liberally is the best way forward:
/// - correct
/// - simple
/// - balance: the cache would still exist and should help
/// 
/// Known callers:
/// - Fetcher.setRevokeAt(..)
/// - push(..)

Map<(Iterable<Statement>, Transformer?), List<Statement>> _cache =
    <(Iterable<Statement>, Transformer?), List<Statement>>{};

void clearDistincterCache() {
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
