import 'package:flutter_test/flutter_test.dart';
import 'package:nerdster/demotest/test_util.dart';
import 'package:nerdster/io/fire_factory.dart';
import 'package:nerdster/io/source_factory.dart';
import 'package:nerdster/logic/labeler.dart';
import 'package:nerdster/logic/trust_pipeline.dart';
import 'package:nerdster/models/model.dart';
import 'package:oneofus_common/direct_firestore_source.dart';
import 'package:oneofus_common/oou_signer.dart';
import 'package:oneofus_common/statement_writer.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    setUpTestRegistry(firestore: firestore);
  });

  test('Labeler: Greedy Moniker Assignment', () async {
    final DemoIdentityKey alice = await DemoIdentityKey.create('alice');
    final DemoIdentityKey bob = await DemoIdentityKey.create('bob');
    final DemoIdentityKey charlie = await DemoIdentityKey.create('charlie');
    final DemoIdentityKey dave = await DemoIdentityKey.create('dave');

    // Alice -> Bob ("Bobby")
    await alice.doTrust(TrustVerb.trust, bob, moniker: 'Bobby');
    // Alice -> Charlie ("Chuck")
    await alice.doTrust(TrustVerb.trust, charlie, moniker: 'Chuck');

    // Charlie -> Bob ("The Imposter") - Should be ignored because Alice already named him
    await charlie.doTrust(TrustVerb.trust, bob, moniker: 'The Imposter');

    // Bob -> Dave ("David")
    await bob.doTrust(TrustVerb.trust, dave, moniker: 'David');

    final DirectFirestoreSource<TrustStatement> source =
        DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));
    final TrustPipeline pipeline = TrustPipeline(source, maxDegrees: 5);
    final TrustGraph graph = await pipeline.build(alice.id);

    final Labeler labeler = Labeler(graph, meIdentity: alice.id);

    expect(labeler.getIdentityLabel(alice.id), 'Me');
    expect(labeler.getIdentityLabel(bob.id), 'Bobby');
    expect(labeler.getIdentityLabel(charlie.id), 'Chuck');
    expect(labeler.getIdentityLabel(dave.id), 'David');
  });

  test('Labeler: PoV Moniker Discovery', () async {
    final DemoIdentityKey alice = await DemoIdentityKey.create('alice');
    final DemoIdentityKey bob = await DemoIdentityKey.create('bob');

    // Alice trusts Bob
    await alice.doTrust(TrustVerb.trust, bob, moniker: 'Bobby');
    // Bob trusts Alice back as "Lisa"
    await bob.doTrust(TrustVerb.trust, alice, moniker: 'Lisa');

    final DirectFirestoreSource<TrustStatement> source =
        DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));
    final TrustPipeline pipeline = TrustPipeline(source, maxDegrees: 5);
    final TrustGraph graph = await pipeline.build(alice.id);

    final Labeler labeler = Labeler(graph);

    // Alice is the pov, but Bob (who she trusts) calls her "Lisa".
    expect(labeler.getIdentityLabel(alice.id), 'Lisa');
  });

  test('Labeler: Identity Resolution', () async {
    final DemoIdentityKey alice = await DemoIdentityKey.create('alice');
    final DemoIdentityKey bob1 = await DemoIdentityKey.create('bob1');
    final DemoIdentityKey bob2 = await DemoIdentityKey.create('bob2');

    // Alice -> Bob1 ("Bob")
    await alice.doTrust(TrustVerb.trust, bob1, moniker: 'Bob');

    // Alice also trusts Bob2 so it's in the graph, but NO moniker
    // We do this manually to avoid DemoKey's default moniker
    final Map<String, dynamic> json = TrustStatement.make(
        await (await alice.keyPair.publicKey).json, await (bob2.publicKey).json, TrustVerb.trust,
        domain: null, moniker: null);
    final StatementWriter writer = SourceFactory.getWriter(kOneofusDomain);
    final OouSigner signer = await OouSigner.make(alice.keyPair);
    await writer.push(json, signer);

    // Bob2 replaces Bob1
    await bob2.replace(bob1);

    final DirectFirestoreSource<TrustStatement> source =
        DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));
    final TrustPipeline pipeline = TrustPipeline(source, maxDegrees: 5);
    final TrustGraph graph = await pipeline.build(alice.id);

    final Labeler labeler = Labeler(graph);

    // Since Bob2 replaces Bob1, Bob2 is canonical and Bob1 is old.
    // Both should have unique labels.
    expect(labeler.getIdentityLabel(bob2.id), 'Bob');
    expect(labeler.getIdentityLabel(bob1.id), "Bob'");
  });

  test('Labeler: Name Conflicts (Disambiguation)', () async {
    final DemoIdentityKey alice = await DemoIdentityKey.create('alice');
    final DemoIdentityKey bob1 = await DemoIdentityKey.create('bob1');
    final DemoIdentityKey bob2 = await DemoIdentityKey.create('bob2');

    // Alice -> Bob1 ("Bob")
    await alice.doTrust(TrustVerb.trust, bob1, moniker: 'Bob');
    // Alice -> Bob2 ("Bob") - Different identity
    await alice.doTrust(TrustVerb.trust, bob2, moniker: 'Bob');

    final DirectFirestoreSource<TrustStatement> source =
        DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));
    final TrustPipeline pipeline = TrustPipeline(source, maxDegrees: 5);
    final TrustGraph graph = await pipeline.build(alice.id);

    final Labeler labeler = Labeler(graph);

    // Order in orderedKeys depends on newest-first.
    // Bob2 was trusted last, so it comes first in the BFS layer.
    expect(labeler.getIdentityLabel(bob2.id), 'Bob');
    expect(labeler.getIdentityLabel(bob1.id), 'Bob (2)');
  });

  test('Labeler: Complex Conflict (Old + Collision)', () async {
    final DemoIdentityKey alice = await DemoIdentityKey.create('alice');
    final DemoIdentityKey bob1 = await DemoIdentityKey.create('bob1');
    final DemoIdentityKey bob2 = await DemoIdentityKey.create('bob2');
    final DemoIdentityKey charlie1 = await DemoIdentityKey.create('charlie1');
    final DemoIdentityKey charlie2 = await DemoIdentityKey.create('charlie2');

    // Alice -> Bob1 ("Bob")
    await alice.doTrust(TrustVerb.trust, bob1, moniker: 'Bob');
    // Bob1 -> Bob2 (to make Bob2 trusted)
    await bob1.doTrust(TrustVerb.trust, bob2);
    // Bob2 replaces Bob1
    await bob2.replace(bob1);

    // Alice -> Charlie1 ("Bob") - Name collision with Bob
    await alice.doTrust(TrustVerb.trust, charlie1, moniker: 'Bob');
    // Charlie1 -> Charlie2
    await charlie1.doTrust(TrustVerb.trust, charlie2);
    // Charlie2 replaces Charlie1
    await charlie2.replace(charlie1);

    final DirectFirestoreSource<TrustStatement> source =
        DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));
    final TrustPipeline pipeline = TrustPipeline(source, maxDegrees: 5);
    final TrustGraph graph = await pipeline.build(alice.id);

    final Labeler labeler = Labeler(graph);

    // Charlie identity was trusted last by Alice, so it comes first in orderedKeys.
    // Charlie identity (also named "Bob"). Charlie2 is canonical.
    expect(labeler.getIdentityLabel(charlie2.id), 'Bob');
    expect(labeler.getIdentityLabel(charlie1.id), "Bob'");

    // Bob identity. Bob2 is canonical.
    expect(labeler.getIdentityLabel(bob2.id), 'Bob (2)');
    expect(labeler.getIdentityLabel(bob1.id), "Bob (2)'");
  });
}
