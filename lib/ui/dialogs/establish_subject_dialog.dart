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
                borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
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
  // When magicPaste returns a high-confidence title, lock the field so users don't
  // rewrite the canonical subject identity into what should be a comment (Option A,
  // see doc/content_submission.md §10). Tapping the lock icon re-enables editing.
  bool _titleLocked = false;
  // Debounce url-field edits so a paste (or a finished-typing URL) triggers a
  // fetch, and remember the last url fetched to avoid refetching the same one.
  Timer? _urlDebounce;
  String? _lastFetchedUrl;
  List<TextField> fields = [];

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  @override
  void dispose() {
    _urlDebounce?.cancel();
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
    // A manual type change (or fresh init) invalidates any locked fetched title
    // and clears all fields (fields are re-created empty below).
    _titleLocked = false;
    // 1. Create new controllers first
    final LinkedHashMap<String, TextEditingController> newControllers =
        LinkedHashMap.of({}); // Correctly init map

    contentType.type2field2type.forEach((key, type) {
      // Start empty: changing type clears all fields.
      final controller = TextEditingController();
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
    // While a fetch is in flight, all fields are read-only until the response arrives.
    final bool fetching = isMagicPasting.value;
    fields = key2controller.entries.map((entry) {
      final bool locked = entry.key == 'title' && _titleLocked;
      return TextField(
        controller: entry.value,
        readOnly: locked || fetching,
        onChanged: entry.key == 'url' ? _onUrlChanged : null,
        decoration: InputDecoration(
          labelText: entry.key,
          border: const OutlineInputBorder(),
          filled: locked,
          fillColor: locked ? Colors.grey.shade100 : null,
          // Compact escape hatch (fits limited phone width): tap the lock to edit anyway.
          suffixIcon: locked
              ? IconButton(
                  icon: const Icon(Icons.lock_outline, size: 20),
                  tooltip: 'Title fetched. Tap to edit anyway.',
                  onPressed: () => setState(() {
                    _titleLocked = false;
                    _rebuildFields();
                  }),
                )
              : null,
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

  /// Magic-paste icon: read a URL from the clipboard and fetch its metadata.
  Future<void> _handleMagicPaste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();

    if (text == null || text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Clipboard is empty.')));
      }
      return;
    }

    final uri = Uri.tryParse(text);
    if (uri == null || !['http', 'https'].contains(uri.scheme)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Clipboard does not contain a valid URL.')));
      }
      return;
    }

    await _fetchAndPopulate(text);
  }

  /// Called as the user edits the url field. Debounced so a paste (or a URL the
  /// user finished typing) triggers a fetch, just like the magic-paste icon does.
  void _onUrlChanged(String value) {
    _urlDebounce?.cancel();
    final trimmed = value.trim();
    final uri = Uri.tryParse(trimmed);
    final bool isUrl =
        uri != null && ['http', 'https'].contains(uri.scheme) && uri.host.contains('.');
    if (!isUrl || trimmed == _lastFetchedUrl) return;
    _urlDebounce = Timer(const Duration(milliseconds: 600), () => _fetchAndPopulate(trimmed));
  }

  /// Shared fetch + populate used by both the magic-paste icon and a url paste.
  /// Locks all fields while the request is in flight (the spinner keeps showing).
  Future<void> _fetchAndPopulate(String url) async {
    if (isMagicPasting.value) return; // a fetch is already in flight
    isMagicPasting.value = true;
    setState(_rebuildFields); // make fields read-only while fetching

    try {
      final metadata = await magicPaste(url);

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
        if (metadata['title'] == null || metadata['title'] == 'Error') {
          return;
        }
      }

      _lastFetchedUrl = url;

      setState(() {
        // 1. Switch Content Type if detected and different (clears fields for the new type).
        if (metadata['contentType'] != null) {
          try {
            final newType = ContentType.values.byName(metadata['contentType']);
            if (newType != contentType) {
              contentType = newType;
              _initControllers();
            }
          } catch (e) {
            debugPrint('Unknown detected content type: ${metadata['contentType']}');
          }
        }

        // 2. Populate Fields - with safety checks for controllers existing
        if (key2controller.containsKey('url')) {
          final resolvedUrl = (metadata['canonicalUrl'] ?? url) as String;
          key2controller['url']!.text = resolvedUrl;
        }

        if (key2controller.containsKey('title') && metadata['title'] != null) {
          key2controller['title']!.text = metadata['title'];
        }

        if (key2controller.containsKey('year') && metadata['year'] != null) {
          key2controller['year']!.text = metadata['year'].toString();
        }

        if (key2controller.containsKey('author') && metadata['author'] != null) {
          key2controller['author']!.text = metadata['author'];
        }

        // Lock the title when the backend is confident it's the canonical title
        // (Option A, doc/content_submission.md §10). Low/none stays editable.
        _titleLocked = metadata['titleConfidence'] == 'high';
        _validate();
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      isMagicPasting.value = false;
      // Re-enable editing (except a locked title) now that the response is in.
      if (mounted) setState(_rebuildFields);
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
              child: Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 14),
                  children: [
                    const TextSpan(
                        text: 'Define the Subject you want to rate, comment on, etc.\n\n'),
                    const TextSpan(
                        text:
                            'The Nerdster uses the logical subject, not a specific product listing. '),
                    const TextSpan(
                        text:
                            'For example, a book is defined by title and author, not by an Amazon or Goodreads link.\n\n'),
                    const TextSpan(
                        text:
                            'Correcting subjects is always possible using EQUATE; click on the link icons ('),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Icon(Icons.link, size: 16, color: Colors.blue),
                    ),
                    const TextSpan(text: ') to do that.'),
                  ],
                ),
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
            small ? 'What?' : 'Logical Subject?',
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
                          small ? 'Subject' : 'Establish Logical Subject',
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
