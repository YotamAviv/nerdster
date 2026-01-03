import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/test_clock.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/v2/follow_logic.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/trust_logic.dart';
import 'package:nerdster/v2/delegates.dart';
import 'package:nerdster/v2/keys.dart';
import 'package:nerdster/fire_choice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() async {
  fireChoice = FireChoice.fake;
  FireFactory.register(kOneofusDomain, FakeFirebaseFirestore(), null);
  FireFactory.register(kNerdsterDomain, FakeFirebaseFirestore(), null);
  TrustStatement.init();
  ContentStatement.init();

  setUp(() async {
    useClock(TestClock());
    DemoKey.reset();
  });

  test('Gallery of Notifications', () async {
    // Actors
    final DemoKey me = await DemoKey.create('me');
    final DemoKey alice = await DemoKey.create('alice');
    final DemoKey bob = await DemoKey.create('bob');
    final DemoKey charlie = await DemoKey.create('charlie');
    final DemoKey dave = await DemoKey.create('dave');
    final DemoKey eve = await DemoKey.create('eve');
    final DemoKey frank = await DemoKey.create('frank');
    final DemoKey mallory = await DemoKey.create('mallory');
    final DemoKey oldKey = await DemoKey.create('oldKey');
    final DemoKey newKey1 = await DemoKey.create('newKey1');
    final DemoKey newKey2 = await DemoKey.create('newKey2');
    final DemoKey badGuy = await DemoKey.create('badGuy');
    final DemoKey distantGuy = await DemoKey.create('distantGuy');
    final DemoKey distantBob = await DemoKey.create('distantBob');
    final DemoKey meContent = await DemoKey.create('meContent');
    final DemoKey aliceContent = await DemoKey.create('aliceContent');

    // --- TRUST LOGIC SCENARIOS ---

    // 0. Delegation
    final d1 = await me.delegate(meContent, domain: 'nerdster.org');
    final d2 = await alice.delegate(aliceContent, domain: 'nerdster.org');

    // 1. Self-Block Attempt: Alice blocks Me
    final s1 = await alice.block(me);

    // 2. Trusted Key Block Attempt: Me trusts Bob, Alice blocks Bob
    final s2 = await me.trust(bob, moniker: 'bob');
    final s3 = await alice.block(bob);

    // 3. Self-Replace Attempt: Alice replaces Me
    final s4 = await alice.replace(me);

    // 4. Blocked Key Replacement: Me blocks BadGuy, Alice replaces BadGuy
    final s5 = await me.block(badGuy);
    final s6 = await alice.replace(badGuy);

    // 5. Distant Replacement: Me trusts DistantGuy, DistantBob (dist 2) replaces DistantGuy
    // Need DistantBob to be dist 2. Me -> Alice -> DistantBob.
    final s7 = await me.trust(alice, moniker: 'alice');
    final s8 = await alice.trust(distantBob, moniker: 'distantBob');
    final s9 = await me.trust(distantGuy, moniker: 'distantGuy');
    final s10 = await distantBob.replace(distantGuy);

    // 6. Double Replacement: Charlie replaces OldKey, Dave replaces OldKey
    // Me -> Charlie, Me -> Dave, Me -> OldKey
    final s11 = await me.trust(charlie, moniker: 'charlie');
    final s12 = await me.trust(dave, moniker: 'dave');
    final s13 = await me.trust(oldKey, moniker: 'oldKey');
    final s14 = await charlie.replace(oldKey);
    final s15 = await dave.replace(oldKey);

    // 7. Trusted Key Replacement: Frank replaces NewKey1 (who is trusted via Me)
    // Wait, "Trusted key $oldKey is being replaced by $issuer".
    // Me -> Frank. Me -> NewKey1. Frank replaces NewKey1.
    final s16 = await me.trust(frank, moniker: 'frank');
    final s17 = await me.trust(newKey1, moniker: 'newKey1');
    final s18 = await frank.replace(newKey1);

    // 8. Trust Blocked Key: Eve trusts BadGuy (who is blocked by Me)
    final s19 = await me.trust(eve, moniker: 'eve');
    final s20 = await eve.trust(badGuy, moniker: 'badGuy');

    // 9. Non-Canonical Trust: Mallory trusts OldKey (who is replaced by Charlie)
    final s21 = await me.trust(mallory, moniker: 'mallory');
    final s22 = await mallory.trust(oldKey, moniker: 'oldKey');

    // Build Trust Graph
    final Map<String, List<TrustStatement>> trustStatements = {
      me.token: [d1, s2, s5, s7, s9, s11, s12, s13, s16, s17, s19, s21],
      alice.token: [d2, s1, s3, s4, s6, s8],
      bob.token: [],
      distantBob.token: [s10],
      charlie.token: [s14],
      dave.token: [s15],
      frank.token: [s18],
      eve.token: [s20],
      mallory.token: [s22],
    };

    for (final list in trustStatements.values) {
      list.sort((a, b) => b.time.compareTo(a.time));
    }

    final TrustGraph trustGraph = reduceTrustGraph(TrustGraph(pov: me.token), trustStatements);

    print('--- Trust Notifications ---');
    for (final n in trustGraph.notifications) {
      print('${n.isConflict ? "CONFLICT" : "INFO"}: ${n.reason}');
    }

    // Verify Trust Notifications
    expect(trustGraph.notifications.any((n) => n.reason.contains("Attempt to block your key")), isTrue);
    expect(trustGraph.notifications.any((n) => n.reason.contains("Attempt to block trusted key")), isTrue);
    expect(trustGraph.notifications.any((n) => n.reason.contains("Attempt to replace your key")), isTrue);
    expect(trustGraph.notifications.any((n) => n.reason.contains("Blocked key")), isTrue);
    expect(trustGraph.notifications.any((n) => n.reason.contains("Replacement constraint ignored")), isTrue);
    expect(trustGraph.notifications.any((n) => n.reason.contains("replaced by both")), isTrue);
    expect(trustGraph.notifications.any((n) => n.reason.contains("Trusted key") && n.reason.contains("is being replaced")), isTrue);
    expect(trustGraph.notifications.any((n) => n.reason.contains("Attempt to trust blocked key")), isTrue);
    expect(trustGraph.notifications.any((n) => n.reason.contains("trusts a non-canonical key")), isTrue);


    // --- FOLLOW LOGIC SCENARIOS ---
    // Context: 'news'

    // Me follows Alice so we can see her follow statements
    final f0 = await meContent.doFollow(alice, {'news': 1});

    // 10. Self-Block in Context: Alice follows Me with -1
    final f1 = await aliceContent.doFollow(me, {'news': -1});

    // 11. Followed Identity Block: Me follows Bob, Alice follows Bob with -1
    final f2 = await meContent.doFollow(bob, {'news': 1});
    final f3 = await aliceContent.doFollow(bob, {'news': -1});

    // 12. Follow Blocked Identity: Me follows BadGuy with -1, Alice follows BadGuy
    final f4 = await meContent.doFollow(badGuy, {'news': -1});
    final f5 = await aliceContent.doFollow(badGuy, {'news': 1});

    final Map<DelegateKey, List<ContentStatement>> contentStatements = {
      DelegateKey(aliceContent.token): [f1, f3, f5],
      DelegateKey(meContent.token): [f0, f2, f4],
    };

    for (final list in contentStatements.values) {
      list.sort((a, b) => b.time.compareTo(a.time));
    }

    final FollowNetwork followNetwork = reduceFollowNetwork(
      trustGraph,
      DelegateResolver(trustGraph),
      ContentResult(delegateContent: contentStatements),
      'news',
    );

    print('\n--- Follow Notifications ---');
    for (final n in followNetwork.notifications) {
      print('${n.isConflict ? "CONFLICT" : "INFO"}: ${n.reason}');
    }

    // Verify Follow Notifications
    expect(followNetwork.notifications.any((n) => n.reason.contains("Attempt to block yourself")), isTrue);
    expect(followNetwork.notifications.any((n) => n.reason.contains("Attempt to block followed identity")), isTrue);
    expect(followNetwork.notifications.any((n) => n.reason.contains("Attempt to follow blocked identity")), isTrue);

  });
}
