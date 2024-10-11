import 'package:flutter/material.dart';

import '../util.dart';
import 'linky.dart';

Future<void> alertException(BuildContext context, Object exception, {StackTrace? stackTrace}) {
  if (b(stackTrace)) {
    debugPrintStack(stackTrace: stackTrace!);
  }
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Error'),
        content: TextField(
          readOnly: true,
          controller: TextEditingController()..text = exception.toString(),
          maxLines: null,
        ),
        actions: <Widget>[
          TextButton(
            child: const Text(
              'Okay',
            ),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}

Future<String?> alert(String title, String body, List<String> options, BuildContext context) {
  List<TextButton> buttons = <TextButton>[];
  for (String option in options) {
    buttons.add(TextButton(
      child: Text(
        option,
      ),
      onPressed: () {
        Navigator.of(context).pop(option);
      },
    ));
  }
  return showDialog<String?>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title),
        content: Linky(body),
        // OLD:
        // content: SizedBox(
        //   width: double.maxFinite,
        //   child: Linky(body),
        // ),
        actions: buttons,
      );
    },
  );
}
