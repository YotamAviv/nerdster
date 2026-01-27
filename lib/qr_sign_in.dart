import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:nerdster/app.dart';
import 'package:nerdster/oneofus/json_qr_display.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/util_ui.dart';
import 'package:nerdster/oneofus/ui/my_checkbox.dart';
import 'package:nerdster/sign_in_session.dart';

/// Nerdster web client / phone app QR sign-in:
/// - Create encryption key (public key token is "session").
/// - Display QR code with "Sign-in parameters" to phone.
/// - Wait for the phone app to POST data to a Cloud function that should write data
///   to a Firestore "session" column which this app should be listening to.
///
/// [domain, url, encryptionPK] => [one-of-us.net, ephemeralPK, delegateCiphertext, delegateCleartext]
final deepCollectionEquality = const DeepCollectionEquality();

Future<void> qrSignIn(BuildContext context) async {
  final ValueNotifier<bool> storeKeys = ValueNotifier<bool>(true);
  final completer = Completer<void>();

  final session = await SignInSession.create();
  // Start listening BEFORE showing dialog
  // ignore: unawaited_futures
  session.listen(
    storeKeys: storeKeys,
    onDone: () {
      if (!completer.isCompleted) {
        if (context.mounted) Navigator.of(context).pop();
        completer.complete();
      }
    },
  );

  await showDialog(
    context: context,
    builder: (_) => QrSignInDialog(forPhone: session.forPhone, storeKeys: storeKeys),
  ).then((_) {
    // If user dismissed the dialog manually, cancel listener and complete
    if (!completer.isCompleted) {
      session.cancel();
      completer.complete(); // dialog was dismissed
    }
  });

  // Wait for either listener or dialog dismissal
  await completer.future;
}

class QrSignInDialog extends StatelessWidget {
  final Json forPhone;
  final ValueNotifier<bool> storeKeys;

  const QrSignInDialog({required this.forPhone, required this.storeKeys, super.key});

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
                      JsonQrDisplay(forPhone, interpret: ValueNotifier(false)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [MyCheckbox(storeKeys, 'Store keys')],
                      )
                    ])))));
  }
}
