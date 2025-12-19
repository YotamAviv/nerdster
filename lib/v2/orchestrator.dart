import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/v2/io.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/trust_logic.dart';

/// The Orchestrator manages the loop between Fetching (IO) and Reducing (Logic).
class TrustPipeline {
  final StatementSource source;
  final int maxDegrees;

  TrustPipeline(this.source, {this.maxDegrees = 6});

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
      // (Though the Source might cache internally, we optimize here too).
      final keysToFetch = frontier.difference(visited).toList();
      if (keysToFetch.isEmpty) break;

      // Map keys to null revokeAt for now (Orchestrator doesn't know revokeAt yet, logic does)
      // Actually, the logic might tell us revokeAt constraints for the frontier.
      // But for now, let's just fetch everything.
      // TODO: Use graph.revokeAtConstraints to filter fetch
      final fetchMap = {for (var k in keysToFetch) k: graph.revokeAtConstraints[k]};

      final newStatementsMap = await source.fetch(fetchMap);
      visited.addAll(keysToFetch);
      
      for (var list in newStatementsMap.values) {
        allStatements.addAll(list.whereType<TrustStatement>());
      }

      // 2. REDUCE (Pure Logic)
      // We re-run the reducer on the accumulated history.
      // Optimization: In a real app, we might make the reducer incremental,
      // but for correctness, re-reducing is safest.
      // We run it twice to ensure backward constraints (like 'replace' with 'revokeAt')
      // are propagated to the nodes they affect.
      graph = reduceTrustGraph(graph, allStatements);
      graph = reduceTrustGraph(graph, allStatements);

      // 3. CALCULATE NEXT FRONTIER
      // The reducer tells us who is trusted. We need to find who is trusted
      // but hasn't been fetched yet.
      // Note: 'graph.distances' contains all trusted nodes.
      frontier = graph.distances.keys.toSet().difference(visited);
    }

    return graph;
  }
}
