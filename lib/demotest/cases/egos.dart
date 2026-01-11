import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/v2/direct_firestore_source.dart';

/// Can be useful for simple scenarios at: http://localhost:<port>/?fire=fake&demo=egosCircle
Future<(DemoIdentityKey, DemoDelegateKey?)> egos() async {
  DemoIdentityKey jock = await DemoIdentityKey.findOrCreate('jock');
  DemoIdentityKey poser = await DemoIdentityKey.findOrCreate('poser');
  DemoIdentityKey hipster = await DemoIdentityKey.findOrCreate('hipster');

  await jock.doTrust(TrustVerb.trust, poser);
  await poser.doTrust(TrustVerb.trust, hipster);
  // a gratuitous trust n' clear.
  await hipster.doTrust(TrustVerb.trust, jock);
  await hipster.doTrust(TrustVerb.clear, jock);

  DemoDelegateKey jockN = await jock.makeDelegate();
  DemoDelegateKey poserN = await poser.makeDelegate();
  DemoDelegateKey hipsterN = await hipster.makeDelegate();

  final Json russ = {
    "contentType": "video",
    "title": "Russell Wilson Top 10 Plays with Seahawks - YouTube",
    "url": "https://www.youtube.com/watch?v=CkZ8VHfmdiU"
  };
  await jockN.doRate(subject: russ, comment: '#Sick!', recommend: true);
  await poserN.doRate(subject: russ, recommend: true);

  Statement h1 = await hipsterN.doRate(subject: {
    "contentType": "article",
    "title": "Big Beard: Growing and Managing Unruly, Big Beards",
    "url":
        "https://thebeardclub.com/blogs/beard-culture/how-to-overcome-the-challenges-of-a-big-beard"
  }, comment: '#Rad!', recommend: true);
  await hipsterN.doRate(subject: {
    "contentType": "article",
    "title":
        "Amazon.com : Pro Volleyball Shorts Spandex Black - No Ride Up - No Roll Up - Ultra Comfortable : Clothing, Shoes & Jewelry",
    "url": "https://www.amazon.com/Pro-Volleyball-Shorts-Spandex-Black/dp/B07NF32YJM"
  }, recommend: true);

  await hipster.delegate(hipsterN, domain: kNerdsterDomain, comment: 'bad', revokeAt: h1.token);
  DemoDelegateKey hipsterN2 = await hipster.makeDelegate();

  await hipsterN2.doRate(subject: {
    "contentType": "article",
    "title": "25+ Coolest Sleeve Tattoos for Men  | Man of Many",
    "url": "https://manofmany.com/entertainment/art/coolest-sleeve-tattoos"
  }, recommend: true);

  Statement h4 = await poserN.doRate(subject: h1.json, recommend: true, comment: 'Yeah, baby.');
  // Hipster likes and comments on poser's like of hipster's submission
  await hipsterN2.doRate(subject: h4.json, recommend: true, comment: 'Thanks!');

  await jockN.doFollow(poser, {'social': 1});
  await poserN.doFollow(hipster, {'social': 1});
  await jockN.doFollow(hipster, {'hip': 1});

  return (poser, poserN);
}

// This test only works in FakeFirebase where we can delete.
// CONSIDER: TEST: Other corruption (bad signature, bad id, ...)
Future<(DemoIdentityKey, DemoDelegateKey?)> egosCorrupt() async {
  final (DemoIdentityKey identity, DemoDelegateKey? delegate) = await egos();

  await delegate!.doRate(title: 'a');
  Statement s = await delegate.doRate(title: 'b');
  await delegate.doRate(title: 'c');

  FirebaseFirestore fire = FireFactory.find(kNerdsterDomain);

  final CollectionReference<Map<String, dynamic>> fireStatements =
      fire.collection(delegate.token).doc('statements').collection('statements');
  try {
    final doc = await fireStatements.doc(s.token).get();
    assert(doc.exists);
    await fireStatements.doc(s.token).delete();
    print('Deleted statement');
  } catch (e) {
    print('Error deleting statement: $e');
  }

  // V2 Verification
  final source = DirectFirestoreSource<ContentStatement>(fire);
  await source.fetch({delegate.token: null});

  // expect(source.notifications.length, 1);
  // expect(source.notifications.first.reason, contains('Notary Chain Violation'));

  return (identity, delegate);
}

Future<(DemoIdentityKey, DemoDelegateKey?)> egosCircle() async {
  final (DemoIdentityKey identity, DemoDelegateKey? delegate) = await egos();
  DemoIdentityKey hipster = DemoIdentityKey.findByName('hipster')!;
  DemoIdentityKey jock = DemoIdentityKey.findByName('jock')!;
  await hipster.doTrust(TrustVerb.trust, jock);
  return (identity, delegate);
}
