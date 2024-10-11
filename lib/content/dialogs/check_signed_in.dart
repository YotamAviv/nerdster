import 'package:flutter/material.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/sign_in_state.dart';

Future<bool?> checkSignedIn(BuildContext context) async {
  if (b(SignInState().signedInDelegate)) {
    return true;
  }
  return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
          child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('You are not signed in'),
                    OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context, false);
                      },
                      child: const Text('Okay'),
                    )
                  ]))));
}
