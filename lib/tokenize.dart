import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nerdster/oneofus/crypto/crypto.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/ok_cancel.dart';
import 'package:nerdster/oneofus/oou_verifier.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';

const kTokenize = 'Tokenize, verify, translate..';

Size _dsize(context) {
  Size size = MediaQuery.of(context).size;
  return Size(size.width * 0.6, size.height * 0.8);
}

const Widget _space = SizedBox(height: 10);

// DEFER: TEST
// DEFER: Make prettier, not all text, some bold, some fixed width font..
// DEFER: Disable button if empty
class Tokenize {
  static final OouVerifier _oouVerifier = OouVerifier();

  static Future<void> make(BuildContext context) async {
    final List<String> words = [];
    final List<Widget> lines = [];

    String? input = await _input(context);
    if (!b(input)) return;

    await _make2(input!, words, lines);

    String title = words.join(', ');
    AlertDialog dialog = AlertDialog(
      title: Text(title),
      content: SizedBox.fromSize(size: _dsize(context), child: ListView(children: lines)),
    );
    await showDialog(context: context, builder: (context) => dialog);
  }

  static _head(s) => Text(s, style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold));
  static _body(s) => Text(s, style: GoogleFonts.courierPrime(fontSize: 12, color: Colors.black));

  static Future<void> _make2(final String input, final List words, final List lines) async {
    Json json;
    try {
      json = jsonDecode(input);
    } catch (e) {
      words.add('Error');
      lines.add(_head('Could not parse JSON'));
      lines.add(_body('Error $e}'));
      return;
    }

    if (json.containsKey('id')) {
      json.remove('id');
      words.add('Removed "id"');
      lines.add(_head('Removed "id" (server computed token, not part of the statement)'));
    }

    final Json ordered = Jsonish.order(json);
    final String ppJson = encoder.convert(ordered);
    words.add('Formatted');
    lines.add(_head('Formatted:'));
    lines.add(_body(ppJson));
    lines.add(_space);

    final String token = sha1.convert(utf8.encode(ppJson)).toString();
    words.add('Tokenized');
    lines.add(_head('Computed SHA1 token:'));
    lines.add(_body(token));
    lines.add(_space);

    OouPublicKey? iKey;
    if (json.containsKey('I')) {
      try {
        iKey = await crypto.parsePublicKey(json['I']!);
      } catch (e) {
        words.add('Error');
        lines.add(_head('Could not parse public key'));
        lines.add(_body('Error: $e'));
        return;
      }
    }

    if (json.containsKey('signature')) {
      if (!b(iKey)) {
        words.add('Error');
        lines.add(_head('''Error: Found "signature" but missing "I" (author's public key)'''));
        return;
      }
      var orderedWithoutSig = Map.from(ordered)..remove("signature");
      String ppJsonWithoutSig = encoder.convert(orderedWithoutSig);
      bool verified = await _oouVerifier.verify(json, ppJsonWithoutSig, json['signature']);
      if (verified) {
        words.add('Verified');
        lines.add(_head('Signature authenticity verified'));
        lines.add(_body(
            'The signature was successfully verified against the statement body (with "signature" omitted) using the provided public key ("I").'));
        lines.add(_space);
      } else {
        words.add('Error');
        lines.add(_head('Signature verification FAILED!'));
        return;
      }
    }

    String translated = encoder.convert(keyLabels.show(json));
    if (translated != ppJson) {
      words.add('Translated');
      lines.add(_head('Translated:'));
      lines.add(_body(translated));
    }
  }

  static Future<String?> _input(BuildContext context) async {
    TextEditingController controller = TextEditingController();
    return await showDialog(
        context: context,
        builder: (context) => Dialog(
            child: SizedBox.fromSize(
                size: _dsize(context),
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
                  const SizedBox(height: 10),
                  OkCancel(() => Navigator.of(context).pop(controller.text), kTokenize,
                      showCancel: false),
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
