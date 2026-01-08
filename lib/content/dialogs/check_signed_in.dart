import 'package:flutter/material.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/oneofus/keys.dart';

Future<bool?> checkSignedIn(BuildContext? context, {TrustGraph? trustGraph}) async {
  String? issue;
  if (!b(signInState.delegate)) {
    issue = 'You are not signed in';
  } else if (trustGraph != null) {
    final myDelegate = signInState.delegate;
    final myIdentity = signInState.identity;

    if (trustGraph.replacements.containsKey(IdentityKey(myDelegate!))) {
      issue = 'Your delegate key is revoked';
    } else if (b(myIdentity) && trustGraph.isTrusted(IdentityKey(myIdentity!))) {
      // Check association
      bool isAssociated = false;
      final statements = trustGraph.edges[IdentityKey(myIdentity!)];
      if (statements != null) {
        for (final s in statements) {
          if (s.verb == TrustVerb.delegate && s.subjectToken == myDelegate) {
            isAssociated = true;
            break;
          }
        }
      }
      if (!isAssociated) {
        issue = 'Delegate key not associated';
      }
    }
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
