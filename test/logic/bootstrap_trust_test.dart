import 'package:flutter_test/flutter_test.dart';
import 'package:nerdster/demotest/test_util.dart';
import 'package:nerdster/io/fire_factory.dart';
import 'package:nerdster/logic/trust_pipeline.dart';
import 'package:nerdster/models/model.dart';
import 'package:oneofus_common/crypto/crypto.dart';
import 'package:oneofus_common/crypto/crypto25519.dart' show crypto;
import 'package:oneofus_common/direct_firestore_source.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/keys.dart';
import 'package:oneofus_common/oou_signer.dart';
import 'package:oneofus_common/trust_statement.dart';

void main() {
  setUp(() async {
    setUpTestRegistry();
  });

  test('Bootstrap: local trust injection makes Yotam network visible', () async {
    // Simulate the real network: yotam trusts alice, alice trusts bob
    final DemoIdentityKey yotam = await DemoIdentityKey.create('yotam');
    final DemoIdentityKey alice = await DemoIdentityKey.create('alice');
    final DemoIdentityKey bob = await DemoIdentityKey.create('bob');

    await yotam.trust(alice, moniker: 'alice');
    await alice.trust(bob, moniker: 'bob');

    // Generate a fresh bootstrap identity (not published anywhere)
    final OouKeyPair bootstrapKeyPair = await crypto.createKeyPair();
    final OouPublicKey bootstrapPublicKey = await bootstrapKeyPair.publicKey;
    final Json bootstrapPublicKeyJson = await bootstrapPublicKey.json;
    final IdentityKey bootstrapIdentityKey = IdentityKey(getToken(bootstrapPublicKeyJson));

    final OouSigner signer = await OouSigner.make(bootstrapKeyPair);

    // Build the synthetic trust statement: bootstrap trusts yotam
    final Json yotamPublicKeyJson = await yotam.publicKey.json;
    final Json trustJson = TrustStatement.make(
      bootstrapPublicKeyJson,
      yotamPublicKeyJson,
      TrustVerb.trust,
      moniker: 'Yotam',
    );
    final Jsonish trustJsonish = await Jsonish.makeSign(trustJson, signer);
    final TrustStatement bootstrapTrustStatement = TrustStatement(trustJsonish);

    // Inject it via localStatements (identical to what bootstrap_sign_in.dart does)
    final Map<IdentityKey, List<TrustStatement>> localStatements = {
      bootstrapIdentityKey: [bootstrapTrustStatement],
    };

    final DirectFirestoreSource<TrustStatement> source =
        DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));

    final TrustPipeline pipeline = TrustPipeline(
      source,
      localStatements: localStatements,
      pathRequirement: (_) => 1,
    );

    final TrustGraph graph = await pipeline.build(bootstrapIdentityKey);

    // Bootstrap identity is the PoV — should see yotam (dist 1) and alice (dist 2) and bob (dist 3)
    expect(graph.isTrusted(yotam.id), isTrue,
        reason: 'Bootstrap should locally trust Yotam');
    expect(graph.isTrusted(alice.id), isTrue,
        reason: 'Bootstrap should see alice (trusted by yotam)');
    expect(graph.isTrusted(bob.id), isTrue,
        reason: 'Bootstrap should see bob (trusted by alice, trusted by yotam)');

    expect(graph.distances[yotam.id], 1);
    expect(graph.distances[alice.id], 2);
    expect(graph.distances[bob.id], 3);
  });

  test('Bootstrap: without localStatements, bootstrap identity sees nothing', () async {
    final DemoIdentityKey yotam = await DemoIdentityKey.create('yotam');
    final DemoIdentityKey alice = await DemoIdentityKey.create('alice');

    await yotam.trust(alice, moniker: 'alice');

    // Bootstrap identity with NO local statements injected
    final OouKeyPair bootstrapKeyPair = await crypto.createKeyPair();
    final OouPublicKey bootstrapPublicKey = await bootstrapKeyPair.publicKey;
    final Json bootstrapPublicKeyJson = await bootstrapPublicKey.json;
    final IdentityKey bootstrapIdentityKey = IdentityKey(getToken(bootstrapPublicKeyJson));

    final DirectFirestoreSource<TrustStatement> source =
        DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));

    final TrustPipeline pipeline = TrustPipeline(source, pathRequirement: (_) => 1);
    final TrustGraph graph = await pipeline.build(bootstrapIdentityKey);

    expect(graph.isTrusted(yotam.id), isFalse,
        reason: 'Without local injection, bootstrap sees no-one');
    expect(graph.isTrusted(alice.id), isFalse);
    expect(graph.orderedKeys.length, 1, reason: 'Only the bootstrap POV itself');
  });
}

