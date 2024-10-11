import 'package:flutter/material.dart';

import 'util.dart';

class OkCancel extends StatefulWidget {
  final VoidCallback okHandler;
  final String okText;
  final ValueNotifier<bool>? okEnabled;

  final VoidCallback? otherHandler;
  final String? otherText;

  const OkCancel(this.okHandler, this.okText,
      {super.key, this.otherHandler, this.otherText, this.okEnabled});

  @override
  State<StatefulWidget> createState() => OkCancelState();
}

class OkCancelState extends State<OkCancel> {
  @override
  void initState() {
    super.initState();
    if (b(widget.okEnabled)) {
      widget.okEnabled!.addListener(listener);
    }
  }

  void listener() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    bool enabled = !b(widget.okEnabled) || widget.okEnabled!.value;

    

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        OutlinedButton(
          onPressed: enabled ? widget.okHandler : null,
          child: Text(widget.okText),
        ),
        if (b(widget.otherText))
          OutlinedButton(
            onPressed: widget.otherHandler,
            child: Text(widget.otherText!),
          ),
        OutlinedButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
