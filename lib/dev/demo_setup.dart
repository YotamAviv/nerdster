import 'package:flutter/material.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/fire_choice.dart';
import 'package:oneofus_common/crypto/crypto.dart';
import 'package:nerdster/singletons.dart';

String? demo;

// To run SimpsonsDemo on PROD:
// - Comment out the line that prohibits it ('not on production') in menus.dart
// - http://localhost:43649/?dev=true
// - Use the DEV menu to run simpsonsDemo
// - Copy the text that pops up and save that to web/common/data/demoData.js, probably in all 3 projects.

Future<bool> tryDemoSignIn(BuildContext? context) async {
  Map<String, String> params = Uri.base.queryParameters;
  if (params['demo'] != null) {
    if (fireChoice == FireChoice.prod) throw 'not on production';
    demo = params['demo']!;
    final (DemoKey identityDemoKey, DemoKey? delegateDemoKey) = await DemoKey.demos[demo]();
    String identity = identityDemoKey.token;
    OouKeyPair? nerdsterKeyPair = (delegateDemoKey != null) ? delegateDemoKey.keyPair : null;
    DemoKey.dumpDemoCredentials();
    await signInState.signIn(identity, nerdsterKeyPair);
    return true;
  }
  return false;
}
