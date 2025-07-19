import 'dart:collection';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nerdster/oneofus/crypto/crypto.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/ok_cancel.dart';
import 'package:nerdster/oneofus/oou_verifier.dart';
import 'package:nerdster/oneofus/ui/linky.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';

const kTokenize = 'Format, Tokenize, Verify, Translate..';

Size _dsize(context) {
  Size size = MediaQuery.of(context).size;
  return Size(size.width * 0.6, size.height * 0.8);
}

const Widget _space = SizedBox(height: 20);

// DEFER: TEST
// DEFER: Make prettier, not all text, some bold, some fixed width font..
// DEFER: Disable button if empty
class Tokenize {
  static final OouVerifier _oouVerifier = OouVerifier();

  static Future<void> make(BuildContext context, {String? input}) async {
    input = await _input(context, input: input);
    if (!b(input)) return;

    Map<String, List<Widget>> processed = await process(input!);

    Widget back = IconButton(
      icon: Icon(Icons.arrow_back),
      onPressed: () async {
        Navigator.of(context).pop();
        await (make(context, input: input));
      },
    );

    List<List<Widget>> widgets = processed.values.toList().map((l) => [...l, _space]).toList();
    List<Widget> widgets2 = widgets.flattened.toList();
    String title = processed.keys.join(', ');
    AlertDialog dialog = AlertDialog(
      title: Row(children: [back, SizedBox(width: 8), Text(title)]),
      content: SizedBox.fromSize(size: _dsize(context), child: ListView(children: widgets2)),
    );
    await showDialog(context: context, builder: (context) => dialog);
  }

  static Text titleText(String s) =>
      Text(s, style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold));
  static Text _bodyText(String s) => Text(s,
      style:
          GoogleFonts.courierPrime(fontWeight: FontWeight.w700, fontSize: 10, color: Colors.black));

  static Future<Map<String, List<Widget>>> process(final String input) async {
    LinkedHashMap<String, List<Widget>> out = LinkedHashMap<String, List<Widget>>();
    Json json;
    try {
      json = jsonDecode(input);
      out['Parsed'] = [Linky('JSON successfully parsed')];
    } catch (e) {
      out['Error'] = [Linky('Failed to parse JSON'), _bodyText('$e}')];
      return out;
    }

    if (json.containsKey('id')) {
      json.remove('id');
      out['Removed "id"'] = [
        Linky('Removed "id" (server computed token, not part of the statement)')
      ];
    }

    final Json ordered = Jsonish.order(json);
    final String ppJson = encoder.convert(ordered);
    out['Formatted'] = [Linky('Formatted JSON (2 spaces)'), _bodyText(ppJson)];

    final String token = sha1.convert(utf8.encode(ppJson)).toString();
    out['Tokenized'] = [Linky('Computed SHA1 hash on formatted JSON'), _bodyText(token)];

    OouPublicKey? iKey;
    if (json.containsKey('I')) {
      try {
        iKey = await crypto.parsePublicKey(json['I']!);
      } catch (e) {
        out['Error'] = [Linky('Error parsing public key "I"'), _bodyText('Error: $e')];
        return out;
      }
    }

    if (json.containsKey('signature')) {
      if (!b(iKey)) {
        out['Error'] = [Linky('''Found "signature" but missing "I" (author's public key)''')];
      }
      var orderedWithoutSig = Map.from(ordered)..remove("signature");
      String ppJsonWithoutSig = encoder.convert(orderedWithoutSig);
      bool verified = await _oouVerifier.verify(json, ppJsonWithoutSig, json['signature']);
      if (verified) {
        out['Verified'] = [
          Linky(
              'Successfully verified signature against the statement body (with "signature" omitted) and the provided signing public key ("I").')
        ];
      } else {
        out['Error'] = [Linky('Signature verification FAILED!')];
        return out;
      }
    }

    String translated = encoder.convert(keyLabels.show(json));
    if (translated != ppJson) {
      out['Translated'] = [
        Linky(
            '''Interpreted some keys, tokens, and formats to be more readble and omitted some unnecessary clutter ('signature', 'previous')'''),
        _bodyText(translated)
      ];
    }

    return out;
  }

  static Future<String?> _input(BuildContext context, {String? input}) async {
    TextEditingController controller = TextEditingController();
    if (b(input)) controller.text = input!;
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
