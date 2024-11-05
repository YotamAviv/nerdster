import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/ok_cancel.dart';
import 'package:nerdster/oneofus/ui/alert.dart';

class Tokenize {
  static Future<(String, String)?> make(BuildContext context) async {
    TextEditingController controller = TextEditingController();

    void okHandler() {
      try {
        dynamic json = jsonDecode(controller.text);
        Jsonish jsonish = Jsonish(json);
        Navigator.pop(context, (jsonish.token, jsonish.ppJson));
      } catch(e) {
        alert('Error', e.toString(), ['Okay'], context);
      }
    }

    return await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
                child: Column(children: [
              TextField(
                  controller: controller,
                  maxLines: 30,
                  style: GoogleFonts.courierPrime(fontSize: 12, color: Colors.black)),
              const SizedBox(height: 10),
              OkCancel(okHandler, 'Tokenize'),
            ])));
  }
}
