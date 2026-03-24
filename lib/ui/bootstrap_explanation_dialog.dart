import 'dart:math';

import 'package:flutter/material.dart';
import 'package:nerdster/logic/interpreter.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/ui/util_ui.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/ui/json_qr_display.dart';

/// Shown when the user taps the orange key icon in bootstrap mode.
/// Explains what bootstrap mode is and how to graduate to a real identity.
class BootstrapExplanationDialog extends StatelessWidget {
  final VoidCallback onSignInPressed;
  final Json identityJson;
  final Json? delegatePublicKeyJson;

  const BootstrapExplanationDialog({
    super.key,
    required this.onSignInPressed,
    required this.identityJson,
    required this.delegatePublicKeyJson,
  });

  void _showKeyDetail(BuildContext context, String title, Json json) {
    showDialog(
        context: context,
        builder: (context) {
          double width = MediaQuery.of(context).size.width;
          return AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
                child: SizedBox(
              width: min(width * 0.8, 300.0),
              child: JsonQrDisplay(json,
                  interpret: ValueNotifier(true),
                  interpreter: NerdsterInterpreter(globalLabeler.value)),
            )),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            ],
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: kBorderRadius,
      ),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Key header — matches the sign-in dialog's status table style
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Bootstrap identity key (orange, tappable — shows its public JSON)
                  InkWell(
                    onTap: () => _showKeyDetail(context, 'Bootstrap Identity Key', identityJson),
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.vpn_key, color: Colors.orange, size: 28),
                          SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Identity',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              Text('bootstrap (untrusted)',
                                  style: TextStyle(fontSize: 11, color: Colors.orange)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Delegate key (blue, tappable — shows QR to scan with ONE-OF-US.NET app)
                  InkWell(
                    onTap: delegatePublicKeyJson != null
                        ? () => _showKeyDetail(context, 'Delegate Key', delegatePublicKeyJson!)
                        : null,
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.vpn_key, color: Colors.blue, size: 28),
                          SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Delegate',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              Text('present', style: TextStyle(fontSize: 11, color: Colors.blue)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Tap the blue delegate key to claim it in the ONE-OF-US.NET app — '
                'scan its QR code if on a separate device, or copy/paste the key text if on the same device.',
                style: TextStyle(fontSize: 11, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Explanation
              const Text(
                'You are using a bootstrap identity.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your ratings, comments, and follows are signed with a delegate key that '
                'belongs to you. If you later graduate to your own identity, you can claim '
                'this delegate key and all your activity will remain valid.',
              ),
              const SizedBox(height: 8),
              const Text(
                'The content you see is from the project owner\'s network: you are viewing '
                'the Nerdster as if the only person you trust is the project owner, and '
                'through him, the people he has vouched for.',
              ),
              const SizedBox(height: 16),

              // How to graduate
              Text(
                'To use the Nerdster as yourself:',
                style:
                    Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text('1. Install the ONE-OF-US.NET phone app from one-of-us.net.'),
              const Text(
                  '2. Create your own identity key. Vouch for people you know and get vouched for.'),
              const Text(
                '3. Claim your delegate key in the ONE-OF-US.NET app via SERVICES: '
                'tap the blue delegate key above, then scan its QR code (if on a separate device) '
                'or copy/paste the key text (if on the same device). '
                'All your ratings, follows, and comments will remain valid under your real identity.',
              ),
              const Text(
                '4. Sign in to the Nerdster with your new identity (App Link or URL scheme). '
                'You will trust whoever you\'ve vouched for, not the project owner.',
              ),
              const SizedBox(height: 20),

              // Buttons
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 4,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Dismiss'),
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onSignInPressed();
                    },
                    child: const Text('Sign in with ONE-OF-US.NET app'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
