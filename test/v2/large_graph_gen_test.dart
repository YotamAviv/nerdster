import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/oneofus/fetcher.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/cases/large_graph.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/feed_controller.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/fire_choice.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/setting_type.dart';

void main() {
  test('Generate Large Graph Scenario', () async {
    fireChoice = FireChoice.fake;
    TrustStatement.init();
    ContentStatement.init();
    Setting.get<bool>(SettingType.skipVerify).value = true;

    final nerdsterFire = FakeFirebaseFirestore();
    final oneofusFire = FakeFirebaseFirestore();

    FireFactory.register(kNerdsterDomain, nerdsterFire, null);
    FireFactory.register(kOneofusDomain, oneofusFire, null);

    DemoKey.reset();
    final (a, aN) = await largeGraph();

    // Dump the statements
    final Map<String, Map<String, List<Json>>> dump = {};
    
    for (var domain in [kNerdsterDomain, kOneofusDomain]) {
      final fire = FireFactory.find(domain);
      final domainDump = <String, List<Json>>{};
      
      for (var demoKey in DemoKey.all) {
        final token = demoKey.token;
        final snapshot = await fire.collection(token).doc('statements').collection('statements').get();
        if (snapshot.docs.isNotEmpty) {
          domainDump[token] = snapshot.docs.map((doc) => doc.data()).toList();
        }
      }
      dump[domain] = domainDump;
    }

    final fullDump = {
      'center': (await a.publicKey.json),
      'domain2token2statements': dump,
    };

    final out = {
      'dump': fullDump,
      'privateKey': await a.keyPair.json,
      'identityToken': a.token,
    };

    final file = File('large_graph_scenario.json');
    await file.writeAsString(jsonEncode(out));
    print('Wrote large graph scenario to ${file.absolute.path}');
  });
}
