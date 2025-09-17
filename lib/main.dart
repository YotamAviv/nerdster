import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nerdster/about.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/content/content_tree.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/key_store.dart';
import 'package:nerdster/oneofus/crypto/crypto.dart';
import 'package:nerdster/oneofus/endpoint.dart';
import 'package:nerdster/oneofus/fetcher.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/oneofus/fire_util.dart';
import 'package:nerdster/oneofus/json_display.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/oneofus_fire.dart';
import 'package:nerdster/prefs.dart';
import 'package:nerdster/progress.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/verify.dart';

import 'firebase_options.dart';
import 'message_handler.dart' if (dart.library.io) 'stub_message_handler.dart';

enum FireChoice {
  fake,
  emulator,
  prod;
}

// default values, may be overwritten by query parameters
FireChoice fireChoice = FireChoice.prod;
bool _fireCheckRead = false;
bool _fireCheckWrite = false;

String? demo;

// This doesn't work. [ContentTree] sets this using [BuildContext].
// On my Pixel 6a, size is (374.2, 713.1).
ValueNotifier<bool> isSmall = ValueNotifier<bool>(true);

const domain2statementType = {
  kOneofusDomain: kOneofusType,
  kNerdsterDomain: kNerdsterType,
};

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Don't even load up Firebase if we're just showing the validate demo
  if (b(Uri.base.queryParameters['verify'])) {
    runApp(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: SafeArea(child: Verify(input: Uri.base.queryParameters['verify'])))));
    return;
  }

  // ------------ Fire ------------
  Map<String, String> params = Uri.base.queryParameters;
  String? fireParam = params['fire'];
  if (b(fireParam)) {
    try {
      fireChoice = FireChoice.values.byName(fireParam!);
      print('fire=$fireChoice');
    } catch (e) {
      print(e);
    }
  }
  if (fireChoice != FireChoice.fake) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await OneofusFire.init();
    if (fireChoice == FireChoice.emulator) {
      // $ firebase --project=nerdster emulators:start
      FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
      FirebaseFunctions.instance.useFunctionsEmulator('127.0.0.1', 5001);
      // $ firebase --project=one-of-us-net -config=oneofus.firebase.json emulators:start
      OneofusFire.firestore.useFirestoreEmulator('localhost', 8081);
      OneofusFire.functions.useFunctionsEmulator('127.0.0.1', 5002);
    }
    FireFactory.register(kNerdsterDomain, FirebaseFirestore.instance, FirebaseFunctions.instance);
    FireFactory.register(kOneofusDomain, OneofusFire.firestore, OneofusFire.functions);
  } else {
    FireFactory.register(kOneofusDomain, FakeFirebaseFirestore(), null);
    FireFactory.register(kNerdsterDomain, FakeFirebaseFirestore(), null);
  }
  _fireCheckRead = params.containsKey('fireCheckRead');
  _fireCheckWrite = params.containsKey('fireCheckWrite');
  if (_fireCheckWrite) {
    await checkWrite(FireFactory.find(kNerdsterDomain), 'firecheck: web:nerdster');
    await checkWrite(FireFactory.find(kOneofusDomain), 'firecheck: web:oneofus');
  }
  if (_fireCheckRead) {
    await checkRead(FireFactory.find(kNerdsterDomain), 'firecheck: web:nerdster');
    await checkRead(FireFactory.find(kOneofusDomain), 'firecheck: web:oneofus');
  }

  switch (fireChoice) {
    case FireChoice.fake:
      Fetcher.initEndpoint(
          kOneofusDomain, const Endpoint('http', '127.0.0.1', 'bogus/export', port: 5002));
      Fetcher.initEndpoint(
          kNerdsterDomain, const Endpoint('http', '127.0.0.1', 'bogus/export', port: 5001));
      break;
    case FireChoice.emulator:
      Fetcher.initEndpoint(kOneofusDomain,
          const Endpoint('http', '127.0.0.1', 'one-of-us-net/us-central1/export', port: 5002));
      Fetcher.initEndpoint(kNerdsterDomain,
          const Endpoint('http', '127.0.0.1', 'nerdster/us-central1/export', port: 5001));
      break;
    case FireChoice.prod:

      /// DEFER: Get export.one-of-us.net from the QR sign in process instead of having it hard-coded here.
      /// Furthermore, replace "one-of-us.net" with "identity" everywhere (for elegance only as
      /// there is no other identity... but there could be)
      Fetcher.initEndpoint(kOneofusDomain, const Endpoint('https', 'export.one-of-us.net', ''));
      Fetcher.initEndpoint(kNerdsterDomain, const Endpoint('https', 'export.nerdster.org', ''));
      break;
  }

  ProgressDialog(); // Just to get its Measure instance to be first
  Fetcher.setCorruptionCollector(baseProblemCollector);
  JsonDisplay.interpreter = keyLabels;
  TrustStatement.init();
  ContentStatement.init();
  await Prefs.init();
  await About.init();

  // ----
  // This didn't work. [ContentTree] sets this using actual width (using [BuildContext]).
  // isSmall.value = defaultTargetPlatform == TargetPlatform.iOS ||
  //     defaultTargetPlatform == TargetPlatform.android;
  isSmall.addListener(() => print('isSmall=${isSmall.value}'));

  // ----
  // Stream to communicate messages from JavaScript to Flutter
  // Add message listener
  if (kIsWeb) {
    initMessageListener();
  }

  // -------------- run app ---------------
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: ContentTree()));
}

