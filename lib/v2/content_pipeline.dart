import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/v2/io.dart';
import 'package:nerdster/v2/model.dart';

class ContentPipeline {
  final StatementSource<ContentStatement> source;

  ContentPipeline(this.source);

  /// Fetches and filters content based on the TrustGraph.
  Future<List<ContentStatement>> fetchContent(TrustGraph graph) async {
    // 1. Identify Trusted Users
    // We only care about users who are trusted (distance < maxDegrees, which is implicit in the graph)
    // and NOT blocked.
    // ORDERING: Must be ordered by Trust Distance (ascending).
    final List<String> trustedUsers = graph.distances.keys
        .where((token) => !graph.blocked.contains(token))
        .toList();
    
    trustedUsers.sort((a, b) {
      final int distA = graph.distances[a]!;
      final int distB = graph.distances[b]!;
      if (distA != distB) return distA.compareTo(distB);
      return a.compareTo(b); // Stable tie-break
    });

    // 2. Fetch Content
    // Use revokeAt constraints from the graph to ensure we get content from the valid identity era.
    final fetchMap = {
      for (var token in trustedUsers) 
        token: graph.revokeAtConstraints[token]
    };

    final Map<String, List<ContentStatement>> rawMap = await source.fetch(fetchMap);
    
    final List<ContentStatement> rawContent = [];
    for (var list in rawMap.values) {
      rawContent.addAll(list);
    }

    // 3. Verify Content
    // The source should only return content for the requested keys.
    // We assert this strictly.
    
    for (final stmt in rawContent) {
      if (!graph.isTrusted(stmt.iToken)) {
         throw 'Pipeline Error: Source returned content from untrusted issuer: ${stmt.iToken}';
      }
      if (graph.blocked.contains(stmt.iToken)) {
         throw 'Pipeline Error: Source returned content from blocked issuer: ${stmt.iToken}';
      }
    }

    // 4. Sort by Time (Newest first)
    // Since we merge content from multiple users, we must sort the result.
    rawContent.sort((a, b) => b.time.compareTo(a.time));

    return rawContent;
  }
}
