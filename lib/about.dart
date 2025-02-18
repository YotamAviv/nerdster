import 'package:flutter/material.dart';
import 'package:nerdster/oneofus/ui/linky.dart';
import 'package:nerdster/prefs.dart';
import 'package:package_info_plus/package_info_plus.dart';

// CODE: Duplicated from Oneofus
class About extends StatelessWidget {
  static late final About singleton;

  final PackageInfo _packageInfo;
  const About._internal(this._packageInfo, {super.key});

  static Future<void> show(BuildContext context) async {
    return showDialog(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          final mediaSize = MediaQuery.of(context).size;
          return Dialog(
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
  Widget build(BuildContext context) {
    int taps = 0;
    return Scaffold(
        appBar: AppBar(title: const Text('''Nerd'ster!''')),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(20.0), children: [
            Linky('''Home: https://nerdster.org'''),
            // TODO: Doesn't work in debug Chrome. Hope for PROD'; delete if doesn't work
            Linky('''Contact: contact@nerdster.org'''),
            const SizedBox(height: 10),
            Text('Package name: ${_packageInfo.packageName}'),
            Text('Version: ${_packageInfo.version}'),
            GestureDetector(
                onTap: () {
                  taps++;
                  if (taps >= 7) {
                    Prefs.dev.value = true;
                    print('You are now a developer.');
                  }
                },
                child: Text('Build number: ${_packageInfo.buildNumber}')),
          ]),
        ));
  }
}
