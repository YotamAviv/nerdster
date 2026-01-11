import 'dart:math';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:nerdster/v2/json_display.dart';
import 'jsonish.dart';
import 'util.dart';

class JsonQrDisplay extends StatelessWidget {
  final dynamic subject; // String (ex. token), Json (ex. key, statement), or null
  final dynamic bogusSubject; //
  final ValueNotifier<bool>? interpret;
  final Interpreter? interpreter;

  const JsonQrDisplay(this.subject,
      {super.key, this.interpret, this.bogusSubject, this.interpreter});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      double qrSize = min(constraints.maxWidth, constraints.maxHeight * (2 / 3));
      if (b(subject)) {
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
                    padding: kPadding,
                    child: V2JsonDisplay(subject,
                        bogusSubject: bogusSubject,
                        interpret: interpret,
                        interpreter: interpreter))),
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
                child: SizedBox(
                    width: x,
                    height: x * 3 / 2,
                    child: JsonQrDisplay(subject, interpret: interpret, interpreter: interpreter)));
          });
        });
  }
}
