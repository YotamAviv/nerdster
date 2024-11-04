import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nerdster/oneofus/ui/my_checkbox.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/ok_cancel.dart';
import 'package:nerdster/oneofus/ui/linky.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/prefs.dart';
import 'package:nerdster/singletons.dart';

class Lgtm {
  static Future<bool?> check(Json json, BuildContext context) async {
    if (Prefs.skipLgtm.value) return true;
    return showDialog<bool?>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) => Dialog(
            child: Padding(
                padding: const EdgeInsets.all(15),
                child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 700,
                      maxHeight: 500,
                    ),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        // Text(encoder.convert(json)),
                        // ShowQr(encoder.convert(json)),
                        Linky('''For your review: Nerd'ster intends to:
- Sign the statemet below using its delegate key (which you delegated and signed with your one-of-us key)
- Publish it at: https://export.nerdster.org/?token=${signInState.signedInDelegate}'''),
                        JsonDisplay(json),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SizedBox(width: 200.0),
                            OkCancel(
                              () {
                                Navigator.pop(context, true);
                              },
                              'Looks Good To Me',
                            ),
                            DontCheckbox(),
                          ],
                        ),
                      ],
                    )))));
  }

  static Future<void> show(Jsonish jsonish, BuildContext context) async {
    if (Prefs.skipLgtm.value) return;
    return showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) => Dialog(
            child: Padding(
                padding: const EdgeInsets.all(15),
                child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 700,
                      maxHeight: 500,
                    ),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        Linky(
                            '''Congrats, check it: https://export.nerdster.org/?token=${signInState.signedInDelegate}'''),
                        JsonDisplay(jsonish.json),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const SizedBox(width: 200),
                            OkCancel(
                              () {
                                Navigator.pop(context, true);
                              },
                              'Okay',
                              showCancel: false,
                            ),
                            DontCheckbox(),
                          ],
                        ),
                      ],
                    )))));
  }
}

class DontCheckbox extends StatelessWidget {
  const DontCheckbox({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 200.0, child: MyCheckbox(Prefs.skipLgtm, '''Don't show again'''));
  }
}

// TODO2: Code duplication.. use in [ShowQr], [JSWidget]
class JsonDisplay extends StatelessWidget {
  final Json json;
  const JsonDisplay(
    this.json, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
        controller: TextEditingController()..text = encoder.convert(json),
        maxLines: null,
        readOnly: true,
        style: GoogleFonts.courierPrime(fontWeight: FontWeight.w700, fontSize: 10));
  }
}
