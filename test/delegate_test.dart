import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/main.dart';
import 'package:nerdster/oneofus/fetcher.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    FireFactory.register(kOneofusDomain, firestore, null);
    FireFactory.register(kNerdsterDomain, firestore, null);
    
    // Force Fetcher to use FakeFirestore instead of HTTP
    fireChoice = FireChoice.fake;

    TrustStatement.init();
    ContentStatement.init();
    DemoKey.reset();
  });

  test('Generate Delegate Statements for Docs', () async {
    final DemoKey alice = await DemoKey.create('alice');
    DemoKey delegateKey = await DemoKey.findOrCreate('delegate');
    Statement delegateStatement1 =
        await alice.doTrust(TrustVerb.delegate, delegateKey, domain: kNerdsterDomain);

    print('### 1. Active Delegation');
    print(const JsonEncoder.withIndent('  ').convert(delegateStatement1.json));

    const Json banana = {
      'contentType': 'recipe',
      'title': "Banana Banana Bread Recipe (with Video)",
      'url': 'https://www.allrecipes.com/recipe/20144/banana-banana-bread/'
    };

    Statement contentStatement = await delegateKey.doRate(
        subject: banana,
        recommend: true,
        comment: '#nutritious and #delicious',
        export: 'marge-banana-rate');

    print('\n### 2. Revoked at a Statement');
    var s2 = await alice.doTrust(TrustVerb.delegate, delegateKey,
        domain: kNerdsterDomain, revokeAt: contentStatement.token);
    print(const JsonEncoder.withIndent('  ').convert(s2.json));

    print('\n### 3. Revoked Immediately (Since Always)');
    var s3 = await alice.doTrust(TrustVerb.delegate, delegateKey,
        domain: kNerdsterDomain, revokeAt: kSinceAlways);
    print(const JsonEncoder.withIndent('  ').convert(s3.json));
  });
}
