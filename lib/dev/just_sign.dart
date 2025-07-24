import 'package:flutter/material.dart';
import 'package:nerdster/content/dialogs/check_signed_in.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';

class JustSign {
  static Future<void> sign(BuildContext? context) async {
  if (!bb(await checkSignedIn(context))) return;
    Json json = {
      'I': signInState.signedInDelegatePublicKeyJson,
      'greeting': '''Hello, Nerd'ster!''',
    };
    String signature = await signInState.signer!.sign(json, encoder.convert(json));
    json['signature'] = signature;
    print(encoder.convert(json));
  }
}
