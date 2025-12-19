import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/v2/io.dart';

/// A caching decorator for [StatementSource] and [ContentSource].
/// Stores fetched atoms in memory to avoid redundant network calls.
class CachedSource implements StatementSource, ContentSource {
  final StatementSource? _trustDelegate;
  final ContentSource? _contentDelegate;
  
  final Map<String, List<TrustStatement>> _trustCache = {};
  final Map<String, List<ContentStatement>> _contentCache = {};

  CachedSource({
    StatementSource? trustDelegate,
    ContentSource? contentDelegate,
  })  : _trustDelegate = trustDelegate,
        _contentDelegate = contentDelegate;

  void clear() {
    _trustCache.clear();
    _contentCache.clear();
  }

  @override
  Future<List<TrustStatement>> fetch(List<String> keys) async {
    final List<TrustStatement> results = [];
    final List<String> missing = [];

    for (var key in keys) {
      if (_trustCache.containsKey(key)) {
        results.addAll(_trustCache[key]!);
      } else {
        missing.add(key);
      }
    }

    if (missing.isNotEmpty && _trustDelegate != null) {
      final fetched = await _trustDelegate.fetch(missing);
      
      // Group by issuer to populate cache
      final byIssuer = <String, List<TrustStatement>>{};
      for (var stmt in fetched) {
        byIssuer.putIfAbsent(stmt.iToken, () => []).add(stmt);
      }

      // Update cache for all requested keys (even if they had no statements)
      for (var key in missing) {
        final stmts = byIssuer[key] ?? [];
        _trustCache[key] = stmts;
        results.addAll(stmts);
      }
    }

    return results;
  }

  @override
  Future<List<ContentStatement>> fetchContent(List<String> keys) async {
    final List<ContentStatement> results = [];
    final List<String> missing = [];

    for (var key in keys) {
      if (_contentCache.containsKey(key)) {
        results.addAll(_contentCache[key]!);
      } else {
        missing.add(key);
      }
    }

    if (missing.isNotEmpty && _contentDelegate != null) {
      final fetched = await _contentDelegate.fetchContent(missing);
      
      // Group by issuer
      final byIssuer = <String, List<ContentStatement>>{};
      for (var stmt in fetched) {
        byIssuer.putIfAbsent(stmt.iToken, () => []).add(stmt);
      }

      // Update cache
      for (var key in missing) {
        final stmts = byIssuer[key] ?? [];
        _contentCache[key] = stmts;
        results.addAll(stmts);
      }
    }

    return results;
  }
}
