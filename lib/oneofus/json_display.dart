import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nerdster/singletons.dart';

import '/main.dart';
import 'util.dart';

class JsonDisplay extends StatefulWidget {
  final dynamic subject; // String (ex. token) or Json (ex. key, statement)
  final ValueNotifier<bool> translate;
  final bool strikethrough;
  // final ValueNotifier<bool> firstTap = ValueNotifier(true);

  JsonDisplay(this.subject, {ValueNotifier<bool>? translate, this.strikethrough = false, super.key})
      : translate = translate ?? ValueNotifier<bool>(true);

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<JsonDisplay> {
  // final TextEditingController controller = TextEditingController();
  // bool firstTap = true;

  @override
  void initState() {
    super.initState();
    initAsync();
  }

  // Possible KLUDGE: repaint when keyLabels is ready, and so we should see "<unknown>" and then "tom".
  Future<void> initAsync() async {
    await keyLabels.waitUntilReady();
    if (!mounted) return;
    setState(() {});
  }

  // @override
  // void dispose() {
  //   // controller.dispose();
  //   super.dispose();
  // }

  @override
  Widget build(BuildContext context) {
    var translated =
        (b(translateFn) && widget.translate.value) ? translateFn!(widget.subject) : widget.subject;
    String display = encoder.convert(translated);
    // controller.text = display;
    return Stack(
      children: [
        Positioned.fill(
            child: SelectableText(display,
                style: GoogleFonts.courierPrime(
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  decoration: widget.strikethrough ? TextDecoration.lineThrough : null,
                ))),
        //   child: TextField(
        // controller: controller,
        // readOnly: true,
        // maxLines: null,
        // onTap: () {
        //   // Select all text on tap
        //   if (firstTap) {
        //     controller.selection =
        //         TextSelection(baseOffset: 0, extentOffset: controller.text.length);
        //     firstTap = false;
        //   }
        // },
        //   style: GoogleFonts.courierPrime(
        //     fontWeight: FontWeight.w700,
        //     fontSize: 10,
        //     decoration: widget.strikethrough ? TextDecoration.lineThrough : null,
        //   ),
        //   decoration: const InputDecoration(
        //     isDense: true,
        //     contentPadding: EdgeInsets.zero,
        //     border: InputBorder.none,
        //   ),
        // )),
        if (b(translateFn))
          Positioned(
            bottom: 0,
            right: 0,
            child: FloatingActionButton(
                heroTag: 'Interperate',
                mini: true, // 40x40 instead of 56x56
                tooltip: !widget.translate.value
                    ? '''Raw JSON shown; click to interperate (make more human readable):
- label known and unknown keys
- convert dates to local time and format
- strip clutter (signature, previous)'''
                    : 'Interpreted JSON shown; click to show the actual data',
                // Was "translate"
                child: Icon(Icons.transform, color: widget.translate.value ? Colors.blue : null),
                onPressed: () async {
                  widget.translate.value = !widget.translate.value;
                  // firstTap = true;
                  setState(() {});
                }),
            // copy/paste doesn't work when embedded in an iFrame. Ctrl-C / Ctrl-V works,
            // and so rather than try/catch/explain, I'll make that the only option.
            // FloatingActionButton(
            //     heroTag: 'Copy',
            //     mini: true, // 40x40 instead of 56x56
            //     tooltip: 'Copy',
            //     child: const Icon(Icons.copy), // , size: 16
            //     onPressed: () async {
            //       await Clipboard.setData(ClipboardData(text: display));
            //     }),
          ),
      ],
    );
  }
}
