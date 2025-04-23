import 'package:flutter/material.dart';
import 'package:nerdster/oneofus/ui/linky.dart';
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
            // Doesn't work in debug Chrome, but seems to do in PROD
            Linky('''Contact: contact@nerdster.org'''),
            const SizedBox(height: 10),
            Text('Package name: ${_packageInfo.packageName}'),
            Text('Version: ${_packageInfo.version}'),
            GestureDetector(
                onTap: () {
                  taps++;
                  if (taps >= 7 && !Prefs.dev.value) {
                    Prefs.dev.value = true;
                    const String message = 'You are now a developer.';
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text(message)));
                    print(message);
                  }
                },
                child: Text('Build number: ${_packageInfo.buildNumber}')),
          ]),
        ));
  }
}
