import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nerdster/models/content_statement.dart';
import 'package:oneofus_common/crypto/crypto.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/keys.dart' show FedKey;
import 'package:nerdster/ui/util/ok_cancel.dart';
import 'package:nerdster/ui/util/alert.dart';
import 'package:oneofus_common/crypto/crypto25519.dart';
import 'package:nerdster/sign_in_state.dart';
import 'package:nerdster/ui/util_ui.dart';

const String kIdentity = "identity";

Future<void> pasteSignIn(BuildContext context, {required ValueNotifier<bool> storeKeys}) async {
  Json? credentials = await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: PasteSignInWidget(),
          ));
  if (credentials == null) return;
  final Json identityPayload = credentials[kIdentity]!;
  final FedKey fedKey = FedKey.fromPayload(identityPayload) ?? FedKey(identityPayload);
  OouPublicKey oneofusPublicKey = await crypto.parsePublicKey(fedKey.pubKeyJson);
  Json? delegateJson = credentials[kNerdsterDomain];
  OouKeyPair? nerdsterKeyPair;
  if (delegateJson != null) {
    nerdsterKeyPair = await crypto.parseKeyPair(delegateJson);
  }

  signInUiHelper(oneofusPublicKey, nerdsterKeyPair, storeKeys.value, endpoint: fedKey.endpoint);
}

class PasteSignInWidget extends StatefulWidget {
  const PasteSignInWidget({super.key});

  @override
  State<PasteSignInWidget> createState() => _PasteSignInWidgetState();
}

class _PasteSignInWidgetState extends State<PasteSignInWidget> {
  final TextEditingController _controller = TextEditingController();

  static const String hintText = '''
Copy/paste keys here.

Identity and delegate key pair:
{
  "identity": {
    "key": {
      "crv": "Ed25519",
      "kty": "OKP",
      "x": "bODE-9iRfmIEQZ7-T4a8fVGHDBTAUbh-SXsBQG-ijkM"
    },
    "url": "https://export.one-of-us.net"
  },
  "nerdster.org": {
    "crv": "Ed25519",
    "d": "ixMCCV8IdUenIY-7XUKrucUdS5jV8X1_mc2FVUDhRZQ",
    "kty": "OKP",
    "x": "jP0DVnxJc1E1cuGtsCmG__zNjSmUylXw3Q0CzGV8tSE"
  }
}

Identity only:
{
  "key": {
    "crv": "Ed25519",
    "kty": "OKP",
    "x": "bODE-9iRfmIEQZ7-T4a8fVGHDBTAUbh-SXsBQG-ijkM"
  },
  "url": "https://export.one-of-us.net"
}

Legacy non-federated identity okay, too:
{
  "identity": {
    "crv": "Ed25519",
    "kty": "OKP",
    "x": "bODE-9iRfmIEQZ7-T4a8fVGHDBTAUbh-SXsBQG-ijkM"
  }
}
''';

  Future<void> _okHandler() async {
    try {
      Json? identityJson;
      Json? delegateJson;

      Json credentials = jsonDecode(_controller.text);

      if (credentials.containsKey(kIdentity)) {
        identityJson = credentials[kIdentity]!;
        final FedKey fedKey = FedKey.fromPayload(identityJson!) ?? FedKey(identityJson);
        await crypto.parsePublicKey(fedKey.pubKeyJson);
        identityJson = fedKey.pubKeyJson;

        delegateJson = credentials[kNerdsterDomain];
        if (delegateJson != null) {
          await crypto.parseKeyPair(delegateJson);
          Navigator.of(context).pop({kIdentity: identityJson, kNerdsterDomain: delegateJson});
        } else {
          Navigator.of(context).pop({kIdentity: identityJson});
        }
      } else {
        // Bare key or {key, url} at top level
        final FedKey fedKey = FedKey.fromPayload(credentials) ?? FedKey(credentials);
        await crypto.parsePublicKey(fedKey.pubKeyJson);
        Navigator.of(context).pop({kIdentity: fedKey.pubKeyJson});
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
            OkCancel(_okHandler, 'Sign in', showCancel: false),
          ]),
        ),
      ),
    );
  }
}
