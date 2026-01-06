import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/crypto/crypto.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/ok_cancel.dart';
import 'package:nerdster/oneofus/ui/alert.dart';
import 'package:nerdster/oneofus/ui/my_checkbox.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/sign_in_state.dart';
import 'package:nerdster/util_ui.dart';

const String kIdentity = "identity";

Future<void> pasteSignIn(BuildContext context) async {
  final ValueNotifier<bool> storeKeys = ValueNotifier<bool>(false);
  Json? credentials = await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: kBorderRadius),
            child: PasteSignInWidget(storeKeys),
          ));
  if (credentials == null) return;
  Json identityJson = credentials[kIdentity]!;
  OouPublicKey oneofusPublicKey = await crypto.parsePublicKey(identityJson);
  Json? delegateJson = credentials[kNerdsterDomain];
  OouKeyPair? nerdsterKeyPair;
  if (b(delegateJson)) {
    nerdsterKeyPair = await crypto.parseKeyPair(delegateJson!);
  }

  // ignore: unawaited_futures
  signInUiHelper(oneofusPublicKey, nerdsterKeyPair, storeKeys.value);
}

class PasteSignInWidget extends StatefulWidget {
  final ValueNotifier<bool> storeKeys;
  const PasteSignInWidget(this.storeKeys, {super.key});

  @override
  State<PasteSignInWidget> createState() => _PasteSignInWidgetState();
}

class _PasteSignInWidgetState extends State<PasteSignInWidget> {
  final TextEditingController _controller = TextEditingController();

  static const String hintText = '''
Copy/paste keys here.

Either both identity and delegate key, like this:
{
  "identity": {
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
}

Or just the identity key, like this:
{
  "crv": "Ed25519",
  "kty": "OKP",
  "x": "bODE-9iRfmIEQZ7-T4a8fVGHDBTAUbh-SXsBQG-ijkM"
}
''';

  Future<void> _okHandler() async {
    try {
      Json? identityJson;
      Json? delegateJson;

      Map<String, dynamic> credentials = jsonDecode(_controller.text);

      if (credentials.containsKey(kIdentity)) {
        // Validate...
        identityJson = credentials[kIdentity]!;
        await crypto.parsePublicKey(identityJson!);

        delegateJson = credentials[kNerdsterDomain];
        if (b(delegateJson)) {
          await crypto.parseKeyPair(delegateJson!);
          Navigator.of(context).pop({kIdentity: identityJson, kNerdsterDomain: delegateJson});
        } else {
          Navigator.of(context).pop({kIdentity: identityJson});
        }
      } else {
        await crypto.parsePublicKey(credentials);
        Navigator.of(context).pop({kIdentity: credentials});
      }
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
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                style: GoogleFonts.courierPrime(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
                decoration: const InputDecoration(
                    hintText: hintText, hintStyle: hintStyle, border: OutlineInputBorder()),
                maxLines: 25,
                controller: _controller),
            const SizedBox(height: 10),
            Row(children: [
              // left filler
              const Spacer(),
              // center OkCancel
              OkCancel(_okHandler, 'Sign in', showCancel: false),
              // right side
              Expanded(
                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  MyCheckbox(widget.storeKeys, 'Store keys'),
                ]),
              )
            ])
          ]),
        ),
      ),
    );
  }
}
