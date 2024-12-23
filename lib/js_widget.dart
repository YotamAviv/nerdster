import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/show_qr.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/prefs.dart';
import 'package:nerdster/singletons.dart';

class JSWidget extends StatelessWidget {
  final Json json;

  const JSWidget(this.json, {super.key});

  @override
  Widget build(BuildContext context) {
    dynamic json2 = json;
    if (Prefs.nice.value) {
      json2 = keyLabels.show(json);
    }

    return InkWell(
        onTap: (() => {ShowQr(encoder.convert(json)).show(context)}),
        onDoubleTap: () {
          ShowQr(Jsonish(json).token).show(context);
        },
        child: Tooltip(
            message: encoder.convert(json2),
            child: Text('{JS}',
                style: GoogleFonts.courierPrime(
                    fontWeight: FontWeight.w700, fontSize: 12, color: Colors.black))));
  }
}
