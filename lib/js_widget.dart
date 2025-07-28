import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/json_qr_display.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/prefs.dart';
import 'package:nerdster/singletons.dart';

class JSWidget extends StatelessWidget {
  final Jsonish jsonish;
  final ValueNotifier<bool>? translate;

  const JSWidget(this.jsonish, {super.key, this.translate});

  @override
  Widget build(BuildContext context) {
    dynamic dyn = (Prefs.keyLabel.value) ? keyLabels.interpret(jsonish) : jsonish;

    String message;
    if (dyn is Jsonish) {
      message = encoder.convert(dyn.json);
    } else if (dyn is Map) {
      message = encoder.convert(dyn);
    } else if (dyn is String) {
      message = dyn;
    } else {
      throw Exception('Unexpected: ${dyn.runtimeType}, $dyn');
    }

    return InkWell(
        onTap: () => JsonQrDisplay(jsonish.json, translate: translate).show(context),
        onDoubleTap: () => JsonQrDisplay(jsonish.token, translate: translate).show(context),
        child: Tooltip(
            message: message,
            child: Text('{JS}',
                style: GoogleFonts.courierPrime(
                    fontWeight: FontWeight.w700, fontSize: 12, color: Colors.black))));
  }
}
