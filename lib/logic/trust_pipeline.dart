import 'package:oneofus_common/trust_statement.dart';
import 'package:oneofus_common/io.dart';
import 'package:nerdster/models/model.dart';
import 'package:nerdster/logic/trust_logic.dart';
import 'package:oneofus_common/keys.dart';

/// The Orchestrator manages the loop between Fetching (IO) and Reducing (Logic).
class TrustPipeline {
  final StatementSource<TrustStatement> source;
  final int maxDegrees;
  final PathRequirement? pathRequirement;

  TrustPipeline(
    this.source, {
    this.maxDegrees = 6,
    this.pathRequirement,
  });

  static int defaultPathRequirement(int distance) {
    if (distance <= 2) return 1;
    if (distance <= 4) return 2;
    return 3;
  }

  static int permissivePathRequirement(int distance) {
    return 1;
  }

  /// Builds the trust graph starting from [povIdentity].
  Future<TrustGraph> build(IdentityKey povIdentity) async {
    // Initial State
    final povKey = povIdentity;
    TrustGraph graph = TrustGraph(pov: povKey);
    Set<IdentityKey> frontier = {povKey};
    Set<IdentityKey> visited = {};
    Map<IdentityKey, List<TrustStatement>> statementsByIssuer = {};

    // The Loop
    for (int depth = 0; depth < maxDegrees; depth++) {
      if (frontier.isEmpty) break;

      // 1. FETCH (Side Effect)
      // We only fetch keys we haven't visited yet to avoid redundant network calls.
      final keysToFetch = frontier.difference(visited).toList();
      if (keysToFetch.isEmpty) break;

      // Map keys to their replacement constraints if known.
      final fetchMap = {for (var k in keysToFetch) k.value: graph.replacementConstraints[k]};

      final newStatementsMap = await source.fetch(fetchMap);
      visited.addAll(keysToFetch);

      // Convert String keys to IdentityKey
      for (var entry in newStatementsMap.entries) {
        statementsByIssuer[IdentityKey(entry.key)] = entry.value;
      }

      // Collect notifications from source (e.g. corruption)
      // Note: Source errors are now handled by the FeedController/Model directly,
      // but if we wanted to include them in the graph, we could.
      // For now, we just let the reducer run.
      // The FeedController will merge source.errors into the model.sourceErrors.

      // 2. REDUCE (Pure Logic)
      // We re-run the reducer on the accumulated history.
      // The reducer is "Strictly Greedy": it processes the graph layer-by-layer.
      // Within each layer, it processes Blocks and Replaces before Trusts.
      // This ensures that same-distance replacements are handled, but "deep"
      // nodes cannot constrain "shallow" nodes.
      final pr = pathRequirement ?? defaultPathRequirement;
      graph = reduceTrustGraph(
        graph,
        statementsByIssuer,
        pathRequirement: pr,
        maxDegrees: maxDegrees,
      );

      // 3. CALCULATE NEXT FRONTIER
      // The reducer tells us who is trusted. We need to find who is trusted
      // but hasn't been fetched yet.
      frontier = graph.distances.keys.toSet().difference(visited);
    }

    return graph;
  }
}
