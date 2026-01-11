import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nerdster/about.dart';
import 'package:nerdster/app.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/demo_setup.dart';
import 'package:nerdster/key_store.dart';
import 'package:nerdster/oneofus/crypto/crypto.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/oneofus/fire_util.dart';
import 'package:nerdster/v2/json_display.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/oneofus_fire.dart';
import 'package:nerdster/setting_type.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/v2/config.dart';
import 'package:nerdster/verify.dart';

import 'firebase_options.dart';
import 'message_handler.dart' if (dart.library.io) 'stub_message_handler.dart';

export 'package:nerdster/fire_choice.dart';

bool _fireCheckRead = false;
bool _fireCheckWrite = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Prefs.init();

  V2JsonDisplay.highlightKeys = Set.unmodifiable({
    'I',
    'moniker',
    'domain',
    'encryptionPk',
    'url',
    ...TrustVerb.values.map((e) => e.label),
    ...ContentVerb.values.map((e) => e.label),
  });
  Verify.highlightKeys = Set.unmodifiable({
    'I',
    'moniker',
    'domain',
    ...TrustVerb.values.map((e) => e.label),
    ...ContentVerb.values.map((e) => e.label),
  });

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
      break;
    case FireChoice.emulator:
      const oneofusUrl = 'http://127.0.0.1:5002/one-of-us-net/us-central1/export';
      const nerdsterUrl = 'http://127.0.0.1:5001/nerdster/us-central1/export';
      V2Config.registerUrl(kOneofusDomain, oneofusUrl);
      V2Config.registerUrl(kNerdsterDomain, nerdsterUrl);
      break;
    case FireChoice.prod:

      /// DEFER: Get export.one-of-us.net from the QR sign in process instead of having it hard-coded here.
      /// Furthermore, replace "one-of-us.net" with "identity" everywhere (for elegance only as
      /// there is no other identity... but there could be)
      const oneofusUrl = 'https://export.one-of-us.net';
      const nerdsterUrl = 'https://export.nerdster.org';
      V2Config.registerUrl(kOneofusDomain, oneofusUrl);
      V2Config.registerUrl(kNerdsterDomain, nerdsterUrl);
      break;
  }

  TrustStatement.init();
  ContentStatement.init();
  await defaultSignIn();
  await initPrefs2();
  await About.init();

  // ----
  // Stream to communicate messages from JavaScript to Flutter
  // Add message listener
  if (kIsWeb) {
    initMessageListener();
  }

  // Gemini: Use runWidget with a View wrapper to support multi-view mode (e.g. embedding in iframes)
  // and avoid "Bad state: The app requested a view, but the platform did not provide one" errors.
  // This explicitly provides the view from PlatformDispatcher.
  runWidget(View(
    view: ui.PlatformDispatcher.instance.views.first,
    child: const NerdsterApp(),
  ));
}

Future<void> defaultSignIn({BuildContext? context}) async {
  // Check URL query parameters
  Map<String, String> params = Uri.base.queryParameters;
  String? identityParam = params['identity'];
  String? oneofusParam = params['oneofus']; // alias, deprecated.
  String? pov;
  if (b(identityParam) || b(oneofusParam)) {
    Json povJson = json.decode(b(identityParam) ? identityParam! : oneofusParam!);
    pov = getToken(povJson);
  }

  if (await tryDemoSignIn(context, pov: pov)) return;

  // Check secure browser storage
  if (fireChoice != FireChoice.fake) {
    OouPublicKey? identityPublicKey;
    OouKeyPair? nerdsterKeyPair;
    (identityPublicKey, nerdsterKeyPair) = await KeyStore.readKeys();
    if (b(identityPublicKey) && b(nerdsterKeyPair)) {
      String identity = getToken(await identityPublicKey!.json);
      await signInState.signIn(identity, nerdsterKeyPair);
      if (pov != null) signInState.pov = pov;
      return;
    }
  }

  // If we have a POV from the URL but no keys, sign in as that identity (view-only)
  if (pov != null) {
    await signInState.signIn(pov, null);
    return;
  }
}

Future<void> initPrefs2() async {
  final bool devDefault = fireChoice != FireChoice.prod;
  Setting.get<bool>(SettingType.showCrypto).value = devDefault;
  Setting.get<bool>(SettingType.dev).value = devDefault;
}
