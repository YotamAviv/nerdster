import 'package:flutter/material.dart';
import 'package:nerdster/app.dart';
import 'package:nerdster/config.dart';
import 'package:nerdster/logic/interpreter.dart';
import 'package:nerdster/logic/labeler.dart';
import 'package:nerdster/models/content_statement.dart';
import 'package:nerdster/settings/prefs.dart';
import 'package:nerdster/settings/setting_type.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/ui/util/linky.dart';
import 'package:nerdster/ui/util/my_checkbox.dart';
import 'package:nerdster/ui/util/ok_cancel.dart';
import 'package:nerdster/ui/util_ui.dart';
import 'package:oneofus_common/ui/json_display.dart';

class Lgtm {
  static Future<bool?> check(Json json, BuildContext context, {required Labeler labeler}) async {
    if (isSmall.value || !Setting.get<bool>(SettingType.lgtm).value) return true;

    assert(signInState.delegate != null);

    var spec = signInState.delegate!;
    Uri uri = FirebaseConfig.makeSimpleUri(kNerdsterDomain, spec);

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
                                interpreter: NerdsterInterpreter(labeler))),
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
