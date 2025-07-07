import 'dart:math';

import 'package:flutter/material.dart';
import 'package:nerdster/content/dialogs/json_display.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// TODO: Rename file (maybe class, too)
/// DEFER: include "Don't show again"
/// DEFER: Use in qrSignin(..).. (WHY? for sport?, unifomity?)
class JsonQrDisplay extends StatelessWidget {
  final dynamic subject; // String (ex. token), Json (ex. key, statement), or null
  final Color color; // TODO: Seems unused. Remove
  final ValueNotifier<bool> translate = ValueNotifier<bool>(false);

  JsonQrDisplay(this.subject, {super.key, this.color = Colors.white});

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

  // // CODE: Probably remove and have callers use showDialog or embed on their own.
  Future<void> show(BuildContext context, {double reduction = 0.6}) async {
    JsonQrDisplay jq = JsonQrDisplay(subject, color: Colors.black);
    return showDialog(
        context: context,
        builder: (context) {
          return LayoutBuilder(builder: (context, constraints) {
            double x = min(constraints.maxWidth * 0.666, constraints.maxHeight) * reduction;
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
