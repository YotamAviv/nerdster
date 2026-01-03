import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nerdster/oneofus/json_highlighter.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/setting_type.dart';

import '../oneofus/json_display.dart'; // For Interpreter

class V2JsonDisplay extends StatefulWidget {
  static Set<String> highlightKeys = {};

  final dynamic subject; // String (ex. token) or Json (ex. key, statement)
  final dynamic bogusSubject;
  final ValueNotifier<bool> interpret;
  final bool strikethrough;
  final Interpreter? interpreter;

  V2JsonDisplay(this.subject,
      {ValueNotifier<bool>? interpret, this.bogusSubject, this.strikethrough = false, this.interpreter, super.key})
      : interpret = interpret ?? ValueNotifier<bool>(true);

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<V2JsonDisplay> {
  @override
  void initState() {
    super.initState();
    initAsync();
    Setting.get<bool>(SettingType.bogus).addListener(listener);
  }

  @override
  void dispose() {
    Setting.get<bool>(SettingType.bogus).removeListener(listener);
    super.dispose();
  }

  void listener() => setState(() {});

  Future<void> initAsync() async {
    final interpreter = widget.interpreter ?? JsonDisplay.interpreter;
    if (b(interpreter)) {
      // KLUDGE: repaint when keyLabels is ready, and so we should see "<unknown>" and then "tom".
      await interpreter!.waitUntilReady();
      if (!mounted) return;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final interpreter = widget.interpreter ?? JsonDisplay.interpreter;
    var useSubject = !Setting.get<bool>(SettingType.bogus).value
        ? widget.subject
        : widget.bogusSubject ?? widget.subject;

    var interpreted = (b(interpreter) && widget.interpret.value)
        ? interpreter!.interpret(useSubject)
        : useSubject;
    String display = encoder.convert(interpreted);

    TextStyle baseStyle = GoogleFonts.courierPrime(
      fontWeight: FontWeight.w700,
      fontSize: 10,
      decoration: widget.strikethrough ? TextDecoration.lineThrough : null,
      color: widget.interpret.value ? interpretedColor : null,
    );

    List<TextSpan> spans =
        highlightJsonKeys(display, baseStyle, keysToHighlight: JsonDisplay.highlightKeys);

    return Stack(
      children: [
        SelectableText.rich(TextSpan(children: spans)),
        if (b(interpreter))
          Positioned(
            bottom: 0,
            right: 0,
            child: FloatingActionButton(
                heroTag: 'Interpret',
                mini: true, // 40x40 instead of 56x56
                tooltip: !widget.interpret.value
                    ? '''Raw JSON shown; click to interpret (make more human readable):
- label known and unknown keys
- convert dates to local time and format
- strip clutter (signature, previous)'''
                    : 'Interpreted JSON shown; click to show the actual data',
                // Was "interpret"
                child:
                    Icon(Icons.transform, color: widget.interpret.value ? interpretedColor : null),
                onPressed: () async {
                  widget.interpret.value = !widget.interpret.value;
                  // firstTap = true;
                  setState(() {});
                }),
          ),
      ],
    );
  }
}
