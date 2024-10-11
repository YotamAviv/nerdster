import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ShowQr extends StatelessWidget {
  final String text;
  final Color color;

  const ShowQr(this.text, {super.key, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    Size availSize = MediaQuery.of(context).size;
    double size = min(availSize.width, availSize.height) / 2;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        QrImageView(
          data: text,
          version: QrVersions.auto,
          size: size,
        ),
        SizedBox(
            width: size,
            height: size / 3,
            child: Stack(
              children: [
                Align(
                    alignment: Alignment.bottomLeft,
                    child: IntrinsicWidth(
                        child: TextField(
                            controller: TextEditingController()..text = text,
                            maxLines: null,
                            readOnly: true,
                            style: GoogleFonts.courierPrime(
                                fontWeight: FontWeight.w700, fontSize: 10, color: color)))),
                Align(
                    alignment: Alignment.bottomRight,
                    child: FloatingActionButton(
                        heroTag: 'Copy',
                        tooltip: 'Copy',
                        child: const Icon(Icons.copy),
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: text));
                        })),
              ],
            )),
      ],
    );
  }

  show(BuildContext context) {
    ShowQr big = ShowQr(text, color: Colors.black);
    return showDialog(
        context: context,
        builder: (BuildContext context) =>
            Dialog(child: Padding(padding: const EdgeInsets.all(15), child: big)));
  }
}
