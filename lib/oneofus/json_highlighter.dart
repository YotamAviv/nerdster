import 'package:flutter/material.dart';

List<TextSpan> highlightJsonKeys(String display, TextStyle baseStyle,
    {Color highlightColor = Colors.blue, required Set<String> keysToHighlight}) {
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
    bool isJsonishKey = keysToHighlight.contains(key);

    spans.add(TextSpan(
      text: display.substring(match.start, match.end),
      style: baseStyle.copyWith(color: isJsonishKey ? highlightColor : null),
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
