import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nerdster/setting_type.dart';
import 'prefs.dart';

import 'util.dart';

abstract class Interpreter {
  dynamic interpret(dynamic d);
  Future<void> waitUntilReady();
}

Color? interpretedColor = Colors.green[900];

class JsonDisplay extends StatefulWidget {
  static Interpreter? interpreter;
  static void set(Interpreter? interpreter) {
    JsonDisplay.interpreter = interpreter;
  }

  final dynamic subject; // String (ex. token) or Json (ex. key, statement)
  final dynamic bogusSubject;
  final ValueNotifier<bool> interpret;
  final bool strikethrough;

  JsonDisplay(this.subject,
      {ValueNotifier<bool>? interpret, this.bogusSubject, this.strikethrough = false, super.key})
      : interpret = interpret ?? ValueNotifier<bool>(true);

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<JsonDisplay> {
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
    if (b(JsonDisplay.interpreter)) {
      // KLUDGE: repaint when keyLabels is ready, and so we should see "<unknown>" and then "tom".
      await JsonDisplay.interpreter!.waitUntilReady();
      if (!mounted) return;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    var useSubject = !Setting.get<bool>(SettingType.bogus).value ? widget.subject : widget.bogusSubject ?? widget.subject;

    var interpreted = (b(JsonDisplay.interpreter) && widget.interpret.value)
        ? JsonDisplay.interpreter!.interpret(useSubject)
        : useSubject;
    String display = encoder.convert(interpreted);
    return Stack(
      children: [
        Positioned.fill(
            child: SelectableText(display,
                style: GoogleFonts.courierPrime(
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  decoration: widget.strikethrough ? TextDecoration.lineThrough : null,
                  color: widget.interpret.value ? interpretedColor : null,
                ))),
        if (b(JsonDisplay.interpreter))
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
