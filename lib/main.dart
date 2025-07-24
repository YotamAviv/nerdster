import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nerdster/about.dart';
import 'package:nerdster/oneofus/json_display.dart';
import 'package:nerdster/verify.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/content/content_tree.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/key_store.dart';
import 'package:nerdster/notifications.dart';
import 'package:nerdster/oneofus/crypto/crypto.dart';
import 'package:nerdster/oneofus/fetcher.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/oneofus/fire_util.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/oneofus_fire.dart';
import 'package:nerdster/prefs.dart';
import 'package:nerdster/progress.dart';
import 'package:nerdster/singletons.dart';

import 'firebase_options.dart';

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

final Corruptor corruptor = Notifications();

const Map<FireChoice, Map<String, (String, String)>> exportUrl = {
  FireChoice.prod: {
    kOneofusDomain: ('export.one-of-us.net', ''),
    kNerdsterDomain: ('export.nerdster.org', '')
  },
  FireChoice.emulator: {
    kOneofusDomain: ('127.0.0.1:5002', 'one-of-us-net/us-central1/export'),
    kNerdsterDomain: ('127.0.0.1:5001', 'nerdster/us-central1/export')
  },
};

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Don't even load up Firebase if we're just showing the validate demo
  if (b(Uri.base.queryParameters['verify'])) {
    runApp(MaterialApp(
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

  ProgressDialog(); // Just to get its Measure instance to be first
  JsonDisplay.interpreter = keyLabels;
  TrustStatement.init();
  ContentStatement.init();
  await Prefs.init();
  await About.init();

  isSmall.addListener(() => print('isSmall=${isSmall.value}'));
  // This doesn't work. [ContentTree] sets this using actual width (using [BuildContext]).
  isSmall.value = defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;

  // -------------- run app ---------------
  runApp(const MaterialApp(home: ContentTree()));
}

Future<void> defaultSignIn(BuildContext context) async {
  // Check URL query parameters
  Map<String, String> params = Uri.base.queryParameters;
  if (b(params['oneofus'])) {
    String oneofusParam = params['oneofus']!;
    Json oneofusJson = json.decode(oneofusParam);
    String oneofus = getToken(oneofusJson);
    await signInState.signIn(oneofus, null, context: context);
    return;
  }

  if (b(params['demo'])) {
    if (fireChoice == FireChoice.prod) throw "Don't create demo in production.";
    demo = params['demo']!;
    DemoKey oneofusDemoKey;
    DemoKey? delegateDemoKey;
    (oneofusDemoKey, delegateDemoKey) = await DemoKey.demos[demo]();
    String oneofus = oneofusDemoKey.token;
    OouKeyPair? nerdsterKeyPair = (delegateDemoKey != null) ? delegateDemoKey.keyPair : null;
    await signInState.signIn(oneofus, nerdsterKeyPair, context: context);
    return;
  }

  // Check secure browswer storage
  if (fireChoice == FireChoice.prod) {
    OouPublicKey? oneofusPublicKey;
    OouKeyPair? nerdsterKeyPair;
    (oneofusPublicKey, nerdsterKeyPair) = await KeyStore.readKeys();
    if (b(oneofusPublicKey)) {
      String oneofus = getToken(await oneofusPublicKey!.json);
      await signInState.signIn(oneofus, nerdsterKeyPair, context: context);
      return;
    }
  }

  // Check for hard coded values
  if (b(hardCodedSignin[fireChoice])) {
    Json oneofusJson = hardCodedSignin[fireChoice]![kOneofusDomain]!;
    String oneofus = getToken(oneofusJson);
    OouKeyPair? hardDelegate = b(hardCodedSignin[fireChoice]![kNerdsterDomain])
        ? await crypto.parseKeyPair(hardCodedSignin[fireChoice]![kNerdsterDomain]!)
        : null;
    await signInState.signIn(oneofus, hardDelegate, context: context);
    return;
  }
}

const Json yotam = {
  "crv": "Ed25519",
  "kty": "OKP",
  "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
};
dynamic hardCodedSignin = {
  FireChoice.emulator: {"one-of-us.net": yotam},
};

Json yotamForCopyPasteSignin = {
  "one-of-us.net": {
    "crv": "Ed25519",
    "kty": "OKP",
    "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
  }
};
