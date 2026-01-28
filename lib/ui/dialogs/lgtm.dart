import 'package:flutter/material.dart';
import 'package:nerdster/models/content_statement.dart';
import 'package:nerdster/app.dart';
import 'package:nerdster/ui/json_display.dart';
import 'package:nerdster/logic/interpreter.dart';
import 'package:nerdster/logic/labeler.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:nerdster/ui/ok_cancel.dart';
import 'package:nerdster/ui/linky.dart';
import 'package:nerdster/ui/my_checkbox.dart';
import 'package:nerdster/settings/prefs.dart';
import 'package:nerdster/settings/setting_type.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/config.dart';
import 'package:nerdster/util_ui.dart';

class Lgtm {
  static Future<bool?> check(Json json, BuildContext context, {required Labeler labeler}) async {
    if (isSmall.value || Setting.get<bool>(SettingType.skipLgtm).value) return true;

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
                        Linky('''For your review: Nerd'ster intends to:
- Sign the statemet below using its delegate key (which you signed using your identity key)
- Publish it at: ${uri.toString()}'''),
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
                                    child: MyCheckbox(
                                        Setting.get<bool>(SettingType.skipLgtm).notifier,
                                        '''Don't show again'''))),
                          ],
                        ),
                      ],
                    )))));
  }
}
