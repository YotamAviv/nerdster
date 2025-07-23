import 'package:flutter/material.dart';

import '../util.dart';
import 'linky.dart';

// TODO: Try to use in more places, have more dialogs look the same.
// CODE: Move to a different UI file
const kPadding = EdgeInsets.all(4);
const kTallPadding = EdgeInsets.fromLTRB(0, 8, 0, 4);
BorderRadius kBorderRadius = BorderRadius.circular(8);

Future<void> alertException(BuildContext context, Object exception, {StackTrace? stackTrace}) {
  if (b(stackTrace)) {
    debugPrintStack(stackTrace: stackTrace!);
  }
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: kBorderRadius),
        title: const Text('Error'),
        content: Column(children: [
          TextField(
            readOnly: true,
            controller: TextEditingController()..text = exception.toString(), // TODO: Leak
            maxLines: null,
          ),
          TextField(
            readOnly: true,
            controller: TextEditingController()..text = stackTrace.toString(),
            maxLines: null,
          )
        ]),
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

Future<String?> alert(String? title, String? content, List<String> options, BuildContext context) {
  List<TextButton> buttons = <TextButton>[];
  for (String option in options) {
    buttons.add(TextButton(
      child: Text(option),
      onPressed: () => Navigator.of(context).pop(option),
    ));
  }
  return showDialog<String?>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: kBorderRadius),
        title: b(title) ? Text(title!) : null,
        content: b(content) ? Linky(content!) : null,
        actions: buttons,
      );
    },
  );
}
