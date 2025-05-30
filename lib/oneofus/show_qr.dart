import 'dart:math';

import 'package:flutter/material.dart';
import 'package:nerdster/content/dialogs/json_display.dart';
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
            child: JsonDisplay(widget.subject)),
      ],
    );
  }
}
