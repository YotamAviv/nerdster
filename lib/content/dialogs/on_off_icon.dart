import 'package:flutter/material.dart';
import 'package:nerdster/main.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/util_ui.dart';

class OnOffIcon extends StatefulWidget {
  final ValueNotifier<bool> valueNotifier;
  final IconData iconOn;
  final IconData iconOff;
  final String tooltipText;
  final String? text;
  final Color? color;
  final bool? disabled;
  final VoidCallback? callback;
  const OnOffIcon(this.valueNotifier, this.iconOn, this.iconOff,
      {required this.tooltipText, super.key, this.text, this.color, this.disabled, this.callback});

  @override
  State<StatefulWidget> createState() {
    return _OnOffIconState();
  }
}

class _OnOffIconState extends State<OnOffIcon> {
  _OnOffIconState();

  @override
  void initState() {
    super.initState();
    widget.valueNotifier.addListener(listener);
    isSmall.addListener(listener);
  }

  @override
  void dispose() {
    widget.valueNotifier.removeListener(listener);
    isSmall.removeListener(listener);
    super.dispose();
  }

  void listener() {
    setState(() {});
  }

  void onPressed() {
    setState(() {
      widget.valueNotifier.value = !widget.valueNotifier.value;
    });
    widget.callback?.call();
  }

  @override
  Widget build(BuildContext context) {
    IconData iconData = widget.valueNotifier.value ? widget.iconOn : widget.iconOff;
    TextStyle? textStyle = bb(widget.disabled) ? hintStyle : null;
    return Tooltip(
        message: widget.tooltipText,
        child: Row(children: [
          if (!isSmall.value && b(widget.text)) Text(style: textStyle, widget.text!),
          IconButton(
              onPressed: bb(widget.disabled) ? null : onPressed,
              color: widget.color,
              icon: Icon(iconData)),
        ]));
  }
}
