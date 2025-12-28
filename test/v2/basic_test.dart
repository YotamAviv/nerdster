import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nerdster/app.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/content/content_statement.dart';

import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/cases/v2_verification.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    DemoKey.reset();
    fireChoice = FireChoice.fake;
    fakeFirestore = FakeFirebaseFirestore();
    TrustStatement.init();
    ContentStatement.init();
    FireFactory.register(kOneofusDomain, fakeFirestore, null);
    FireFactory.register(kNerdsterDomain, fakeFirestore, null);
  });

  test('Basic Scenario: Marge sees Bart and Lisa', () async {
    await testBasicScenario();
  });
}
