import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/ui/json_highlighter.dart';

abstract class Interpreter {
  dynamic interpret(dynamic d);
}

class JsonDisplay extends StatefulWidget {
  // Global interpreter that can be set by the app
  static Interpreter? interpreter;

  // Custom text style fallback - can be set globally
  static TextStyle? defaultTextStyle;

  static Set<String> highlightKeys = {};

  final dynamic subject; // String (ex. token) or Json (ex. key, statement)
  final ValueNotifier<bool> interpret;
  final bool strikethrough;
  final Interpreter? interpreterParam;
  final StackFit fit;
  final TextStyle? textStyle;

  // Use 'interpreter' as parameter name to match legacy usage in Nerdster
  JsonDisplay(this.subject,
      {ValueNotifier<bool>? interpret,
      this.strikethrough = false,
      Interpreter? interpreter,
      this.fit = StackFit.loose,
      this.textStyle,
      super.key})
      : interpret = interpret ?? ValueNotifier<bool>(true),
        interpreterParam = interpreter;

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<JsonDisplay> {
  static const JsonEncoder encoder = JsonEncoder.withIndent('  ');

  @override
  Widget build(BuildContext context) {
    // Basic interpretation: If interpreter is present, use it. Otherwise just use subject.
    Map show = Jsonish.order(widget.subject);
    final Interpreter? activeInterpreter = widget.interpreterParam ?? JsonDisplay.interpreter;
    if (widget.interpret.value) {
      show = activeInterpreter!.interpret(widget.subject);
    }

    String display = encoder.convert(show);

    // Use passed style, then global default, then hardcoded fallback
    final effectiveTextStyle = widget.textStyle ??
        JsonDisplay.defaultTextStyle ??
        GoogleFonts.courierPrime(
          fontWeight: FontWeight.w700,
          fontSize: 10,
        );

    TextStyle baseStyle = effectiveTextStyle.copyWith(
      decoration: widget.strikethrough ? TextDecoration.lineThrough : null,
      color: widget.interpret.value ? Colors.green[900] : null,
    );

    List<TextSpan> spans =
        highlightJsonKeys(display, baseStyle, keysToHighlight: JsonDisplay.highlightKeys);

    return Stack(
      fit: widget.fit,
      children: [
        SelectionArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 64, left: 16, right: 16),
            child: Text.rich(TextSpan(children: spans)),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: FloatingActionButton(
              heroTag: null,
              mini: true,
              tooltip: !widget.interpret.value
                  ? 'Raw JSON shown; click to interpret'
                  : 'Interpreted JSON shown; click to show raw',
              backgroundColor: Colors.white,
              child: Icon(Icons.transform,
                  color: widget.interpret.value ? Colors.green[900] : Colors.grey),
              onPressed: () {
                setState(() {
                  widget.interpret.value = !widget.interpret.value;
                });
              }),
        ),
      ],
    );
  }
}
