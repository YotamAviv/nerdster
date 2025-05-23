import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nerdster/oneofus/crypto/crypto.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/ok_cancel.dart';
import 'package:nerdster/oneofus/oou_verifier.dart';
import 'package:nerdster/oneofus/ui/alert.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';

const kTokenize = 'Tokenize, verify, translate..';

// DEFER: TEST
// DEFER: Make prettier, not all text, some bold, some fixed width font..
// DEFER: Disable button if empty
class Tokenize {
  static final OouVerifier _oouVerifier = OouVerifier();

  static Future<void> make(BuildContext context) async {
    final List words = [];
    final List lines = [];

    String? input = await _input(context);
    if (!b(input)) return;

    await _make2(input!, words, lines);

    await alert(words.join(', '), lines.join('\n'), ['okay'], context);
  }

  static Future<void> _make2(final String input, final List words, final List lines) async {
    Json json;
    try {
      json = jsonDecode(input);
    } catch (e) {
      words.add('Error');
      lines.add('Could not parse JSON');
      lines.add('Error $e}');
      return;
    }

    if (json.containsKey('id')) {
      json.remove('id');
      words.add('Removed "id"');
      lines.add('Removed "id" (server computed token, not part of the statement)');
      lines.add('');
    }

    final Json ordered = Jsonish.order(json);
    final String ppJson = encoder.convert(ordered);
    words.add('Formatted');
    lines.add('Formatted:');
    lines.add(ppJson);
    lines.add('');

    final String token = sha1.convert(utf8.encode(ppJson)).toString();
    words.add('Tokenized');
    lines.add('Computed token:');
    lines.add(token);
    lines.add('');

    OouPublicKey? iKey;
    if (json.containsKey('I')) {
      lines.add('''Found "I" (author's public key)''');
      try {
        iKey = await crypto.parsePublicKey(json['I']!);
        lines.add('Parsed "I"');
        lines.add('');
      } catch (e) {
        words.add('Error');
        lines.add('Could not parse public key: $e');
        lines.add('Error $e');
        return;
      }
    }

    if (json.containsKey('signature')) {
      lines.add('Found "signature"');
      if (!b(iKey)) {
        words.add('Error');
        lines.add('''Error: Missing "I" (author's public key)''');
        return;
      }
      var orderedWithoutSig = Map.from(ordered)..remove("signature");
      String ppJsonWithoutSig = encoder.convert(orderedWithoutSig);
      bool verified = await _oouVerifier.verify(json, ppJsonWithoutSig, json['signature']);
      if (verified) {
        words.add('Verified');
        lines.add('Verified signature!');
        lines.add('');
      } else {
        words.add('Error');
        lines.add('Signature verification FAILED!');
        return;
      }
    }

    var show = keyLabels.show(json);
    words.add('Translated');
    lines.add('Translated:');
    lines.add(encoder.convert(show));
    lines.add('');
  }

  static Future<String?> _input(BuildContext context) async {
    TextEditingController controller = TextEditingController();
    return await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
            child: SizedBox(
                width: (MediaQuery.of(context).size).width / 2,
                child: Column(children: [
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
                            child: const Icon(Icons.paste),
                            onPressed: () async {
                              final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
                              String? clipboardText = clipboardData?.text;
                              if (b(clipboardText)) controller.text = clipboardText!;
                            }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  OkCancel(() {
                    try {
                      Navigator.of(context).pop(controller.text);
                    } catch (e) {
                      alert('Error', e.toString(), ['Okay'], context);
                    }
                  }, kTokenize),
                  const SizedBox(height: 5),
                ]))));
  }
}

var tmp = {
  "I": {"crv": "Ed25519", "kty": "OKP", "x": "UPHFiTmf7dthz3OvZ715R85HbSGavW56CQzbzH3Xo_s"},
  "time": "2024-06-18T07:00:00.000Z",
  "delegate": {"kty": "OKP", "crv": "Ed25519", "x": "NLc1ECj6Ys7Zqm5eSB2iFxf9QvBeyYuTuzkBnnKhYI8"},
  "with": {"domain": "nerdster.org"},
  "statement": "net.one-of-us",
  "previous": "dbe6ef5c80050b3792c01749ec0a6ceecdd657e0",
  "signature":
      "f0263389d2e0d5312a469e306ce4212932c7defda749476531958662f70295cf4fd7f2df6fc3cc3061a07d7dc977fc46a2d5ce3d84a2067765127ebf8bf3d802"
};
