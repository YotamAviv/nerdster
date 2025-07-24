import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'util.dart';

abstract class Interpreter {
  dynamic interpret(dynamic d);
  Future<void> waitUntilReady();
}

class JsonDisplay extends StatefulWidget {
  static Interpreter? interpreter;
  static void set(Interpreter? interpreter) {
    JsonDisplay.interpreter = interpreter;
  }

  final dynamic subject; // String (ex. token) or Json (ex. key, statement)
  final ValueNotifier<bool> translate;
  final bool strikethrough;

  JsonDisplay(this.subject, {ValueNotifier<bool>? translate, this.strikethrough = false, super.key})
      : translate = translate ?? ValueNotifier<bool>(true);

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<JsonDisplay> {
  @override
  void initState() {
    super.initState();
    initAsync();
  }

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
    var translated = (b(JsonDisplay.interpreter) && widget.translate.value)
        ? JsonDisplay.interpreter!.interpret(widget.subject)
        : widget.subject;
    String display = encoder.convert(translated);
    return Stack(
      children: [
        Positioned.fill(
            child: SelectableText(display,
                style: GoogleFonts.courierPrime(
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  decoration: widget.strikethrough ? TextDecoration.lineThrough : null,
                ))),
        if (b(JsonDisplay.interpreter))
          Positioned(
            bottom: 0,
            right: 0,
            child: FloatingActionButton(
                heroTag: 'Interperate',
                mini: true, // 40x40 instead of 56x56
                tooltip: !widget.translate.value
                    ? '''Raw JSON shown; click to interperate (make more human readable):
- label known and unknown keys
- convert dates to local time and format
- strip clutter (signature, previous)'''
                    : 'Interpreted JSON shown; click to show the actual data',
                // Was "translate"
                child: Icon(Icons.transform, color: widget.translate.value ? Colors.blue : null),
                onPressed: () async {
                  widget.translate.value = !widget.translate.value;
                  // firstTap = true;
                  setState(() {});
                }),
          ),
      ],
    );
  }
}
