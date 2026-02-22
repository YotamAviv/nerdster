import 'package:flutter/material.dart';

import 'package:nerdster/app.dart';

class MyCheckbox extends StatefulWidget {
  final ValueNotifier<bool> valueNotifier;
  final String? title;
  final bool opposite;
  final bool alwaysShowTitle;
  const MyCheckbox(this.valueNotifier, this.title,
      {super.key, this.opposite = false, this.alwaysShowTitle = false});

  @override
  State<StatefulWidget> createState() {
    return _MyCheckboxState();
  }
}

class _MyCheckboxState extends State<MyCheckbox> {
  _MyCheckboxState();

  @override
  void initState() {
    super.initState();
    isSmall.addListener(_onSmallChanged);
  }

  @override
  void dispose() {
    isSmall.removeListener(_onSmallChanged);
    super.dispose();
  }

  void _onSmallChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    Widget checkbox = Checkbox(
      value: widget.opposite ? !widget.valueNotifier.value : widget.valueNotifier.value,
      onChanged: (bool? value) =>
          setState(() => widget.valueNotifier.value = widget.opposite ? !value! : value!),
    );

    if (widget.title != null) {
      if (isSmall.value && !widget.alwaysShowTitle) {
        return Tooltip(message: widget.title!, child: checkbox);
      } else {
        return Row(children: [checkbox, Text(widget.title!)]);
      }
    } else {
      return checkbox;
    }
  }
}
