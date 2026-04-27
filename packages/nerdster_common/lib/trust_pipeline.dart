import 'package:oneofus_common/statement_source.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:oneofus_common/keys.dart';
import 'package:nerdster_common/trust_graph.dart';
import 'package:nerdster_common/trust_logic.dart';

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

  static int permissivePathRequirement(int distance) => 1;

  static int strictPathRequirement(int distance) {
    if (distance <= 1) return 1;
    if (distance <= 3) return 2;
    return 3;
  }

  Future<TrustGraph> build(IdentityKey povIdentity) async {
    TrustGraph graph = TrustGraph(pov: povIdentity);
    Set<IdentityKey> frontier = {povIdentity};
    Set<IdentityKey> visited = {};
    Map<IdentityKey, List<TrustStatement>> statementsByIssuer = {};

    for (int depth = 0; depth < maxDegrees; depth++) {
      if (frontier.isEmpty) break;

      final keysToFetch = frontier.difference(visited).toList();
      if (keysToFetch.isEmpty) break;

      final fetchMap = {for (var k in keysToFetch) k.value: graph.replacementConstraints[k]};

      final newStatementsMap = await source.fetch(fetchMap);
      visited.addAll(keysToFetch);

      for (var entry in newStatementsMap.entries) {
        statementsByIssuer[IdentityKey(entry.key)] = entry.value;
      }

      final pr = pathRequirement ?? defaultPathRequirement;
      graph = reduceTrustGraph(
        graph,
        statementsByIssuer,
        pathRequirement: pr,
        maxDegrees: maxDegrees,
      );

      frontier = graph.distances.keys.toSet().difference(visited);
    }

    return graph;
  }
}
