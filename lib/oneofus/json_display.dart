import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '/main.dart';
import 'util.dart';


class JsonDisplay extends StatefulWidget {
  final dynamic subject; // String (ex. token) or Json (ex. key, statement)
  final ValueNotifier<bool> translate;
  final bool strikethrough;

  JsonDisplay(this.subject,
      {ValueNotifier<bool>? translate, this.strikethrough = false, super.key})
      : translate = translate ?? ValueNotifier<bool>(false);

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<JsonDisplay> {
  @override
  Widget build(BuildContext context) {
    var translated = (b(translateFn) && widget.translate.value) ? translateFn!(widget.subject) : widget.subject;
    String display = encoder.convert(translated);
    return Stack(
      children: [
        Align(
            alignment: Alignment.topLeft,
            child: TextField(
                decoration: InputDecoration(
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none),
                controller: TextEditingController()..text = display,
                maxLines: null,
                readOnly: true,
                style: GoogleFonts.courierPrime(
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  decoration: widget.strikethrough ? TextDecoration.lineThrough : null,
                ))),
        Align(
            alignment: Alignment.bottomRight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (b(translateFn)) FloatingActionButton(
                    heroTag: 'Translate',
                    mini: true, // 40x40 instead of 56x56
                    tooltip: !widget.translate.value
                        ? 'interperate known keys, make more human readable'
                        : 'show raw statement',
                    child:
                        Icon(Icons.translate, color: widget.translate.value ? Colors.blue : null),
                    onPressed: () async {
                      widget.translate.value = !widget.translate.value;
                      setState(() {});
                    }),
                FloatingActionButton(
                    heroTag: 'Copy',
                    mini: true, // 40x40 instead of 56x56
                    tooltip: 'Copy',
                    child: const Icon(Icons.copy), // , size: 16
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: display));
                    }),
              ],
            )),
      ],
    );
  }
}
