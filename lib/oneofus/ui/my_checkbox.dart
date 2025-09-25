import 'package:flutter/material.dart';
import 'package:nerdster/oneofus/util.dart';

class MyCheckbox extends StatefulWidget {
  final ValueNotifier<bool> valueNotifier;
  final String? title;
  final bool opposite;
  const MyCheckbox(this.valueNotifier, this.title, {super.key, this.opposite = false});

  @override
  State<StatefulWidget> createState() {
    return _MyCheckboxState();
  }
}

class _MyCheckboxState extends State<MyCheckbox> {
  _MyCheckboxState();

  @override
  Widget build(BuildContext context) {
    final Widget checkbox = Checkbox(
      value: widget.opposite ? !widget.valueNotifier.value : widget.valueNotifier.value,
      onChanged: (bool? value) =>
          setState(() => widget.valueNotifier.value = widget.opposite ? !value! : value!),
    );
    if (b(widget.title)) {
      return Row(children: [checkbox, Text(widget.title!)]);
    } else {
      return checkbox;
    }
  }
}
