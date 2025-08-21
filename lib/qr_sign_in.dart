import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/main.dart';
import 'package:nerdster/oneofus/crypto/crypto.dart';
import 'package:nerdster/oneofus/fetcher.dart';
import 'package:nerdster/oneofus/json_qr_display.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/ui/my_checkbox.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/sign_in_state.dart';

/// Nerdster web client / phone app QR sign-in:
/// - Create encryption key (public key token is "session").
/// - Display QR code with "Sign-in parameters" to phone.
/// - Wait for the phone app to POST data Cloud function that just writes that Firestore "session"
///   column which this app should be listening to.
///
/// V1: works fine, looks bad:
///   [domain, uri, method, publicKey, session] => [one-of-us.net, publicKey, delegateCiphertext, delegateCleartext]
/// V2: looks better:
///   [domain, url, encryptionPK] => [one-of-us.net, ephemeralPK, delegateCiphertext, delegateCleartext]
/// Can't change to V1 without breaking things as there may be phones with old versions out there.
/// Workaround is fake it:
/// - show V1 in the QR, show V2 in the text below (just for show, "bogus")
/// - teach phone to handle either and so that eventually we migrate to V2.

final deepCollectionEquality = const DeepCollectionEquality();

Future<void> qrSignIn(BuildContext context) async {
  Json forPhone = {};
  Json forPhoneV2 = {};
  forPhone['domain'] = kNerdsterDomain;
  forPhoneV2['domain'] = kNerdsterDomain;
  // Getting this to work deployed at Google Cloud functions proved as fustrating as I had anticipated.
  // Kudos: https://stackoverflow.com/questions/76306434/unpredictable-urls-with-firebase-cloud-functions-2nd-gen
  // notes that predictable URLs can still do work, but not in camelCase, yes in
  // notcamelcase, and so 'signin' (not 'signIn').

  forPhone['method'] = 'POST';
  forPhone['uri'] = 'https://signin.nerdster.org/signin';
  forPhoneV2['url'] = 'https://signin.nerdster.org/signin';
  if (fireChoice == FireChoice.emulator) {
    forPhone['uri'] = 'http://127.0.0.1:5001/nerdster/us-central1/signin';
    forPhoneV2['url'] = 'http://127.0.0.1:5001/nerdster/us-central1/signin';
  }
  // disposable PKE key pair for phone to encrypt to this web app.
  final PkeKeyPair pkeKeyPair = await crypto.createPke();
  final PkePublicKey pkePK = await pkeKeyPair.publicKey;
  var pkePKJson = await pkePK.json;
  final String session = getToken(pkePKJson);
  forPhone['session'] = session;
  forPhone['publicKey'] = pkePKJson;
  forPhoneV2['encryptionPk'] = pkePKJson;

  ValueNotifier<bool> storeKeys = ValueNotifier<bool>(true);

  final completer = Completer<void>();
  final firestore = FirebaseFirestore.instance;
  StreamSubscription? subscription;

  // Listen for encrypted keypair to arrive at collection
  // Start listening BEFORE showing dialog
  subscription = firestore.collection('sessions').doc('doc').collection(session).snapshots().listen(
    (QuerySnapshot<Json> docSnapshots) async {
      if (docSnapshots.docs.isEmpty || completer.isCompleted) return;
      completer.complete(); // signal that something arrived
      await subscription!.cancel();

      Json? data = docSnapshots.docs.first.data();

      Json? endpointJson = data['endpoint'];
      if (endpointJson != null) {
        print('got endpoint: $endpointJson');
        assert(deepCollectionEquality.equals(endpointJson, Fetcher.getEndpoint(kOneofusDomain)));
      }

      // Unpack identity public key
      final String identityKey = data.containsKey('identity') ? 'identity' : kOneofusDomain;
      Json identityJson = data[identityKey]!;
      OouPublicKey oneofusPublicKey = await crypto.parsePublicKey(identityJson);

      // Optionally unpack and decrypt Nerdster private key
      Json? delegateJson;
      OouKeyPair? nerdsterKeyPair;
      if (b(data['delegateCiphertext']) || b(data['delegateCleartext'])) {
        final String ephemeralPKKey = data.containsKey('ephemeralPK') ? 'ephemeralPK' : 'publicKey';
        PkePublicKey phonePkePublicKey = await crypto.parsePkePublicKey(data[ephemeralPKKey]);

        String? delegateCiphertext = data['delegateCiphertext'];
        String? delegateCleartext = data['delegateCleartext'];
        assert(!(b(delegateCiphertext) && b(delegateCleartext)));
        // TODO: Migrate to always encrypt, need to wait for iPhones to all be updated.
        if (b(delegateCiphertext)) {
          print('delegate key encrypted: YES');
          delegateCleartext = await pkeKeyPair.decrypt(delegateCiphertext!, phonePkePublicKey);
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
    builder: (_) =>
        QrSignInDialog(forPhone: forPhone, forPhoneBogus: forPhoneV2, storeKeys: storeKeys),
  ).then((_) {
    // If user dismissed the dialog manually, cancel listener and complete
    if (!completer.isCompleted) completer.complete(); // dialog was dismissed
  });

  // Wait for either listener or dialog dismissal
  await completer.future;
  await subscription.cancel(); // safe double cancel
}

class QrSignInDialog extends StatelessWidget {
  final Json forPhone;
  final Json forPhoneBogus;
  final ValueNotifier<bool> storeKeys;

  const QrSignInDialog(
      {required this.forPhone, required this.forPhoneBogus, required this.storeKeys, super.key});

  @override
  Widget build(BuildContext context) {
    final Size availableSize = MediaQuery.of(context).size;
    final double width = min(availableSize.width * 0.4, availableSize.height * 0.9 / 2);

    return Dialog(
        shape: RoundedRectangleBorder(borderRadius: kBorderRadius),
        child: SingleChildScrollView(
            child: Padding(
                padding: kPadding,
                child: SizedBox(
                    width: width,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('Sign-in Parameters',
                          style: TextStyle(fontSize: 20), textAlign: TextAlign.center),
                      JsonQrDisplay(forPhone,
                          bogusSubject: forPhoneBogus, interpret: ValueNotifier(false)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [MyCheckbox(storeKeys, 'Store keys')],
                      )
                    ])))));
  }
}
