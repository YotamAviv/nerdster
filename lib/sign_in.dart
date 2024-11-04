import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/key_store.dart';
import 'package:nerdster/oneofus/ui/my_checkbox.dart';
import 'package:nerdster/oneofus/crypto/crypto.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/ok_cancel.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/ui/alert.dart';
import 'package:nerdster/oneofus/ui/linky.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/sign_in_state.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Nerdster web client QR sign-in:
/// - creates a PKE keyPair (and a session string (for a Firestore collection, but could be for HTTP POST instead).
/// - show these to the user's phone:
///   - the PKE public key
///   - host: nerdster.org
///   - method: Firebase
/// Next listen to Firebase for writes to that session.
/// - the user's phone packs these up and communicates them to the server
///   (Fire collection in our case, but could be HTTP POST)
///   - (optiona) encrypted Nerdster key pair
///   - Oneofus public key
/// - Nerdster web client can now read that from the database, decrypt it, and use it for the session.
Future<void> qrSignin(BuildContext context) async {
  Map<String, dynamic> forPhone = <String, dynamic>{};
  forPhone['domain'] = kNerdsterDomain;
  forPhone['method'] = 'Firestore';

  // Create a disposable PKE key pair for having phone encrypt stuff to this running web app.
  final PkeKeyPair keyPair = await crypto.createPke();
  final PkePublicKey publicKey = await keyPair.publicKey;
  final Map<String, dynamic> publicKeyJson = await publicKey.json;
  forPhone['publicKey'] = publicKeyJson;
  // Name a "session"
  final String session = Jsonish(publicKeyJson).token;
  forPhone['session'] = session;
  ValueNotifier<bool> storeKeys = ValueNotifier<bool>(false);
  // ignore: unawaited_futures
  showDialog(
      context: context,
      builder: (BuildContext context) {
        final String forPhoneString = encoder.convert(forPhone);
        return Dialog(
            child: Padding(
                padding: const EdgeInsets.all(15),
                child: SizedBox(
                    width: (MediaQuery.of(context).size).width / 2,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Linky('QR code for signing in using the one-of-us.net phone app.'),
                        QrImageView(
                          data: forPhoneString,
                          version: QrVersions.auto,
                          size: 300.0,
                        ),
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            TextField(
                                controller: TextEditingController()..text = forPhoneString,
                                maxLines: 10,
                                readOnly: true,
                                style: GoogleFonts.courierPrime(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: Colors.black)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                MyCheckbox(storeKeys, 'Store keys'),
                                FloatingActionButton(
                                    heroTag: 'Copy',
                                    tooltip: 'Copy',
                                    child: const Icon(Icons.copy),
                                    onPressed: () async {
                                      await Clipboard.setData(ClipboardData(text: forPhoneString));
                                    }),
                              ],
                            )
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
      if (docSnapshots.docs.isEmpty) {
        return;
      }
      Map<String, dynamic>? data = docSnapshots.docs.first.data();

      // Unpack Oneofus public key
      OouPublicKey oneofusPublicKey = await crypto.parsePublicKey(data[kOneofusDomain]);

      // optionally unpack and decrypt Nerdster private key
      OouKeyPair? nerdsterKeyPair;
      if (b(data['publicKey'])) {
        PkePublicKey phonePkePublicKey = await crypto.parsePkePublicKey(data['publicKey']);
        String? delegateCiphertext = data['delegateCiphertext'];
        if (b(delegateCiphertext)) {
          String delegateCleartext = await keyPair.decrypt(delegateCiphertext!, phonePkePublicKey);
          nerdsterKeyPair = await crypto.parseKeyPair(jsonDecode(delegateCleartext));
        }
      }

      // Center and optionally sign in
      SignInState state = SignInState();
      state.center = getToken(await oneofusPublicKey.json);
      if (b(nerdsterKeyPair)) {
        await state.signIn(nerdsterKeyPair!);
        if (storeKeys.value) {
          await KeyStore.storeKeys(oneofusPublicKey, nerdsterKeyPair);
        }
      }

      // Stop listening
      // ignore: unawaited_futures
      subscription!.cancel();

      // Dismiss dialog
      if (context.mounted) Navigator.of(context).pop();
    },
  );
  // DEFER: delete session
}

Future<void> pasteSignin(BuildContext context) async {
  final TextEditingController controller = TextEditingController();
  final ValueNotifier<bool> storeKeys = ValueNotifier<bool>(false);

  const String hintText = '''
Those without the phone app can sign by copy/pasting their keys in here.
Nerd'ster will need:
- nerdster.org delegate key pair for signing statements.
- one-of-us.org public key for centering the network around you.
(In case you only include the one-of-us.net public key, you'll be centered but not signed in.)
The text to copy/paste here should like like this:
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

  Future<void> okHandler() async {
    try {
      Map<String, dynamic> json = jsonDecode(controller.text);
      OouKeyPair? nerdsterKeyPair;
      if (json[kNerdsterDomain] != null) {
        nerdsterKeyPair = await crypto.parseKeyPair(json[kNerdsterDomain]!);
      }
      OouPublicKey oneofusPublicKey = await crypto.parsePublicKey(json[kOneofusDomain]!);

      if (storeKeys.value) {
        await KeyStore.storeKeys(oneofusPublicKey, nerdsterKeyPair);
      }

      // Center and optinally sign in
      SignInState state = SignInState();
      state.center = Jsonish(await oneofusPublicKey.json).token;
      if (b(nerdsterKeyPair)) {
        await state.signIn(nerdsterKeyPair!);
      }

      Navigator.pop(context);
    } catch (exception) {
      return alertException(context, exception);
    }
  }

  await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => Dialog(
          child: SingleChildScrollView(
              child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: SizedBox(
                      width: (MediaQuery.of(context).size).width / 2,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            // scrollController: scrollController,
                            decoration: const InputDecoration(
                                hintText: hintText,
                                hintStyle: hintStyle,
                                border: OutlineInputBorder()),
                            maxLines: 20,
                            controller: controller,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              OkCancel(okHandler, 'Sign in'),
                              MyCheckbox(storeKeys, 'Store keys'),
                            ],
                          )
                        ],
                      ))))));
}
