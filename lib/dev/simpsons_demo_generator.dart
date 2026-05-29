import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:nerdster/firebase_options.dart';
import 'package:nerdster/config.dart';
import 'package:nerdster/fire_choice.dart';
import 'package:nerdster/models/content_statement.dart';
import 'package:nerdster/models/dismiss_statement.dart';
import 'package:nerdster/models/equivalence_statement.dart';
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
  const resolvedFireChoice = FireChoice.emulator;

  FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  FirebaseFunctions.instance.useFunctionsEmulator('127.0.0.1', 5001);

  channelFactory = ChannelFactory(resolvedFireChoice);
  channelFactory.register('nerdster.org', firestore: FirebaseFirestore.instance);
  if (resolvedFireChoice == FireChoice.emulator) {
    channelFactory.registerRedirect('https://export.nerdster.org', 'http://127.0.0.1:5001/nerdster/us-central1/export');
    channelFactory.registerRedirect('https://write.nerdster.org', 'http://127.0.0.1:5001/nerdster/us-central1/write2');
    channelFactory.registerRedirect('https://export.one-of-us.net', 'http://127.0.0.1:5002/one-of-us-net/us-central1/export');
    channelFactory.registerRedirect('https://write.one-of-us.net', 'http://127.0.0.1:5002/one-of-us-net/us-central1/write2');
    channelFactory.registerRedirect('https://export.karennet.net', 'http://127.0.0.1:5004/karennet/us-central1/export');
    channelFactory.registerRedirect('https://write.karennet.net', 'http://127.0.0.1:5004/karennet/us-central1/write2');
  }

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
  EquivalenceStatement.init();
  await channelFactory.clearCache();
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
