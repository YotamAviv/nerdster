import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nerdster/models/content_types.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:nerdster/logic/metadata_service.dart';
import 'package:nerdster/ui/util/ok_cancel.dart';
import 'package:nerdster/ui/util_ui.dart';

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
  return showModalBottomSheet<Jsonish?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => Theme(
          data: Theme.of(context),
          child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding:
                  EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
              child: SingleChildScrollView(child: SubjectFields()))));
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
  final List<ContentType> types = ContentType.values;
  final _FetchingUrlWidget fetchingUrlWidget = _FetchingUrlWidget();
  final ValueNotifier<bool> okEnabled = ValueNotifier(false);
  final ValueNotifier<bool> isMagicPasting = ValueNotifier(false);
  List<TextField> fields = [];

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  @override
  void dispose() {
    for (final controller in key2controller.values) {
      controller.dispose();
    }
    okEnabled.dispose();
    isMagicPasting.dispose();
    super.dispose();
  }

  void _validate() {
    bool valid = true;
    for (final entry in key2controller.entries) {
      if (entry.value.text.trim().isEmpty) {
        valid = false;
        break;
      }
    }
    if (valid && contentType.type2field2type.containsKey('url')) {
      final url = key2controller['url']?.text.trim() ?? '';
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme || !['http', 'https'].contains(uri.scheme)) {
        valid = false;
      }
    }
    if (valid != okEnabled.value) {
      okEnabled.value = valid;
    }
  }

  void _initControllers() {
    key2controller.clear();
    for (MapEntry<String, String> entry in contentType.type2field2type.entries) {
      final key = entry.key;
      final controller = TextEditingController();
      key2controller[key] = controller;
      controller.addListener(_validate);

      // Special case: auto-fill title from url
      if (key == 'url') {
        controller.addListener(_listenForUrlTitle);
      }
    }
    _rebuildFields();
    _validate();
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
        fetchingUrlWidget.message.value = error ?? 'Title fetched from URL.';
        fetchingUrlWidget.isError.value = error != null;
        if (error != null) {
          print(error);
        }
      }
    });
  }


  void _okHandler() async {
    Json map = <String, dynamic>{};
    map['contentType'] = contentType.label;
    for (final entry in key2controller.entries) {
      final value = entry.value.text.trim();
      map[entry.key] = value;
    }
    final Jsonish subject = Jsonish(map);
    Navigator.pop(context, subject);
  }

  Future<void> _handleMagicPaste() async {
    isMagicPasting.value = true;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();

      if (text == null || text.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Clipboard is empty.')));
        return;
      }
      
      // Basic URL Check
      final uri = Uri.tryParse(text);
      if (uri == null || !['http', 'https'].contains(uri.scheme)) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Clipboard does not contain a valid URL.')));
        return;
      }

      // Call Cloud Function
      final metadata = await magicPaste(text);
      
      if (!mounted) return;

      if (metadata == null) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not fetch details for this URL.')));
         return;
      }

      setState(() {
         // 1. Switch Content Type if detected and different
         if (metadata['contentType'] != null) {
            try {
               final newType = ContentType.values.byName(metadata['contentType']);
               if (newType != contentType) {
                  contentType = newType;
                  // Re-init controllers for new type
                  for (final controller in key2controller.values) controller.dispose();
                  _initControllers(); 
               }
            } catch (e) {
               // Initial Content Type guess failed or not in our enum
               debugPrint('Unknown detected content type: ${metadata['contentType']}');
            }
         }

         // 2. Populate Fields - with safety checks for controllers existing
         // URL
         if (key2controller.containsKey('url')) {
            key2controller['url']!.text = metadata['canonicalUrl'] ?? text;
         }
         
         // Title
         if (key2controller.containsKey('title') && metadata['title'] != null) {
            key2controller['title']!.text = metadata['title'];
         }

         // Year
         if (key2controller.containsKey('year') && metadata['year'] != null) {
            key2controller['year']!.text = metadata['year'].toString();
         }

         // Author
         if (key2controller.containsKey('author') && metadata['author'] != null) {
            key2controller['author']!.text = metadata['author'];
         }

         // Validate form
         _validate();
      });

    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
       isMagicPasting.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget cornerWidget = const SizedBox(width: 80.0);
    if (!contentType.type2field2type.containsKey('url')) {
      cornerWidget = SizedBox(
        width: 80.0,
        child: Align(
          alignment: Alignment.centerRight,
          child: Tooltip(
            message: '''A ${contentType.label} doesn't have a singular URL.
In case multiple people rate a book, their ratings will be grouped correctly only if they all use the same fields and values.
You can include a URL in a comment or relate or equate this book to an article with a URL.''',
            child: Text('no URL?', style: linkStyle),
          ),
        ),
      );
    } else {
      cornerWidget = SizedBox(
        width: 80.0,
        child: Align(
          alignment: Alignment.centerRight,
          child: fetchingUrlWidget,
        ),
      );
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
              SizedBox(
                width: 80.0,
                child: ValueListenableBuilder<bool>(
                  valueListenable: isMagicPasting,
                  builder: (context, isLoading, child) {
                    if (isLoading) {
                      return const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)));
                    }
                    return IconButton(
                      icon: const Icon(Icons.content_paste_go, color: Colors.blueAccent),
                      tooltip: 'Magic Paste (Detect from Clipboard)',
                      onPressed: _handleMagicPaste,
                    );
                  },
                ),
              ),
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
                  dropdownMenuEntries: types
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
          OkCancel(_okHandler, 'Establish Subject', okEnabled: okEnabled),
        ],
      ),
    );
  }
}

void tryFetchTitle(
    String url, Function(String url, {String? title, String? error}) callback) async {
  if (!url.startsWith('http://') && !url.startsWith('https://')) return;
  try {
    final title = await fetchTitle(url);
    callback(url, title: title);
  } catch (e) {
    callback(url, error: e.toString());
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
