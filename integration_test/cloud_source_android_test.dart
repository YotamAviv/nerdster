import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nerdster/firebase_options.dart';
import 'package:nerdster/oneofus_fire.dart';
import 'package:nerdster/config.dart';
import 'package:nerdster/fire_choice.dart';
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
    OneofusFire.firestore.useFirestoreEmulator(host, 8081);

    channelFactory = ChannelFactory(FireChoice.emulator);
    channelFactory.register(
        exportUrl: 'https://export.nerdster.org',
        functionsUrl: 'https://us-central1-nerdster.cloudfunctions.net',
        emulatorExportUrl: 'http://$host:5001/nerdster/us-central1/export',
        emulatorFunctionsUrl: 'http://$host:5001/nerdster/us-central1',
        firestore: FirebaseFirestore.instance);
    channelFactory.register(
        exportUrl: 'https://export.one-of-us.net',
        functionsUrl: 'https://us-central1-one-of-us-net.cloudfunctions.net',
        emulatorExportUrl: 'http://$host:5002/one-of-us-net/us-central1/export',
        emulatorFunctionsUrl: 'http://$host:5002/one-of-us-net/us-central1',
        firestore: OneofusFire.firestore);

    FirebaseConfig.registerRedirect(
      'https://export.one-of-us.net', 
      'http://$host:5002/one-of-us-net/us-central1/export'
    );
    FirebaseConfig.registerRedirect(
      'https://export.nerdster.org',
      'http://$host:5001/nerdster/us-central1/export'
    );
    FirebaseConfig.registerRedirect(
      'https://us-central1-nerdster.cloudfunctions.net',
      'http://$host:5001/nerdster/us-central1',
    );
    FirebaseConfig.registerRedirect(
      'https://us-central1-one-of-us-net.cloudfunctions.net',
      'http://$host:5002/one-of-us-net/us-central1',
    );
  });

  testWidgets('Cloud Source Verification', (WidgetTester tester) async {
    // We execute the cross-platform permutation tests securely inside testWidgets natively
    await runCloudSourceVerification();
  });
}
