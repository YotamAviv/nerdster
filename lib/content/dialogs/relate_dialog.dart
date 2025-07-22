import 'package:flutter/material.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/json_display.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/ok_cancel.dart';
import 'package:nerdster/oneofus/ui/alert.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/util_ui.dart';

extension OptionalText on TextEditingController {
  String? get nonEmptyText => text.isEmpty ? null : text;
}

class RelateDialog extends StatefulWidget {
  final ValueNotifier<Json> top;
  final ValueNotifier<Json> bottom;
  final ValueNotifier<ContentVerb> verb;
  final TextEditingController commentController;

  RelateDialog(Json subject, Json otherSubject, ContentStatement? priorStatement, {super.key})
      : top = ValueNotifier(subject),
        bottom = ValueNotifier(otherSubject),
        verb = ValueNotifier(priorStatement?.verb ?? ContentVerb.relate),
        commentController = TextEditingController()..text = priorStatement?.comment ?? '';
  // CONSIDER:
  // if (priorStatement.subjectToken != subjectToken) {
  //   flip();
  // }

  @override
  State<StatefulWidget> createState() => _State();

  Future<Json?> show(BuildContext context) async {
    return await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: kBorderRadius),
        child: Padding(padding: kPadding, child: this),
      ),
    );
  }
}

class _State extends State<RelateDialog> {
  void okHandler() async {
    Json json = ContentStatement.make(
        signInState.signedInDelegatePublicKeyJson!, widget.verb.value, widget.top.value,
        other: widget.bottom.value, comment: widget.commentController.nonEmptyText);
    Navigator.pop(context, json);
  }

  void flip() {
    Json tmp = widget.top.value;
    widget.top.value = widget.bottom.value;
    widget.bottom.value = tmp;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      children: [
        JsonDisplay(widget.top.value),
        Row(
          children: [
            IconButton(onPressed: flip, icon: const Icon(Icons.swap_vert)),
            DropdownMenu(
              initialSelection: widget.verb.value,
              requestFocusOnTap: true,
              onSelected: (ContentVerb? selected) {
                widget.verb.value = selected!;
              },
              dropdownMenuEntries: const [
                DropdownMenuEntry(label: 'is related to', value: ContentVerb.relate),
                DropdownMenuEntry(label: 'is not related to', value: ContentVerb.dontRelate),
                DropdownMenuEntry(
                    label: 'is equivalent to (below is a duplicate)', value: ContentVerb.equate),
                DropdownMenuEntry(
                    label: 'is not equivalent to (not a duplicate of)',
                    value: ContentVerb.dontEquate),
              ],
            ),
          ],
        ),
        JsonDisplay(widget.bottom.value),
        const SizedBox(height: 10),
        TextField(
          decoration: const InputDecoration(
              hintText: "Comment", border: OutlineInputBorder(), hintStyle: hintStyle),
          maxLines: 4,
          controller: widget.commentController,
        ),
        const SizedBox(height: 10),
        OkCancel(okHandler, 'Okay'),
      ],
    );
  }
}
