import 'dart:async';
import 'dart:math';

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
  Prefs.init();
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

    // Random if yes hardcoded and no delegate
    // TODO: pick a follow context
    if (b(hardOneofus) && !b(hardDelegate)) {
      signInState.center = hardOneofus!;
      await oneofusNet.waitUntilReady();
      List<String> n = List.of(oneofusNet.network.keys);
      n.shuffle(Random(DateTime.now().millisecondsSinceEpoch));
      while (n.isNotEmpty) {
        signInState.center = n.first;
        await oneofusNet.waitUntilReady();
        if (oneofusNet.network.keys.contains(hardOneofus)) {
          await signInState.signIn(n.first, null);
          break;
        } else {
          n.removeAt(0);
        }
      }
    } else {
      await signInState.signIn(hardOneofus!, hardDelegate);
    }
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

dynamic hardCodedSignin = {
  FireChoice.prod: {"one-of-us.net": '2c3142d16cac3c5aeb6d7d40a4ca6beb7bd92431'},

  // Yotam
  // FireChoice.emulator: {"one-of-us.net": '2c3142d16cac3c5aeb6d7d40a4ca6beb7bd92431'}

  // Loner
  FireChoice.emulator: {
    "one-of-us.net": '33dddd8f0638bb617f6274f8dccdc9c4d3b754aa',
    "nerdster.org": {
      "crv": "Ed25519",
      "d": "lfnx_MYqtMYxdpznMuf9V-GfRly6UtS_MpNd2obEK_A",
      "kty": "OKP",
      "x": "yQdgsPSBj3QyOqUL7PCqxsc6UH3dMk8nzvKveG506jM"
    }
  }

  // simpsons
  // FireChoice.emulator: {
  //   "one-of-us.net": 'd466beac8a2413b897c50c84f2543d73968ec456',
  //   "nerdster.org": {
  //     "crv": "Ed25519",
  //     "d": "HXI46ZmAT8kkNp4njYDL72usUNowYOGJA4xuDanYxH4",
  //     "kty": "OKP",
  //     "x": "ZXnLr2JA8EnE89E3LKwfEQuzipUs4VBQZPESB1vWle8"
  //   }
  // }
};
