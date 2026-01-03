import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/test_clock.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/demotest/cases/test_utils.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/v2/delegates.dart';
import 'package:nerdster/v2/orchestrator.dart';
import 'package:nerdster/v2/source_factory.dart';
import 'package:nerdster/v2/labeler.dart';

/// A gallery of all possible Trust and Follow notifications.
///
/// This demo sets up a scenario where every type of notification defined in the
/// V2 specification is generated.
///
/// Trust Notifications:
/// 1. Attempt to block your key
/// 2. Attempt to block trusted key
/// 3. Attempt to replace your key
/// 4. Blocked key is being replaced
/// 5. Trusted key is being replaced (Replacement constraint ignored)
/// 6. Key replaced by both X and Y
/// 7. Trusted key is being replaced
/// 8. Attempt to trust blocked key
/// 9. Identity trusts a non-canonical key directly
///
/// Follow Notifications:
/// 10. Attempt to block you
/// 11. Attempt to block followed identity
/// 12. Attempt to follow blocked identity
Future<(DemoKey, DemoKey?)> notificationsGallery() async {
  useClock(TestClock());

  // Actors
  final DemoKey me = await DemoKey.findOrCreate('me');
  final DemoKey alice = await DemoKey.findOrCreate('alice');
  final DemoKey bob = await DemoKey.findOrCreate('bob');
  final DemoKey charlie = await DemoKey.findOrCreate('charlie');
  final DemoKey dave = await DemoKey.findOrCreate('dave');
  final DemoKey eve = await DemoKey.findOrCreate('eve');
  final DemoKey frank = await DemoKey.findOrCreate('frank');
  final DemoKey mallory = await DemoKey.findOrCreate('mallory');
  final DemoKey oldKey = await DemoKey.findOrCreate('oldKey');
  final DemoKey newKey1 = await DemoKey.findOrCreate('newKey1');
  final DemoKey badGuy = await DemoKey.findOrCreate('badGuy');
  final DemoKey distantGuy = await DemoKey.findOrCreate('distantGuy');
  final DemoKey distantBob = await DemoKey.findOrCreate('distantBob');
  final DemoKey meContent = await DemoKey.findOrCreate('meContent');
  final DemoKey aliceContent = await DemoKey.findOrCreate('aliceContent');
  final DemoKey blocker = await DemoKey.findOrCreate('blocker');

  // --- TRUST LOGIC SCENARIOS ---

  // 0. Delegation
  await me.delegate(meContent, domain: 'nerdster.org');
  await alice.delegate(aliceContent, domain: 'nerdster.org');

  // 1. Self-Block Attempt: Blocker blocks Me
  await me.trust(blocker, moniker: 'blocker');
  await blocker.block(me);

  // 2. Trusted Key Block Attempt: Me trusts Bob, Alice blocks Bob
  await me.trust(bob, moniker: 'bob');
  await alice.block(bob);

  // 3. Self-Replace Attempt: Alice replaces Me
  await alice.replace(me);

  // 4. Blocked Key Replacement: Me blocks BadGuy, Alice replaces BadGuy
  await me.block(badGuy);
  await alice.replace(badGuy);

  // 5. Distant Replacement: Me trusts DistantGuy, DistantBob (dist 2) replaces DistantGuy
  // Need DistantBob to be dist 2. Me -> Alice -> DistantBob.
  await me.trust(alice, moniker: 'alice');
  await alice.trust(distantBob, moniker: 'distantBob');
  await me.trust(distantGuy, moniker: 'distantGuy');
  await distantBob.replace(distantGuy);

  // 6. Double Replacement: Charlie replaces OldKey, Dave replaces OldKey
  // Me -> Charlie, Me -> Dave, Me -> OldKey
  await me.trust(charlie, moniker: 'charlie');
  await me.trust(dave, moniker: 'dave');
  await me.trust(oldKey, moniker: 'oldKey');
  await charlie.replace(oldKey);
  await dave.replace(oldKey);

  // 7. Trusted Key Replacement: Frank replaces NewKey1 (who is trusted via Me)
  // Wait, "Trusted key $oldKey is being replaced by $issuer".
  // Me -> Frank. Me -> NewKey1. Frank replaces NewKey1.
  await me.trust(frank, moniker: 'frank');
  await me.trust(newKey1, moniker: 'newKey1');
  await frank.replace(newKey1);

  // 8. Trust Blocked Key: Eve trusts BadGuy (who is blocked by Me)
  await me.trust(eve, moniker: 'eve');
  await eve.trust(badGuy, moniker: 'badGuy');

  // 9. Non-Canonical Trust: Mallory trusts OldKey (who is replaced by Charlie)
  await me.trust(mallory, moniker: 'mallory');
  await mallory.trust(oldKey, moniker: 'oldKey');

  // 10. Delegate Already Claimed: Bob claims AliceContent (already claimed by Alice)
  await bob.delegate(aliceContent, domain: 'nerdster.org');

  // 11. Multiple Delegates: Bob creates a second delegate
  final DemoKey bobContent2 = await bob.makeDelegate();
  await bobContent2.doRate(subject: {
      'contentType': 'book',
      'title': 'Bob Book 2',
      'author': 'unknown',
      'year': 2025
  });

  // Add a delegate key for each player, and have them submit their name as a bogus book
  final List<DemoKey> players = [
    me,
    alice,
    bob,
    charlie,
    dave,
    eve,
    frank,
    mallory,
    oldKey,
    newKey1,
    badGuy,
    distantGuy,
    distantBob
  ];

  for (DemoKey player in players) {
    DemoKey contentKey;
    if (player == me) {
      contentKey = meContent;
    } else if (player == alice) {
      contentKey = aliceContent;
    } else {
      contentKey = await player.makeDelegate();
    }

    await contentKey.doRate(subject: {
      'contentType': 'book',
      'title': player.name,
      'author': 'unknown',
      'year': 2025
    });
  }

  // Verify
  final src = SourceFactory.get<TrustStatement>(kOneofusDomain);
  final pipeline = TrustPipeline(src);
  final trustGraph = await pipeline.build(me.token);

  // Trigger delegate resolution to generate notifications
  final resolver = DelegateResolver(trustGraph);
  resolver.resolveForIdentity(alice.token);
  resolver.resolveForIdentity(bob.token);

  check(trustGraph.notifications.any((n) => n.reason.contains("Attempt to block your key")), "Missing: Attempt to block your key");
  check(trustGraph.notifications.any((n) => n.reason.contains("Attempt to block trusted key")), "Missing: Attempt to block trusted key");
  check(trustGraph.notifications.any((n) => n.reason.contains("Attempt to replace your key")), "Missing: Attempt to replace your key");
  check(trustGraph.notifications.any((n) => n.reason.contains("Blocked key")), "Missing: Blocked key");
  check(trustGraph.notifications.any((n) => n.reason.contains("Replacement constraint ignored")), "Missing: Replacement constraint ignored");
  check(trustGraph.notifications.any((n) => n.reason.contains("replaced by both")), "Missing: replaced by both");
  check(trustGraph.notifications.any((n) => n.reason.contains("Trusted key") && n.reason.contains("is being replaced")), "Missing: Trusted key is being replaced");
  check(trustGraph.notifications.any((n) => n.reason.contains("Attempt to trust blocked key")), "Missing: Attempt to trust blocked key");
  check(trustGraph.notifications.any((n) => n.reason.contains("trusts a non-canonical key")), "Missing: trusts a non-canonical key");
  check(trustGraph.notifications.any((n) => n.reason.contains("Delegate key ${aliceContent.token} already claimed by ${alice.token}")), "Missing: Delegate key already claimed");

  // Verify Labels
  final labeler = V2Labeler(trustGraph, delegateResolver: resolver);
  final bobDelegates = resolver.getDelegatesForIdentity(bob.token);
  final nerdsterDelegates = bobDelegates.where((d) => resolver.getDomainForDelegate(d) == 'nerdster.org').toList();
  
  check(nerdsterDelegates.length >= 2, "Missing: Bob should have at least 2 delegates");
  
  final label1 = labeler.getLabel(nerdsterDelegates[0]);
  final label2 = labeler.getLabel(nerdsterDelegates[1]);
  
  // Note: The order depends on the order in resolver.getDelegatesForIdentity which depends on statement order.
  // We expect them to be ordered by appearance or something deterministic.
  // If not, we might need to check if set of labels matches.
  
  final labels = nerdsterDelegates.map((d) => labeler.getLabel(d)).toSet();
  check(labels.contains("bob@nerdster.org"), "Missing label: bob@nerdster.org");
  check(labels.contains("bob@nerdster.org (2)"), "Missing label: bob@nerdster.org (2)");

  return (me, null);
}
