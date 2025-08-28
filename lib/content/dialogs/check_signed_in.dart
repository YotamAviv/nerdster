import 'package:flutter/material.dart';
import 'package:nerdster/notifications.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';

/// TODO: Conditions:
/// - signInState.signedInDelegate
/// - signInState.signedInDelegate associated with signInState.centerReset
/// - signInState.signedInDelegate not revoked
/// Side effects:
/// - myDelegateStatements is ready
Future<bool?> checkSignedIn(BuildContext? context) async {
  String? issue;
  if (!b(signInState.signedInDelegate)) {
    issue = 'You are not signed in';
  } else {
    await delegateCheck.waitUntilReady();
    issue = delegateCheck.issue.value?.title;
  }

  if (!b(issue)) return true;

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
                    Text(issue!),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Okay'),
                    )
                  ]))));
}
