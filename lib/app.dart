import 'package:flutter/material.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/v2/nerdy_content_view.dart';
import 'package:nerdster/v2/fancy_shadow_view.dart';
import 'package:nerdster/v2/graph_demo.dart';
import 'package:nerdster/content/content_tree.dart';
import 'package:nerdster/net/net_tree.dart';
import 'package:nerdster/verify.dart';
import 'package:nerdster/setting_type.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/oneofus/jsonish.dart';
export 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/fire_choice.dart';
export 'package:nerdster/fire_choice.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/key_store.dart';
import 'package:nerdster/oneofus/crypto/crypto.dart';
import 'dart:convert';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// This doesn't work. [ContentTree] sets this using [BuildContext].
// On my Pixel 6a, size is (374.2, 713.1).
ValueNotifier<bool> isSmall = ValueNotifier<bool>(true);

String? demo;

Future<void> defaultSignIn({BuildContext? context}) async {
  // Check URL query parameters
  Map<String, String> params = Uri.base.queryParameters;
  // CONSIDER: Leverage Prefs Settings for identity/oneofus. Then again, the keys...
  String? identityParam = params['identity'];
  String? oneofusParam = params['oneofus']; // alias, deprecated.
  if (b(identityParam) || b(oneofusParam)) {
    String param = b(identityParam) ? identityParam! : oneofusParam!;
    dynamic povData;
    try {
      povData = json.decode(param);
    } catch (e) {
      povData = param;
    }
    String pov = getToken(povData);
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

Future<void> initPrefs2() async {
  final bool devDefault = fireChoice != FireChoice.prod;
  Setting.get<bool>(SettingType.showCrypto).value = devDefault;
  Setting.get<bool>(SettingType.showJson).value = devDefault;
  Setting.get<bool>(SettingType.showKeys).value = devDefault;
  Setting.get<bool>(SettingType.showStatements).value = devDefault;
  Setting.get<bool>(SettingType.dev).value = devDefault;

  // Sync showStuff with dependent settings
  Setting.get<bool>(SettingType.showCrypto).addListener(() {
    final showStuffValue = Setting.get<bool>(SettingType.showCrypto).value;
    Setting.get<bool>(SettingType.showJson).value = showStuffValue;
    Setting.get<bool>(SettingType.showKeys).value = showStuffValue;
    Setting.get<bool>(SettingType.showStatements).value = showStuffValue;
  });
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
  "x": "NOqGmF9lMMWEUL9lMWs0mZZM9BSybVplqvawUkLbwOs"
};

dynamic hardCodedSignIn = {
  // FireChoice.emulator: {'identity': yotam},
  // FireChoice.emulator: {'identity': lisaEmulator},
};

class NerdsterApp extends StatelessWidget {
  const NerdsterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      home: ListenableBuilder(
        listenable: signInState,
        builder: (context, _) {
          final path = Uri.base.path;
          final rootToken = signInState.pov;

          if (path == '/m' || path.startsWith('/m/') || path == '/m.html' || path == '/v2/phone') {
            return FancyShadowView(rootToken: rootToken);
          } else if (path == '/v2/graph') {
            return TrustGraphVisualizerLoader(rootToken: rootToken);
          } else if (path == '/legacy/content') {
            return ContentTree();
          } else if (path == '/legacy/net') {
            return NetTreeView(NetTreeView.makeRoot());
          } else if (Uri.base.queryParameters.containsKey('verifyFullScreen') &&
              b(Setting.get(SettingType.verify).value)) {
            return const StandaloneVerify();
          } else {
            // Default to NerdyContentView
            return NerdyContentView(rootToken: rootToken);
          }
        },
      ),
    );
  }
}
