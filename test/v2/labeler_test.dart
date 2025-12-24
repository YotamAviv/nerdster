import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/v2/trust_logic.dart';
import 'package:nerdster/v2/labeler.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/v2/direct_firestore_source.dart';
import 'package:nerdster/v2/orchestrator.dart';
import 'package:nerdster/main.dart';
import 'package:nerdster/oneofus/crypto/crypto.dart';
import 'package:nerdster/oneofus/fetcher.dart';
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
    final alice = await DemoKey.create('alice');
    final bob = await DemoKey.create('bob');
    final charlie = await DemoKey.create('charlie');
    final dave = await DemoKey.create('dave');

    // Alice -> Bob ("Bobby")
    await alice.doTrust(TrustVerb.trust, bob, moniker: 'Bobby');
    // Alice -> Charlie ("Chuck")
    await alice.doTrust(TrustVerb.trust, charlie, moniker: 'Chuck');
    
    // Charlie -> Bob ("The Imposter") - Should be ignored because Alice already named him
    await charlie.doTrust(TrustVerb.trust, bob, moniker: 'The Imposter');
    
    // Bob -> Dave ("David")
    await bob.doTrust(TrustVerb.trust, dave, moniker: 'David');

    final source = DirectFirestoreSource<TrustStatement>(kOneofusDomain);
    final pipeline = TrustPipeline(source, maxDegrees: 5);
    final graph = await pipeline.build(alice.token);
    
    final labeler = V2Labeler(graph);

    expect(labeler.getLabel(alice.token), 'Me');
    expect(labeler.getLabel(bob.token), 'Bobby');
    expect(labeler.getLabel(charlie.token), 'Chuck');
    expect(labeler.getLabel(dave.token), 'David');
  });

  test('V2Labeler: Root Moniker Discovery', () async {
    final alice = await DemoKey.create('alice');
    final bob = await DemoKey.create('bob');

    // Alice trusts Bob
    await alice.doTrust(TrustVerb.trust, bob, moniker: 'Bobby');
    // Bob trusts Alice back as "Lisa"
    await bob.doTrust(TrustVerb.trust, alice, moniker: 'Lisa');

    final source = DirectFirestoreSource<TrustStatement>(kOneofusDomain);
    final pipeline = TrustPipeline(source, maxDegrees: 5);
    final graph = await pipeline.build(alice.token);
    
    final labeler = V2Labeler(graph);

    // Alice is the root, but Bob (who she trusts) calls her "Lisa".
    expect(labeler.getLabel(alice.token), 'Lisa');
  });

  test('V2Labeler: Identity Resolution', () async {
    final alice = await DemoKey.create('alice');
    final bob1 = await DemoKey.create('bob1');
    final bob2 = await DemoKey.create('bob2');

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
    final fetcher = Fetcher(alice.token, kOneofusDomain);
    final signer = await OouSigner.make(alice.keyPair);
    await fetcher.push(json, signer);
    
    // Bob2 replaces Bob1
    await bob2.replace(bob1);

    final source = DirectFirestoreSource<TrustStatement>(kOneofusDomain);
    final pipeline = TrustPipeline(source, maxDegrees: 5);
    final graph = await pipeline.build(alice.token);
    
    final labeler = V2Labeler(graph);

    // Since Bob2 replaces Bob1, Bob2 is canonical and Bob1 is old.
    // Both should have unique labels.
    expect(labeler.getLabel(bob2.token), 'Bob');
    expect(labeler.getLabel(bob1.token), "Bob'");
  });

  test('V2Labeler: Name Conflicts (Disambiguation)', () async {
    final alice = await DemoKey.create('alice');
    final bob1 = await DemoKey.create('bob1');
    final bob2 = await DemoKey.create('bob2');

    // Alice -> Bob1 ("Bob")
    await alice.doTrust(TrustVerb.trust, bob1, moniker: 'Bob');
    // Alice -> Bob2 ("Bob") - Different identity
    await alice.doTrust(TrustVerb.trust, bob2, moniker: 'Bob');

    final source = DirectFirestoreSource<TrustStatement>(kOneofusDomain);
    final pipeline = TrustPipeline(source, maxDegrees: 5);
    final graph = await pipeline.build(alice.token);
    
    final labeler = V2Labeler(graph);

    // Order in orderedKeys depends on newest-first. 
    // Bob2 was trusted last, so it comes first in the BFS layer.
    expect(labeler.getLabel(bob2.token), 'Bob');
    expect(labeler.getLabel(bob1.token), 'Bob (2)');
  });

  test('V2Labeler: Complex Conflict (Old + Collision)', () async {
    final alice = await DemoKey.create('alice');
    final bob1 = await DemoKey.create('bob1');
    final bob2 = await DemoKey.create('bob2');
    final charlie1 = await DemoKey.create('charlie1');
    final charlie2 = await DemoKey.create('charlie2');

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

    final source = DirectFirestoreSource<TrustStatement>(kOneofusDomain);
    final pipeline = TrustPipeline(source, maxDegrees: 5);
    final graph = await pipeline.build(alice.token);
    
    final labeler = V2Labeler(graph);

    // Charlie identity was trusted last by Alice, so it comes first in orderedKeys.
    // Charlie identity (also named "Bob"). Charlie2 is canonical.
    expect(labeler.getLabel(charlie2.token), 'Bob');
    expect(labeler.getLabel(charlie1.token), "Bob'");

    // Bob identity. Bob2 is canonical.
    expect(labeler.getLabel(bob2.token), 'Bob (2)');
    expect(labeler.getLabel(bob1.token), "Bob (2)'");
  });
}
