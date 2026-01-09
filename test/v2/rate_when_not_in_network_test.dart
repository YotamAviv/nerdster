import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/demotest/cases/rate_when_not_in_network.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/main.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/oneofus/trust_statement.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() async {
    fireChoice = FireChoice.fake;

    firestore = FakeFirebaseFirestore();
    FireFactory.register(kOneofusDomain, firestore, null);
    FireFactory.register(kNerdsterDomain, firestore, null);
    TrustStatement.init();
    ContentStatement.init();
    DemoKey.reset();
  });

  test('Rate When Not In Network Scenario', () async {
    await rateWhenNotInNetwork();
  });
}
