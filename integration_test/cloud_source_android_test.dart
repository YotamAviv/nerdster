import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:nerdster/firebase_options.dart';
import 'package:nerdster/io/fire_factory.dart';
import 'package:nerdster/oneofus_fire.dart';
import 'package:nerdster/config.dart';
import 'package:nerdster/models/content_statement.dart' show kNerdsterDomain;
import 'package:oneofus_common/trust_statement.dart' show kOneofusDomain;
import 'package:nerdster/dev/cloud_source_suite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (e) {
      if (!e.toString().contains('duplicate-app')) rethrow;
    }
    await OneofusFire.init();

    final host = defaultTargetPlatform == TargetPlatform.android ? '10.0.2.2' : '127.0.0.1';

    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
    OneofusFire.firestore.useFirestoreEmulator(host, 8081);
    OneofusFire.functions.useFunctionsEmulator(host, 5002);

    FireFactory.register(kNerdsterDomain, FirebaseFirestore.instance, FirebaseFunctions.instance);
    FireFactory.register(kOneofusDomain, OneofusFire.firestore, OneofusFire.functions);

    FirebaseConfig.registerRedirect(
      'https://export.one-of-us.net', 
      'http://$host:5002/one-of-us-net/us-central1/export'
    );
    FirebaseConfig.registerRedirect(
      'https://export.nerdster.org', 
      'http://$host:5001/nerdster/us-central1/export'
    );
  });

  testWidgets('Cloud Source Verification', (WidgetTester tester) async {
    // We execute the cross-platform permutation tests securely inside testWidgets natively
    await runCloudSourceVerification();
  });
}
