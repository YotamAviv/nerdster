import 'package:nerdster/demotest/cases/test_utils.dart';
import 'package:nerdster/logic/delegates.dart';
import 'package:nerdster/logic/labeler.dart';
import 'package:nerdster/logic/trust_pipeline.dart';
import 'package:nerdster/io/source_factory.dart';

// TODO: Use proper DemoKey

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
Future<(DemoIdentityKey, DemoDelegateKey?)> notificationsGallery() async {
  useClock(TestClock());

  // Actors
  final DemoIdentityKey me = await DemoIdentityKey.findOrCreate('me');
  final DemoIdentityKey alice = await DemoIdentityKey.findOrCreate('alice');
  final DemoIdentityKey bob = await DemoIdentityKey.findOrCreate('bob');
  final DemoIdentityKey charlie = await DemoIdentityKey.findOrCreate('charlie');
  final DemoIdentityKey dave = await DemoIdentityKey.findOrCreate('dave');
  final DemoIdentityKey eve = await DemoIdentityKey.findOrCreate('eve');
  final DemoIdentityKey frank = await DemoIdentityKey.findOrCreate('frank');
  final DemoIdentityKey mallory = await DemoIdentityKey.findOrCreate('mallory');
  final DemoIdentityKey oldKey = await DemoIdentityKey.findOrCreate('oldKey');
  final DemoIdentityKey newKey1 = await DemoIdentityKey.findOrCreate('newKey1');
  final DemoIdentityKey badGuy = await DemoIdentityKey.findOrCreate('badGuy');
  final DemoIdentityKey distantGuy = await DemoIdentityKey.findOrCreate('distantGuy');
  final DemoIdentityKey distantBob = await DemoIdentityKey.findOrCreate('distantBob');

  final DemoDelegateKey meContent = await DemoDelegateKey.findOrCreate('meContent');
  final DemoDelegateKey aliceContent = await DemoDelegateKey.findOrCreate('aliceContent');

  final DemoIdentityKey blocker = await DemoIdentityKey.findOrCreate('blocker');

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
  // This should NOT generate a notification for the POV.
  await me.trust(mallory, moniker: 'mallory');
  await mallory.trust(oldKey, moniker: 'oldKey');

  // 10. Delegate Already Claimed: Bob claims AliceContent (already claimed by Alice)
  await bob.delegate(aliceContent, domain: 'nerdster.org');

  // 11. Multiple Delegates: Bob creates a second delegate
  final DemoDelegateKey bobContent2 = await bob.makeDelegate();
  await bobContent2.doRate(
      subject: {'contentType': 'book', 'title': 'Bob Book 2', 'author': 'unknown', 'year': 2025});

  // Add a delegate key for each player, and have them submit their name as a bogus book
  final List<DemoIdentityKey> players = [
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

  for (DemoIdentityKey player in players) {
    DemoDelegateKey contentKey;
    if (player == me) {
      contentKey = meContent;
    } else if (player == alice) {
      contentKey = aliceContent;
    } else {
      contentKey = await player.makeDelegate();
    }

    await contentKey.doRate(
        subject: {'contentType': 'book', 'title': player.name, 'author': 'unknown', 'year': 2025});
  }

  // Verify
  final src = SourceFactory.get<TrustStatement>(kOneofusDomain);
  final pipeline = TrustPipeline(src);
  final trustGraph = await pipeline.build(me.id);

  // Trigger delegate resolution to generate notifications
  final resolver = DelegateResolver(trustGraph);
  resolver.resolveForIdentity(alice.id);
  resolver.resolveForIdentity(bob.id);

  check(trustGraph.notifications.any((n) => n.reason.contains("Attempt to block your key")),
      "Missing: Attempt to block your key");
  check(trustGraph.notifications.any((n) => n.reason.contains("Attempt to block trusted key")),
      "Missing: Attempt to block trusted key");
  check(trustGraph.notifications.any((n) => n.reason.contains("Attempt to replace your key")),
      "Missing: Attempt to replace your key");
  check(trustGraph.notifications.any((n) => n.reason.contains("Blocked key")),
      "Missing: Blocked key");
  check(trustGraph.notifications.any((n) => n.reason.contains("Replacement constraint ignored")),
      "Missing: Replacement constraint ignored");
  check(trustGraph.notifications.any((n) => n.reason.contains("replaced by both")),
      "Missing: replaced by both");
  check(
      (trustGraph.notifications + resolver.notifications)
          .any((n) => n.reason.contains("Trusted key") && n.reason.contains("is being replaced")),
      "Missing: Trusted key is being replaced");
  check(trustGraph.notifications.any((n) => n.reason.contains("Attempt to trust blocked key")),
      "Missing: Attempt to trust blocked key");
  check(!trustGraph.notifications.any((n) => n.reason.contains("trust a non-canonical key")),
      "Unexpected: trust a non-canonical key notification found");
  check(
      (trustGraph.notifications + resolver.notifications).any((n) => n.reason
          .contains("Delegate key ${aliceContent.token} already claimed by ${alice.token}")),
      "Missing: Delegate key already claimed");

  // Verify Labels
  final labeler = Labeler(trustGraph, delegateResolver: resolver);
  final bobDelegates = resolver.getDelegatesForIdentity(bob.id);
  final nerdsterDelegates =
      bobDelegates.where((d) => resolver.getDomainForDelegate(d) == 'nerdster.org').toList();

  check(nerdsterDelegates.length >= 2, "Missing: Bob should have at least 2 delegates");

  // Note: The order depends on the order in resolver.getDelegatesForIdentity which depends on statement order.
  // We expect them to be ordered by appearance or something deterministic.
  // If not, we might need to check if set of labels matches.

  final labels = nerdsterDelegates.map((d) => labeler.getLabel(d.value)).toSet();
  check(labels.contains("bob@nerdster.org"), "Missing label: bob@nerdster.org");
  check(labels.contains("bob@nerdster.org (2)"), "Missing label: bob@nerdster.org (2)");

  return (me, null);
}
