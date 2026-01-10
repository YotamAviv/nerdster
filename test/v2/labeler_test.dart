import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/oneofus/keys.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/v2/labeler.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/v2/direct_firestore_source.dart';
import 'package:nerdster/v2/orchestrator.dart';
import 'package:nerdster/app.dart';
import 'package:nerdster/v2/io.dart';
import 'package:nerdster/v2/source_factory.dart';
import 'package:nerdster/oneofus/oou_signer.dart';

import 'package:nerdster/content/content_statement.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() async {
    fireChoice = FireChoice.fake;
    firestore = FakeFirebaseFirestore();
    FireFactory.register(kOneofusDomain, firestore, null);
    FireFactory.register(kNerdsterDomain, firestore, null);
    TrustStatement.init();
    ContentStatement.init();
    DemoKey.reset();
  });

  test('V2Labeler: Greedy Moniker Assignment', () async {
    final alice = await DemoIdentityKey.create('alice');
    final bob = await DemoIdentityKey.create('bob');
    final charlie = await DemoIdentityKey.create('charlie');
    final dave = await DemoIdentityKey.create('dave');

    // Alice -> Bob ("Bobby")
    await alice.doTrust(TrustVerb.trust, bob, moniker: 'Bobby');
    // Alice -> Charlie ("Chuck")
    await alice.doTrust(TrustVerb.trust, charlie, moniker: 'Chuck');
    
    // Charlie -> Bob ("The Imposter") - Should be ignored because Alice already named him
    await charlie.doTrust(TrustVerb.trust, bob, moniker: 'The Imposter');
    
    // Bob -> Dave ("David")
    await bob.doTrust(TrustVerb.trust, dave, moniker: 'David');

    final source = DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));
    final pipeline = TrustPipeline(source, maxDegrees: 5);
    final graph = await pipeline.build(alice.id);
    
    final labeler = V2Labeler(graph, meIdentity: alice.id);

    expect(labeler.getIdentityLabel(alice.id), 'Me');
    expect(labeler.getIdentityLabel(bob.id), 'Bobby');
    expect(labeler.getIdentityLabel(charlie.id), 'Chuck');
    expect(labeler.getIdentityLabel(dave.id), 'David');
  });

  test('V2Labeler: PoV Moniker Discovery', () async {
    final alice = await DemoIdentityKey.create('alice');
    final bob = await DemoIdentityKey.create('bob');

    // Alice trusts Bob
    await alice.doTrust(TrustVerb.trust, bob, moniker: 'Bobby');
    // Bob trusts Alice back as "Lisa"
    await bob.doTrust(TrustVerb.trust, alice, moniker: 'Lisa');

    final source = DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));
    final pipeline = TrustPipeline(source, maxDegrees: 5);
    final graph = await pipeline.build(alice.id);
    
    final labeler = V2Labeler(graph);

    // Alice is the pov, but Bob (who she trusts) calls her "Lisa".
    expect(labeler.getIdentityLabel(alice.id), 'Lisa');
  });

  test('V2Labeler: Identity Resolution', () async {
    final alice = await DemoIdentityKey.create('alice');
    final bob1 = await DemoIdentityKey.create('bob1');
    final bob2 = await DemoIdentityKey.create('bob2');

    // Alice -> Bob1 ("Bob")
    await alice.doTrust(TrustVerb.trust, bob1, moniker: 'Bob');
    
    // Alice also trusts Bob2 so it's in the graph, but NO moniker
    // We do this manually to avoid DemoKey's default moniker
    final json = TrustStatement.make(
        await (await alice.keyPair.publicKey).json, 
        await (bob2.publicKey).json, 
        TrustVerb.trust,
        domain: null, 
        moniker: null);
    final StatementWriter writer = SourceFactory.getWriter(kOneofusDomain);
    final signer = await OouSigner.make(alice.keyPair);
    await writer.push(json, signer);
    
    // Bob2 replaces Bob1
    await bob2.replace(bob1);

    final source = DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));
    final pipeline = TrustPipeline(source, maxDegrees: 5);
    final graph = await pipeline.build(alice.id);
    
    final labeler = V2Labeler(graph);

    // Since Bob2 replaces Bob1, Bob2 is canonical and Bob1 is old.
    // Both should have unique labels.
    expect(labeler.getIdentityLabel(bob2.id), 'Bob');
    expect(labeler.getIdentityLabel(bob1.id), "Bob'");
  });

  test('V2Labeler: Name Conflicts (Disambiguation)', () async {
    final alice = await DemoIdentityKey.create('alice');
    final bob1 = await DemoIdentityKey.create('bob1');
    final bob2 = await DemoIdentityKey.create('bob2');

    // Alice -> Bob1 ("Bob")
    await alice.doTrust(TrustVerb.trust, bob1, moniker: 'Bob');
    // Alice -> Bob2 ("Bob") - Different identity
    await alice.doTrust(TrustVerb.trust, bob2, moniker: 'Bob');

    final source = DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));
    final pipeline = TrustPipeline(source, maxDegrees: 5);
    final graph = await pipeline.build(alice.id);
    
    final labeler = V2Labeler(graph);

    // Order in orderedKeys depends on newest-first. 
    // Bob2 was trusted last, so it comes first in the BFS layer.
    expect(labeler.getIdentityLabel(bob2.id), 'Bob');
    expect(labeler.getIdentityLabel(bob1.id), 'Bob (2)');
  });

  test('V2Labeler: Complex Conflict (Old + Collision)', () async {
    final alice = await DemoIdentityKey.create('alice');
    final bob1 = await DemoIdentityKey.create('bob1');
    final bob2 = await DemoIdentityKey.create('bob2');
    final charlie1 = await DemoIdentityKey.create('charlie1');
    final charlie2 = await DemoIdentityKey.create('charlie2');

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

    final source = DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));
    final pipeline = TrustPipeline(source, maxDegrees: 5);
    final graph = await pipeline.build(alice.id);
    
    final labeler = V2Labeler(graph);

    // Charlie identity was trusted last by Alice, so it comes first in orderedKeys.
    // Charlie identity (also named "Bob"). Charlie2 is canonical.
    expect(labeler.getIdentityLabel(charlie2.id), 'Bob');
    expect(labeler.getIdentityLabel(charlie1.id), "Bob'");

    // Bob identity. Bob2 is canonical.
    expect(labeler.getIdentityLabel(bob2.id), 'Bob (2)');
    expect(labeler.getIdentityLabel(bob1.id), "Bob (2)'");
  });
}
