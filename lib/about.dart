import 'package:flutter/material.dart';
import 'package:nerdster/oneofus/ui/linky.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/prefs.dart';
import 'package:package_info_plus/package_info_plus.dart';

// CODE: Duplicated from Oneofus
class About extends StatelessWidget {
  static late final About singleton;

  final PackageInfo _packageInfo;
  const About._internal(this._packageInfo);

  static Future<void> show(BuildContext context) async {
    return showDialog(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          final mediaSize = MediaQuery.of(context).size;
          return Dialog(
              shape: RoundedRectangleBorder(borderRadius: kBorderRadius),
              child: SizedBox(
                  width: mediaSize.width / 2,
                  height: (MediaQuery.of(context).size).height / 2,
                  child: singleton));
        });
  }

  static Future<void> init() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    singleton = About._internal(packageInfo);
  }

  @override
  @override
  Widget build(BuildContext context) {
    int taps = 0;
    return SafeArea(
      child: Padding(
        padding: kPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Nerd\'ster!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Linky('Home: https://nerdster.org'),
            Linky('Contact: contact@nerdster.org'),
            const SizedBox(height: 10),
            Text('Package name: ${_packageInfo.packageName}'),
            Text('Version: ${_packageInfo.version}'),
            GestureDetector(
              onTap: () {
                taps++;
                if (taps >= 7 && !Setting.get<bool>(SettingType.dev).value) {
                  Setting.get<bool>(SettingType.dev).value = true;
                  const String message = 'You are now a developer.';
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text(message)),
                  );
                  print(message);
                }
              },
              child: Text('Build number: ${_packageInfo.buildNumber}'),
            ),
          ],
        ),
      ),
    );
  }
}
