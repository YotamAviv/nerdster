import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:nerdster/firebase_options.dart';
import 'package:nerdster/oneofus_fire.dart';
import 'package:nerdster/config.dart';
import 'package:nerdster/fire_choice.dart';
import 'package:nerdster/models/content_statement.dart';
import 'package:nerdster/models/dismiss_statement.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/cases/simpsons_demo.dart';
import 'package:oneofus_common/trust_statement.dart';

import 'package:nerdster/dev/widget_runner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    if (!e.toString().contains('duplicate-app')) rethrow;
  }
  await OneofusFire.init();

  // TO RUN ON PROD: change FireChoice.emulator → FireChoice.prod and remove the
  // 4 useFirestoreEmulator/useFunctionsEmulator calls and the emulator* URL args below.
  const resolvedFireChoice = FireChoice.emulator;

  // EMULATOR ONLY — remove these 4 lines for prod:
  FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  FirebaseFunctions.instance.useFunctionsEmulator('127.0.0.1', 5001);
  OneofusFire.firestore.useFirestoreEmulator('localhost', 8081);
  OneofusFire.functions.useFunctionsEmulator('127.0.0.1', 5002);

  channelFactory = ChannelFactory(resolvedFireChoice);
  channelFactory.register(kNerdsterDomain,
      exportUrl: 'https://export.nerdster.org',
      functionsUrl: 'https://us-central1-nerdster.cloudfunctions.net',
      emulatorExportUrl: 'http://127.0.0.1:5001/nerdster/us-central1/export',
      emulatorFunctionsUrl: 'http://127.0.0.1:5001/nerdster/us-central1',
      firestore: FirebaseFirestore.instance);
  channelFactory.register(kOneofusDomain,
      exportUrl: 'https://export.one-of-us.net',
      functionsUrl: 'https://us-central1-one-of-us-net.cloudfunctions.net',
      emulatorExportUrl: 'http://127.0.0.1:5002/one-of-us-net/us-central1/export',
      emulatorFunctionsUrl: 'http://127.0.0.1:5002/one-of-us-net/us-central1',
      firestore: OneofusFire.firestore);
  channelFactory.register(kKarenetDomain,
      exportUrl: 'https://export.karennet.net',
      functionsUrl: 'https://us-central1-karennet-e4291.cloudfunctions.net',
      emulatorExportUrl: 'http://127.0.0.1:5004/karennet/us-central1/export',
      emulatorFunctionsUrl: 'http://127.0.0.1:5004/karennet/us-central1');

  if (resolvedFireChoice == FireChoice.emulator) {
    FirebaseConfig.registerRedirect('https://export.one-of-us.net',
        'http://127.0.0.1:5002/one-of-us-net/us-central1/export');
    FirebaseConfig.registerRedirect('https://export.nerdster.org',
        'http://127.0.0.1:5001/nerdster/us-central1/export');
    FirebaseConfig.registerRedirect('https://export.karennet.net',
        'http://127.0.0.1:5004/karennet/us-central1/export');
  }

  runApp(WidgetRunner(scenario: _generateDemoData));
}

Future<void> _generateDemoData() async {
  TrustStatement.init();
  ContentStatement.init();
  DismissStatement.init();
  channelFactory.clearCache();
  DemoKey.reset();

  await simpsonsDemo();

  // ignore: avoid_print
  print('===PUBLIC_KEYS_JSON_START===');
  // ignore: avoid_print
  print(DemoKey.getExportsJson());
  // ignore: avoid_print
  print('===PUBLIC_KEYS_JSON_END===');

  // ignore: avoid_print
  print('===PRIVATE_KEYS_JSON_START===');
  // ignore: avoid_print
  print(await DemoKey.getPrivateKeysJson());
  // ignore: avoid_print
  print('===PRIVATE_KEYS_JSON_END===');

  // ignore: avoid_print
  print('PASS');
}
