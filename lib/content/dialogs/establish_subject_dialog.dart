import 'dart:async';
import 'dart:collection';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/content/content_types.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/ok_cancel.dart';
import 'package:nerdster/util_ui.dart';

/// Fetching URL title:
/// CORS rules out fetching the HTML title ourselves.
/// This class used to have code that does that, and it worked locally with security disabled in Chrome.
/// flutter run -d chrome --web-browser-flag "--disable-web-security"
///
/// We use Firebase backend functions to
/// - listen to writes to a 'urls' collection,
/// - get the url from documents tha appear there
/// - use Node on the server side to fetch the HTML and exctract the title
/// - write that back to the Firebase doc.
/// This class uses that mechanism.

final FirebaseFunctions? _functions = FireFactory.findFunctions(kNerdsterDomain);

Future<Jsonish?> establishSubjectDialog(BuildContext context) {
  return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => Dialog(
          child: SizedBox(width: (MediaQuery.of(context).size).width / 2, child: SubjectFields())));
}

class SubjectFields extends StatefulWidget {
  const SubjectFields({super.key});

  @override
  State<StatefulWidget> createState() {
    return _SubjectFieldsState();
  }
}

class _SubjectFieldsState extends State<SubjectFields> {
  ContentType contentType = ContentType.article;
  List<TextField> fields = <TextField>[];
  LinkedHashMap<String, TextEditingController> key2controller =
      LinkedHashMap<String, TextEditingController>();
  final List<ContentType> typesMinusAll = List.from(ContentType.values)..removeAt(0);

  okHandler() async {
    Map<String, dynamic> map = <String, dynamic>{};
    map['contentType'] = contentType.label;
    for (MapEntry<String, TextEditingController> e in key2controller.entries) {
      String s = e.value.text;
      map[e.key] = s;
    }
    Jsonish subject = Jsonish(map);
    Navigator.pop(context, subject);
  }

  listen() {
    // Special case kludge for auto-filling 'title' field from 'url' field.
    TextEditingController urlController = key2controller['url']!;
    TextEditingController titleController = key2controller['title']!;
    if (urlController.text.isEmpty) return;
    tryFetchTitle(urlController.text, (String url, {String? title, String? error}) {
      if (urlController.text == url) {
        if (title != null) {
          titleController.text = title;
        }
        // TODO: Show the user the error somehow (so that he knows we tried but paywall, forbidden, whatever prevented us)
        // I didn't like Snackbar
        // I don't think I can use hint text effectively as it's hidden once there's any text in the TextField.
        // I can probably use the border color, but the user would not know what that means.
        if (error != null) {
          print(error);
        }
      }
    });
  }

  @override
  void dispose() {
    // CONSIDER: Stop listening? Am I leaking Controllers?
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    key2controller = LinkedHashMap<String, TextEditingController>();
    fields = <TextField>[];
    for (MapEntry<String, String> entry in contentType.type2field2type.entries) {
      TextEditingController controller = TextEditingController();
      key2controller[entry.key] = controller;
      String hintText = entry.key;
      TextField textField = TextField(
          decoration: InputDecoration(
              hintText: hintText, hintStyle: hintStyle, border: const OutlineInputBorder()),
          controller: controller);
      fields.add(textField);
      // Special case kludge for auto-filling 'title' field from 'url' field.
      if (entry.key == 'url') {
        controller.addListener(listen);
      }
    }

    Widget noUrl = const SizedBox(width: 80.0);
    if (!contentType.type2field2type.keys.any((x) => x == 'url')) {
      noUrl = SizedBox(
        width: 80.0,
        child: Tooltip(
            message: '''A ${contentType.label} doesn't have a singular URL.
In case multiple people rate a book, their ratings will be grouped correctly only if they all use the same fields and values.
You can include a URL in a comment or relate or equate this book to an article with a URL.''',
            child: Text('no URL?', style: linkStyle)),
      );
    }

    return Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const SizedBox(width: 80.0),
              DropdownMenu<ContentType>(
                initialSelection: ContentType.article,
                requestFocusOnTap: true,
                label: const Text('Type'),
                onSelected: (ContentType? contentType) {
                  setState(() {
                    this.contentType = contentType!;
                  });
                },
                dropdownMenuEntries:
                    typesMinusAll.map<DropdownMenuEntry<ContentType>>((ContentType type) {
                  return DropdownMenuEntry<ContentType>(
                      value: type, label: type.label, leadingIcon: Icon(type.iconDatas.$1));
                }).toList(),
              ),
              noUrl,
            ]),
            const SizedBox(height: 10),
            ...fields,
            const SizedBox(height: 10),
            OkCancel(okHandler, 'Establish Subject'),
          ],
        ));
  }
}

void tryFetchTitle(String url, Function(String url, {String title, String error}) callback) async {
  if (_functions == null) return;
  if (!url.startsWith('http://') && !url.startsWith('https://')) return;
  try {
    var retval = await _functions!.httpsCallable('cloudfetchtitle').call({"url": url});
    callback(url, title: retval.data["title"]);
  } on FirebaseFunctionsException catch (e) {
    String error = [e.toString().trim(), if (e.details != null) e.details].join(', ');
    callback(url, error: error);
  }
}
