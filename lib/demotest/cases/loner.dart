import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/oneofus/fetcher.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';

Future<(DemoKey, DemoKey?)> loner() async {
  DemoKey loner = await DemoKey.findOrCreate('loner');
  DemoKey lonerN = await loner.makeDelegate();

  return (loner, lonerN);
}

Future<(DemoKey, DemoKey?)> lonerEquate() async {
  final out = await loner();
  DemoKey lonerN = await DemoKey.findOrCreate('loner-nerdster0');

  await lonerN.doRate(title: 'a');
  await lonerN.doRate(title: 'b');
  await lonerN.doRelate(ContentVerb.equate, title: 'a', otherTitle: 'b');

  return out;
}

Future<(DemoKey, DemoKey?)> lonerRevokeDelegate() async {
  final (DemoKey identity, DemoKey? delegate) = await loner();

  await identity.doTrust(TrustVerb.delegate, delegate!,
      domain: kNerdsterDomain, revokeAt: 'yes, please');

  return (identity, delegate);
}

Future<(DemoKey, DemoKey?)> lonerClearDelegate() async {
  final (DemoKey identity, DemoKey? delegate) = await loner();

  await identity.doTrust(TrustVerb.clear, delegate!);

  return (identity, delegate);
}

Future<(DemoKey, DemoKey?)> lonerBadDelegate() async {
  final (DemoKey identity, DemoKey? delegate) = await loner();
  DemoKey other = await DemoKey.findOrCreate('someone');

  return (other, delegate);
}

Future<(DemoKey, DemoKey?)> lonerCorrupt() async {
  final (DemoKey identity, DemoKey? delegate) = await loner();

  // This is detected as corrupt without this top statement. 
  // Corruption cases should unit tested in Fetcher, not in integration tests like this.
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

  Fetcher.clear();

  return (identity, delegate);
}
