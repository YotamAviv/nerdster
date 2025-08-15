import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/main.dart';
import 'package:nerdster/oneofus/crypto/crypto.dart';
import 'package:nerdster/oneofus/json_qr_display.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/ui/linky.dart';
import 'package:nerdster/oneofus/ui/my_checkbox.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/sign_in_state.dart';

/// This doc is a little stale as of the switch to HTTP POST.
/// Nerdster web client QR sign-in:
/// - Create a PKE keyPair and a session string.
/// - Display QR code containing the public key and a session ID for user's phone to scan.
/// - Wait for the phone app to POST data to your backend (which writes to Firestore).
/// The user's phone packs these up and communicates them to the server (HTTP POST)
///   - Oneofus public key
///   - (optional) Nerdster key pair (optionally encrypted, iPhone App Store restrictions.)
/// Nerdster web client reads that from Firestore and signs in.

Future<void> qrSignIn(BuildContext context) async {
  Map<String, dynamic> forPhone = <String, dynamic>{};
  forPhone['domain'] = kNerdsterDomain;
  // Getting this to work deployed at Google Cloud functions proved as fustrating as I had anticipated.
  // Kudos: https://stackoverflow.com/questions/76306434/unpredictable-urls-with-firebase-cloud-functions-2nd-gen
  // notes that predictable URLs can still do work, but not in camelCase, yes in
  // notcamelcase, and so 'signin' (not 'signIn').
  forPhone['method'] = 'POST';
  forPhone['uri'] = 'https://signin.nerdster.org/signin';
  if (fireChoice == FireChoice.emulator) {
    forPhone['uri'] = 'http://127.0.0.1:5001/nerdster/us-central1/signin)';
  }
  // disposable PKE key pair for phone to encrypt to this web app.
  final PkeKeyPair keyPair = await crypto.createPke();
  final PkePublicKey publicKey = await keyPair.publicKey;
  final String session = getToken(await publicKey.json);
  forPhone['session'] = session;
  forPhone['publicKey'] = await publicKey.json;

  ValueNotifier<bool> storeKeys = ValueNotifier<bool>(true);

  final completer = Completer<void>();
  final firestore = FirebaseFirestore.instance;
  StreamSubscription? subscription;

  // Listen for encrypted keypair to arrive at collection
  // Start listening BEFORE showing dialog
  subscription = firestore.collection('sessions').doc('doc').collection(session).snapshots().listen(
    (QuerySnapshot<Map<String, dynamic>> docSnapshots) async {
      if (docSnapshots.docs.isEmpty || completer.isCompleted) return;
      completer.complete(); // signal that something arrived
      await subscription!.cancel();

      Map<String, dynamic>? data = docSnapshots.docs.first.data();

      // Unpack Oneofus public key
      Json identityJson = data[kOneofusDomain]!;
      OouPublicKey oneofusPublicKey = await crypto.parsePublicKey(identityJson);

      // Optionally unpack and decrypt Nerdster private key
      Json? delegateJson;
      OouKeyPair? nerdsterKeyPair;
      if (b(data['publicKey'])) {
        PkePublicKey phonePkePublicKey = await crypto.parsePkePublicKey(data['publicKey']);

        String? delegateCiphertext = data['delegateCiphertext'];
        String? delegateCleartext = data['delegateCleartext'];
        assert(!(b(delegateCiphertext) && b(delegateCleartext)));
        if (b(delegateCiphertext)) {
          print('delegate key encrypted: YES');
          delegateCleartext = await keyPair.decrypt(delegateCiphertext!, phonePkePublicKey);
        } else {
          print('delegate key encrypted: NO');
        }
        delegateJson = jsonDecode(delegateCleartext!);
        nerdsterKeyPair = await crypto.parseKeyPair(delegateJson!);
      }

      // Dismiss dialog if still open
      if (context.mounted) Navigator.of(context).pop();

      // DEFER: delete session

      await signInUiHelper(oneofusPublicKey, nerdsterKeyPair, storeKeys.value, context);
    },
  );

  await showDialog(
    context: context,
    builder: (_) => QrSignInDialog(forPhone: forPhone, storeKeys: storeKeys),
  ).then((_) {
    // If user dismissed the dialog manually, cancel listener and complete
    if (!completer.isCompleted) completer.complete(); // dialog was dismissed
  });

  // Wait for either listener or dialog dismissal
  await completer.future;
  await subscription.cancel(); // safe double cancel
}

class QrSignInDialog extends StatelessWidget {
  final Map<String, dynamic> forPhone;
  final ValueNotifier<bool> storeKeys;

  const QrSignInDialog({required this.forPhone, required this.storeKeys, super.key});

  @override
  Widget build(BuildContext context) {
    final Size availableSize = MediaQuery.of(context).size;
    final double width = min(availableSize.width * 0.4, availableSize.height * 0.9 / 2);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: kBorderRadius),
      child: Padding(
        padding: kPadding,
        child: SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Sign-in Parameters',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              Text('requesting identity and/or delegate key', textAlign: TextAlign.center),
              JsonQrDisplay(forPhone, interpret: ValueNotifier(false)),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [MyCheckbox(storeKeys, 'Store keys')],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
