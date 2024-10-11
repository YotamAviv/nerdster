import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:nerdster/content/content_base.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/content/content_tree.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/follow/follow_net.dart';
import 'package:nerdster/key_store.dart';
import 'package:nerdster/net/key_lables.dart';
import 'package:nerdster/net/oneofus_equiv.dart';
import 'package:nerdster/net/oneofus_net.dart';
import 'package:nerdster/oneofus/crypto/crypto.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/oneofus/fire_util.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/oneofus_fire.dart';
import 'package:nerdster/sign_in_state.dart';

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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
  String? fireCheckReadParam = params['fireCheckRead'];
  if (b(fireCheckReadParam)) {
    try {
      _fireCheckRead = bool.parse(fireCheckReadParam!);
      print('_fireCheckRead=$_fireCheckRead');
    } catch (e) {
      print(e);
    }
  }
  String? fireCheckWriteParam = params['fireCheckWrite'];
  if (b(fireCheckWriteParam)) {
    try {
      _fireCheckWrite = bool.parse(fireCheckWriteParam!);
      print('_fireCheckWrite=$_fireCheckWrite');
    } catch (e) {
      print(e);
    }
  }

  if (fireChoice != FireChoice.fake) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await OneofusFire.init();
    if (fireChoice == FireChoice.emulator) {
      // $ firebase --project=nerdster emulators:start
      FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
      // $ firebase --project=one-of-us-net -config=oneofus-nerdster.firebase.json emulators:start
      OneofusFire.oneofusFirestore.useFirestoreEmulator('localhost', 8081);
    }
    FireFactory.registerFire(kOneofusDomain, OneofusFire.oneofusFirestore);
    FireFactory.registerFire(kNerdsterDomain, FirebaseFirestore.instance);
  } else {
    FireFactory.registerFire(kOneofusDomain, FakeFirebaseFirestore());
    FireFactory.registerFire(kNerdsterDomain, FakeFirebaseFirestore());
  }
  TrustStatement.init();
  ContentStatement.init();

  if (_fireCheckWrite) {
    await checkWrite('firecheck:Nerdster-nerdster.org', FireFactory.find(kNerdsterDomain));
    await checkWrite('firecheck:Nerdster-one-of-us.net', FireFactory.find(kOneofusDomain));
  }
  if (_fireCheckRead) {
    await checkRead('firecheck:Nerdster-nerdster.org', FireFactory.find(kNerdsterDomain));
    await checkRead('firecheck:Nerdster-one-of-us.net', FireFactory.find(kOneofusDomain));
  }

  // ------------ sign in credentials ------------
  await defaultSignIn();
  ContentBase();
  OneofusNet();
  OneofusEquiv();
  FollowNet();
  KeyLabels();

  // -------------- run app ---------------
  runApp(const MaterialApp(
    home: ContentTreeView(),
    // navigatorKey: navigatorKey, // Setting a global key for navigator
    // Ddidn't work, see https://stackoverflow.com/questions/56280736/alertdialog-without-context-in-flutter
  ));
}

Future<void> defaultSignIn() async {
  String? oneofusToken;
  OouKeyPair? nerdsterKeyPair;

  // Check URL query parameters
  Map<String, String> params = Uri.base.queryParameters;
  oneofusToken = params['oneofus'];

  // Check secure browswer storage
  if (!b(oneofusToken) && fireChoice == FireChoice.prod) {
    OouPublicKey? oneofusPublicKey;
    (oneofusPublicKey, nerdsterKeyPair) = await KeyStore.readKeys();
    if (b(oneofusPublicKey)) {
      oneofusToken = Jsonish(await oneofusPublicKey!.json).token;
    }
  }

  // Check for hard coded values
  if (!b(oneofusToken) && b(hardCodedSignin[fireChoice])) {
    nerdsterKeyPair = b(hardCodedSignin[fireChoice]![kNerdsterDomain])
        ? await crypto.parseKeyPair(hardCodedSignin[fireChoice]![kNerdsterDomain]!)
        : null;
    oneofusToken = hardCodedSignin[fireChoice]![kOneofusDomain]!;
  }

  // Init the first demo
  if (!b(oneofusToken)) {
    DemoKey oneofusDemoKey;
    DemoKey? delegateDemoKey;
    (oneofusDemoKey, delegateDemoKey) = await DemoKey.demos.values.first();
    print('Loaded demo: ${DemoKey.demos.keys.first}');
    await printDemoCredentials(oneofusDemoKey, delegateDemoKey);
    oneofusToken = oneofusDemoKey.token;
    nerdsterKeyPair = (delegateDemoKey != null) ? delegateDemoKey.keyPair : null;
  }

  // SignInState.init
  SignInState.init(oneofusToken!);
  if (b(nerdsterKeyPair)) {
    await SignInState().signIn(nerdsterKeyPair!);
  }
}

dynamic hardCodedSignin = {
  FireChoice.prod: {"one-of-us.net": '2c3142d16cac3c5aeb6d7d40a4ca6beb7bd92431'},
  FireChoice.emulator: null,
// simpsons
//   FireChoice.emulator: {
//   "one-of-us.net": "1bb5e280c0cf2d336c99c515e7d2b2eb97c091b5",
//   "nerdster.org": {
//     "crv": "Ed25519",
//     "d": "CztxZ4fms_cAaZ-I6tblayVtOrh8zx_LSgwrn5S0Nfk",
//     "kty": "OKP",
//     "x": "VMBRQj3Rk-4dUOF9TejgCF_75o6JzJed9BN7WzhOvmY"
//   }
// },
//   FireChoice.fake: null,
};
