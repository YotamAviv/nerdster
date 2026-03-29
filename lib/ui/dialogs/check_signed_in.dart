import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:nerdster/singletons.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:nerdster/models/model.dart';
import 'package:oneofus_common/keys.dart';
import 'package:nerdster/ui/util_ui.dart';
import 'package:url_launcher/url_launcher.dart';

Future<bool?> checkSignedIn(BuildContext? context, {TrustGraph? trustGraph}) async {
  String? issue;

  if (signInState.delegate == null) {
    issue = 'You are not fully signed in';
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
      builder: (context) {
        final linkRecognizer = TapGestureRecognizer()
          ..onTap = () => launchUrl(
                Uri.parse('https://one-of-us.net'),
                mode: LaunchMode.externalApplication,
              );

        const WidgetSpan greenKey = WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Icon(Icons.vpn_key_outlined, color: Colors.green, size: 16),
        );

        const WidgetSpan blueKey = WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Icon(Icons.vpn_key, color: Colors.blue, size: 16),
        );

        const style = TextStyle(fontSize: 13, color: Colors.black54);

        return Dialog(
            shape: RoundedRectangleBorder(borderRadius: kBorderRadius),
            child: Padding(
                padding: kPadding,
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: Text(issue!,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      if (issue == 'You are not fully signed in') ...[
                        const SizedBox(height: 12),
                        RichText(
                          text: TextSpan(style: style, children: [
                            const TextSpan(text: 'You\'re partially signed in (identity only — '),
                            greenKey,
                            const TextSpan(text: ' in the top left is green).\n\n'),
                            const TextSpan(
                                text: 'To fully sign in, Nerdster needs a delegate key ('),
                            blueKey,
                            const TextSpan(text: ') associated with your identity.\n\n'),
                            const TextSpan(text: 'Tap '),
                            greenKey,
                            const TextSpan(
                                text: ' in the top left and sign in again using an identity app, like '),
                            TextSpan(
                              text: 'ONE-OF-US.NET',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.blue,
                                  decoration: TextDecoration.underline),
                              recognizer: linkRecognizer,
                            ),
                            const TextSpan(text: '.'),
                          ]),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.center,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Okay'),
                        ),
                      ),
                    ])));
      });
}
