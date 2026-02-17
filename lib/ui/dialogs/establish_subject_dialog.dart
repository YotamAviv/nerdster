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
  // fetchingUrlWidget removed as auto-fetch is deprecated
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
    // 1. Create new controllers first
    final LinkedHashMap<String, TextEditingController> newControllers = LinkedHashMap.of({}); // Correctly init map

    contentType.type2field2type.forEach((key, type) {
      final controller = TextEditingController();
      // If we had a value for this key before (e.g. switching types but keeping 'title'), copy it over?
      // For now, let's keep it clean as different types might mean different things for 'title'.
      // But preserving 'title' is usually nice.
      if (key2controller.containsKey(key)) {
        try {
          controller.text = key2controller[key]!.text;
        } catch(e) { /* ignore if old controller is somehow dead */ }
      }
      newControllers[key] = controller;
      controller.addListener(_validate);
    });

    // 2. Safely dispose old controllers
    // We defer disposal to the end of the frame to ensure they aren't being used by the UI during the transition
    final oldControllers = key2controller.values.toList();
    // Be very careful about disposal timing. It's safer to just let GC handle it if we remove from map
    // OR create new, then dispose old immediately BUT the UI must rebuild WITH new ones first.
    // The previous error was because we disposed BEFORE rebuilding the fields list.
    // By creating new ones first, putting them in the map, and REBUILDING fields,
    // the UI will use the new ones on next build.
    // But we still need to dispose the old ones eventually.
    // Let's just create new, rebuild fields, and THEN dispose.
    
    key2controller.clear();
    key2controller.addAll(newControllers);

    _rebuildFields();
    
    // Now dispose old ones - safely.
    // Actually, since we replaced key2controller contents, the next build() will generate text fields with NEW controllers.
    // The OLD widgets are still holding the OLD controllers until that build happens.
    // So disposal MUST happen after next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final controller in oldControllers) {
         try { controller.dispose(); } catch(_) {}
      }
    });
  }

  void _rebuildFields() {
    fields = key2controller.entries.map((entry) {
      return TextField(
        controller: entry.value,
        decoration: InputDecoration(
          labelText: entry.key,
          border: const OutlineInputBorder(),
        ),
      );
    }).toList();
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
    // Help users understand why some types don't have URL fields
    if (!contentType.type2field2type.containsKey('url')) {
      cornerWidget = SizedBox(
        width: 80.0,
        child: Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: const Icon(Icons.help_outline, color: Colors.grey),
              tooltip: 'Why no URL field?',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Why No URL for ${contentType.label}?'),
                    content: Text(
                      'Nerdster tracks the logical subject (the work itself), not a specific product listing.\n\n'
                      'For example, a Book is defined by its Title and Author, not by its Amazon or Goodreads link.\n\n'
                      'This ensures that everyone rating "The Hobbit" is contributing to the same subject, regardless of which edition or store they bought it from.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Got it'),
                      ),
                    ],
                  ),
                );
              },
            )),
      );
    } else {
      cornerWidget = const SizedBox(width: 80); // Placeholder for alignment
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
