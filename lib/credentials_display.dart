import 'dart:math';

import 'package:flutter/material.dart';
import 'package:nerdster/oneofus/json_qr_display.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/ui/my_checkbox.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/prefs.dart';

class CredentialsDisplay extends StatelessWidget {
  final Json? identityJson;
  final Json? delegateJson;
  final bool showDontShow;
  final ValueNotifier<bool> interpret = ValueNotifier(true);

  CredentialsDisplay(this.identityJson, this.delegateJson, {super.key, this.showDontShow = true});

  @override
  Widget build(BuildContext context) {
    Size whole = MediaQuery.of(context).size;
    double w = whole.width / 4;
    // make a little smaller
    w = w * 0.8;
    double h = min(w * 3 / 2, whole.height - 200);
    w = h * 2 / 3;
    return SizedBox(
      width: w * 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Column(
                children: [
                  Text('Identity'),
                  SizedBox(
                      width: w, height: h, child: JsonQrDisplay(identityJson, interpret: interpret))
                ],
              ),
              Column(
                children: [
                  Text('Nerdster delegate'),
                  SizedBox(
                      width: w, height: h, child: JsonQrDisplay(delegateJson, interpret: interpret))
                ],
              ),
            ],
          ),
          if (showDontShow)
            Row(children: [
              Spacer(),
              MyCheckbox(
                  Setting.get<bool>(SettingType.skipCredentials).notifier, "Don't show again")
            ]),
        ],
      ),
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
