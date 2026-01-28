import 'package:flutter/material.dart';
import 'package:nerdster/singletons.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:nerdster/models/model.dart';
import 'package:oneofus_common/keys.dart';
import 'package:nerdster/util_ui.dart';

Future<bool?> checkSignedIn(BuildContext? context, {TrustGraph? trustGraph}) async {
  String? issue;
  if (signInState.delegate == null) {
    issue = 'You are not signed in';
  } else if (trustGraph != null) {
    final myDelegate = signInState.delegate;
    final myIdentity = signInState.identity;

    if (trustGraph.replacements.containsKey(IdentityKey(myDelegate!))) {
      issue = 'Your delegate key is revoked';
    } else if (trustGraph.isTrusted(IdentityKey(myIdentity))) {
      // Check association
      bool isAssociated = false;
      final statements = trustGraph.edges[IdentityKey(myIdentity)];
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

  if (issue == null) return true;

  if (context == null) return false;
  return showDialog<bool>(
      context: context,
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
