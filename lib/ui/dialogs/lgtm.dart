import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nerdster/app.dart';
import 'package:nerdster/config.dart';
import 'package:nerdster_common/ui/json_interpreter.dart';
import 'package:nerdster/logic/labeler.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nerdster/settings/prefs.dart';
import 'package:nerdster/settings/setting_type.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/ui/util_ui.dart';
import 'package:oneofus_common/ui/json_display.dart';

class Lgtm {
  static Future<bool?> check(Json json, BuildContext context,
      {required Labeler labeler, OverlayState? overlayState}) async {
    if (!Setting.get<bool>(SettingType.lgtm).value) return true;
    assert(signInState.delegate != null);

    final spec = signInState.delegate!;
    final Uri uri = Uri.parse(FirebaseConfig.contentUrl)
        .replace(queryParameters: {'spec': spec});

    if (overlayState != null) {
      final completer = Completer<bool?>();
      late OverlayEntry entry;
      void close(bool? result) {
        entry.remove();
        if (!completer.isCompleted) completer.complete(result);
      }
      entry = OverlayEntry(builder: (_) => Material(
        type: MaterialType.transparency,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: _LgtmSheet(
            json: json, labeler: labeler, uri: uri,
            onConfirm: () => close(true), onCancel: () => close(null),
          ),
        ),
      ));
      overlayState.insert(entry);
      return completer.future;
    }

    return showModalBottomSheet<bool?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black45,
      builder: (context) => _LgtmSheet(
        json: json, labeler: labeler, uri: uri,
        onConfirm: () => Navigator.pop(context, true),
        onCancel: () => Navigator.pop(context, null),
      ),
    );
  }

  /// Shows the second FYI card after the statement has been published and signed.
  static Future<void> showPublished(Json signedJson, BuildContext context,
      {required Labeler labeler}) async {
    if (!Setting.get<bool>(SettingType.lgtm).value) return;
    if (!context.mounted) return;

    final spec = signInState.delegate!;
    final Uri uri = Uri.parse(FirebaseConfig.contentUrl)
        .replace(queryParameters: {'spec': spec});

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black45,
      builder: (context) => _LgtmPublishedSheet(
        json: signedJson, labeler: labeler, uri: uri,
        onClose: () => Navigator.pop(context),
      ),
    );
  }
}

// ─── Shared widgets ─────────────────────────────────────────────────────────

Widget _buildDragHandle() => Center(
  child: Container(
    width: 36, height: 4,
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: Colors.grey[300],
      borderRadius: BorderRadius.circular(2),
    ),
  ),
);

class _LinkRow extends StatelessWidget {
  final Uri uri;
  final Labeler labeler;
  final ValueNotifier<bool> interpret;
  const _LinkRow({required this.uri, required this.labeler, required this.interpret});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: interpret,
      builder: (context, interpreted, _) {
        final spec = uri.queryParameters['spec'] ?? '';
        final label = labeler.getLabel(spec);
        final baseUrl = uri.replace(queryParameters: {}).toString().replaceAll('?', '');
        final linkStyle = const TextStyle(fontSize: 11, color: Colors.blue, decoration: TextDecoration.underline);
        return GestureDetector(
          onTap: () => launchUrl(uri, mode: LaunchMode.externalApplication),
          child: interpreted
              ? Text(label, style: linkStyle, maxLines: 1, overflow: TextOverflow.ellipsis)
              : RichText(
                  text: TextSpan(style: linkStyle, children: [
                    TextSpan(text: '$baseUrl?spec=\n'),
                    TextSpan(text: spec),
                  ]),
                ),
        );
      },
    );
  }
}

// ─── Card 1: before publishing ───────────────────────────────────────────────

class _LgtmSheet extends StatefulWidget {
  final Json json;
  final Labeler labeler;
  final Uri uri;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _LgtmSheet({
    required this.json, required this.labeler, required this.uri,
    required this.onConfirm, required this.onCancel,
  });

  @override
  State<_LgtmSheet> createState() => _LgtmSheetState();
}

class _LgtmSheetState extends State<_LgtmSheet> {
  final ValueNotifier<bool> _interpret = ValueNotifier(true);

  @override
  void dispose() { _interpret.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDragHandle(),
          const Text(
            'FYI: To be signed and published using the nerdster.org delegate key (which you signed using your identity key)',
            style: TextStyle(fontSize: 13, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          _LinkRow(uri: widget.uri, labeler: widget.labeler, interpret: _interpret),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: isSmall.value ? 200 : 280),
            child: ClipRRect(
              borderRadius: kBorderRadius,
              child: Container(
                color: Colors.grey[50],
                child: JsonDisplay(widget.json,
                    interpret: _interpret,
                    interpreter: JsonInterpreter(widget.labeler)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: widget.onCancel, child: const Text('Cancel')),
              const SizedBox(width: 8),
              FilledButton(onPressed: widget.onConfirm, child: const Text('Okay')),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Card 2: after publishing ────────────────────────────────────────────────

class _LgtmPublishedSheet extends StatefulWidget {
  final Json json;
  final Labeler labeler;
  final Uri uri;
  final VoidCallback onClose;

  const _LgtmPublishedSheet({
    required this.json, required this.labeler, required this.uri, required this.onClose,
  });

  @override
  State<_LgtmPublishedSheet> createState() => _LgtmPublishedSheetState();
}

class _LgtmPublishedSheetState extends State<_LgtmPublishedSheet> {
  final ValueNotifier<bool> _interpret = ValueNotifier(true);

  @override
  void dispose() { _interpret.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDragHandle(),
          const Text(
            'Published ✓',
            style: TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          _LinkRow(uri: widget.uri, labeler: widget.labeler, interpret: _interpret),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: isSmall.value ? 200 : 280),
            child: ClipRRect(
              borderRadius: kBorderRadius,
              child: Container(
                color: Colors.grey[50],
                child: JsonDisplay(widget.json,
                    interpret: _interpret,
                    interpreter: JsonInterpreter(widget.labeler),
                    keyColors: const {'signature': Colors.red}),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(onPressed: widget.onClose, child: const Text('Okay')),
          ),
        ],
      ),
    );
  }
}
