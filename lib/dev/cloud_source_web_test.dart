import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:nerdster/firebase_options.dart';
import 'package:nerdster/fire_choice.dart';
import 'package:nerdster/oneofus_fire.dart';
import 'package:nerdster/config.dart';

import 'package:nerdster/dev/widget_runner.dart';
import 'package:nerdster/dev/cloud_source_suite.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    if (!e.toString().contains('duplicate-app')) rethrow;
  }
  await OneofusFire.init();

  // Route entirely to localhost emulators for testing
  FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  FirebaseFunctions.instance.useFunctionsEmulator('127.0.0.1', 5001);
  OneofusFire.firestore.useFirestoreEmulator('localhost', 8081);
  OneofusFire.functions.useFunctionsEmulator('127.0.0.1', 5002);

  channelFactory = ChannelFactory(FireChoice.emulator);
  channelFactory.register('nerdster.org', firestore: FirebaseFirestore.instance);
  channelFactory.register('one-of-us.net', firestore: OneofusFire.firestore);
  channelFactory.registerRedirect('https://export.nerdster.org', 'http://127.0.0.1:5001/nerdster/us-central1/export');
  channelFactory.registerRedirect('https://write.nerdster.org', 'http://127.0.0.1:5001/nerdster/us-central1/write2');
  channelFactory.registerRedirect('https://export.one-of-us.net', 'http://127.0.0.1:5002/one-of-us-net/us-central1/export');
  channelFactory.registerRedirect('https://write.one-of-us.net', 'http://127.0.0.1:5002/one-of-us-net/us-central1/write2');

  // Manually register redirects to point to local emulators
  FirebaseConfig.registerRedirect(
    'https://export.one-of-us.net', 
    'http://127.0.0.1:5002/one-of-us-net/us-central1/export'
  );
  FirebaseConfig.registerRedirect(
    'https://export.nerdster.org',
    'http://127.0.0.1:5001/nerdster/us-central1/export'
  );
  FirebaseConfig.registerRedirect(
    'https://us-central1-nerdster.cloudfunctions.net',
    'http://127.0.0.1:5001/nerdster/us-central1',
  );
  FirebaseConfig.registerRedirect(
    'https://us-central1-one-of-us-net.cloudfunctions.net',
    'http://127.0.0.1:5002/one-of-us-net/us-central1',
  );

  runApp(WidgetRunner(
    scenario: runCloudSourceVerification,
  ));
}
