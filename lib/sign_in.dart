import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:nerdster/bar_refresh.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/key_store.dart';
import 'package:nerdster/main.dart';
import 'package:nerdster/oneofus/crypto/crypto.dart';
import 'package:nerdster/oneofus/json_qr_display.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/ui/linky.dart';
import 'package:nerdster/oneofus/ui/my_checkbox.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';

/// This doc is a little stale as of the switch to HTTP POST.
/// Nerdster web client QR sign-in:
/// - creates a PKE keyPair and a session string for HTTP POST.
/// - show stuff to the user's phone.
/// Next listen to Firebase for writes to that session collection
/// (Firestore Cloud Function is POST'ed to by phone and writes to a Firebase collection).
/// - the user's phone packs these up and communicates them to the server (HTTP POST)
///   - Oneofus public key
///   - (optional) encrypted Nerdster key pair (optionally encrypted, iPhone App Store restrictions.)
/// - Nerdster web client then reads that from the database, (optionally) decrypts, and signs in.

Future<void> qrSignin(BuildContext context) async {
  Map<String, dynamic> forPhone = <String, dynamic>{};
  forPhone['domain'] = kNerdsterDomain;

  // Getting this to work deployed at Google Cloud functions proved as fustrating as I had anticipated.
  // Kudos: https://stackoverflow.com/questions/76306434/unpredictable-urls-with-firebase-cloud-functions-2nd-gen
  // notes that predictable URLs can still do work, but not in camelCase, yes in
  // notcamelcase, and so 'signin' (not 'signIn').
  forPhone['method'] = 'POST';
  // OLD: forPhone['uri'] = 'https://us-central1-nerdster.cloudfunctions.net/signin';
  forPhone['uri'] = 'https://signin.nerdster.org/signin';
  if (fireChoice == FireChoice.emulator) {
    forPhone['uri'] = 'http://127.0.0.1:5001/nerdster/us-central1/signin)';
  }
  // disposable PKE key pair for phone to encrypt to this web app.
  final PkeKeyPair keyPair = await crypto.createPke();
  final PkePublicKey publicKey = await keyPair.publicKey;
  final Map<String, dynamic> publicKeyJson = await publicKey.json;
  final String session = getToken(publicKeyJson);
  forPhone['session'] = session;
  forPhone['publicKey'] = publicKeyJson;

  ValueNotifier<bool> storeKeys = ValueNotifier<bool>(true);
  // ignore: unawaited_futures
  showDialog(
      context: context,
      builder: (BuildContext context) {
        Size availableSize = MediaQuery.of(context).size;
        double width = min(availableSize.width * 0.4, availableSize.height * 0.9 / 2);
        return Dialog(
            shape: RoundedRectangleBorder(borderRadius: kBorderRadius),
            child: Padding(
                padding: kPadding,
                child: SizedBox(
                    width: width,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Linky('QR code for signing in using the one-of-us.net phone app.'),
                        JsonQrDisplay(forPhone, translate: ValueNotifier(false)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            MyCheckbox(storeKeys, 'Store keys'),
                          ],
                        )
                      ],
                    ))));
      });

  // Listen for encrypted keypair to arrive at collection
  final firestore = FirebaseFirestore.instance;
  StreamSubscription? subscription;
  subscription = firestore.collection('sessions').doc('doc').collection(session).snapshots().listen(
    (QuerySnapshot<Map<String, dynamic>> docSnapshots) async {
      if (docSnapshots.docs.isEmpty) return;

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

      // Stop listening
      // ignore: unawaited_futures
      subscription!.cancel();

      // Dismiss dialog
      if (context.mounted) Navigator.of(context).pop();

      // ignore: unawaited_futures
      signIn(oneofusPublicKey, nerdsterKeyPair, storeKeys.value, context);
    },
  );
  // DEFER: delete session
}

Future<void> signIn(OouPublicKey oneofusPublicKey, OouKeyPair? nerdsterKeyPair, bool store,
    BuildContext context) async {
  if (store) {
    await KeyStore.storeKeys(oneofusPublicKey, nerdsterKeyPair);
  } else {
    await KeyStore.wipeKeys();
  }

  final String oneofusToken = getToken(await oneofusPublicKey.json);
  await signInState.signIn(oneofusToken, nerdsterKeyPair, context: context);
  await BarRefresh.refresh(context);
}

Future<void> qrSignin(BuildContext context) async {
  Map<String, dynamic> forPhone = <String, dynamic>{};
  forPhone['domain'] = kNerdsterDomain;
  forPhone['method'] = 'POST';
  forPhone['uri'] = (fireChoice == FireChoice.emulator)
      ? 'http://127.0.0.1:5001/nerdster/us-central1/signin'
      : 'https://signin.nerdster.org/signin';

  final PkeKeyPair keyPair = await crypto.createPke();
  final PkePublicKey publicKey = await keyPair.publicKey;
  final Map<String, dynamic> publicKeyJson = await publicKey.json;
  final String session = getToken(publicKeyJson);
  forPhone['session'] = session;
  forPhone['publicKey'] = publicKeyJson;

  final firestore = FirebaseFirestore.instance;
  final completer = Completer<void>();
  StreamSubscription? subscription;

  ValueNotifier<bool> storeKeys = ValueNotifier<bool>(true);

  // Start listening BEFORE showing dialog
  subscription = firestore
      .collection('sessions')
      .doc('doc') // FIXME: is 'doc' correct here? This seems placeholder-ish.
      .collection(session)
      .snapshots()
      .listen((QuerySnapshot<Map<String, dynamic>> docSnapshots) async {
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

    // Proceed with sign-in
    await signIn(oneofusPublicKey, nerdsterKeyPair, storeKeys.value, context);
  });

// chatGPT's change so that I stop listening for Firebase event if user dismisses dialog
//   // Show the dialog
//   await showDialog(
//     context: context,
//     barrierDismissible: true,
//     builder: (BuildContext context) {
//       Size availableSize = MediaQuery.of(context).size;
//       double width = min(availableSize.width * 0.4, availableSize.height * 0.9 / 2);
//       return Dialog(
//         shape: RoundedRectangleBorder(borderRadius: kBorderRadius),
//         child: Padding(
//           padding: kPadding,
//           child: SizedBox(
//             width: width,
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 const Linky('QR code for signing in using the one-of-us.net phone app.'),
//                 JsonQrDisplay(forPhone, translate: ValueNotifier(false)),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.end,
//                   children: [
//                     MyCheckbox(storeKeys, 'Store keys'),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ),
//       );
//     },
//   ).then((_) {
//     // If user dismissed the dialog manually, cancel listener and complete
//     if (!completer.isCompleted) {
//       completer.complete();
//     }
//   });

//   // Wait for either listener or dialog dismissal
//   await completer.future;
//   await subscription?.cancel(); // safe double cancel
// }
