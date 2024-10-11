import 'package:flutter/material.dart';
import 'package:nerdster/oneofus/util.dart';

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
  }

  void listener() {
    setState(() {});
  }

  void onPressed() {
    setState(() {
      widget.valueNotifier.value = !widget.valueNotifier.value;
    });
    if (b(widget.callback)) {
      (widget.callback!)();
    }
  }

  @override
  Widget build(BuildContext context) {
    IconData iconData = widget.valueNotifier.value ? widget.iconOn : widget.iconOff;
    TextStyle? textStyle = bb(widget.disabled) ? hintStyle : null;
    return Tooltip(
        message: widget.tooltipText,
        // child: Container(
        // decoration: BoxDecoration(
        //     border: Border.all(color: const Color.fromARGB(96, 185, 159, 159), width: 4)),
        child: Row(children: [
          if (b(widget.text)) Text(style: textStyle, widget.text!),
          IconButton(
              onPressed: bb(widget.disabled) ? null : onPressed,
              color: widget.color,
              icon: Icon(iconData)),
        ]));
  }
}
