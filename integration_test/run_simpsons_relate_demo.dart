import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nerdster/firebase_options.dart';
import 'package:nerdster/config.dart';
import 'package:oneofus_common/statement.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:oneofus_common/fire_factory.dart';
import 'package:nerdster/oneofus_fire.dart';
import 'package:nerdster/app.dart';

import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/cases/simpsons_relate_demo.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    DemoKey.reset();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await OneofusFire.init();

    // Connect to Emulators
    fireChoice = FireChoice.emulator;
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    OneofusFire.firestore.useFirestoreEmulator('localhost', 8081);

    // Configure V2 for Emulator
    const host = 'localhost';
    const oneofusUrl = 'http://$host:5002/one-of-us-net/us-central1/export';
    const nerdsterUrl = 'http://$host:5001/nerdster/us-central1/export';

    FirebaseConfig.registerUrl(kOneofusDomain, oneofusUrl);
    FirebaseConfig.registerUrl(kNerdsterDomain, nerdsterUrl);

    FireFactory.register(kOneofusDomain, OneofusFire.firestore, null);
    FireFactory.register(kNerdsterDomain, FirebaseFirestore.instance, null);

    TrustStatement.init();
    ContentStatement.init();
  });

  testWidgets('Run Simpsons Relate Demo', (WidgetTester tester) async {
    print('Starting Simpsons Relate Demo...');

    await simpsonsRelateDemo();

    print('\n--- Demo Keys (Copy JSON for Paste Sign-In) ---');

    final characters = ['lisa', 'bart', 'homer', 'marge'];

    for (var name in characters) {
      final identityKey = DemoIdentityKey.findByName(name);
      final delegateKey = DemoDelegateKey.findByName('$name-nerdster0');

      if (identityKey != null && delegateKey != null) {
        final json = {
          'identity': await identityKey.publicKey.json,
          'nerdster.org': await delegateKey.keyPair.json,
        };

        print('\nName: $name');
        print('Credentials JSON:');
        print(jsonEncode(json));
      }
    }
    print('-----------------------------------------------\n');
    print('Demo completed successfully.');
  });
}
