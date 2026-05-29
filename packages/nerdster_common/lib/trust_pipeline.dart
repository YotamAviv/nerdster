import 'package:oneofus_common/channel_factory.dart';
import 'package:oneofus_common/statement_source.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:oneofus_common/keys.dart';
import 'package:nerdster_common/trust_graph.dart';
import 'package:nerdster_common/trust_logic.dart';

class TrustPipeline {
  final StatementSource<TrustStatement> source;
  // If provided, keys are grouped by endpoint domain and fetched from the
  // appropriate registered channel rather than always using [source].
  final ChannelFactory? channelFactory;
  final int maxDegrees;
  final PathRequirement? pathRequirement;

  TrustPipeline(
    this.source, {
    this.channelFactory,
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
    final sw = Stopwatch()..start();

    for (int depth = 0; depth < maxDegrees; depth++) {
      if (frontier.isEmpty) break;

      final keysToFetch = frontier.difference(visited)
          .where((k) => !graph.equivalent2canonical.containsKey(k))
          .toList();
      if (keysToFetch.isEmpty) break;

      final fetchMap = {for (var k in keysToFetch) k.value: null};

      Map<String, List<TrustStatement>> newStatementsMap;
      if (channelFactory != null) {
        newStatementsMap = {};
        final byUrl = <String, Map<String, String?>>{};
        for (final key in keysToFetch) {
          final url = FedKey.find(key)?.endpoint['url'] as String? ?? kNativeUrl;
          byUrl.putIfAbsent(url, () => {})[key.value] = null;
        }
        for (final entry in byUrl.entries) {
          final ch = channelFactory!.getChannel<TrustStatement>(entry.key, 'statements');
          print('[TrustPipeline] depth=$depth url=${entry.key} keys=${entry.value.length}');
          final results = await ch.fetch(entry.value);
          newStatementsMap.addAll(results);
        }
      } else {
        newStatementsMap = await source.fetch(fetchMap);
      }
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

    sw.stop();
    print('[TrustPipeline] done: ${sw.elapsedMilliseconds}ms  keys=${graph.distances.length}');
    return graph;
  }
}
