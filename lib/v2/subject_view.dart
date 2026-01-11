import 'package:flutter/material.dart';
import 'package:nerdster/oneofus/jsonish.dart';

class V2SubjectView extends StatelessWidget {
  final Json subject;
  final bool strikethrough;

  const V2SubjectView({
    super.key,
    required this.subject,
    this.strikethrough = false,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> rows = [];
    final type = subject['contentType']!;

    subject.forEach((key, value) {
      if (key == 'contentType') return;

      String displayKey;
      if (key == 'url') {
        displayKey = 'URL';
      } else if (key.isNotEmpty) {
        displayKey = key[0].toUpperCase() + key.substring(1);
      } else {
        displayKey = key;
      }
      rows.add(
        Text(
          '$displayKey: $value',
          style: TextStyle(
            fontSize: 16,
            decoration: strikethrough ? TextDecoration.lineThrough : null,
          ),
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        ),
      );
    });

    rows.add(
      Text(
        '($type)',
        style: TextStyle(
          fontSize: 16,
          decoration: strikethrough ? TextDecoration.lineThrough : null,
        ),
        softWrap: false,
        overflow: TextOverflow.ellipsis,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}
