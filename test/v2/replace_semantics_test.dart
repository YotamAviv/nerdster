import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nerdster/fire_choice.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/trust_logic.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/jsonish.dart';

import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/demotest/demo_key.dart';

void main() {
  setUpAll(() {
    fireChoice = FireChoice.fake;
    TrustStatement.init();
  });

  setUp(() {
    DemoKey.reset();
    FireFactory.register(kOneofusDomain, FakeFirebaseFirestore(), null);
  });

  test('Replace Semantics: Should default to <since always> if revokeAt is missing', () async {
    final alice = await DemoKey.create('alice');
    final aliceNew = await DemoKey.create('aliceNew');

    // aliceNew replaces alice
    final s1 = await aliceNew.doTrust(TrustVerb.replace, alice);

    final tg = reduceTrustGraph(
      TrustGraph(pov: aliceNew.token),
      {
        aliceNew.token: [s1],
      },
    );

    expect(tg.replacementConstraints[alice.token], equals(kSinceAlways));
  });

  test('Replace Semantics: Should be issuer-aware for revokeAt resolution', () async {
    final alice = await DemoKey.create('alice');
    final aliceNew = await DemoKey.create('aliceNew');
    final bob = await DemoKey.create('bob');

    // Bob has a statement with token 'bob-token'
    final sBob = await bob.doTrust(TrustVerb.trust, alice, moniker: 'alice');
    
    // aliceNew replaces alice, but mistakenly uses Bob's token as revokeAt
    final sReplace = await aliceNew.doTrust(TrustVerb.replace, alice, revokeAt: sBob.token);

    final tg = reduceTrustGraph(
      TrustGraph(pov: aliceNew.token),
      {
        aliceNew.token: [sReplace],
        bob.token: [sBob],
      },
    );

    expect(tg.replacementConstraints[alice.token], equals(sBob.token));
    
    // Now check if it actually revokes since always because the issuer doesn't match
    // We can't easily check the internal resolveReplacementLimit result without more setup,
    // but we can check if statements from 'alice' are filtered out.
    
    final sAlice = await alice.doTrust(TrustVerb.trust, bob, moniker: 'bob');
    
    final tg2 = reduceTrustGraph(
      TrustGraph(pov: aliceNew.token),
      {
        aliceNew.token: [sReplace],
        bob.token: [sBob],
        alice.token: [sAlice],
      },
    );

    // If it worked, sAlice should be filtered out because revokeAt was invalid (wrong issuer) -> <since always>
    expect(tg2.distances.containsKey(bob.token), isFalse, 
      reason: 'Bob should not be trusted via Alice because Alice is revoked since always');
  });
}
