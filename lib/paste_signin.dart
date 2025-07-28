import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/crypto/crypto.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/ok_cancel.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/ui/alert.dart';
import 'package:nerdster/oneofus/ui/my_checkbox.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/sign_in.dart';
import 'package:nerdster/util_ui.dart';

Future<void> pasteSignin(BuildContext context) async {
  final ValueNotifier<bool> storeKeys = ValueNotifier<bool>(false);
  Json credentials = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: kBorderRadius),
            child: PasteSigninWidget(storeKeys),
          ));

  Json identityJson = credentials[kOneofusDomain]!;
  OouPublicKey oneofusPublicKey = await crypto.parsePublicKey(identityJson);
  Json? delegateJson = credentials[kNerdsterDomain];
  OouKeyPair? nerdsterKeyPair;
  if (b(delegateJson)) {
    nerdsterKeyPair = await crypto.parseKeyPair(delegateJson!);
  }

  // ignore: unawaited_futures
  signIn(oneofusPublicKey, nerdsterKeyPair, storeKeys.value, context);
}


class PasteSigninWidget extends StatefulWidget {
  final ValueNotifier<bool> storeKeys;
  const PasteSigninWidget(this.storeKeys, {super.key});

  @override
  State<PasteSigninWidget> createState() => _PasteSigninWidgetState();
}

class _PasteSigninWidgetState extends State<PasteSigninWidget> {
  final TextEditingController _controller = TextEditingController();

  static const String hintText = '''
Those without the phone app can sign by copy/pasting their keys here.
Nerd'ster will need:
- one-of-us.org public key for centering the network around you
- nerdster.org delegate key pair for signing statements (optional)
(In case you only include the one-of-us.net public key, you'll be centered but not signed in.)
The text to copy/paste here should look like this:
{
  "one-of-us.net": {
    "crv": "Ed25519",
    "kty": "OKP",
    "x": "bODE-9iRfmIEQZ7-T4a8fVGHDBTAUbh-SXsBQG-ijkM"
  },
  "nerdster.org": {
    "crv": "Ed25519",
    "d": "ixMCCV8IdUenIY-7XUKrucUdS5jV8X1_mc2FVUDhRZQ",
    "kty": "OKP",
    "x": "jP0DVnxJc1E1cuGtsCmG__zNjSmUylXw3Q0CzGV8tSE"
  }
}''';

  Future<void> _okHandler() async {
    try {
      Map<String, dynamic> credentials = jsonDecode(_controller.text);

      // Validate here, duplicated by caller of dialog.
      Json identityJson = credentials[kOneofusDomain]!;
      await crypto.parsePublicKey(identityJson);
      Json? delegateJson = credentials[kNerdsterDomain];
      if (b(delegateJson)) {
        await crypto.parseKeyPair(delegateJson!);
      }

      Navigator.of(context).pop(credentials);
    } catch (exception) {
      alertException(context, exception);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: kPadding,
        child: SizedBox(
          width: MediaQuery.of(context).size.width / 2,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  hintText: hintText,
                  hintStyle: hintStyle,
                  border: OutlineInputBorder(),
                ),
                maxLines: 20,
                controller: _controller,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OkCancel(_okHandler, 'Sign in'),
                  MyCheckbox(widget.storeKeys, 'Store keys'),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
