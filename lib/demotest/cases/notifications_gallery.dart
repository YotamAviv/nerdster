import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/test_clock.dart';
import 'package:nerdster/oneofus/util.dart';

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
/// 10. Attempt to block yourself
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

  // --- TRUST LOGIC SCENARIOS ---

  // 0. Delegation
  await me.delegate(meContent, domain: 'nerdster.org');
  await alice.delegate(aliceContent, domain: 'nerdster.org');

  // 1. Self-Block Attempt: Alice blocks Me
  await alice.block(me);

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


  // --- FOLLOW LOGIC SCENARIOS ---
  // Context: 'news'

  // Me follows Alice so we can see her follow statements
  await meContent.doFollow(alice, {'news': 1});

  // 10. Self-Block in Context: Alice follows Me with -1
  await aliceContent.doFollow(me, {'news': -1});

  // 11. Followed Identity Block: Me follows Bob, Alice follows Bob with -1
  await meContent.doFollow(bob, {'news': 1});
  await aliceContent.doFollow(bob, {'news': -1});

  // 12. Follow Blocked Identity: Me follows BadGuy with -1, Alice follows BadGuy
  await meContent.doFollow(badGuy, {'news': -1});
  await aliceContent.doFollow(badGuy, {'news': 1});

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

  return (me, null);
}
