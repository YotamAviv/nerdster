import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:nerdster/firebase_options.dart';
import 'package:nerdster/io/fire_factory.dart';
import 'package:nerdster/io/source_factory.dart';
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

  // TO RUN ON PROD: change FireChoice.emulator → FireChoice.prod, then delete
  // the 4 useFirestoreEmulator/useFunctionsEmulator lines and the 4 registerRedirect
  // lines below (9 lines total). Keep FireFactory.register lines — they're needed for prod too.
  fireChoice = FireChoice.emulator;

  // EMULATOR ONLY — delete these 4 lines for prod:
  FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  FirebaseFunctions.instance.useFunctionsEmulator('127.0.0.1', 5001);
  OneofusFire.firestore.useFirestoreEmulator('localhost', 8081);
  OneofusFire.functions.useFunctionsEmulator('127.0.0.1', 5002);

  FireFactory.register(kNerdsterDomain, FirebaseFirestore.instance, FirebaseFunctions.instance);
  FireFactory.register(kOneofusDomain, OneofusFire.firestore, OneofusFire.functions);

  // EMULATOR ONLY — delete these 4 registerRedirect calls for prod:
  FirebaseConfig.registerRedirect(
      'https://export.one-of-us.net', 'http://127.0.0.1:5002/one-of-us-net/us-central1/export');
  FirebaseConfig.registerRedirect(
      'https://export.nerdster.org', 'http://127.0.0.1:5001/nerdster/us-central1/export');
  FirebaseConfig.registerRedirect(
      'https://us-central1-nerdster.cloudfunctions.net', 'http://127.0.0.1:5001/nerdster/us-central1');
  FirebaseConfig.registerRedirect(
      'https://us-central1-one-of-us-net.cloudfunctions.net', 'http://127.0.0.1:5002/one-of-us-net/us-central1');

  runApp(WidgetRunner(scenario: _generateDemoData));
}

Future<void> _generateDemoData() async {
  TrustStatement.init();
  ContentStatement.init();
  DismissStatement.init();
  SourceFactory.reset();
  DemoKey.reset();

  await simpsonsDemo();

  // ignore: avoid_print
  print('===DEMO_DATA_JS_START===');
  // ignore: avoid_print
  print(DemoKey.getExportsString());
  // ignore: avoid_print
  print('===DEMO_DATA_JS_END===');

  // ignore: avoid_print
  print('===PRIVATE_KEYS_JS_START===');
  // ignore: avoid_print
  print(await DemoKey.getPrivateKeysString());
  // ignore: avoid_print
  print('===PRIVATE_KEYS_JS_END===');

  // ignore: avoid_print
  print('PASS');
}
