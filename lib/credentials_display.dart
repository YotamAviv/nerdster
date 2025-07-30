import 'package:flutter/material.dart';
import 'package:nerdster/oneofus/json_qr_display.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/util.dart';

/// CONSIDER: "Don't show again" for displaying sign-in credentials
class CredentialsDisplay extends StatelessWidget {
  final Json? identityJson;
  final Json? delegateJson;
  final ValueNotifier<bool> interpret = ValueNotifier(true);

  CredentialsDisplay(this.identityJson, this.delegateJson, {super.key});

  @override
  Widget build(BuildContext context) {
    Size whole = MediaQuery.of(context).size;
    double w = whole.width / 4;
    double h = w * 3 / 2;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          Column(
            children: [
              Text('Identity'),
              SizedBox(width: w, height: h, child: JsonQrDisplay(identityJson, interpret: interpret))
            ],
          ),
          Column(
            children: [
              Text('Nerdster delegate'),
              SizedBox(width: w, height: h, child: JsonQrDisplay(delegateJson, interpret: interpret))
            ],
          )
        ]),
      ],
    );
  }
}

// DEFER: Move to file
// ChatGPT: "How do I place a dialog at the top right?"
void showTopRightDialog(BuildContext context, Widget content) {
  final overlay = Overlay.of(context);
  late OverlayEntry overlayEntry;

  overlayEntry = OverlayEntry(
    builder: (context) {
      return Stack(
        children: [
          // Transparent barrier to dismiss the dialog
          Positioned.fill(
            child: GestureDetector(
                onTap: () => overlayEntry.remove(),
                behavior: HitTestBehavior.translucent,
                child: Container(color: Colors.transparent)),
          ),

          // Your custom dialog content at top-right
          Positioned(
            top: 45,
            right: 5,
            child: Material(
              elevation: 8,
              borderRadius: kBorderRadius,
              child: Container(
                padding: kPadding,
                decoration: BoxDecoration(borderRadius: kBorderRadius),
                child: content,
              ),
            ),
          ),
        ],
      );
    },
  );

  overlay.insert(overlayEntry);
}
