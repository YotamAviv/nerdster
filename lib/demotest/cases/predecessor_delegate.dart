import 'package:nerdster/demotest/cases/simpsons_demo.dart';
import 'package:nerdster/demotest/test_util.dart';
import 'package:nerdster/logic/delegates.dart';
import 'package:nerdster_common/trust_pipeline.dart';

/// Verifies that delegate keys from predecessor (replaced) identity keys
/// are NOT visible in content resolution from a peer's PoV.
///
/// Equivalent (replaced) keys are fully revoked — their OOU statements are not fetched.
/// homer (old key) has delegate homerD. homer2 replaced homer. Lisa trusts homer2.
/// From Lisa's PoV, homer's OOU statements are never fetched, so homerD is unknown
/// to DelegateResolver and Lisa does not see Beer Wars.
Future<void> predecessorDelegate() async {
  await simpsonsDemo();

  final lisa = await DemoIdentityKey.findOrCreate('lisa');
  final homer2 = await DemoIdentityKey.findOrCreate('homer2');
  // homerD is named 'homer-nerdster0' by makeDelegate's naming convention
  final homerD = await DemoDelegateKey.findOrCreate('homer-nerdster0');

  final trustSource = channelFactory.getChannel<TrustStatement>(kNativeUrl, 'statements');
  final trustPipeline = TrustPipeline(trustSource);
  final graph = await trustPipeline.build(lisa.id);

  check(graph.orderedKeys.contains(homer2.id), 'homer2 in Lisa\'s trust graph');

  final resolver = DelegateResolver(graph);
  final homer2Delegates = resolver.getDelegatesForIdentity(homer2.id);
  check(!homer2Delegates.contains(homerD.id),
      'homerD (predecessor delegate) correctly NOT found — equivalent keys are fully revoked');
}
