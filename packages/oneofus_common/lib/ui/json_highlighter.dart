import 'package:flutter/material.dart';

List<TextSpan> highlightJsonKeys(String display, TextStyle baseStyle,
    {Color highlightColor = Colors.blue, required Set<String> keysToHighlight,
     Map<String, Color>? keyColors}) {
  List<TextSpan> spans = [];
  final RegExp keyPattern = RegExp(r'"[^"]+":');
  int lastMatchEnd = 0;

  for (final match in keyPattern.allMatches(display)) {
    if (match.start > lastMatchEnd) {
      spans.add(TextSpan(
        text: display.substring(lastMatchEnd, match.start),
        style: baseStyle,
      ));
    }

    String key = display.substring(match.start + 1, match.end - 2);
    final Color? color = keyColors?[key] ??
        (keysToHighlight.contains(key) ? highlightColor : null);

    spans.add(TextSpan(
      text: display.substring(match.start, match.end),
      style: baseStyle.copyWith(color: color),
    ));

    lastMatchEnd = match.end;
  }

  if (lastMatchEnd < display.length) {
    spans.add(TextSpan(
      text: display.substring(lastMatchEnd),
      style: baseStyle,
    ));
  }

  return spans;
}
