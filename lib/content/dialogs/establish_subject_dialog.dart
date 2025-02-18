import 'dart:async';
import 'dart:collection';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:nerdster/content/content_types.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/ok_cancel.dart';
import 'package:nerdster/oneofus/util.dart';
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
    if (key2controller['url']!.text.isEmpty) {
      return;
    }
    tryFetchTitle(key2controller['url']!.text, (url, title) {
      if (key2controller['url']!.text == url) {
        key2controller['title']!.text = title;
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
      fields.add(
        TextField(
          decoration: InputDecoration(
              hintText: hintText, hintStyle: hintStyle, border: const OutlineInputBorder()),
          controller: controller,
        ),
      );
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
                      value: type, label: type.label, leadingIcon: Icon (type.iconDatas.$1));
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

void tryFetchTitle(String url, Function(String, String) callback) {
  if (!url.startsWith('http://') && !url.startsWith('https://')) {
    return;
  }
  try {
    Uri uri = Uri.parse(url);
    print('uri=$uri');
  } catch (e) {
    print(e);
    return;
  }

  // Listen for something to arrive at collection, doesn't seem to work with fake fire
  final firestore = FirebaseFirestore.instance;
  String doc = clock.nowIso;

  StreamSubscription? subscription;

  void onDone() {
    if (b(subscription)) {
      subscription!.cancel();
      print('cancelled');
      subscription = null;
    }
  }

  void onData(DocumentSnapshot<Map<String, dynamic>> event) {
    Json? data = event.data();
    if (b(data) && b(data!['title'])) {
      String title = data['title'];
      print(title);
      callback(url, title);
      onDone();
    }
  }

  firestore.collection('urls').doc(doc).set({'url': url}).then((dummy) {
    subscription = firestore
        .collection('urls')
        .doc(doc)
        .snapshots()
        .listen(onData, cancelOnError: true, onDone: () {
      subscription!.cancel();
    });
    print('listening...');
  });
}
