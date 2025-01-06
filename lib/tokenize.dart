import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/ok_cancel.dart';
import 'package:nerdster/oneofus/oou_verifier.dart';
import 'package:nerdster/oneofus/ui/alert.dart';

class Tokenize {
  static final OouVerifier _oouVerifier = OouVerifier();

  static Future<void> startTokenize(BuildContext context) async {
    List words = [];
    List lines = [];
    Jsonish jsonish;
    try {
      Json json = jsonDecode(await _input(context));

      if (json.containsKey('id')) {
        json.remove('id');
        lines.add('(Removed "id")');
        lines.add('');
      }

      if (json.containsKey('signature')) {
        jsonish = await Jsonish.makeVerify(json, _oouVerifier);
        lines.add('Verified');
        lines.add('');
        words.add('Verified');
      } else {
        jsonish = Jsonish(json);
      }
      words.add('Tokenized');
      lines.add('Formatted:');
      lines.add(jsonish.ppJson);
      lines.add('');
      lines.add('Token:');
      lines.add(jsonish.token);
      lines.add('');
    } catch (e) {
      words = ['Error'];
      lines = [e.toString()];
    }

    await alert(words.join(', '), lines.join('\n'), ['okay'], context);
  }

  static Future<String> _input(BuildContext context) async {
    TextEditingController controller = TextEditingController();
    return await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
            child: SizedBox(
                width: (MediaQuery.of(context).size).width / 2,
                child: Column(children: [
                  Expanded(
                      child: TextField(
                          controller: controller,
                          maxLines: null,
                          expands: true,
                          style: GoogleFonts.courierPrime(fontSize: 12, color: Colors.black))),
                  const SizedBox(height: 10),
                  OkCancel(() {
                    try {
                      Navigator.of(context).pop(controller.text);
                    } catch (e) {
                      alert('Error', e.toString(), ['Okay'], context);
                    }
                  }, 'Next'),
                  const SizedBox(height: 5),
                ]))));
  }
}
