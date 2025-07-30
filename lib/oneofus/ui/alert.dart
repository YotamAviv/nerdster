import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../json_qr_display.dart';
import '../jsonish.dart';
import '../util.dart';
import 'linky.dart';

Future<void> alertException(BuildContext context, Object exception, {StackTrace? stackTrace}) {
  if (b(stackTrace)) debugPrintStack(stackTrace: stackTrace!);

  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: kBorderRadius),
        title: const Text('Error'),
        content: Column(children: [
          SelectableText(exception.toString(),
              style: GoogleFonts.courierPrime(
                fontWeight: FontWeight.w700,
                fontSize: 10,
              )),
          SelectableText(stackTrace.toString(),
              style: GoogleFonts.courierPrime(
                fontWeight: FontWeight.w700,
                fontSize: 10,
              )),
        ]),
        actions: <Widget>[
          TextButton(
            child: const Text('Okay'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
    },
  );
}

Future<String?> alert(String? title, dynamic content, List<String> options, BuildContext context) {
  List<TextButton> buttons = <TextButton>[];
  for (String option in options) {
    buttons.add(TextButton(
      child: Text(option),
      onPressed: () => Navigator.of(context).pop(option),
    ));
  }
  Widget? widget;
  if (content is Widget) {
    widget = content;
  } else if (content is String) {
    widget = Linky(content);
  } else if (content is Json) {
    widget = SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: JsonQrDisplay(content, interpret: ValueNotifier(false)));
  }
  return showDialog<String?>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: kBorderRadius),
        title: b(title) ? Text(title!) : null,
        content: widget,
        actions: buttons,
      );
    },
  );
}
