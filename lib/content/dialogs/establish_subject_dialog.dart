import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/content/content_types.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
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

late final FirebaseFunctions? _functions = FireFactory.findFunctions(kNerdsterDomain);

Future<Jsonish?> establishSubjectDialog(BuildContext context) {
  double width = max(MediaQuery.of(context).size.width / 2, 500);
  return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: kBorderRadius),
          child: SizedBox(width: width, child: SubjectFields())));
}

class SubjectFields extends StatefulWidget {
  const SubjectFields({super.key});

  @override
  State<SubjectFields> createState() => _SubjectFieldsState();
}

class _SubjectFieldsState extends State<SubjectFields> {
  ContentType contentType = ContentType.article;
  final LinkedHashMap<String, TextEditingController> key2controller =
      LinkedHashMap<String, TextEditingController>();
  final List<ContentType> typesMinusAll = List.from(ContentType.values)..removeAt(0);
  final _FetchingUrlWidget fetchingUrlWidget = _FetchingUrlWidget();
  List<TextField> fields = [];

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    key2controller.clear();
    for (MapEntry<String, String> entry in contentType.type2field2type.entries) {
      final key = entry.key;
      final controller = TextEditingController();
      key2controller[key] = controller;

      // Special case: auto-fill title from url
      if (key == 'url') {
        controller.addListener(_listenForUrlTitle);
      }
    }
    _rebuildFields();
  }

  void _rebuildFields() {
    fields = key2controller.entries.map((entry) {
      return TextField(
        decoration: InputDecoration(
          hintText: entry.key,
          hintStyle: hintStyle,
          border: const OutlineInputBorder(),
        ),
        controller: entry.value,
      );
    }).toList();
  }

  void _listenForUrlTitle() {
    final urlController = key2controller['url'];
    final titleController = key2controller['title'];
    if (urlController == null || titleController == null || urlController.text.isEmpty) return;

    fetchingUrlWidget.isRunning.value = true;

    tryFetchTitle(urlController.text, (String url, {String? title, String? error}) {
      if (urlController.text == url) {
        fetchingUrlWidget.isRunning.value = false;
        if (title != null) {
          titleController.text = title;
        }
        fetchingUrlWidget.message.value = b(error) ? error! : 'Title fetched from URL.';
        fetchingUrlWidget.isError.value = b(error);
        if (error != null) {
          print(error);
        }
      }
    });
  }

  void _okHandler() async {
    Map<String, dynamic> map = <String, dynamic>{};
    map['contentType'] = contentType.label;
    for (final entry in key2controller.entries) {
      final value = entry.value.text.trim();
      map[entry.key] = value;
    }
    final Jsonish subject = Jsonish(map);
    Navigator.pop(context, subject);
  }

  @override
  void dispose() {
    for (final controller in key2controller.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget cornerWidget = const SizedBox(width: 80.0);
    if (!contentType.type2field2type.containsKey('url')) {
      cornerWidget = SizedBox(
        width: 80.0,
        child: Tooltip(
          message: '''A ${contentType.label} doesn't have a singular URL.
In case multiple people rate a book, their ratings will be grouped correctly only if they all use the same fields and values.
You can include a URL in a comment or relate or equate this book to an article with a URL.''',
          child: Text('no URL?', style: linkStyle),
        ),
      );
    } else {
      cornerWidget = fetchingUrlWidget;
    }

    return Padding(
      padding: kTallPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 80.0),
              DropdownMenu<ContentType>(
                initialSelection: contentType,
                requestFocusOnTap: true,
                label: const Text('Type'),
                onSelected: (ContentType? newType) {
                  if (newType == null || newType == contentType) return;
                  setState(() {
                    // Clean up old controllers
                    for (final controller in key2controller.values) {
                      controller.dispose();
                    }
                    contentType = newType;
                    fetchingUrlWidget.isError.value = false;
                    fetchingUrlWidget.isRunning.value = false;
                    fetchingUrlWidget.message.value = '';
                    _initControllers(); // Create new controllers + fields
                  });
                },
                dropdownMenuEntries: typesMinusAll
                    .map((type) => DropdownMenuEntry<ContentType>(
                          value: type,
                          label: type.label,
                          leadingIcon: Icon(type.iconDatas.$1),
                        ))
                    .toList(),
              ),
              cornerWidget,
            ],
          ),
          const SizedBox(height: 10),
          ...fields,
          const SizedBox(height: 10),
          OkCancel(_okHandler, 'Establish Subject'),
        ],
      ),
    );
  }
}

void tryFetchTitle(String url, Function(String url, {String title, String error}) callback) async {
  if (_functions == null) return;
  if (!url.startsWith('http://') && !url.startsWith('https://')) return;
  try {
    var retval = await _functions!.httpsCallable('cloudfetchtitle').call({"url": url});
    callback(url, title: retval.data["title"]);
  } on FirebaseFunctionsException catch (e) {
    String error = [e.message, if (e.details != null) e.details].join(', ');
    callback(url, error: error);
  }
}

class _FetchingUrlWidget extends StatefulWidget {
  final ValueNotifier<bool> isRunning = ValueNotifier(false);
  final ValueNotifier<bool> isError = ValueNotifier(false);
  final ValueNotifier<String> message = ValueNotifier('');

  @override
  State<StatefulWidget> createState() => _FetchingUrlWidgetState();
}

class _FetchingUrlWidgetState extends State<_FetchingUrlWidget> {
  @override
  void initState() {
    super.initState();
    widget.isRunning.addListener(listener);
    widget.message.addListener(listener);
  }

  @override
  void dispose() {
    widget.isRunning.removeListener(listener);
    widget.message.removeListener(listener);
    super.dispose();
  }

  void listener() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
        message: widget.message.value,
        child: Icon(!widget.isRunning.value ? Icons.refresh : Icons.rotate_right_outlined,
            color: widget.isRunning.value
                ? Colors.green
                : widget.isError.value
                    ? Colors.red
                    : Colors.black));
  }
}