Future<void> defaultSignIn(BuildContext context) async {
  // Check URL query parameters
  Map<String, String> params = Uri.base.queryParameters;
  // CONSIDER: Leverage Prefs Settings for identity/oneofus. Then again, the keys...
  String? identityParam = params['identity'];
  String? oneofusParam = params['oneofus']; // alias, deprecated.
  if (b(identityParam) || b(oneofusParam)) {
    Json povJson = json.decode(b(identityParam) ? identityParam! : oneofusParam!);
    String pov = getToken(povJson);
    await signInState.signIn(pov, null, context: context);
    // NEXT: signInState.pov = pov; // Add stack of visitors
    return;
  }

  if (b(params['demo'])) {
    if (fireChoice == FireChoice.prod) throw 'not on production';
    demo = params['demo']!;
    final (DemoKey identityDemoKey, DemoKey? delegateDemoKey) = await DemoKey.demos[demo]();
    String identity = identityDemoKey.token;
    OouKeyPair? nerdsterKeyPair = (delegateDemoKey != null) ? delegateDemoKey.keyPair : null;
    DemoKey.dumpDemoCredentials();
    await signInState.signIn(identity, nerdsterKeyPair, context: context);
    return;
  }

  // Check secure browswer storage
  if (fireChoice == FireChoice.prod) {
    OouPublicKey? identityPublicKey;
    OouKeyPair? nerdsterKeyPair;
    (identityPublicKey, nerdsterKeyPair) = await KeyStore.readKeys();
    // It's been annoying to not be able to sign out if I wasn't fully signed in.
    // TODO: Don't even persist identity key if I'm not fully signed in.
    if (b(identityPublicKey) && b(nerdsterKeyPair)) {
      String identity = getToken(await identityPublicKey!.json);
      await signInState.signIn(identity, nerdsterKeyPair, context: context);
      return;
    }
  }

  // Check for hard coded values
  if (b(hardCodedSignIn[fireChoice])) {
    Json identityJson = Map.of(hardCodedSignIn[fireChoice]!['identity']!);
    String identity = getToken(identityJson);
    OouKeyPair? hardDelegate = b(hardCodedSignIn[fireChoice]![kNerdsterDomain])
        ? await crypto.parseKeyPair(hardCodedSignIn[fireChoice]![kNerdsterDomain]!)
        : null;
    await signInState.signIn(identity, hardDelegate, context: context);
    return;
  }
}

const Json yotam = {
  "crv": "Ed25519",
  "kty": "OKP",
  "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
};

var lisa = {"crv": "Ed25519", "kty": "OKP", "x": "cLpFiVQn_bAXK7Yg2JW5oFyibjZXqw6fRopx8xdbRkE"};
var lisaEmulator = {
  "crv": "Ed25519",
  "kty": "OKP",
  "x": "24pUZag3dUUKPttLAyI1bv8tJBkjS6lqOa9brgnkrOw"
};

dynamic hardCodedSignIn = {
  // FireChoice.emulator: {'identity': yotam},
  FireChoice.emulator: {'identity': lisaEmulator},
};
