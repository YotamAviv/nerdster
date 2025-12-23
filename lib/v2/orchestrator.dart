import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/v2/io.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/trust_logic.dart';

/// The Orchestrator manages the loop between Fetching (IO) and Reducing (Logic).
class TrustPipeline {
  final StatementSource source;
  final int maxDegrees;
  final PathRequirement? pathRequirement;

  TrustPipeline(this.source, {
    this.maxDegrees = 6,
    this.pathRequirement,
  });

  static int defaultPathRequirement(int distance) {
    if (distance <= 2) return 1;
    if (distance <= 4) return 2;
    return 3;
  }

  /// Builds the trust graph starting from [rootToken].
  Future<TrustGraph> build(String rootToken) async {
    // Initial State
    TrustGraph graph = TrustGraph(root: rootToken);
    Set<String> frontier = {rootToken};
    Set<String> visited = {};
    List<TrustStatement> allStatements = [];

    // The Loop
    for (int depth = 0; depth < maxDegrees; depth++) {
      if (frontier.isEmpty) break;

      // 1. FETCH (Side Effect)
      // We only fetch keys we haven't visited yet to avoid redundant network calls.
      final keysToFetch = frontier.difference(visited).toList();
      if (keysToFetch.isEmpty) break;

      // Map keys to their revokeAt constraints if known.
      final fetchMap = {for (var k in keysToFetch) k: graph.revokeAtConstraints[k]};

      final newStatementsMap = await source.fetch(fetchMap);
      visited.addAll(keysToFetch);
      
      for (var list in newStatementsMap.values) {
        allStatements.addAll(list.whereType<TrustStatement>());
      }

      // 2. REDUCE (Pure Logic)
      // We re-run the reducer on the accumulated history.
      // We run it twice to ensure backward constraints (like 'replace' with 'revokeAt')
      // are propagated to the nodes they affect.
      final pr = pathRequirement ?? defaultPathRequirement;
      graph = reduceTrustGraph(graph, allStatements, pathRequirement: pr);
      graph = reduceTrustGraph(graph, allStatements, pathRequirement: pr);

      // 3. CALCULATE NEXT FRONTIER
      // The reducer tells us who is trusted. We need to find who is trusted
      // but hasn't been fetched yet.
      frontier = graph.distances.keys.toSet().difference(visited);
    }

    return graph;
  }
}
