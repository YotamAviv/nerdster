import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:nerdster/about.dart';
import 'package:nerdster/bar_refresh.dart';
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
import 'package:nerdster/prefs.dart';
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
  await Prefs.init();
  TrustStatement.init();
  ContentStatement.init();
  await About.init();

  if (_fireCheckWrite) {
    await checkWrite(FireFactory.find(kNerdsterDomain), 'firecheck: web:nerdster');
    await checkWrite(FireFactory.find(kOneofusDomain), 'firecheck: web:oneofus');
  }
  if (_fireCheckRead) {
    await checkRead(FireFactory.find(kNerdsterDomain), 'firecheck: web:nerdster');
    await checkRead(FireFactory.find(kOneofusDomain), 'firecheck: web:oneofus');
  }

  // ------------ sign in credentials ------------
  await defaultSignIn();
  ContentBase();
  OneofusNet();
  OneofusEquiv();
  FollowNet();
  KeyLabels();

  // Show 'loading', start the timer.
  BarRefresh.refresh();

  // -------------- run app ---------------
  runApp(const MaterialApp(
    home: ContentTreeView(),
    // navigatorKey: navigatorKey, // Setting a global key for navigator
    // Ddidn't work, see https://stackoverflow.com/questions/56280736/alertdialog-without-context-in-flutter
  ));
}

Future<void> defaultSignIn() async {
  // Check URL query parameters
  Map<String, String> params = Uri.base.queryParameters;
  if (b(params['oneofus'])) {
    await signInState.signIn(params['oneofus']!, null);
    return;
  }

  // Check secure browswer storage
  if (fireChoice == FireChoice.prod) {
    OouPublicKey? oneofusPublicKey;
    OouKeyPair? nerdsterKeyPair;
    (oneofusPublicKey, nerdsterKeyPair) = await KeyStore.readKeys();
    if (b(oneofusPublicKey)) {
      await signInState.signIn(getToken(await oneofusPublicKey!.json), nerdsterKeyPair);
      return;
    }
  }

  // Check for hard coded values
  if (b(hardCodedSignin[fireChoice])) {
    String? hardOneofus = hardCodedSignin[fireChoice]![kOneofusDomain]!;
    OouKeyPair? hardDelegate = b(hardCodedSignin[fireChoice]![kNerdsterDomain])
        ? await crypto.parseKeyPair(hardCodedSignin[fireChoice]![kNerdsterDomain]!)
        : null;
    await signInState.signIn(hardOneofus!, hardDelegate);
    return;
  }

  // Init the first demo
  DemoKey oneofusDemoKey;
  DemoKey? delegateDemoKey;
  (oneofusDemoKey, delegateDemoKey) = await DemoKey.demos.values.first();
  print('Loaded demo: ${DemoKey.demos.keys.first}');
  await printDemoCredentials(oneofusDemoKey, delegateDemoKey);
  String oneofusToken = oneofusDemoKey.token;
  OouKeyPair? nerdsterKeyPair = (delegateDemoKey != null) ? delegateDemoKey.keyPair : null;
  await signInState.signIn(oneofusToken, nerdsterKeyPair);
}

// Parts of the code use Jsonish.find(signInState.center)! to find the center public key, and so
// we call Jsonish(lonerNoDelegatePK) here in anticipation of that.
const Json dummyPublicKey = {
  "crv": "Ed25519",
  "kty": "OKP",
  "x": "f7ersaoKfgPjXh182kc2tKNxAMqT1h-I4vT2rBssR7g"
};
String dummyOneofus = Jsonish(dummyPublicKey).token;
const String yotam = '2c3142d16cac3c5aeb6d7d40a4ca6beb7bd92431';
dynamic hardCodedSignin = {
  // TEMP: FireChoice.prod: {"one-of-us.net": dummyOneofus},
  FireChoice.prod: {"one-of-us.net": yotam},

  // Yotam
  FireChoice.emulator: {"one-of-us.net": yotam}
  // FireChoice.emulator: {"one-of-us.net": dummyOneofus}

  // Loner
  // FireChoice.emulator: {
  //   "one-of-us.net": '8772bb811c3a48abe68a9d0cc6910e0321df769a',
  //   "nerdster.org": {
  //     "crv": "Ed25519",
  //     "d": "vdY5zLTyfdjz8uOQxJoMOro9ZzMGhxrsH-l0lEc0gx8",
  //     "kty": "OKP",
  //     "x": "_MdFUWv9CYe6VY270cQIpsidBp3HfqLzvLIzj6xYhLA"
  //   }
  // }

  // simpsons
  // FireChoice.emulator: {
  // }
};

// simpsons PROD
String bart = '163d570bdbcdb84c78ec4138813569e773806d8b';
var bartKeys = {
  "one-of-us.net": {
    "crv": "Ed25519",
    "kty": "OKP",
    "x": "dm2mW57IpaFWBDvCl9zDZz6okLB26kDVZzVqEc0tDTc"
  },
  "nerdster.org": {
    "crv": "Ed25519",
    "d": "NWraRSnhWNwi-35aANivWYtBgRWmryPiDtN_CaxDvPA",
    "kty": "OKP",
    "x": "3X_v6Zlxztv85f202TZ8BsxM8OAWgta8Bu_vjoSa-LI"
  }
};
var lisaWithWrongDelegateBart = {
  "one-of-us.net": {
    "crv": "Ed25519",
    "kty": "OKP",
    "x": "DbUGydInoa0RAVZIzVZCpS2LhzbqVTQfOMxgGzct1rU"
  },
  "nerdster.org": {
    "crv": "Ed25519",
    "d": "NWraRSnhWNwi-35aANivWYtBgRWmryPiDtN_CaxDvPA",
    "kty": "OKP",
    "x": "3X_v6Zlxztv85f202TZ8BsxM8OAWgta8Bu_vjoSa-LI"
  }
};
var bartFullKeys = {
  "one-of-us.net": {
    "crv": "Ed25519",
    "d": "vb_axJuiskCfxKBLONtbFRTf8qRukxW73Urc2AZ6LeQ",
    "kty": "OKP",
    "x": "dm2mW57IpaFWBDvCl9zDZz6okLB26kDVZzVqEc0tDTc"
  },
  "nerdster.org": {
    "crv": "Ed25519",
    "d": "NWraRSnhWNwi-35aANivWYtBgRWmryPiDtN_CaxDvPA",
    "kty": "OKP",
    "x": "3X_v6Zlxztv85f202TZ8BsxM8OAWgta8Bu_vjoSa-LI"
  }
};
