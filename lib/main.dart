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
import 'package:nerdster/config.dart';
import 'package:nerdster/dev/demo_setup.dart';
import 'package:nerdster/key_store.dart';
import 'package:nerdster/key_storage_coordinator.dart';
import 'package:nerdster/models/content_statement.dart';
import 'package:nerdster/models/dismiss_statement.dart';
import 'package:nerdster/models/equivalence_statement.dart';
import 'package:nerdster/oneofus_fire.dart';
import 'package:nerdster/settings/prefs.dart';
import 'package:nerdster/settings/setting_type.dart';
import 'package:nerdster/sign_in_state.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/verify.dart';

import 'package:nerdster/dev/test_runner_screen.dart';
import 'package:oneofus_common/crypto/crypto.dart';
import 'package:oneofus_common/fire_util.dart';
import 'package:oneofus_common/keys.dart' show FedKey;
import 'package:oneofus_common/trust_statement.dart';
import 'package:oneofus_common/ui/json_display.dart';

import 'firebase_options.dart';
import 'message_handler.dart' if (dart.library.io) 'stub_message_handler.dart';
import 'package:app_links/app_links.dart';

export 'package:nerdster/fire_choice.dart';

bool _fireCheckRead = false;
bool _fireCheckWrite = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // On mobile, Uri.base is not the deep-link URI — read via app_links.
  Uri startupUri = Uri.base;
  if (!kIsWeb) {
    try {
      final initialLink = await AppLinks().getInitialLinkString();
      if (initialLink != null) startupUri = Uri.parse(initialLink);
    } catch (_) {}
  }
  await Prefs.init(startupUri: startupUri);
  KeyStorageCoordinator.instance.start();

  JsonDisplay.highlightKeys = Set.unmodifiable({
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
  Map<String, String> params = startupUri.queryParameters;
  final String? fireParam = params['fire'];
  final FireChoice resolvedFireChoice = fireParam != null
      ? FireChoice.values.byName(fireParam)
      : (const String.fromEnvironment('fire') == 'emulator'
          ? FireChoice.emulator
          : FireChoice.prod);

  // On Android emulator, 10.0.2.2 reaches the host machine; web uses 127.0.0.1.
  final emulatorHost = kIsWeb ? '127.0.0.1' : '10.0.2.2';

  FirebaseFirestore nerdsterFirestore;
  FirebaseFirestore oneofusFirestore;
  FirebaseFirestore? karennetFirestore;
  if (resolvedFireChoice != FireChoice.fake) {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (e) {
      if (!e.toString().contains('duplicate-app')) rethrow;
    }
    await OneofusFire.init();
    if (resolvedFireChoice == FireChoice.emulator) {
      // $ firebase --project=nerdster emulators:start
      FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
      FirebaseFunctions.instance.useFunctionsEmulator('127.0.0.1', 5001);
      // $ firebase --project=one-of-us-net -config=oneofus.firebase.json emulators:start
      OneofusFire.firestore.useFirestoreEmulator('localhost', 8081);
      OneofusFire.functions.useFunctionsEmulator('127.0.0.1', 5002);
      // registerRedirect for FirebaseConfig.resolveUrl() used by lgtm.dart and node_details.dart.
      FirebaseConfig.registerRedirect('https://export.nerdster.org',
          'http://$emulatorHost:5001/nerdster/us-central1/export');
      FirebaseConfig.registerRedirect('https://export.one-of-us.net',
          'http://$emulatorHost:5002/one-of-us-net/us-central1/export');
      FirebaseConfig.registerRedirect('https://export.karennet.net',
          'http://$emulatorHost:5004/karennet/us-central1/export');
    }
    nerdsterFirestore = FirebaseFirestore.instance;
    oneofusFirestore = OneofusFire.firestore;
  } else {
    nerdsterFirestore = FakeFirebaseFirestore();
    oneofusFirestore = FakeFirebaseFirestore();
    karennetFirestore = FakeFirebaseFirestore();
  }

  channelFactory = ChannelFactory(resolvedFireChoice,
      skipVerify: Setting.get<bool>(SettingType.skipVerify));
  channelFactory.register('nerdster.org', firestore: nerdsterFirestore);
  channelFactory.register('one-of-us.net', firestore: oneofusFirestore);
  if (karennetFirestore != null) {
    channelFactory.register('karennet.net', firestore: karennetFirestore);
  }
  if (resolvedFireChoice == FireChoice.emulator) {
    channelFactory.registerRedirect('https://export.nerdster.org', 'http://$emulatorHost:5001/nerdster/us-central1/export');
    channelFactory.registerRedirect('https://write.nerdster.org', 'http://$emulatorHost:5001/nerdster/us-central1/write2');
    channelFactory.registerRedirect('https://export.one-of-us.net', 'http://$emulatorHost:5002/one-of-us-net/us-central1/export');
    channelFactory.registerRedirect('https://write.one-of-us.net', 'http://$emulatorHost:5002/one-of-us-net/us-central1/write2');
    channelFactory.registerRedirect('https://export.karennet.net', 'http://$emulatorHost:5004/karennet/us-central1/export');
  }

  _fireCheckRead = params.containsKey('fireCheckRead');
  _fireCheckWrite = params.containsKey('fireCheckWrite');
  if (_fireCheckWrite) {
    await checkWrite(nerdsterFirestore, 'firecheck: web:nerdster');
    await checkWrite(oneofusFirestore, 'firecheck: web:oneofus');
  }
  if (_fireCheckRead) {
    await checkRead(nerdsterFirestore, 'firecheck: web:nerdster');
    await checkRead(oneofusFirestore, 'firecheck: web:oneofus');
  }

  TrustStatement.init();
  ContentStatement.init();
  DismissStatement.init();
  EquivalenceStatement.init();
  await defaultSignIn(params: params);
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
  const bool runWidgetMode = bool.fromEnvironment('RUN_WIDGET', defaultValue: false);
  
  runWidget(View(
    view: ui.PlatformDispatcher.instance.views.first,
    child: runWidgetMode ? const TestRunnerScreen() : const NerdsterApp(),
  ));

  // Handle deep links arriving while the app is already running.
  // With singleTask launch mode, Android delivers the new intent via onNewIntent,
  // which app_links surfaces here as a uriLinkStream event.
  if (!kIsWeb) {
    AppLinks().uriLinkStream.listen((uri) {
      final p = uri.queryParameters;
      for (final setting in Setting.all) {
        setting.updateFromQueryParam(p);
      }
      defaultSignIn(params: p);
    }, onError: (_) {});
  }
}

Future<void> defaultSignIn({BuildContext? context, Map<String, String>? params}) async {
  // Check URL query parameters (deep-link URI on mobile, Uri.base on web)
  params ??= Uri.base.queryParameters;

  // Parse pov/target FedKey payloads. FedKey.fromPayload handles both old (bare JWK)
  // and new ({key, url}) formats; its constructor registers in Jsonish as a side-effect.
  // Accept both ?pov= (new) and ?identity= (legacy, for old shared links).
  String? pov;
  final String? povParam = params['pov'] ?? params['identity'];
  if (povParam != null) {
    try {
      final Json povJson = json.decode(povParam);
      final FedKey? fedKey = FedKey.fromPayload(povJson);
      if (fedKey != null) pov = fedKey.identityKey.value;
    } catch (e) {
      debugPrint('Could not parse pov from URL: $e');
    }
  }

  final String? targetParam = params['target'];
  if (targetParam != null) {
    try {
      final Json targetJson = json.decode(targetParam);
      final FedKey? fedKey = FedKey.fromPayload(targetJson);
      if (fedKey != null) startupTarget = fedKey.identityKey.value;
    } catch (e) {
      debugPrint('Could not parse target from URL: $e');
    }
  }

  SignInMethod? overrideMethod;
  String? methodParam = params['method'];
  if (methodParam != null) {
    try {
      overrideMethod = SignInMethod.values.byName(methodParam);
    } catch (e) {
      debugPrint('Invalid method override passed via URL: $methodParam');
    }
  }

  if (await tryDemoSignIn(context)) return;

  // Check secure browser storage
  if (fireChoice != FireChoice.fake) {
    OouPublicKey? identityPublicKey;
    OouKeyPair? nerdsterKeyPair;
    Map<String, dynamic> endpoint = {};
    SignInMethod? storedMethod;
    try {
      (identityPublicKey, nerdsterKeyPair, endpoint, storedMethod) = await KeyStore.readKeys()
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('KeyStore.readKeys() failed or timed out: $e');
    }

    if (overrideMethod != null) {
      storedMethod = overrideMethod;
    }

    if (identityPublicKey != null) {
      final Json identityJson = await identityPublicKey.json;
      final fedKey = FedKey(identityJson, endpoint);
      await signInState.signInWithFedKey(fedKey, nerdsterKeyPair, method: storedMethod);
    }
  }

  if (pov != null) signInState.pov = pov; // override PoV from URL param
}
