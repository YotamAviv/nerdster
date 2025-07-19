import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/tokenize.dart';

/// Why: So that the web page can show an embedded verification
/// Otherwise, it's all nice to have, but not worth polishing.
///
/// from: https://www.urlencoder.org/
/// ?tokenize=%0A%7B%0A%20%20%22statement%22%3A%20%22org.nerdster%22%2C%0A%20%20%22time%22%3A%20%222025-07-03T14%3A11%3A25.901Z%22%2C%0A%20%20%22I%22%3A%20%7B%0A%20%20%20%20%22crv%22%3A%20%22Ed25519%22%2C%0A%20%20%20%20%22kty%22%3A%20%22OKP%22%2C%0A%20%20%20%20%22x%22%3A%20%22qmNE2eAuBYKAdtOJrwq9bpeps-HDsvV9mRhWT1R8xCI%22%0A%20%20%7D%2C%0A%20%20%22rate%22%3A%20%7B%0A%20%20%20%20%22contentType%22%3A%20%22book%22%2C%0A%20%20%20%20%22author%22%3A%20%22Ring%20Lardner%22%2C%0A%20%20%20%20%22title%22%3A%20%22Champion%22%0A%20%20%7D%2C%0A%20%20%22with%22%3A%20%7B%0A%20%20%20%20%22recommend%22%3A%20true%0A%20%20%7D%2C%0A%20%20%22comment%22%3A%20%22A%20long-form%20cynical%20joke%2C%20fantastic%20counterpoint%20dessert%20piece%20to%20%5C%22Ghosts%20of%20Manila%5C%22%2C%20a%2020%20page%20setup%20to%20punch%20line%20%28no%20pun%20intended%29.%22%2C%0A%20%20%22previous%22%3A%20%226282a02d21eff999e0a3a9216a087f7a4ce79d0c%22%2C%0A%20%20%22signature%22%3A%20%22276f15ca9c32a02fcaaaec68019df09a0768ab7cd0109723811df4d7eda313fdd10afeee8a9dcf3f368f238dc2fc7543c671f3f9d855ba82573c0723ce84a107%22%0A%7D
class Checker extends StatefulWidget {
  final ValueNotifier<String?> input = ValueNotifier<String?>(null);

  Checker({super.key, String? input2}) {
    if (b(input2)) input.value = input2;
  }

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<Checker> {
  @override
  Widget build(BuildContext context) {
    TextEditingController controller = TextEditingController();
    if (b(widget.input.value)) controller.text = widget.input.value!;
    return Column(children: [
      Row(
        children: [
          Tokenize.titleText('Validate...'),
          IconButton(
              icon: Icon(Icons.arrow_forward),
              onPressed: () async {
                Map<String, List<Widget>> processed = await Tokenize.process(controller.text);
                String title = processed.keys.join(', ');
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        // BUG: NEXT: TEMP: Replaces whole screen instead of just dialog contents.
                        builder: (context) => Scaffold(
                                body: SafeArea(
                                    child: Column(
                              children: [
                                Row(children: [
                                  IconButton(
                                      icon: Icon(Icons.arrow_back),
                                      onPressed: () => Navigator.of(context).pop()),
                                  Tokenize.titleText(title)
                                ]),
                                ProcessedDisplay(processed),
                              ],
                            )))));
              }),
        ],
      ),
      Expanded(
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            TextField(
                controller: controller,
                maxLines: null,
                expands: true,
                style: GoogleFonts.courierPrime(fontSize: 12, color: Colors.black)),
            FloatingActionButton(
                heroTag: 'Paste',
                tooltip: 'Paste',
                mini: true, // 40x40 instead of 56x56
                child: const Icon(Icons.paste),
                onPressed: () async {
                  final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
                  String? clipboardText = clipboardData?.text;
                  if (b(clipboardText)) controller.text = clipboardText!;
                }),
          ],
        ),
      ),
    ]);
  }
}

class ProcessedDisplay extends StatelessWidget {
  final Map<String, List<Widget>> processed;

  const ProcessedDisplay(this.processed, {super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: processed.values.toList().map((l) => [...l, _space]).toList().flattened.toList());
  }
}

const Widget _space = SizedBox(height: 20);

var tmp = {
  "statement": "org.nerdster",
  "time": "2025-07-03T14:11:25.901Z",
  "I": {"crv": "Ed25519", "kty": "OKP", "x": "qmNE2eAuBYKAdtOJrwq9bpeps-HDsvV9mRhWT1R8xCI"},
  "rate": {"contentType": "book", "author": "Ring Lardner", "title": "Champion"},
  "with": {"recommend": true},
  "comment":
      "A long-form cynical joke, fantastic counterpoint dessert piece to \"Ghosts of Manila\", a 20 page setup to punch line (no pun intended).",
  "previous": "6282a02d21eff999e0a3a9216a087f7a4ce79d0c",
  "signature":
      "276f15ca9c32a02fcaaaec68019df09a0768ab7cd0109723811df4d7eda313fdd10afeee8a9dcf3f368f238dc2fc7543c671f3f9d855ba82573c0723ce84a107"
};
