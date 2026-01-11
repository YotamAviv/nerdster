import 'package:flutter/material.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/app.dart';
import 'package:nerdster/v2/json_display.dart';
import 'package:nerdster/v2/interpreter.dart';
import 'package:nerdster/v2/labeler.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/ok_cancel.dart';
import 'package:nerdster/oneofus/ui/linky.dart';
import 'package:nerdster/oneofus/ui/my_checkbox.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/setting_type.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/v2/config.dart';

class Lgtm {
  static Future<bool?> check(Json json, BuildContext context, {required V2Labeler labeler}) async {
    if (Setting.get<bool>(SettingType.skipLgtm).value) return true;

    assert(b(signInState.delegate));

    var spec = signInState.delegate!;
    Uri uri = V2Config.makeSimpleUri(kNerdsterDomain, spec);

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
                            child: V2JsonDisplay(json,
                                interpret: ValueNotifier(true),
                                interpreter: V2Interpreter(labeler))),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SizedBox(width: 200.0),
                            OkCancel(() {
                              Navigator.pop(context, true);
                            }, 'Looks Good To Me'),
                            SizedBox(
                                width: 200.0,
                                child: MyCheckbox(Setting.get<bool>(SettingType.skipLgtm).notifier,
                                    '''Don't show again''')),
                          ],
                        ),
                      ],
                    )))));
  }
}
