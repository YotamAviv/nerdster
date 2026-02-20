import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nerdster/app.dart';
import 'package:nerdster/models/content_types.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:nerdster/logic/metadata_service.dart';
import 'package:nerdster/ui/util/ok_cancel.dart';

/// Fetching URL Metadata:
/// Uses Firebase Cloud Functions (magicPaste) to extract title, author, year,
/// and image from URLs. The backend handles CORS and parsing Schema.org/OpenGraph metadata.

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
    final LinkedHashMap<String, TextEditingController> newControllers =
        LinkedHashMap.of({}); // Correctly init map

    contentType.type2field2type.forEach((key, type) {
      final controller = TextEditingController();
      // If we had a value for this key before (e.g. switching types but keeping 'title'), copy it over?
      // For now, let's keep it clean as different types might mean different things for 'title'.
      // But preserving 'title' is usually nice.
      if (key2controller.containsKey(key)) {
        try {
          controller.text = key2controller[key]!.text;
        } catch (e) {/* ignore if old controller is somehow dead */}
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
        try {
          controller.dispose();
        } catch (_) {}
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
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Clipboard is empty.')));
        return;
      }

      // Basic URL Check
      final uri = Uri.tryParse(text);
      if (uri == null || !['http', 'https'].contains(uri.scheme)) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Clipboard does not contain a valid URL.')));
        return;
      }

      // Call Cloud Function
      final metadata = await magicPaste(text);

      if (!mounted) return;

      if (metadata == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not fetch details for this URL.')));
        return;
      }

      // Handle known errors from robust logic
      if (metadata['error'] != null) {
        final errHelper = metadata['error'].toString();
        debugPrint('MagicPaste backend error: $errHelper');
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Metadata Fetch Failed: $errHelper')));
        // Still populate partial data if available (e.g. timeout might return partial?)
        // But usually we stop.
        if (metadata['title'] == null || metadata['title'] == 'Error') {
          return;
        }
      }

      setState(() {
        // 1. Switch Content Type if detected and different
        if (metadata['contentType'] != null) {
          try {
            final newType = ContentType.values.byName(metadata['contentType']);
            if (newType != contentType) {
              contentType = newType;
              // Re-init controllers for new type
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
    void showHelpDialog() {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Establish Subject'),
          content: Scrollbar(
            child: SingleChildScrollView(
              child: const Text(
                'Define the Subject you want to rate, comment on, etc.\n\n'
                'The Nerdster uses the logical subject, not a specific product listing. '
                'For example, a Book is defined by title and author, not by an Amazon or Goodreads link.\n\n'
                'Correcting subjects is always possible using EQUATE; click on the link icons to do that.',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
    }

    return ValueListenableBuilder<bool>(
      valueListenable: isSmall,
      builder: (context, small, _) {
        final Widget helpLink = GestureDetector(
          onTap: showHelpDialog,
          child: Text(
            small ? 'What?' : 'What is a Subject?',
            style: const TextStyle(
              color: Colors.blue,
              decoration: TextDecoration.underline,
              decorationColor: Colors.blue,
              fontSize: 12,
            ),
          ),
        );
        return Padding(
          padding: EdgeInsets.fromLTRB(small ? 4 : 12, 16, small ? 4 : 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Header: [dropdown] [📋 paste]   [Establish Subject]
              //                                  [What is a Subject?]
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left: type dropdown
                    DropdownMenu<ContentType>(
                      initialSelection: contentType,
                      requestFocusOnTap: true,
                      label: const Text('Type'),
                      onSelected: (ContentType? newType) {
                        if (newType == null || newType == contentType) return;
                        setState(() {
                          contentType = newType;
                          _initControllers();
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
                    // Magic paste button + loading spinner
                    ValueListenableBuilder<bool>(
                      valueListenable: isMagicPasting,
                      builder: (context, isLoading, child) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.content_paste_go,
                                  color: isLoading
                                      ? Colors.blueAccent.withOpacity(0.4)
                                      : Colors.blueAccent),
                              iconSize: 32,
                              tooltip: '''Paste link to fill fields.
Copy a web URL or a Share link first.''',
                              onPressed: isLoading ? null : _handleMagicPaste,
                            ),
                            if (isLoading)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                          ],
                        );
                      },
                    ),
                    const Spacer(),
                    // Right: title top, help link bottom
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          small ? 'Subject' : 'Establish Subject',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        helpLink,
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ...fields.expand((f) => [f, const SizedBox(height: 8)]),
              OkCancel(_okHandler, 'Establish Subject', okEnabled: okEnabled),
            ],
          ),
        );
      },
    );
  }
}
