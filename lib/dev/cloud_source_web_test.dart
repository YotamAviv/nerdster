import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:nerdster/firebase_options.dart';
import 'package:nerdster/io/fire_factory.dart';
import 'package:nerdster/oneofus_fire.dart';
import 'package:nerdster/config.dart';
import 'package:nerdster/models/content_statement.dart' show kNerdsterDomain;
import 'package:oneofus_common/trust_statement.dart' show kOneofusDomain;

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

  // Register the factories
  FireFactory.register(kNerdsterDomain, FirebaseFirestore.instance, FirebaseFunctions.instance);
  FireFactory.register(kOneofusDomain, OneofusFire.firestore, OneofusFire.functions);

  // Manually register redirects to point to local emulators
  FirebaseConfig.registerRedirect(
    'https://export.one-of-us.net', 
    'http://127.0.0.1:5002/one-of-us-net/us-central1/export'
  );
  FirebaseConfig.registerRedirect(
    'https://export.nerdster.org', 
    'http://127.0.0.1:5001/nerdster/us-central1/export'
  );

  runApp(WidgetRunner(
    scenario: runCloudSourceVerification,
  ));
}
