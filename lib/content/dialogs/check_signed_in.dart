import 'package:flutter/material.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';

Future<bool?> checkSignedIn(BuildContext? context) async {
  String? issue;
  if (!b(signInState.delegate)) {
    issue = 'You are not signed in';
  }

  if (!b(issue)) return true;

  if (!b(context)) return false;
  return showDialog<bool>(
      context: context!,
      barrierDismissible: true,
      builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: kBorderRadius),
          child: Padding(
              padding: kPadding,
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(issue!),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Okay'),
                    )
                  ]))));
}
