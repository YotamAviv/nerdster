import 'package:flutter/material.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';

Future<bool?> checkSignedIn(BuildContext? context) async {
  if (b(signInState.signedInDelegate)) return true;
  if (!b(context)) return false;
  return showDialog<bool>(
      context: context!,
      barrierDismissible: false,
      builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: kBorderRadius),
          child: Padding(
              padding: kPadding,
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('You are not signed in'),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Okay'),
                    )
                  ]))));
}
