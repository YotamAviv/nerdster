import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/ok_cancel.dart';
import 'package:nerdster/oneofus/oou_verifier.dart';
import 'package:nerdster/oneofus/ui/alert.dart';

class Tokenize {
  static Future<void> startTokenize(BuildContext context) async {
    Json json = await collect(context);

    try {
      String? removedId;
      if (json.containsKey('id')) {
        json.remove('id');
        removedId = '("id" removed)\n\n';
      }
      Jsonish jsonish = Jsonish(json);
      await alert(
          'Token (SHA1 hash of pretty printed JSON)',
          '''${removedId?? ''}token:
${jsonish.token}

JSON:
${jsonish.ppJson}''',
          ['okay'],
          context);
    } catch (e) {
      alert('Error', e.toString(), ['Okay'], context);
    }
  }

  static Future<void> startVerify(BuildContext context) async {
    Json json = await collect(context);

    try {
      String? removedId;
      if (json.containsKey('id')) {
        json.remove('id');
        removedId = '("id" removed)\n\n';
      }
      Jsonish jsonish = await Jsonish.makeVerify(json, OouVerifier());
      await alert(
          'Verified',
          '''${removedId?? ''}token:
${jsonish.token}

formatted JSON:
${jsonish.ppJson}''',
          ['okay'],
          context);
    } catch (e) {
      alert('Error', e.toString(), ['Okay'], context);
    }
  }


  static Future<Json> collect(BuildContext context) async {
    TextEditingController controller = TextEditingController();
    return await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
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
                  Json json = jsonDecode(controller.text);
                  Navigator.of(context).pop(json);
                } catch (e) {
                  alert('Error', e.toString(), ['Okay'], context);
                }
              }, 'Next'),
              const SizedBox(height: 5),
            ])));
  }
}
