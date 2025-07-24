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
import 'package:nerdster/oneofus/ok_cancel.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/ui/alert.dart';
import 'package:nerdster/oneofus/ui/linky.dart';
import 'package:nerdster/oneofus/ui/my_checkbox.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/util_ui.dart';

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
///
/// DEFER: Add floating paste icon

class CredentialsWidget extends StatelessWidget {
  final Json? identityJson;
  final Json? delegateJson;

  const CredentialsWidget(this.identityJson, this.delegateJson, {super.key});

  @override
  Widget build(BuildContext context) {
    Size whole = MediaQuery.of(context).size;
    double w = whole.width / 4;
    double h = w * 3 / 2;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          Column(
            children: [
              Text('Identity'),
              SizedBox(width: w, height: h, child: JsonQrDisplay(identityJson))
            ],
          ),
          Column(
            children: [
              Text('Nerdster delegate'),
              SizedBox(width: w, height: h, child: JsonQrDisplay(delegateJson))
            ],
          )
        ]),
      ],
    );
  }
}

// DEFER: Move to file
// ChatGPT: "How do I place a dialog at the top right?"
void showTopRightDialog(BuildContext context, Widget content) {
  final overlay = Overlay.of(context);
  late OverlayEntry overlayEntry;

  overlayEntry = OverlayEntry(
    builder: (context) {
      return Stack(
        children: [
          // Transparent barrier to dismiss the dialog
          Positioned.fill(
            child: GestureDetector(
                onTap: () => overlayEntry.remove(),
                behavior: HitTestBehavior.translucent,
                child: Container(color: Colors.transparent)),
          ),

          // Your custom dialog content at top-right
          Positioned(
            top: 45,
            right: 5,
            child: Material(
              elevation: 8,
              borderRadius: kBorderRadius,
              child: Container(
                padding: kPadding,
                decoration: BoxDecoration(borderRadius: kBorderRadius),
                child: content,
              ),
            ),
          ),
        ],
      );
    },
  );

  overlay.insert(overlayEntry);
}

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
                        JsonQrDisplay(forPhone),
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
