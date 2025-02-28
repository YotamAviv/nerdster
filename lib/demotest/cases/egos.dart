import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';

Future<(DemoKey, DemoKey?)> egos() async {
  DemoKey jock = await DemoKey.findOrCreate('jock');
  DemoKey poser = await DemoKey.findOrCreate('poser');
  DemoKey hipster = await DemoKey.findOrCreate('hipster');

  await jock.doTrust(TrustVerb.trust, poser);
  await poser.doTrust(TrustVerb.trust, hipster);

  DemoKey jockN = await jock.makeDelegate();
  DemoKey poserN = await poser.makeDelegate();
  DemoKey hipsterN = await hipster.makeDelegate();

  await jockN.doRate(subject: {
    "contentType": "video",
    "title": "Russell Wilson Top 10 Plays with Seahawks - YouTube",
    "url": "https://www.youtube.com/watch?v=CkZ8VHfmdiU"
  }, comment: 'Sick!', recommend: true);

  Statement h1 = await hipsterN.doRate(subject: {
    "contentType": "article",
    "title": "Big Beard: Growing and Managing Unruly, Big Beards",
    "url":
        "https://thebeardclub.com/blogs/beard-culture/how-to-overcome-the-challenges-of-a-big-beard"
  }, comment: 'Rad!', recommend: true);
  Statement h2 = await hipsterN.doRate(subject: {
    "contentType": "article",
    "title":
        "Amazon.com : Pro Volleyball Shorts Spandex Black - No Ride Up - No Roll Up - Ultra Comfortable : Clothing, Shoes & Jewelry",
    "url": "https://www.amazon.com/Pro-Volleyball-Shorts-Spandex-Black/dp/B07NF32YJM"
  }, recommend: true);

  await hipster.doTrust(TrustVerb.delegate, hipsterN,
      domain: kNerdsterDomain, comment: 'bad', revokeAt: h1.token);
  DemoKey hipsterN2 = await hipster.makeDelegate();

  Statement h3 = await hipsterN2.doRate(subject: {
    "contentType": "article",
    "title": "25+ Coolest Sleeve Tattoos for Men  | Man of Many",
    "url": "https://manofmany.com/entertainment/art/coolest-sleeve-tattoos"
  }, recommend: true);

  Statement h4 = await poserN.doRate(subject: h1.json, recommend: true, comment: 'Yeah, baby.');
  // Hipster likes and comments on poser's like of hipster's submission
  Statement h5 = await hipsterN2.doRate(subject: h4.json, recommend: true, comment: 'Thanks!');

  await jockN.doFollow(poser, {'social': 1});
  await poserN.doFollow(hipster, {'social': 1});
  await jockN.doFollow(hipster, {'hip': 1});

  print('jock:');
  await printDemoCredentials(jock, jockN);
  print('poser:');
  await printDemoCredentials(poser, poserN);
  print('hipster (hipsterN2):');
  await printDemoCredentials(hipster, hipsterN2);

  return (poser, poserN);
}
