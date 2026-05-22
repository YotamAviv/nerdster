import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:nerdster/app.dart';
import 'package:nerdster/config.dart';
import 'package:nerdster_common/ui/json_interpreter.dart';
import 'package:nerdster/logic/labeler.dart';

import 'package:nerdster/settings/prefs.dart';
import 'package:nerdster/settings/setting_type.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/ui/util/linky.dart';
import 'package:nerdster/ui/util/my_checkbox.dart';
import 'package:nerdster/ui/util/ok_cancel.dart';
import 'package:nerdster/ui/util_ui.dart';
import 'package:oneofus_common/ui/json_display.dart';

class Lgtm {
  /// Shows the FYI dialog. When [overlayState] is provided, the dialog is
  /// inserted as an overlay entry (painted above everything already in that
  /// overlay) so it doesn't fight with manually-managed overlay panels.
  static Future<bool?> check(Json json, BuildContext context,
      {required Labeler labeler, OverlayState? overlayState}) async {
    if (isSmall.value || !Setting.get<bool>(SettingType.lgtm).value) return true;

    assert(signInState.delegate != null);

    final spec = signInState.delegate!;
    final Uri uri = Uri.parse(FirebaseConfig.contentUrl)
        .replace(queryParameters: {'spec': jsonEncode(spec)});

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
          child: Center(
            child: _LgtmContent(
              uri: uri,
              json: json,
              labeler: labeler,
              onConfirm: () => close(true),
              onCancel: () => close(null),
            ),
          ),
        );
      });

      overlayState.insert(entry); // inserts at the top — above all existing entries
      return completer.future;
    }

    return showDialog<bool?>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: kBorderRadius),
            child: Padding(
                padding: kPadding,
                child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 700,
                      maxHeight: 500,
                    ),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        Linky(
                            '''FYI: To be signed using the nerdster.org delegate key (which you signed using your identity key) and published at: ${uri.toString()}\n'''),
                        SizedBox(
                            height: 300,
                            child: JsonDisplay(json,
                                interpret: ValueNotifier(true),
                                interpreter: JsonInterpreter(labeler))),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Spacer(),
                            OkCancel(() {
                              Navigator.pop(context, true);
                            }, 'Looks Good To Me'),
                            Expanded(
                                child: Align(
                                    alignment: Alignment.centerRight,
                                    child: MyCheckbox(Setting.get<bool>(SettingType.lgtm).notifier,
                                        '''Don't show again'''))),
                          ],
                        ),
                      ],
                    )))));
  }
}

class _LgtmContent extends StatelessWidget {
  final Uri uri;
  final Json json;
  final Labeler labeler;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _LgtmContent({
    required this.uri,
    required this.json,
    required this.labeler,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: kBorderRadius),
      child: Padding(
        padding: kPadding,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700, maxHeight: 500),
          child: ListView(
            shrinkWrap: true,
            children: [
              Linky(
                  '''FYI: To be signed using the nerdster.org delegate key (which you signed using your identity key) and published at: ${uri.toString()}\n'''),
              SizedBox(
                  height: 300,
                  child: JsonDisplay(json,
                      interpret: ValueNotifier(true),
                      interpreter: JsonInterpreter(labeler))),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Spacer(),
                  OutlinedButton(onPressed: onConfirm, child: const Text('Looks Good To Me')),
                  const SizedBox(width: 8),
                  OutlinedButton(onPressed: onCancel, child: const Text('Cancel')),
                  Expanded(
                      child: Align(
                          alignment: Alignment.centerRight,
                          child: MyCheckbox(
                              Setting.get<bool>(SettingType.lgtm).notifier, "Don't show again"))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
