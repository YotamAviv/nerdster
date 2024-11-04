import 'package:flutter/material.dart';

class MyCheckbox extends StatefulWidget {
  final ValueNotifier<bool> valueNotifier;
  final String title;
  const MyCheckbox(this.valueNotifier, this.title, {super.key});

  @override
  State<StatefulWidget> createState() {
    return _MyCheckboxState();
  }
}

class _MyCheckboxState extends State<MyCheckbox> {
  _MyCheckboxState();

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Checkbox(
        value: widget.valueNotifier.value,
        onChanged: (bool? value) {
          setState(() {
            widget.valueNotifier.value = value!;
          });
        },
      ),
      Text(widget.title),
    ]);
  }
}
