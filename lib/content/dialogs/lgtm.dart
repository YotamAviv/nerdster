import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nerdster/main.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/ok_cancel.dart';
import 'package:nerdster/oneofus/ui/linky.dart';
import 'package:nerdster/oneofus/ui/my_checkbox.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/prefs.dart';
import 'package:nerdster/singletons.dart';

class Lgtm {
  static Future<bool?> check(Json json, BuildContext context) async {
    if (isSmall.value || Prefs.skipLgtm.value) return true;
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
- Sign the statemet below using its delegate key (which you signed using your one-of-us key)
- Publish it at: https://export.nerdster.org/?token=${signInState.signedInDelegate}'''),
                        JsonDisplay(json),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SizedBox(width: 200.0),
                            OkCancel(() {
                              Navigator.pop(context, true);
                            }, 'Looks Good To Me'),
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

// CODE: Code duplication.. use in [ShowQr], [JSWidget]
class JsonDisplay extends StatefulWidget {
  final Json json;
  final ValueNotifier<bool> translate = ValueNotifier<bool>(false);

  JsonDisplay(this.json, {super.key});

  @override
  State<StatefulWidget> createState() => JsonDisplayState();
}

class JsonDisplayState extends State<JsonDisplay> {
  @override
  Widget build(BuildContext context) {
    var translated = widget.translate.value ? keyLabels.show(widget.json) : widget.json;
    String display = encoder.convert(translated);
    // KLUGE: I couldn't get the Stack to position the floaters on the bottom without a Sized Box.
    return SizedBox(
        width: 700,
        height: 300,
        child: Stack(
          children: [
            Align(
                alignment: Alignment.topLeft,
                child: TextField(
                    controller: TextEditingController()..text = display,
                    maxLines: null,
                    readOnly: true,
                    style: GoogleFonts.courierPrime(fontWeight: FontWeight.w700, fontSize: 10))),
            Align(
                alignment: Alignment.bottomRight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FloatingActionButton(
                        heroTag: 'Translate',
                        tooltip: 'Translate',
                        child: Icon(Icons.translate,
                            color: widget.translate.value ? Colors.blue : null),
                        onPressed: () async {
                          widget.translate.value = !widget.translate.value;
                          setState(() {});
                        }),
                    FloatingActionButton(
                        heroTag: 'Copy',
                        tooltip: 'Copy',
                        child: const Icon(Icons.copy),
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: display));
                        }),
                  ],
                )),
          ],
        ));
  }
}
