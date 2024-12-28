import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/ok_cancel.dart';
import 'package:nerdster/oneofus/ui/alert.dart';

class Tokenize {
  static Future<void> show(BuildContext context) async {
    TextEditingController controller = TextEditingController();

    Future<void> okHandler() async {
      try {
        Json json = jsonDecode(controller.text);
        bool removedId = false;
        if (json.containsKey('id')) {
          json.remove('id');
          removedId = true;
        }
        Jsonish jsonish = Jsonish(json);
        Navigator.of(context).pop();
        
        await alert(
            removedId ? 'removed "id", formatted, hashed' : 'formatted, hashed',
            '''token (sha1 hash of formatted JSON):
${jsonish.token}

formatted JSON:
${jsonish.ppJson}''',
            ['okay'], context);
      } catch (e) {
        alert('Error', e.toString(), ['Okay'], context);
      }
    }

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
              OkCancel(okHandler, 'Tokenize'),
              const SizedBox(height: 5),
            ])));
  }
}
