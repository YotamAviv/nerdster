import 'package:flutter/material.dart';
import 'package:nerdster/main.dart';
import 'package:nerdster/oneofus/json_display.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/ok_cancel.dart';
import 'package:nerdster/oneofus/ui/linky.dart';
import 'package:nerdster/oneofus/ui/my_checkbox.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/prefs.dart';
import 'package:nerdster/singletons.dart';

class Lgtm {
  static Future<bool?> check(Json json, BuildContext context) async {
    if (isSmall.value || Prefs.skipLgtm.value) return true;
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
- Sign the statemet below using its delegate key (which you signed using your one-of-us key)
- Publish it at: https://export.nerdster.org/?token=${signInState.signedInDelegate}'''),
                        SizedBox(height: 300, child: JsonDisplay(json)),
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
                                child: MyCheckbox(Prefs.skipLgtm, '''Don't show again''')),
                          ],
                        ),
                      ],
                    )))));
  }
}
