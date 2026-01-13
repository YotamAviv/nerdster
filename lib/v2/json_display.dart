import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nerdster/oneofus/json_highlighter.dart';
import 'package:nerdster/oneofus/util.dart';

abstract class Interpreter {
  dynamic interpret(dynamic d);
  Future<void> waitUntilReady();
}

Color? interpretedColor = Colors.green[900];

class V2JsonDisplay extends StatefulWidget {
  static Set<String> highlightKeys = {};

  final dynamic subject; // String (ex. token) or Json (ex. key, statement)
  final ValueNotifier<bool> interpret;
  final bool strikethrough;
  final Interpreter? interpreter;

  V2JsonDisplay(this.subject,
      {ValueNotifier<bool>? interpret,
      this.strikethrough = false,
      this.interpreter,
      super.key})
      : interpret = interpret ?? ValueNotifier<bool>(true);

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<V2JsonDisplay> {
  @override
  Widget build(BuildContext context) {
    final Interpreter? interpreter = widget.interpreter;
    final useSubject = widget.subject;

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
        highlightJsonKeys(display, baseStyle, keysToHighlight: V2JsonDisplay.highlightKeys);

    return Stack(
      children: [
        SelectableText.rich(TextSpan(children: spans)),
        if (b(interpreter))
          Positioned(
            bottom: 0,
            right: 0,
            child: FloatingActionButton(
                heroTag: null, // Fix for multiple FABs
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
