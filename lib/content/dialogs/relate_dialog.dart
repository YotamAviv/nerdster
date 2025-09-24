import 'package:flutter/material.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/json_display.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/ok_cancel.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/util_ui.dart';

extension OptionalText on TextEditingController {
  String? get nonEmptyText => text.isEmpty ? null : text;
}

class RelateDialog extends StatefulWidget {
  final Json subject;
  final Json otherSubject;
  final ContentStatement? priorStatement;

  const RelateDialog(this.subject, this.otherSubject, this.priorStatement, {super.key});
  @override
  State<StatefulWidget> createState() => _State();

  // CODE: This seems to be the way I like to show dialogs (my current state of the art regarding
  // padding, shape, ...).
  // This should not be a specific memeber on this class.
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
  late ValueNotifier<Json> top;
  late ValueNotifier<Json> bottom;
  late ValueNotifier<ContentVerb> verb;
  late TextEditingController commentController;

  @override
  void initState() {
    super.initState();

    top = ValueNotifier(widget.subject);
    bottom = ValueNotifier(widget.otherSubject);
    verb = ValueNotifier(widget.priorStatement?.verb ?? ContentVerb.relate);
    commentController = TextEditingController()..text = widget.priorStatement?.comment ?? '';

    // Klunky: Could just get them right before flipping.
    if (b(widget.priorStatement) &&
        widget.priorStatement!.subjectToken != getToken(widget.subject)) {
      flip();
    }
  }

  @override
  void dispose() {
    top.dispose();
    bottom.dispose();
    verb.dispose();
    commentController.dispose();
    super.dispose();
  }

  void okHandler() async {
    Json json = ContentStatement.make(signInState.delegatePublicKeyJson!, verb.value, top.value,
        other: bottom.value, comment: commentController.nonEmptyText);
    Navigator.pop(context, json);
  }

  void flip() {
    setState(() {
      Json tmp = top.value;
      top.value = bottom.value;
      bottom.value = tmp;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      children: [
        SizedBox(height: 100, child: JsonDisplay(top.value)),
        Row(
          children: [
            IconButton(onPressed: flip, icon: const Icon(Icons.swap_vert)),
            DropdownMenu(
              initialSelection: verb.value,
              requestFocusOnTap: true,
              onSelected: (ContentVerb? selected) {
                verb.value = selected!;
              },
              dropdownMenuEntries: [
                DropdownMenuEntry(label: 'is related to', value: ContentVerb.relate),
                DropdownMenuEntry(label: 'is not related to', value: ContentVerb.dontRelate),
                DropdownMenuEntry(
                    label: 'is equivalent to (below is a duplicate)', value: ContentVerb.equate),
                DropdownMenuEntry(
                    label: 'is not equivalent to (not a duplicate of)',
                    value: ContentVerb.dontEquate),
                // TODO: Disable the choice and the Okay button when nothing's changed from prior
                DropdownMenuEntry(
                    label: 'clear', value: ContentVerb.clear, enabled: b(widget.priorStatement)),
              ],
            ),
          ],
        ),
        SizedBox(height: 100, child: JsonDisplay(bottom.value)),
        const SizedBox(height: 10),
        TextField(
          decoration: const InputDecoration(
              hintText: "Comment", border: OutlineInputBorder(), hintStyle: hintStyle),
          maxLines: 4,
          controller: commentController,
        ),
        const SizedBox(height: 10),
        OkCancel(okHandler, 'Okay'),
      ],
    );
  }
}
