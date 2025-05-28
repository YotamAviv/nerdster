import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ShowQr extends StatefulWidget {
  final dynamic subject; // String (ex. token) or Json (ex. key, statement)
  final Color color;
  final ValueNotifier<bool> translate = ValueNotifier<bool>(false);

  ShowQr(this.subject, {super.key, this.color = Colors.white});

  @override
  State<StatefulWidget> createState() => ShowQrState();

  show(BuildContext context) {
    ShowQr big = ShowQr(subject, color: Colors.black);
    showDialog(
        context: context,
        builder: (BuildContext context) =>
            Dialog(child: Padding(padding: const EdgeInsets.all(15), child: big)));
  }
}

class ShowQrState extends State<ShowQr> {
  @override
  Widget build(BuildContext context) {
    Size availSize = MediaQuery.of(context).size;
    double size = min(availSize.width, availSize.height) / 2;

    var translated = widget.translate.value ? keyLabels.show(widget.subject) : widget.subject;
    String display = widget.subject is Json ? encoder.convert(translated) : translated;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        QrImageView(data: display, version: QrVersions.auto, size: size),
        SizedBox(
            width: size,
            height: size / 3,
            child: Stack(
              children: [
                Align(
                    alignment: Alignment.topLeft,
                    child: IntrinsicWidth(
                        child: TextField(
                            controller: TextEditingController()..text = display,
                            maxLines: null,
                            readOnly: true,
                            style: GoogleFonts.courierPrime(
                                fontWeight: FontWeight.w700, fontSize: 10, color: widget.color)))),
                Align(
                    alignment: Alignment.bottomRight,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        FloatingActionButton(
                            heroTag: 'Translate',
                            tooltip: 'Translate',
                            child: Icon(Icons.translate,
                                color: widget.translate.value ? Colors.blue : null),
                            onPressed: () async {
                              widget.translate.value = !widget.translate.value;
                              setState(() {});
                            }),
                        FloatingActionButton(
                            heroTag: 'Copy',
                            tooltip: 'Copy',
                            child: const Icon(Icons.copy),
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: display));
                            }),
                      ],
                    )),
              ],
            )),
      ],
    );
  }
}
