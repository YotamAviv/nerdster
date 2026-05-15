import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nerdster/firebase_options.dart';
import 'package:nerdster/oneofus_fire.dart';
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

  channelFactory = ChannelFactory(FireChoice.prod);
  channelFactory.register(
      exportUrl: 'https://export.nerdster.org',
      functionsUrl: 'https://us-central1-nerdster.cloudfunctions.net',
      firestore: FirebaseFirestore.instance);
  channelFactory.register(
      exportUrl: 'https://export.one-of-us.net',
      functionsUrl: 'https://us-central1-one-of-us-net.cloudfunctions.net',
      firestore: OneofusFire.firestore);
  channelFactory.register(
      exportUrl: 'https://export.karennet.net',
      functionsUrl: 'https://us-central1-karennet-e4291.cloudfunctions.net');

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
