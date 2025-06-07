import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';

class JsonDisplay extends StatefulWidget {
  final Json json;
  final ValueNotifier<bool> translate;
  final bool strikethrough;

  JsonDisplay(this.json, {ValueNotifier<bool>? translate, this.strikethrough = false, super.key})
      : translate = translate ?? ValueNotifier<bool>(false);

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<JsonDisplay> {
  @override
  Widget build(BuildContext context) {
    var translated = widget.translate.value ? keyLabels.show(widget.json) : widget.json;
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
                  disabledBorder: InputBorder.none,
                ),
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
                FloatingActionButton(
                    heroTag: 'Translate',
                    tooltip: !widget.translate.value ? 'interperate known keys, make more human readable' : 'show raw statement',
                    child:
                        Icon(Icons.translate, color: widget.translate.value ? Colors.blue : null),
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
    );
  }
}
