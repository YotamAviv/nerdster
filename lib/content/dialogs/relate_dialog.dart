import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/ok_cancel.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/sign_in_state.dart';

Future<Json?> relateDialog(
    BuildContext context, Json subject, Json otherSubject, ContentStatement? priorStatement) {
  TextEditingController top = TextEditingController()..text = Jsonish(subject).ppJson;
  ContentVerb verb = ContentVerb.relate;
  TextEditingController bottom = TextEditingController()..text = Jsonish(otherSubject).ppJson;
  TextEditingController commentController = TextEditingController();

  void okHandler() async {
    String? comment;
    if (commentController.text.isNotEmpty) {
      comment = commentController.text;
    }
    Json json = ContentStatement.make(SignInState().signedInDelegatePublicKeyJson!, verb, subject,
        other: otherSubject, comment: comment);
    Navigator.pop(context, json);
  }

  void flip() {
    {
      var tmp = top.text;
      top.text = bottom.text;
      bottom.text = tmp;
    }
    {
      var tmp = otherSubject;
      otherSubject = subject;
      subject = tmp;
    }
  }

  if (priorStatement != null) {
    verb = priorStatement.verb;
    commentController.text = priorStatement.comment ?? '';
    String subjectToken = getToken(subject);
    if (priorStatement.subjectToken != subjectToken) {
      flip();
    }
  }

  return showDialog<Json>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) => Dialog(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: ListView(
          shrinkWrap: true,
          children: [
            TextField(
                controller: top,
                maxLines: 6,
                readOnly: true,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                ),
                style: GoogleFonts.courierPrime(
                    fontWeight: FontWeight.w700, fontSize: 14, color: Colors.black)),
            Row(
              children: [
                IconButton(onPressed: flip, icon: const Icon(Icons.swap_vert)),
                DropdownMenu(
                  initialSelection: verb,
                  requestFocusOnTap: true,
                  onSelected: (ContentVerb? selected) {
                    verb = selected!;
                  },
                  dropdownMenuEntries: const [
                    DropdownMenuEntry(label: 'is related to', value: ContentVerb.relate),
                    DropdownMenuEntry(label: 'is not related to', value: ContentVerb.dontRelate),
                    DropdownMenuEntry(
                        label: 'is equivalent to (below is a duplicate)',
                        value: ContentVerb.equate),
                    DropdownMenuEntry(
                        label: 'is not equivalent to (not a duplicate of)',
                        value: ContentVerb.dontEquate),
                  ],
                ),
              ],
            ),
            TextField(
                controller: bottom,
                maxLines: 6,
                readOnly: true,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                ),
                style: GoogleFonts.courierPrime(
                    fontWeight: FontWeight.w700, fontSize: 14, color: Colors.black)),
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
        ),
      ),
    ),
  );
}
