import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nerdster/models/content_statement.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:oneofus_common/fire_factory.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/statement.dart';
import 'package:oneofus_common/trust_statement.dart';

Future<(DemoIdentityKey, DemoDelegateKey?)> loner() async {
  DemoIdentityKey loner = await DemoIdentityKey.findOrCreate('loner');
  DemoDelegateKey lonerN = await loner.makeDelegate();

  return (loner, lonerN);
}

Future<(DemoIdentityKey, DemoDelegateKey?)> lonerEquate() async {
  final out = await loner();
  DemoDelegateKey lonerN = await DemoDelegateKey.findOrCreate('loner-nerdster0');

  await lonerN.doRate(title: 'a');
  await lonerN.doRate(title: 'b');
  await lonerN.doRelate(ContentVerb.equate, title: 'a', otherTitle: 'b');

  return out;
}

Future<(DemoIdentityKey, DemoDelegateKey?)> lonerRevokeDelegate() async {
  final (DemoIdentityKey identity, DemoDelegateKey? delegate) = await loner();

  await identity.delegate(delegate!, domain: kNerdsterDomain, revokeAt: 'yes, please');

  // BUG: missing notification

  return (identity, delegate);
}

Future<(DemoIdentityKey, DemoDelegateKey?)> lonerClearDelegate() async {
  final (DemoIdentityKey identity, DemoDelegateKey? delegate) = await loner();

  // Clearing a delegate is not technically a TrustVerb.clear on an IdentityKey,
  // but delegate keys are keys.
  // However, DemoIdentityKey.clear expects a DemoIdentityKey in the current API.
  // We need allow clearing a delegate? or use doDelegateTrust?
  // Let's assume we want to revoke it fully.
  await identity.delegate(delegate!, domain: kNerdsterDomain, revokeAt: kSinceAlways);

  // BUG: missing notification

  return (identity, delegate);
}

Future<(DemoIdentityKey, DemoDelegateKey?)> lonerBadDelegate() async {
  final (DemoIdentityKey identity, DemoDelegateKey? delegate) = await loner();

  // BUG: missing notification

  return (
    identity,
    delegate
  ); // Returning other makes no sense based on fn name? Reverted to identity
}

Future<(DemoIdentityKey, DemoDelegateKey?)> lonerCorrupt() async {
  final (DemoIdentityKey identity, DemoDelegateKey? delegate) = await loner();

  // This is detected as corrupt without this top statement.
  // Corruption cases should unit tested in Fetcher, not in integration tests like this.
  await delegate!.doRate(title: 'a');
  Statement s = await delegate.doRate(title: 'b');
  await delegate.doRate(title: 'c');

  FirebaseFirestore fire = FireFactory.find(kNerdsterDomain);

  final CollectionReference<Json> fireStatements =
      fire.collection(delegate.token).doc('statements').collection('statements');
  try {
    final doc = await fireStatements.doc(s.token).get();
    assert(doc.exists);
    await fireStatements.doc(s.token).delete();
    print('Deleted statement');
  } catch (e) {
    print('Error deleting statement: $e');
  }

  return (identity, delegate);
}
