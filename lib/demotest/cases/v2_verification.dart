import 'package:nerdster/demotest/cases/test_utils.dart';
import 'package:nerdster/v2/io.dart';
import 'package:nerdster/v2/orchestrator.dart';
import 'package:nerdster/v2/source_factory.dart';

/// Executes the pipeline and verifies the graph state for the Basic Scenario.
///
/// [source] - The source to use. Defaults to [SourceFactory.get(kOneofusDomain)].
/// [description] - Optional description for error messages (useful for permutations).
Future<(DemoIdentityKey, DemoDelegateKey?)> basicScenario({
  StatementSource<TrustStatement>? source,
  String? description,
}) async {
  // Clear any existing keys to ensure isolation
  DemoKey.reset();

  var lisa = await DemoIdentityKey.create('lisa');
  var marge = await DemoIdentityKey.create('marge');
  var bart = await DemoIdentityKey.create('bart');

  await lisa.trust(marge, moniker: 'marge');
  await marge.trust(lisa, moniker: 'lisa');
  await marge.trust(bart, moniker: 'bart');

  final src = source ?? SourceFactory.get<TrustStatement>(kOneofusDomain);
  final pipeline = TrustPipeline(src);
  final graph = await pipeline.build(marge.id);

  final p = description != null ? '[$description] ' : '';

  check(graph.isTrusted(lisa.id), '${p}Marge should trust Lisa');
  check(graph.distances[lisa.id] == 1, '${p}Lisa should be distance 1');

  check(graph.isTrusted(bart.id), '${p}Marge should trust Bart');
  check(graph.distances[bart.id] == 1, '${p}Bart should be distance 1');

  return (lisa, null);
}
