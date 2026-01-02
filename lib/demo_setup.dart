import 'package:flutter/material.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/fire_choice.dart';
import 'package:nerdster/oneofus/crypto/crypto.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';

String? demo;

Future<bool> tryDemoSignIn(BuildContext? context, {String? pov}) async {
  Map<String, String> params = Uri.base.queryParameters;
  if (b(params['demo'])) {
    if (fireChoice == FireChoice.prod) throw 'not on production';
    demo = params['demo']!;
    final (DemoKey identityDemoKey, DemoKey? delegateDemoKey) = await DemoKey.demos[demo]();
    String identity = identityDemoKey.token;
    OouKeyPair? nerdsterKeyPair = (delegateDemoKey != null) ? delegateDemoKey.keyPair : null;
    DemoKey.dumpDemoCredentials();
    await signInState.signIn(identity, nerdsterKeyPair, context: context);
    if (pov != null) signInState.pov = pov;
    return true;
  }
  return false;
}
