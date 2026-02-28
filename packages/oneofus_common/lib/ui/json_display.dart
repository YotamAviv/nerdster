import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/ui/json_highlighter.dart';

abstract class Interpreter {
  dynamic interpret(dynamic d);
}

// Cycle order: interpreted → raw → token → interpreted
enum _DisplayMode { interpreted, raw, token }

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

  late _DisplayMode _mode;

  @override
  void initState() {
    super.initState();
    _mode = widget.interpret.value ? _DisplayMode.interpreted : _DisplayMode.raw;
  }

  void _cycle() {
    setState(() {
      switch (_mode) {
        case _DisplayMode.interpreted:
          _mode = _DisplayMode.raw;
          widget.interpret.value = false;
          break;
        case _DisplayMode.raw:
          _mode = _DisplayMode.interpreted;
          widget.interpret.value = true;
          break;
        case _DisplayMode.token:
          // Token mode is not in the cycle but keep switch exhaustive
          _mode = _DisplayMode.interpreted;
          widget.interpret.value = true;
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final Interpreter? activeInterpreter = widget.interpreterParam ?? JsonDisplay.interpreter;

    String display;
    switch (_mode) {
      case _DisplayMode.interpreted:
        display = encoder.convert(activeInterpreter!.interpret(widget.subject));
        break;
      case _DisplayMode.raw:
        display = encoder.convert(Jsonish.order(widget.subject));
        break;
      case _DisplayMode.token:
        display = getToken(widget.subject);
        break;
    }

    // Use passed style, then global default, then hardcoded fallback
    final effectiveTextStyle = widget.textStyle ??
        JsonDisplay.defaultTextStyle ??
        GoogleFonts.courierPrime(
          fontWeight: FontWeight.w700,
          fontSize: 10,
        );

    final Color? modeColor = switch (_mode) {
      _DisplayMode.interpreted => Colors.green[900],
      _DisplayMode.raw => null,
      _DisplayMode.token => Colors.blue[900],
    };

    TextStyle baseStyle = effectiveTextStyle.copyWith(
      decoration: widget.strikethrough ? TextDecoration.lineThrough : null,
      color: modeColor,
    );

    List<TextSpan> spans =
        highlightJsonKeys(display, baseStyle, keysToHighlight: JsonDisplay.highlightKeys);

    final (IconData icon, String tooltip) = switch (_mode) {
      _DisplayMode.interpreted => (Icons.transform, 'Interpreted → Raw'),
      _DisplayMode.raw => (Icons.data_object, 'Raw → Interpreted'),
      _DisplayMode.token => (Icons.tag, 'Token'),
    };

    return Stack(
      fit: widget.fit,
      children: [
        SelectionArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 64, left: 16, right: 16),
            child: Text.rich(TextSpan(children: spans)),
          ),
        ),
        if (activeInterpreter != null)
          Positioned(
            bottom: 0,
            right: 0,
            child: FloatingActionButton(
                heroTag: null,
                mini: true,
                tooltip: tooltip,
                backgroundColor: Colors.white,
                child: Icon(icon, color: modeColor ?? Colors.grey),
                onPressed: _cycle),
          ),
      ],
    );
  }
}
