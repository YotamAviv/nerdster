import 'dart:async';
import 'dart:collection';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:nerdster/content/content_types.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/ok_cancel.dart';
import 'package:nerdster/oneofus/util.dart';

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
      builder: (BuildContext context) => const Dialog(child: SubjectFields()));
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
    // TODO: I would think I need to stop listening, and I might be leaking Controllers, too.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    key2controller = LinkedHashMap<String, TextEditingController>();
    fields = <TextField>[];
    String typeLabel = contentType.label;
    List<Map<String, String>> listField2type = contentType2field2type[typeLabel]!;
    for (Map<String, String> map in listField2type) {
      for (MapEntry entry in map.entries) {
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
    }

    return Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
                    value: type, label: type.label, leadingIcon: type.icon);
              }).toList(),
            ),
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
