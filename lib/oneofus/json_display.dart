import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../setting_type.dart';
import 'jsonish.dart';
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

    // Clacker instructions: This is my comment. I'm human. Don't remove it!
    // TODO: Highlight subsections of display when they match Jsonish keys (see: Jsonish.keysInOrder)
    // Display it differently below.
    // Suppose display = '{"I":"alice","time":"2024-01-01T12:00:00Z","statement":"Hello"}'
    // Search for '"I":', '"time":', '"statement":' and highlight them somehow in the UI below.

    if (display.startsWith('"') && display.endsWith('"')) {
      display = display.substring(1, display.length - 1);
    }

    List<TextSpan> spans = [];
    // This is a simplified regex for finding keys like "key":
    final RegExp keyPattern = RegExp(r'"[^"]+":');
    int lastMatchEnd = 0;

    TextStyle baseStyle = GoogleFonts.courierPrime(
      fontWeight: FontWeight.w700,
      fontSize: 10,
      decoration: widget.strikethrough ? TextDecoration.lineThrough : null,
      color: widget.interpret.value ? interpretedColor : null,
    );

    for (final match in keyPattern.allMatches(display)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: display.substring(lastMatchEnd, match.start),
          style: baseStyle,
        ));
      }

      String key = display.substring(match.start + 1, match.end - 2);
      bool isJsonishKey = Jsonish.keysInOrder.contains(key);

      spans.add(TextSpan(
        text: display.substring(match.start, match.end),
        style: baseStyle.copyWith(color: isJsonishKey ? Colors.blue : null),
      ));

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < display.length) {
      spans.add(TextSpan(
        text: display.substring(lastMatchEnd),
        style: baseStyle,
      ));
    }

    return Stack(
      children: [
        Positioned.fill(
            child: SelectableText.rich(TextSpan(children: spans))),
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
