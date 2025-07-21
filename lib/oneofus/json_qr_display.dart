import 'dart:math';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'json_display.dart';
import 'jsonish.dart';
import 'util.dart';

/// CONSIDER: "Don't show again" for displaying sign-in credentials
/// DEFER: Use in qrSignin(..).. (WHY? for sport?, uniformity?)

// TODO: Move to different file, try to use in more places, have more dialogs look the same.
const kPadding = EdgeInsets.all(4);
BorderRadius kBorderRadius = BorderRadius.circular(8);

class JsonQrDisplay extends StatelessWidget {
  final dynamic subject; // String (ex. token), Json (ex. key, statement), or null
  final ValueNotifier<bool> translate = ValueNotifier<bool>(false);

  JsonQrDisplay(this.subject, {super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      double qrSize = min(constraints.maxWidth, constraints.maxHeight * (2 / 3));
      if (b(subject)) {
        String display = subject is Json ? encoder.convert(subject) : subject;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(
                data: display,
                version: QrVersions.auto,
                size: qrSize,
                padding: const EdgeInsets.all(4)),
            SizedBox(
                width: qrSize,
                height: qrSize / 2,
                child: Padding(padding: kPadding, child: JsonDisplay(subject))),
          ],
        );
      } else {
        return Center(child: (Text('<none>')));
      }
    });
  }

  Future<void> show(BuildContext context, {double reduction = 0.9}) async {
    return showDialog(
        context: context,
        builder: (context) {
          return LayoutBuilder(builder: (context, constraints) {
            double x = min(constraints.maxWidth, constraints.maxHeight * (2 / 3)) * reduction;
            return Dialog(
                shape: RoundedRectangleBorder(borderRadius: kBorderRadius),
                child: SizedBox(width: x, height: x * 3 / 2, child: JsonQrDisplay(subject)));
          });
        });
  }
}
