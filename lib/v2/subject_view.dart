import 'package:flutter/material.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/v2/labeler.dart';

class V2SubjectView extends StatelessWidget {
  final Json subject;
  final bool strikethrough;
  final V2Labeler? labeler;

  const V2SubjectView({
    super.key,
    required this.subject,
    this.strikethrough = false,
    this.labeler,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> rows = [];
    final String? type = subject['contentType'];

    if (type == null) {
      assert(subject['statement'] != null);
      Json contributor = subject['I']!;
      String labeledContributor = labeler?.getLabel(getToken(contributor)) ?? getToken(contributor);
      rows.add(
        Text(
          'contribution by $labeledContributor',
          style: TextStyle(
            fontSize: 16,
            decoration: strikethrough ? TextDecoration.lineThrough : null,
          ),
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        ),
      );
    } else {
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
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}
