import 'dart:math';

import 'package:flutter/material.dart';
import 'json_display.dart';
import 'jsonish.dart';
import 'util.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// CONSIDER: "Don't show again" for displaying sign-in credentials
/// DEFER: Use in qrSignin(..).. (WHY? for sport?, uniformity?)
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
            QrImageView(data: display, version: QrVersions.auto, size: qrSize),
            SizedBox(width: qrSize, height: qrSize / 2, child: JsonDisplay(subject)),
          ],
        );
      } else {
        return Center(child: (Text('<none>')));
      }
    });
  }

  Future<void> show(BuildContext context, {double reduction = 0.6}) async {
    JsonQrDisplay jq = JsonQrDisplay(subject);
    return showDialog(
        context: context,
        builder: (context) {
          return LayoutBuilder(builder: (context, constraints) {
            double x = min(constraints.maxWidth, constraints.maxHeight * 0.666, ) * reduction;
            return Dialog(
                insetPadding: EdgeInsets.zero,
                child: SizedBox(
                    width: x,
                    height: x * 1.5,
                    child: Padding(padding: const EdgeInsets.all(15), child: jq)));
          });
        });
  }
}
