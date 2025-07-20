import 'dart:collection';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nerdster/oneofus/crypto/crypto.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/oou_verifier.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';

// NEXT: Way more simple (for video viewer):
// - VERIFIED! (green) / INVALID! (red) / (not signed)
// - don't show notes that don't matter (removed id, formatted, parsed) unless they actually happened

/// from: https://www.urlencoder.org/
/// ?verify=%0A%7B%0A%20%20%22statement%22%3A%20%22org.nerdster%22%2C%0A%20%20%22time%22%3A%20%222025-07-03T14%3A11%3A25.901Z%22%2C%0A%20%20%22I%22%3A%20%7B%0A%20%20%20%20%22crv%22%3A%20%22Ed25519%22%2C%0A%20%20%20%20%22kty%22%3A%20%22OKP%22%2C%0A%20%20%20%20%22x%22%3A%20%22qmNE2eAuBYKAdtOJrwq9bpeps-HDsvV9mRhWT1R8xCI%22%0A%20%20%7D%2C%0A%20%20%22rate%22%3A%20%7B%0A%20%20%20%20%22contentType%22%3A%20%22book%22%2C%0A%20%20%20%20%22author%22%3A%20%22Ring%20Lardner%22%2C%0A%20%20%20%20%22title%22%3A%20%22Champion%22%0A%20%20%7D%2C%0A%20%20%22with%22%3A%20%7B%0A%20%20%20%20%22recommend%22%3A%20true%0A%20%20%7D%2C%0A%20%20%22comment%22%3A%20%22A%20long-form%20cynical%20joke%2C%20fantastic%20counterpoint%20dessert%20piece%20to%20%5C%22Ghosts%20of%20Manila%5C%22%2C%20a%2020%20page%20setup%20to%20punch%20line%20%28no%20pun%20intended%29.%22%2C%0A%20%20%22previous%22%3A%20%226282a02d21eff999e0a3a9216a087f7a4ce79d0c%22%2C%0A%20%20%22signature%22%3A%20%22276f15ca9c32a02fcaaaec68019df09a0768ab7cd0109723811df4d7eda313fdd10afeee8a9dcf3f368f238dc2fc7543c671f3f9d855ba82573c0723ce84a107%22%0A%7D
const String kVerify = 'Verify...';
const Widget _space = SizedBox(height: 20);
Text _titleText(String s) => Text(s, style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold));
Text _bodyBigText(String s) =>
    Text(s, style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold));
Text _bodyText(String s) =>
    Text(s, style: GoogleFonts.courierPrime(fontSize: 12, color: Colors.black));
OouVerifier _oouVerifier = OouVerifier();

class Verify extends StatelessWidget {
  final String? input;

  const Verify({super.key, this.input});

  @override
  Widget build(BuildContext context) {
    TextEditingController controller = TextEditingController(text: input ?? '');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(
        children: [
          _titleText(kVerify),
          IconButton(
              icon: Icon(Icons.arrow_forward),
              onPressed: () async {
                String title = 'TODO';
                await Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => Scaffold(
                            body: SafeArea(
                                child: ListView(
                          children: [
                            Row(children: [
                              IconButton(
                                  icon: Icon(Icons.arrow_back),
                                  onPressed: () => Navigator.of(context).pop()),
                              _titleText(title),
                            ]),
                            Padding(
                                padding: EdgeInsetsGeometry.all(16),
                                child: Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey),
                                      borderRadius: BorderRadius.circular(
                                          4), // default for OutlineInputBorder
                                    ),
                                    child: ProcessedPanel(controller.text))),
                          ],
                        )))));
              }),
        ],
      ),
      _space,
      Expanded(
          child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          TextField(
              decoration: InputDecoration(
                labelText: 'JSON text to process',
                border: OutlineInputBorder(),
                alignLabelWithHint: true, // Important: aligns label with top-aligned input
              ),
              controller: controller,
              maxLines: null,
              textAlignVertical: TextAlignVertical.top,
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
      )),
    ]);
  }
}

class ProcessedPanel extends StatefulWidget {
  final String input;

  const ProcessedPanel(this.input, {super.key});

  @override
  State<ProcessedPanel> createState() => _ProcessedPanelState();
}

class _ProcessedPanelState extends State<ProcessedPanel> {
  Widget? _body;

  @override
  void initState() {
    super.initState();
    _startProcessing();
  }

  void _set(Widget child) => setState(() => _body = child);

  Future<void> _startProcessing() async {
    final input = widget.input;
    Json json;

    try {
      json = jsonDecode(input);
    } catch (e) {
      _set(_error([
        _bodyBigText('Failed to parse JSON'),
        _bodyText('$e'),
      ]));
      return;
    }

    final children = <Widget>[
      _bodyBigText('JSON successfully parsed'),
    ];

    if (json.containsKey('id')) {
      json.remove('id');
      children.addAll([
        _space,
        _bodyBigText('Stripped "id" (server computed token, not part of the statement)')
      ]);
    }

    final Json ordered = Jsonish.order(json);
    final String ppJson = encoder.convert(ordered);
    if (ppJson.trim() != input.trim()) {
      children.addAll([
        _space,
        _bodyBigText('Formatted JSON (2 spaces)'),
        _bodyText(ppJson),
      ]);
    }

    final String token = sha1.convert(utf8.encode(ppJson)).toString();
    children.addAll([
      _space,
      _bodyBigText('Computed SHA1 hash on formatted JSON'),
      _bodyText(token),
    ]);

    OouPublicKey? iKey;
    if (json.containsKey('I')) {
      try {
        iKey = await crypto.parsePublicKey(json['I']!);
      } catch (e) {
        _set(_error([
          _bodyBigText('Error parsing public key "I"'),
          _bodyText('$e'),
        ]));
        return;
      }
    }

    final String? signature = json['signature'];

    // If only one of signature or I is present, treat as an error
    if ((signature != null && iKey == null) || (signature == null && iKey != null)) {
      _set(_error([
        _bodyBigText('Invalid statement'),
        _bodyText(
            'Both "signature" and "I" (author\'s public key) must be present together, or neither.'),
      ]));
      return;
    }

    if (json.containsKey('signature')) {
      final withoutSig = Map.from(ordered)..remove('signature');
      final String jsonWithoutSig = encoder.convert(withoutSig);
      final verified = await _oouVerifier.verify(json, jsonWithoutSig, signature);

      if (verified) {
        children.addAll([
          _space,
          _bodyBigText('✔ Verified'),
          _bodyText('Signature successfully verified.'),
        ]);
      } else {
        _set(_error([_bodyBigText('✘ Signature verification FAILED!')]));
        return;
      }
    }

    final String interpreted = encoder.convert(keyLabels.interpret(json));
    if (interpreted != ppJson) {
      children.addAll([
        _space,
        _bodyBigText('Interpreted for readability'),
        _bodyText(interpreted),
      ]);
    }

    _set(Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return _body ??
        const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        );
  }

  Widget _error(List<Widget> content) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: content),
      );
}

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
