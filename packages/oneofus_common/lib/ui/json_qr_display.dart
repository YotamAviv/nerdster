import 'dart:math';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:oneofus_common/ui/json_display.dart';
import 'package:oneofus_common/jsonish.dart';

class JsonQrDisplay extends StatelessWidget {
  final dynamic subject; // String (ex. token), Json (ex. key, statement), or null
  final ValueNotifier<bool>? interpret;
  final Interpreter? interpreter;

  const JsonQrDisplay(this.subject, {super.key, this.interpret, this.interpreter});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      double qrSize = min(constraints.maxWidth, constraints.maxHeight * (2 / 3));
      if (subject != null) {
        String display = subject is Json ? encoder.convert(subject) : subject;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
                width: qrSize,
                height: qrSize,
                child: QrImageView(
                  data: display,
                  version: QrVersions.auto,
                  // DEFER: I've seen issues iwth the QR image exceeding its bounds. I suspect
                  // that it's not my bug or usage.
                  // size: qrSize,
                  // size: qrSize - 8,
                  // padding: kPadding,
                  // also tried putting the thing in my own Padding(child: ...)
                )),
            SizedBox(
                width: qrSize,
                height: qrSize / 2,
                child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: JsonDisplay(subject,
                        interpret: interpret ?? ValueNotifier(false), interpreter: interpreter))),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                child: SizedBox(
                    width: x,
                    height: x * 3 / 2,
                    child: JsonQrDisplay(subject, interpret: interpret, interpreter: interpreter)));
          });
        });
  }
}
