import 'package:flutter/material.dart';
import 'package:nerdster/main.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/util_ui.dart';

class OnOffIcons extends StatefulWidget {
  final ValueNotifier<Object?> valueNotifier;
  final String tooltipText;
  final Map<Object, (IconData, IconData)> key2icons;
  final String? text;
  final Color? color;
  final bool? disabled;
  final VoidCallback? callback;
  const OnOffIcons(this.valueNotifier, this.key2icons,
      {required this.tooltipText, super.key, this.text, this.color, this.disabled, this.callback});

  @override
  State<StatefulWidget> createState() {
    return _State();
  }
}

class _State extends State<OnOffIcons> {
  _State();

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

  void onPressed(Object key) {
    setState(() {
      if (widget.valueNotifier.value == key) {
        widget.valueNotifier.value = null;
      } else {
        widget.valueNotifier.value = key;
      }
    });
    widget.callback?.call();
  }

  @override
  Widget build(BuildContext context) {
    List<IconButton> buttons = [];
    for (MapEntry e in widget.key2icons.entries) {
      var key = e.key;
      var icons = e.value;
      IconData iconData = widget.valueNotifier.value == e.key ? icons.$1 : icons.$2;
      buttons.add(IconButton(
          padding: EdgeInsets.zero,
          onPressed: bb(widget.disabled) ? null : () => onPressed(key),
          color: widget.color,
          icon: Icon(iconData)));
    }
    TextStyle? textStyle = bb(widget.disabled) ? hintStyle : null;
    return Tooltip(
        message: widget.tooltipText,
        child: Row(spacing: 0, mainAxisSize: MainAxisSize.min, children: [
          if (!isSmall.value && b(widget.text)) Text(style: textStyle, widget.text!),
          ...buttons,
        ]));
  }
}
