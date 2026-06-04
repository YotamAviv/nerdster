import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nerdster/app.dart';
import 'package:nerdster_common/ui/json_interpreter.dart';
import 'package:nerdster/logic/labeler.dart';

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

    if (overlayState != null) {
      final completer = Completer<bool?>();
      late OverlayEntry entry;

      void close(bool? result) {
        entry.remove();
        if (!completer.isCompleted) completer.complete(result);
      }

      entry = OverlayEntry(builder: (_) {
        return Material(
          type: MaterialType.transparency,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: _LgtmSheet(
              json: json,
              labeler: labeler,
              onConfirm: () => close(true),
              onCancel: () => close(null),
            ),
          ),
        );
      });

      overlayState.insert(entry);
      return completer.future;
    }

    return showModalBottomSheet<bool?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black45,
      builder: (context) => _LgtmSheet(
        json: json,
        labeler: labeler,
        onConfirm: () => Navigator.pop(context, true),
        onCancel: () => Navigator.pop(context, null),
      ),
    );
  }
}

class _LgtmSheet extends StatelessWidget {
  final Json json;
  final Labeler labeler;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _LgtmSheet({
    required this.json,
    required this.labeler,
    required this.onConfirm,
    required this.onCancel,
  });

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
          // drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            'FYI: To be signed and published using the nerdster.org delegate key (which you signed using your identity key)',
            style: TextStyle(fontSize: 13, color: Colors.black87),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: isSmall.value ? 220 : 300),
            child: ClipRRect(
              borderRadius: kBorderRadius,
              child: Container(
                color: Colors.grey[50],
                child: JsonDisplay(json,
                    interpret: ValueNotifier(true),
                    interpreter: JsonInterpreter(labeler)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: onCancel, child: const Text('Cancel')),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: onConfirm,
                child: const Text('Okay'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
