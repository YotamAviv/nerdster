import 'package:flutter/material.dart';

/// "?" next to a QR code, explaining why it's for an identity app and not the phone's camera.
/// See doc/qr_identity_app_only.md in the oneofus repo.
class QrHelpButton extends StatelessWidget {
  /// Names the QR, e.g. 'This sign-in code'.
  final String what;

  /// What the QR holds, e.g. 'sign in parameters'.
  final String holds;

  /// An extra paragraph for this screen, or null.
  final String? extra;

  const QrHelpButton({required this.what, required this.holds, this.extra, super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.help_outline, size: 20),
      tooltip: 'Why not the camera?',
      visualDensity: VisualDensity.compact,
      onPressed: () => show(context, what: what, holds: holds, extra: extra),
    );
  }

  static Future<void> show(BuildContext context,
          {required String what, required String holds, String? extra}) =>
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Scan with an identity app'),
          content: SingleChildScrollView(
            child: Text(
              '$what holds $holds. It doesn\'t open a web page, so a phone\'s camera can\'t do '
              'anything with it. Scan it with the Scan button in an identity app, such as the '
              'ONE-OF-US.NET app.\n\n'
              'Our decentralized identity paradigm avoids referencing any specific company or '
              'service. Any app that supports that paradigm can scan it. A camera-friendly code '
              'would have to point at a specific service.'
              '${extra == null ? '' : '\n\n$extra'}',
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
          ],
        ),
      );
}
